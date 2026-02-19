-- ====================================================================
-- FIX SHOP-SPECIFIC MECHANIC ROUTING
-- ====================================================================
-- PROBLEM: When customer selects Shop B, request is being sent to 
-- mechanics from Shop A instead. System should only search for 
-- available mechanics within the selected shop.
--
-- SOLUTION: Update broadcast function to respect preferred_shop_id
-- ====================================================================

-- ====================================================================
-- 1. CREATE IMPROVED FUNCTION TO FIND SHOP-SPECIFIC MECHANICS
-- ====================================================================

CREATE OR REPLACE FUNCTION find_available_mechanics_in_shop(
    p_shop_id uuid,
    p_request_id uuid DEFAULT NULL
)
RETURNS TABLE(
    mechanic_id uuid,
    mechanic_name text,
    mechanic_status text,
    is_available boolean,
    current_jobs_count integer,
    phone_number text
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        mas.mechanic_id,
        up.first_name || ' ' || up.last_name as mechanic_name,
        mas.current_status,
        (mas.current_status = 'available' AND 
         mas.is_accepting_requests = true AND 
         mas.current_request_id IS NULL) as is_available,
        COALESCE(
            (SELECT COUNT(*) 
             FROM service_requests sr 
             WHERE sr.assigned_mechanic_id = mas.mechanic_id 
             AND sr.status IN ('accepted', 'in_progress', 'inspection_started', 'work_started')
            ), 0
        )::integer as current_jobs_count,
        up.phone_number
    FROM mechanic_availability_status mas
    JOIN user_profiles up ON up.id = mas.mechanic_id
    JOIN shop_mechanics sm ON sm.mechanic_id = mas.mechanic_id
    WHERE sm.shop_id = p_shop_id
      AND sm.is_active = true
      AND up.user_type = 'mechanic'
      AND up.status = 'active'
    ORDER BY 
        (mas.current_status = 'available' AND mas.is_accepting_requests = true) DESC,
        current_jobs_count ASC;
END;
$$ LANGUAGE plpgsql;

-- ====================================================================
-- 2. UPDATE BROADCAST FUNCTION TO RESPECT PREFERRED SHOP
-- ====================================================================

CREATE OR REPLACE FUNCTION broadcast_service_request_with_shop_filter(
    p_request_id uuid,
    p_max_radius_km numeric DEFAULT 25.0,
    p_response_timeout_minutes integer DEFAULT 30
)
RETURNS jsonb AS $$
DECLARE
    v_request_data record;
    v_mechanic record;
    v_notified_count integer := 0;
    v_available_count integer := 0;
    v_result jsonb;
    v_preferred_shop_id uuid;
BEGIN
    -- Get request details including preferred shop
    SELECT 
        customer_id, 
        pickup_latitude, 
        pickup_longitude, 
        category_id, 
        title, 
        description,
        preferred_shop_id,
        shop_id,
        request_type
    INTO v_request_data
    FROM public.service_requests 
    WHERE id = p_request_id;
    
    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'success', false, 
            'error', 'Request not found'
        );
    END IF;
    
    -- Determine which shop to search in
    v_preferred_shop_id := COALESCE(v_request_data.preferred_shop_id, v_request_data.shop_id);
    
    -- ====================================================================
    -- CASE 1: SHOP-SPECIFIC REQUEST (Customer selected a specific shop)
    -- ====================================================================
    IF v_preferred_shop_id IS NOT NULL THEN
        RAISE NOTICE '🏪 Shop-specific request for shop: %', v_preferred_shop_id;
        
        -- Find available mechanics ONLY in the selected shop
        FOR v_mechanic IN 
            SELECT 
                mas.mechanic_id,
                up.first_name || ' ' || up.last_name as mechanic_name,
                mas.current_status,
                (mas.current_status = 'available' AND 
                 mas.is_accepting_requests = true AND 
                 mas.current_request_id IS NULL) as is_available
            FROM mechanic_availability_status mas
            JOIN user_profiles up ON up.id = mas.mechanic_id
            JOIN shop_mechanics sm ON sm.mechanic_id = mas.mechanic_id
            WHERE sm.shop_id = v_preferred_shop_id
              AND sm.is_active = true
              AND mas.is_accepting_requests = true
            ORDER BY 
                (mas.current_status = 'available') DESC,
                mas.last_status_update DESC
        LOOP
            v_available_count := v_available_count + 1;
            
            -- Only notify if mechanic is truly available
            IF v_mechanic.is_available THEN
                -- Insert routing entry for this mechanic
                INSERT INTO public.request_routing (
                    request_id,
                    eligible_mechanic_id,
                    eligible_shop_id,
                    routing_type,
                    is_notified,
                    notified_at,
                    response_deadline,
                    distance_km
                ) VALUES (
                    p_request_id,
                    v_mechanic.mechanic_id,
                    v_preferred_shop_id,
                    'shop_based',
                    true,
                    now(),
                    now() + (p_response_timeout_minutes || ' minutes')::interval,
                    0.0 -- Same shop, minimal distance
                )
                ON CONFLICT (request_id, eligible_mechanic_id) 
                DO UPDATE SET
                    is_notified = true,
                    notified_at = now();
                
                -- Insert broadcast notification record
                INSERT INTO public.request_broadcasts (
                    request_id,
                    provider_id,
                    provider_type,
                    shop_id,
                    mechanic_id,
                    distance_km,
                    notification_sent_at,
                    is_eligible,
                    response_status
                )
                SELECT 
                    p_request_id,
                    sp.id,
                    'shop'::text,
                    v_preferred_shop_id,
                    v_mechanic.mechanic_id,
                    0.0,
                    now(),
                    true,
                    'pending'
                FROM service_providers sp
                WHERE sp.user_id = v_mechanic.mechanic_id
                ON CONFLICT (request_id, provider_id) 
                DO NOTHING;
                
                v_notified_count := v_notified_count + 1;
                
                RAISE NOTICE '✅ Notified mechanic: % (ID: %)', 
                    v_mechanic.mechanic_name, v_mechanic.mechanic_id;
            ELSE
                RAISE NOTICE '⏸️ Mechanic % is not available (status: %)', 
                    v_mechanic.mechanic_name, v_mechanic.current_status;
            END IF;
        END LOOP;
        
        -- Update request status
        IF v_notified_count > 0 THEN
            -- Mechanics available - update to broadcasting
            UPDATE public.service_requests 
            SET 
                request_type = 'shop_based',
                broadcast_status = 'broadcasting',
                broadcast_started_at = now(),
                broadcast_expires_at = now() + (p_response_timeout_minutes || ' minutes')::interval,
                notified_providers_count = v_notified_count,
                status = CASE 
                    WHEN status = 'pending' THEN 'pending'
                    ELSE status 
                END
            WHERE id = p_request_id;
            
            v_result := jsonb_build_object(
                'success', true,
                'request_id', p_request_id,
                'shop_id', v_preferred_shop_id,
                'notified_mechanics', v_notified_count,
                'total_mechanics_in_shop', v_available_count,
                'message', format('%s available mechanic(s) notified in selected shop', v_notified_count)
            );
        ELSE
            -- No available mechanics in the shop
            UPDATE public.service_requests 
            SET 
                broadcast_status = 'no_mechanics_available',
                status = 'pending'
            WHERE id = p_request_id;
            
            v_result := jsonb_build_object(
                'success', false,
                'request_id', p_request_id,
                'shop_id', v_preferred_shop_id,
                'notified_mechanics', 0,
                'total_mechanics_in_shop', v_available_count,
                'error', 'no_available_mechanics',
                'message', CASE 
                    WHEN v_available_count = 0 THEN 'No mechanics found in the selected shop'
                    ELSE format('All mechanics in the selected shop are currently busy (%s total)', v_available_count)
                END,
                'user_message', CASE 
                    WHEN v_available_count = 0 THEN 'Sorry, there are no mechanics in the selected shop. Please try another shop.'
                    ELSE format('All %s mechanics in this shop are currently busy. Please wait or select another shop.', v_available_count)
                END
            );
        END IF;
        
        RETURN v_result;
    
    -- ====================================================================
    -- CASE 2: BROADCAST REQUEST (No specific shop selected)
    -- ====================================================================
    ELSE
        RAISE NOTICE '📡 Broadcast request - searching all nearby mechanics';
        
        -- Find available mechanics within radius from ALL shops/mechanics
        FOR v_mechanic IN 
            SELECT 
                mas.mechanic_id,
                up.first_name || ' ' || up.last_name as mechanic_name,
                mas.location_latitude,
                mas.location_longitude,
                sm.shop_id,
                -- Calculate distance using Haversine formula
                (6371 * acos(
                    cos(radians(v_request_data.pickup_latitude)) * 
                    cos(radians(mas.location_latitude)) * 
                    cos(radians(mas.location_longitude) - radians(v_request_data.pickup_longitude)) + 
                    sin(radians(v_request_data.pickup_latitude)) * 
                    sin(radians(mas.location_latitude))
                )) as distance_km
            FROM mechanic_availability_status mas
            JOIN user_profiles up ON up.id = mas.mechanic_id
            LEFT JOIN shop_mechanics sm ON sm.mechanic_id = mas.mechanic_id AND sm.is_active = true
            WHERE 
                mas.current_status = 'available'
                AND mas.is_accepting_requests = true
                AND mas.location_latitude IS NOT NULL 
                AND mas.location_longitude IS NOT NULL
                AND mas.current_request_id IS NULL
                -- Distance filter
                AND (6371 * acos(
                    cos(radians(v_request_data.pickup_latitude)) * 
                    cos(radians(mas.location_latitude)) * 
                    cos(radians(mas.location_longitude) - radians(v_request_data.pickup_longitude)) + 
                    sin(radians(v_request_data.pickup_latitude)) * 
                    sin(radians(mas.location_latitude))
                )) <= p_max_radius_km
            ORDER BY distance_km ASC
            LIMIT 20
        LOOP
            -- Insert routing entry for each eligible mechanic
            INSERT INTO public.request_routing (
                request_id,
                eligible_mechanic_id,
                eligible_shop_id,
                routing_type,
                is_notified,
                notified_at,
                response_deadline,
                distance_km
            ) VALUES (
                p_request_id,
                v_mechanic.mechanic_id,
                v_mechanic.shop_id,
                'any_available',
                true,
                now(),
                now() + (p_response_timeout_minutes || ' minutes')::interval,
                v_mechanic.distance_km
            )
            ON CONFLICT (request_id, eligible_mechanic_id) 
            DO UPDATE SET
                is_notified = true,
                notified_at = now();
            
            v_notified_count := v_notified_count + 1;
            
            RAISE NOTICE '✅ Notified mechanic: % (%.2f km away)', 
                v_mechanic.mechanic_name, v_mechanic.distance_km;
        END LOOP;
        
        -- Update request status
        UPDATE public.service_requests 
        SET 
            request_type = 'broadcast',
            broadcast_status = 'broadcasting',
            broadcast_started_at = now(),
            broadcast_expires_at = now() + (p_response_timeout_minutes || ' minutes')::interval,
            broadcast_radius_km = p_max_radius_km,
            notified_providers_count = v_notified_count
        WHERE id = p_request_id;
        
        v_result := jsonb_build_object(
            'success', true,
            'request_id', p_request_id,
            'notified_mechanics', v_notified_count,
            'broadcast_radius_km', p_max_radius_km,
            'message', format('Broadcast sent to %s nearby mechanics', v_notified_count),
            'expires_at', (now() + (p_response_timeout_minutes || ' minutes')::interval)
        );
        
        RETURN v_result;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- ====================================================================
-- 3. CREATE TRIGGER TO AUTO-BROADCAST ON REQUEST CREATION
-- ====================================================================

CREATE OR REPLACE FUNCTION trigger_auto_broadcast_request()
RETURNS TRIGGER AS $$
BEGIN
    -- Only broadcast if status is pending and not yet broadcasted
    IF NEW.status = 'pending' AND 
       (NEW.broadcast_status IS NULL OR NEW.broadcast_status = 'not_started') AND
       NEW.assigned_mechanic_id IS NULL THEN
        
        -- Call the broadcast function
        PERFORM broadcast_service_request_with_shop_filter(
            NEW.id,
            COALESCE(NEW.broadcast_radius_km, 25.0),
            COALESCE(NEW.max_response_time_minutes, 30)
        );
        
        RAISE NOTICE '🔔 Auto-broadcast triggered for request: %', NEW.id;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop existing trigger if exists
DROP TRIGGER IF EXISTS auto_broadcast_new_request ON public.service_requests;

-- Create trigger for new requests
CREATE TRIGGER auto_broadcast_new_request
    AFTER INSERT ON public.service_requests
    FOR EACH ROW
    WHEN (NEW.status = 'pending' AND NEW.assigned_mechanic_id IS NULL)
    EXECUTE FUNCTION trigger_auto_broadcast_request();

-- ====================================================================
-- 4. ADD UNIQUE CONSTRAINT TO PREVENT DUPLICATE ROUTING
-- ====================================================================

-- Add unique constraint if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'request_routing_unique_mechanic_per_request'
    ) THEN
        ALTER TABLE public.request_routing
        ADD CONSTRAINT request_routing_unique_mechanic_per_request 
        UNIQUE (request_id, eligible_mechanic_id);
    END IF;
END $$;

-- ====================================================================
-- 5. CREATE HELPER FUNCTION TO CHECK SHOP AVAILABILITY
-- ====================================================================

-- Drop existing function first to avoid return type conflict
DROP FUNCTION IF EXISTS check_shop_mechanic_availability(uuid);

CREATE OR REPLACE FUNCTION check_shop_mechanic_availability(
    p_shop_id uuid
)
RETURNS jsonb AS $$
DECLARE
    v_total_mechanics integer;
    v_available_mechanics integer;
    v_busy_mechanics integer;
    v_offline_mechanics integer;
    v_result jsonb;
BEGIN
    -- Count mechanics by status
    SELECT 
        COUNT(*) as total,
        COUNT(*) FILTER (WHERE mas.current_status = 'available' AND mas.is_accepting_requests = true) as available,
        COUNT(*) FILTER (WHERE mas.current_status IN ('busy', 'in_service')) as busy,
        COUNT(*) FILTER (WHERE mas.current_status = 'offline') as offline
    INTO v_total_mechanics, v_available_mechanics, v_busy_mechanics, v_offline_mechanics
    FROM shop_mechanics sm
    JOIN mechanic_availability_status mas ON mas.mechanic_id = sm.mechanic_id
    WHERE sm.shop_id = p_shop_id
      AND sm.is_active = true;
    
    v_result := jsonb_build_object(
        'shop_id', p_shop_id,
        'total_mechanics', v_total_mechanics,
        'available_mechanics', v_available_mechanics,
        'busy_mechanics', v_busy_mechanics,
        'offline_mechanics', v_offline_mechanics,
        'can_accept_requests', (v_available_mechanics > 0),
        'status_message', CASE 
            WHEN v_total_mechanics = 0 THEN 'No mechanics in this shop'
            WHEN v_available_mechanics > 0 THEN format('%s mechanic(s) available', v_available_mechanics)
            WHEN v_busy_mechanics > 0 THEN format('All %s mechanics are currently busy', v_busy_mechanics)
            ELSE 'No mechanics available'
        END
    );
    
    RETURN v_result;
END;
$$ LANGUAGE plpgsql;

-- ====================================================================
-- 6. TEST QUERIES
-- ====================================================================

-- Check which shops have available mechanics
/*
SELECT 
    s.id as shop_id,
    s.shop_name,
    check_shop_mechanic_availability(s.id) as availability
FROM shops s
WHERE s.is_active = true
ORDER BY s.shop_name;
*/

-- Find available mechanics in a specific shop
/*
SELECT * FROM find_available_mechanics_in_shop('YOUR_SHOP_ID_HERE');
*/

-- Manually trigger broadcast for a request
/*
SELECT broadcast_service_request_with_shop_filter('YOUR_REQUEST_ID_HERE');
*/

-- ====================================================================
-- SUMMARY
-- ====================================================================
/*
WHAT THIS FIX DOES:

1. ✅ SHOP-SPECIFIC ROUTING: When customer selects Shop B, only mechanics 
   from Shop B will receive the request notification.

2. ✅ AVAILABILITY CHECK: Before notifying mechanics, system checks if they 
   are truly available (status = 'available' and accepting requests).

3. ✅ CLEAR ERROR MESSAGES: If no mechanics are available in the selected shop:
   - Customer sees: "All X mechanics in this shop are currently busy"
   - Or: "No mechanics found in the selected shop"

4. ✅ BROADCAST FALLBACK: If customer doesn't select a specific shop, 
   system broadcasts to all nearby mechanics within radius.

5. ✅ AUTO-BROADCAST: New requests are automatically broadcast when created.

6. ✅ DUPLICATE PREVENTION: Unique constraint prevents same mechanic from 
   being notified multiple times for the same request.

HOW TO USE:

1. Run this entire SQL file in Supabase SQL Editor
2. System will now automatically route requests correctly
3. Customers selecting Shop B will only see Shop B mechanics
4. If all Shop B mechanics are busy, customer gets a clear message

TESTING:

1. Create a service request and select Shop B
2. Check that only Shop B mechanics receive notification
3. If all Shop B mechanics are busy, verify customer sees busy message
4. Try without selecting a shop - should broadcast to all nearby mechanics
*/
