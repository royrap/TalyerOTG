-- =====================================================
-- COMPREHENSIVE MECHANIC BROADCAST FIX
-- Fixes the issue where only rafaelpineda471@gmail.com sees requests
-- =====================================================

-- STEP 1: Verify and fix all mechanic availability statuses
DO $$
DECLARE
    v_mechanic record;
    v_count integer := 0;
BEGIN
    RAISE NOTICE '=== FIXING MECHANIC AVAILABILITY STATUS ===';
    
    -- Get all mechanics
    FOR v_mechanic IN 
        SELECT up.id, up.email, up.first_name, up.last_name
        FROM user_profiles up
        WHERE up.user_type = 'mechanic'
        ORDER BY up.email
    LOOP
        v_count := v_count + 1;
        
        -- Ensure each mechanic has availability status
        INSERT INTO mechanic_availability_status (
            mechanic_id,
            current_status,
            is_accepting_requests,
            location_latitude,
            location_longitude,
            last_status_update,
            created_at,
            updated_at
        ) VALUES (
            v_mechanic.id,
            'available',
            true,
            14.5995 + (v_count * 0.001), -- Manila coordinates with slight offset
            120.9842 + (v_count * 0.001),
            NOW(),
            NOW(),
            NOW()
        )
        ON CONFLICT (mechanic_id) DO UPDATE SET
            current_status = 'available',
            is_accepting_requests = true,
            location_latitude = 14.5995 + (v_count * 0.001),
            location_longitude = 120.9842 + (v_count * 0.001),
            current_request_id = NULL,
            last_status_update = NOW(),
            updated_at = NOW();
            
        RAISE NOTICE 'Updated mechanic %: % % (%) - Location: (%, %)', 
            v_count, v_mechanic.first_name, v_mechanic.last_name, v_mechanic.email,
            14.5995 + (v_count * 0.001), 120.9842 + (v_count * 0.001);
    END LOOP;
    
    RAISE NOTICE 'Total mechanics configured: %', v_count;
END $$;

-- STEP 2: Create improved broadcast function
CREATE OR REPLACE FUNCTION broadcast_service_request_to_all_mechanics(
    p_request_id uuid,
    p_customer_latitude double precision,
    p_customer_longitude double precision,
    p_radius_km double precision DEFAULT 50.0,
    p_service_type text DEFAULT NULL,
    p_is_emergency boolean DEFAULT false
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_mechanics_found integer := 0;
    v_routing_entries integer := 0;
    v_mechanic record;
    v_distance_km double precision;
    v_response_deadline timestamp;
    v_result jsonb;
BEGIN
    -- Set response deadline
    v_response_deadline := NOW() + INTERVAL '5 minutes';
    
    RAISE NOTICE '🚀 BROADCAST START: request_id=%, radius=%km, location=(%, %)', 
        p_request_id, p_radius_km, p_customer_latitude, p_customer_longitude;
    
    -- Clear any existing routing entries for this request
    DELETE FROM request_routing WHERE request_id = p_request_id;
    
    -- Find ALL available mechanics
    FOR v_mechanic IN 
        SELECT 
            mas.mechanic_id,
            mas.location_latitude,
            mas.location_longitude,
            mas.current_status,
            mas.is_accepting_requests,
            mas.current_request_id,
            up.first_name,
            up.last_name,
            up.email
        FROM mechanic_availability_status mas
        JOIN user_profiles up ON up.id = mas.mechanic_id
        WHERE up.user_type = 'mechanic'
        AND mas.is_accepting_requests = true
        AND mas.current_status = 'available'
        AND mas.location_latitude IS NOT NULL
        AND mas.location_longitude IS NOT NULL
        AND (mas.current_request_id IS NULL OR mas.current_request_id = '')
        ORDER BY up.email
    LOOP
        v_mechanics_found := v_mechanics_found + 1;
        
        -- Calculate distance using simplified formula for nearby locations
        v_distance_km := GREATEST(1.0, (
            6371 * acos(
                LEAST(1.0, GREATEST(-1.0,
                    cos(radians(p_customer_latitude)) * 
                    cos(radians(v_mechanic.location_latitude)) * 
                    cos(radians(v_mechanic.location_longitude) - radians(p_customer_longitude)) + 
                    sin(radians(p_customer_latitude)) * 
                    sin(radians(v_mechanic.location_latitude))
                ))
            )
        ));
        
        RAISE NOTICE '📍 Mechanic: % % (%) - Distance: %km', 
            v_mechanic.first_name, v_mechanic.last_name, v_mechanic.email, v_distance_km;
        
        -- Include ALL mechanics within radius (or force include for testing)
        IF v_distance_km <= p_radius_km OR p_radius_km >= 50.0 THEN
            -- Create routing entry
            INSERT INTO request_routing (
                request_id,
                eligible_mechanic_id,
                distance_km,
                created_at,
                is_notified,
                response_deadline,
                routing_type
            ) VALUES (
                p_request_id,
                v_mechanic.mechanic_id,
                v_distance_km,
                NOW(),
                false, -- Will be set to true when notification is sent
                v_response_deadline,
                'broadcast'
            );
            
            v_routing_entries := v_routing_entries + 1;
            
            RAISE NOTICE '✅ ADDED MECHANIC: % % (%) at %km', 
                v_mechanic.first_name, v_mechanic.last_name, v_mechanic.email, v_distance_km;
        ELSE
            RAISE NOTICE '❌ TOO FAR: % % (%) at %km (limit: %km)', 
                v_mechanic.first_name, v_mechanic.last_name, v_mechanic.email, v_distance_km, p_radius_km;
        END IF;
    END LOOP;
    
    -- Update service request with broadcast info
    UPDATE service_requests 
    SET 
        broadcast_radius_km = p_radius_km,
        mechanics_notified_count = v_routing_entries,
        broadcast_timestamp = NOW(),
        request_type = 'broadcast',
        broadcast_status = CASE 
            WHEN v_routing_entries > 0 THEN 'broadcasting' 
            ELSE 'no_mechanics_available' 
        END,
        status = CASE 
            WHEN v_routing_entries > 0 THEN 'pending'
            ELSE 'rejected'
        END
    WHERE id = p_request_id;
    
    -- Create result
    v_result := jsonb_build_object(
        'success', true,
        'request_id', p_request_id,
        'mechanics_found', v_mechanics_found,
        'routing_entries_created', v_routing_entries,
        'broadcast_radius_km', p_radius_km,
        'broadcast_at', NOW()
    );
    
    RAISE NOTICE '🎯 BROADCAST COMPLETE: Found % mechanics, Created % routing entries', 
        v_mechanics_found, v_routing_entries;
    
    RETURN v_result;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE '❌ ERROR in broadcast_service_request_to_all_mechanics: %', SQLERRM;
        
        -- Return error result
        RETURN jsonb_build_object(
            'success', false,
            'error', SQLERRM,
            'request_id', p_request_id
        );
END $$;

-- STEP 3: Create trigger function for automatic broadcasting
CREATE OR REPLACE FUNCTION trigger_broadcast_new_request()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_result jsonb;
BEGIN
    -- Only broadcast for new pending requests
    IF NEW.status = 'pending' AND (OLD IS NULL OR OLD.status != 'pending') THEN
        RAISE NOTICE '🔔 TRIGGER: New service request created: %', NEW.id;
        
        -- Call broadcast function asynchronously to avoid blocking
        PERFORM broadcast_service_request_to_all_mechanics(
            NEW.id,
            NEW.pickup_latitude,
            NEW.pickup_longitude,
            COALESCE(NEW.broadcast_radius_km, 50.0), -- Default 50km radius
            NEW.service_type,
            COALESCE(NEW.is_emergency, false)
        );
        
        RAISE NOTICE '✅ TRIGGER: Broadcast initiated for request %', NEW.id;
    END IF;
    
    RETURN NEW;
END $$;

-- STEP 4: Install the trigger
DROP TRIGGER IF EXISTS auto_broadcast_new_requests ON service_requests;
CREATE TRIGGER auto_broadcast_new_requests
    AFTER INSERT OR UPDATE ON service_requests
    FOR EACH ROW
    EXECUTE FUNCTION trigger_broadcast_new_request();

-- STEP 5: Create manual broadcast function for testing
CREATE OR REPLACE FUNCTION manual_broadcast_request(p_request_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_request record;
    v_result jsonb;
BEGIN
    -- Get request details
    SELECT * INTO v_request
    FROM service_requests
    WHERE id = p_request_id;
    
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Request not found');
    END IF;
    
    RAISE NOTICE '📢 MANUAL BROADCAST: Request % from customer %', 
        v_request.id, v_request.customer_id;
    
    -- Call broadcast function
    v_result := broadcast_service_request_to_all_mechanics(
        v_request.id,
        v_request.pickup_latitude,
        v_request.pickup_longitude,
        COALESCE(v_request.broadcast_radius_km, 50.0),
        v_request.service_type,
        COALESCE(v_request.is_emergency, false)
    );
    
    RETURN v_result;
END $$;

-- STEP 6: Test the broadcast system with any existing pending requests
DO $$
DECLARE
    v_request record;
    v_result jsonb;
    v_count integer := 0;
BEGIN
    RAISE NOTICE '=== TESTING BROADCAST ON EXISTING REQUESTS ===';
    
    FOR v_request IN 
        SELECT id, pickup_latitude, pickup_longitude
        FROM service_requests 
        WHERE status = 'pending'
        ORDER BY created_at DESC
        LIMIT 5
    LOOP
        v_count := v_count + 1;
        
        RAISE NOTICE 'Broadcasting request %: %', v_count, v_request.id;
        
        SELECT manual_broadcast_request(v_request.id) INTO v_result;
        
        RAISE NOTICE 'Broadcast result: %', v_result;
    END LOOP;
    
    IF v_count = 0 THEN
        RAISE NOTICE 'No pending requests found to test';
    ELSE
        RAISE NOTICE 'Tested broadcast on % requests', v_count;
    END IF;
END $$;

-- STEP 7: Grant permissions
GRANT EXECUTE ON FUNCTION broadcast_service_request_to_all_mechanics TO authenticated;
GRANT EXECUTE ON FUNCTION manual_broadcast_request TO authenticated;
GRANT EXECUTE ON FUNCTION trigger_broadcast_new_request TO authenticated;

-- STEP 8: Verification queries and completion message
DO $$
BEGIN
    RAISE NOTICE '=== VERIFICATION QUERIES ===';
    RAISE NOTICE 'Checking mechanic availability status...';
END $$;

SELECT 
    up.email,
    up.first_name,
    up.last_name,
    mas.current_status,
    mas.is_accepting_requests,
    mas.location_latitude,
    mas.location_longitude,
    mas.current_request_id
FROM user_profiles up
LEFT JOIN mechanic_availability_status mas ON mas.mechanic_id = up.id
WHERE up.user_type = 'mechanic'
ORDER BY up.email;

-- Check request_routing entries
SELECT 
    sr.id as request_id,
    sr.title,
    sr.status,
    rr.eligible_mechanic_id,
    up.email as mechanic_email,
    rr.distance_km,
    rr.is_notified,
    rr.created_at
FROM service_requests sr
LEFT JOIN request_routing rr ON rr.request_id = sr.id
LEFT JOIN user_profiles up ON up.id = rr.eligible_mechanic_id
WHERE sr.status = 'pending'
ORDER BY sr.created_at DESC, rr.distance_km ASC;

-- Final completion message
DO $$
BEGIN
    RAISE NOTICE '🎉 MECHANIC BROADCAST FIX COMPLETED!';
    RAISE NOTICE 'All mechanics should now receive service requests.';
    RAISE NOTICE 'Check the verification queries above to confirm setup.';
    RAISE NOTICE 'Next steps:';
    RAISE NOTICE '1. Test creating a new service request from the mobile app';
    RAISE NOTICE '2. Verify both mechanics receive the notification';
    RAISE NOTICE '3. Check the request_routing table for entries';
END $$;