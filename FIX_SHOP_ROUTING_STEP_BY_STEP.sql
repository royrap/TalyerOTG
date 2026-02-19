-- =====================================================
-- SHOP REQUEST ROUTING FIX - RUN EACH SECTION SEPARATELY
-- =====================================================
-- IMPORTANT: Copy and run ONE section at a time!
-- Wait for each section to complete before running the next one
-- =====================================================

-- =====================================================
-- SECTION 1: DISABLE RLS (RUN THIS FIRST, ALONE)
-- =====================================================

ALTER TABLE request_routing DISABLE ROW LEVEL SECURITY;

-- =====================================================
-- SECTION 2: DROP POLICIES (RUN THIS SECOND, ALONE)
-- =====================================================

DROP POLICY IF EXISTS "System can manage request routing" ON request_routing;
DROP POLICY IF EXISTS "Users can view routing for their requests" ON request_routing;
DROP POLICY IF EXISTS "mechanic_can_view_own_routings" ON request_routing;
DROP POLICY IF EXISTS "Mechanics can view own routing entries" ON request_routing;
DROP POLICY IF EXISTS "Service can insert routing entries" ON request_routing;

-- =====================================================
-- SECTION 3: DROP TRIGGER (RUN THIS THIRD, ALONE)
-- =====================================================

DROP TRIGGER IF EXISTS on_service_request_insert_shop_routing ON service_requests;

-- =====================================================
-- SECTION 4: DROP FUNCTION (RUN THIS FOURTH, ALONE)
-- =====================================================

DROP FUNCTION IF EXISTS handle_shop_based_routing() CASCADE;

-- =====================================================
-- SECTION 5: CREATE FUNCTION (RUN THIS FIFTH, ALONE)
-- =====================================================

CREATE OR REPLACE FUNCTION handle_shop_based_routing()
RETURNS TRIGGER 
SECURITY DEFINER
LANGUAGE plpgsql
AS $$
DECLARE
    v_shop_mechanics_count integer := 0;
    v_mechanic_record RECORD;
    v_routing_id uuid;
BEGIN
    -- Only process shop-based requests
    IF NEW.shop_id IS NOT NULL THEN
        RAISE NOTICE '🏪 SHOP REQUEST: % (shop: %)', NEW.id, NEW.shop_id;
        
        -- Count available mechanics
        SELECT COUNT(*) INTO v_shop_mechanics_count
        FROM shop_mechanics sm
        JOIN mechanic_availability_status mas ON mas.mechanic_id = sm.mechanic_id
        WHERE sm.shop_id = NEW.shop_id
        AND sm.is_active = true
        AND sm.is_available = true
        AND mas.current_status = 'available'
        AND mas.is_accepting_requests = true;
        
        RAISE NOTICE '📊 Found % mechanics', v_shop_mechanics_count;
        
        IF v_shop_mechanics_count = 0 THEN
            RAISE WARNING '⚠️ No mechanics available';
            RETURN NEW;
        END IF;
        
        -- Create routing for each mechanic
        FOR v_mechanic_record IN
            SELECT 
                sm.mechanic_id,
                up.email
            FROM shop_mechanics sm
            JOIN user_profiles up ON up.id = sm.mechanic_id
            JOIN mechanic_availability_status mas ON mas.mechanic_id = sm.mechanic_id
            WHERE sm.shop_id = NEW.shop_id
            AND sm.is_active = true
            AND sm.is_available = true
            AND mas.current_status = 'available'
            AND mas.is_accepting_requests = true
        LOOP
            v_routing_id := gen_random_uuid();
            
            -- Insert routing entry
            BEGIN
                INSERT INTO request_routing (
                    id,
                    request_id,
                    eligible_mechanic_id,
                    eligible_shop_id,
                    routing_type,
                    distance_km,
                    is_notified,
                    notified_at,
                    created_at,
                    response_deadline
                ) VALUES (
                    v_routing_id,
                    NEW.id,
                    v_mechanic_record.mechanic_id,
                    NEW.shop_id,
                    'shop_based',
                    0.0,
                    true,
                    NOW(),
                    NOW(),
                    NOW() + INTERVAL '30 minutes'
                );
                
                RAISE NOTICE '✅ Routing: % → %', v_routing_id, v_mechanic_record.email;
                    
            EXCEPTION WHEN OTHERS THEN
                RAISE WARNING '❌ Routing failed: %', SQLERRM;
            END;
            
            -- Insert notification
            BEGIN
                INSERT INTO notifications (
                    user_id,
                    title,
                    body,
                    type,
                    data,
                    read,
                    created_at
                ) VALUES (
                    v_mechanic_record.mechanic_id,
                    'New Service Request',
                    'A customer needs your help. Tap to view details.',
                    'service_request',
                    jsonb_build_object(
                        'request_id', NEW.id,
                        'shop_id', NEW.shop_id,
                        'routing_id', v_routing_id,
                        'routing_type', 'shop_based'
                    ),
                    false,
                    NOW()
                );
                
                RAISE NOTICE '📱 Notification sent';
                
            EXCEPTION WHEN OTHERS THEN
                RAISE WARNING '⚠️ Notification failed: %', SQLERRM;
            END;
        END LOOP;
        
        -- Update request
        UPDATE service_requests 
        SET 
            mechanics_notified_count = v_shop_mechanics_count,
            request_type = 'shop_based',
            broadcast_started_at = NOW()
        WHERE id = NEW.id;
        
        RAISE NOTICE '✅ COMPLETE: % mechanics notified', v_shop_mechanics_count;
    END IF;
    
    RETURN NEW;
END;
$$;

-- =====================================================
-- SECTION 6: CREATE TRIGGER (RUN THIS SIXTH, ALONE)
-- =====================================================

CREATE TRIGGER on_service_request_insert_shop_routing
    AFTER INSERT ON service_requests
    FOR EACH ROW
    EXECUTE FUNCTION handle_shop_based_routing();

-- =====================================================
-- SECTION 7: ASSIGN MECHANICS TO SHOPS (RUN THIS SEVENTH, ALONE)
-- =====================================================

DO $$
DECLARE
    v_shop_record RECORD;
    v_mechanic_record RECORD;
    v_count integer := 0;
BEGIN
    RAISE NOTICE 'Assigning mechanics to shops...';
    
    FOR v_mechanic_record IN
        SELECT id, email FROM user_profiles WHERE user_type = 'mechanic'
    LOOP
        FOR v_shop_record IN
            SELECT id FROM shops WHERE is_active = true
        LOOP
            INSERT INTO shop_mechanics (
                shop_id, mechanic_id, is_active, is_available
            ) VALUES (
                v_shop_record.id,
                v_mechanic_record.id,
                true,
                true
            )
            ON CONFLICT (shop_id, mechanic_id) DO UPDATE SET
                is_active = true,
                is_available = true;
                
            v_count := v_count + 1;
        END LOOP;
    END LOOP;
    
    RAISE NOTICE '✅ Assigned % mechanics', v_count;
END $$;

-- =====================================================
-- SECTION 8: SET AVAILABILITY (RUN THIS EIGHTH, ALONE)
-- =====================================================

DO $$
DECLARE
    v_mechanic_record RECORD;
BEGIN
    RAISE NOTICE 'Setting mechanic availability...';
    
    FOR v_mechanic_record IN
        SELECT id, email FROM user_profiles WHERE user_type = 'mechanic'
    LOOP
        INSERT INTO mechanic_availability_status (
            mechanic_id,
            current_status,
            is_accepting_requests
        ) VALUES (
            v_mechanic_record.id,
            'available',
            true
        )
        ON CONFLICT (mechanic_id) DO UPDATE SET
            current_status = 'available',
            is_accepting_requests = true;
            
        RAISE NOTICE '✅ Available: %', v_mechanic_record.email;
    END LOOP;
END $$;

-- =====================================================
-- SECTION 9: VERIFY (RUN THIS LAST TO CHECK)
-- =====================================================

-- Check shop mechanics
SELECT 
    s.shop_name,
    COUNT(sm.mechanic_id) as total_mechanics,
    array_agg(up.email) as mechanics
FROM shops s
LEFT JOIN shop_mechanics sm ON sm.shop_id = s.id AND sm.is_active = true
LEFT JOIN user_profiles up ON up.id = sm.mechanic_id
WHERE s.is_active = true
GROUP BY s.shop_name
ORDER BY s.shop_name;

-- Check mechanic status
SELECT 
    up.email,
    mas.current_status,
    mas.is_accepting_requests,
    COUNT(sm.shop_id) as shops_assigned
FROM user_profiles up
LEFT JOIN mechanic_availability_status mas ON mas.mechanic_id = up.id
LEFT JOIN shop_mechanics sm ON sm.mechanic_id = up.id AND sm.is_active = true
WHERE up.user_type = 'mechanic'
GROUP BY up.email, mas.current_status, mas.is_accepting_requests
ORDER BY up.email;

-- =====================================================
-- AFTER RUNNING ALL SECTIONS ABOVE, TEST WITH THIS:
-- =====================================================

-- Create a test request (replace values as needed)
/*
INSERT INTO service_requests (
    id,
    customer_id,
    shop_id,
    title,
    description,
    pickup_latitude,
    pickup_longitude,
    pickup_address,
    status
) VALUES (
    gen_random_uuid(),
    (SELECT id FROM user_profiles WHERE user_type = 'customer' LIMIT 1),
    (SELECT id FROM shops WHERE is_active = true LIMIT 1),
    '🧪 TEST Request',
    'Testing shop-based routing',
    14.5995,
    120.9842,
    'Test Location',
    'pending'
);

-- Then check if routing was created:
SELECT 
    sr.title,
    COUNT(rr.id) as routing_entries,
    array_agg(up.email) as notified_mechanics
FROM service_requests sr
LEFT JOIN request_routing rr ON rr.request_id = sr.id
LEFT JOIN user_profiles up ON up.id = rr.eligible_mechanic_id
WHERE sr.title LIKE '%TEST%'
GROUP BY sr.id, sr.title
ORDER BY sr.created_at DESC
LIMIT 1;
*/
