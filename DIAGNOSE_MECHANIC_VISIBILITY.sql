-- =====================================================
-- DIAGNOSE MECHANIC VISIBILITY ISSUE
-- Why yujiro fuma can't see requests but Rafael can
-- =====================================================

-- STEP 1: Check all mechanics and their availability status
SELECT 
    '=== MECHANIC STATUS CHECK ===' as section,
    up.email,
    up.first_name,
    up.last_name,
    up.user_type,
    mas.current_status,
    mas.is_accepting_requests,
    mas.location_latitude,
    mas.location_longitude,
    mas.current_request_id,
    mas.last_status_update,
    CASE 
        WHEN mas.is_accepting_requests = true 
        AND mas.current_status = 'available'
        AND mas.location_latitude IS NOT NULL
        AND mas.location_longitude IS NOT NULL
        AND mas.current_request_id IS NULL
        THEN '✅ ELIGIBLE FOR BROADCASTS'
        ELSE '❌ NOT ELIGIBLE - ' || 
            CASE 
                WHEN mas.is_accepting_requests = false THEN 'NOT ACCEPTING REQUESTS'
                WHEN mas.current_status != 'available' THEN 'STATUS: ' || mas.current_status
                WHEN mas.location_latitude IS NULL OR mas.location_longitude IS NULL THEN 'NO LOCATION'
                WHEN mas.current_request_id IS NOT NULL THEN 'BUSY WITH REQUEST: ' || mas.current_request_id
                ELSE 'OTHER ISSUE'
            END
    END as broadcast_eligibility
FROM user_profiles up
LEFT JOIN mechanic_availability_status mas ON mas.mechanic_id = up.id
WHERE up.user_type = 'mechanic'
ORDER BY up.email;

-- STEP 2: Check current service requests
SELECT 
    '=== SERVICE REQUESTS CHECK ===' as section,
    sr.id,
    sr.customer_id,
    customer.email as customer_email,
    sr.status,
    sr.assigned_mechanic_id,
    assigned_mech.email as assigned_mechanic_email,
    sr.shop_id,
    sr.request_type,
    sr.broadcast_radius_km,
    sr.mechanics_notified_count,
    sr.broadcast_timestamp,
    sr.pickup_latitude,
    sr.pickup_longitude,
    sr.created_at,
    sr.updated_at
FROM service_requests sr
LEFT JOIN user_profiles customer ON customer.id = sr.customer_id
LEFT JOIN user_profiles assigned_mech ON assigned_mech.id = sr.assigned_mechanic_id
WHERE sr.status IN ('pending', 'assigned')
ORDER BY sr.created_at DESC
LIMIT 5;

-- STEP 3: Check request routing entries
SELECT 
    '=== REQUEST ROUTING CHECK ===' as section,
    rr.id as routing_id,
    rr.request_id,
    rr.eligible_mechanic_id,
    mech.email as mechanic_email,
    mech.first_name,
    mech.last_name,
    rr.distance_km,
    rr.is_notified,
    rr.notified_at,
    rr.response_deadline,
    rr.routing_type,
    rr.created_at
FROM request_routing rr
LEFT JOIN user_profiles mech ON mech.id = rr.eligible_mechanic_id
WHERE rr.request_id IN (
    SELECT id FROM service_requests 
    WHERE status IN ('pending', 'assigned')
)
ORDER BY rr.created_at DESC;

-- STEP 4: Check if there are any pending requests without routing
SELECT 
    '=== REQUESTS WITHOUT ROUTING ===' as section,
    sr.id,
    sr.customer_id,
    customer.email as customer_email,
    sr.status,
    sr.shop_id,
    sr.request_type,
    sr.mechanics_notified_count,
    sr.broadcast_timestamp,
    sr.created_at,
    CASE 
        WHEN sr.shop_id IS NULL THEN 'SHOULD BE BROADCAST'
        ELSE 'DIRECT TO SHOP'
    END as expected_routing
FROM service_requests sr
LEFT JOIN user_profiles customer ON customer.id = sr.customer_id
LEFT JOIN request_routing rr ON rr.request_id = sr.id
WHERE sr.status = 'pending'
AND rr.request_id IS NULL
ORDER BY sr.created_at DESC;

-- STEP 5: Check distance calculation between mechanics and latest request
WITH latest_request AS (
    SELECT id, pickup_latitude, pickup_longitude
    FROM service_requests 
    WHERE status = 'pending'
    ORDER BY created_at DESC
    LIMIT 1
)
SELECT 
    '=== DISTANCE CALCULATION CHECK ===' as section,
    up.email,
    up.first_name,
    up.last_name,
    mas.location_latitude,
    mas.location_longitude,
    lr.pickup_latitude as request_lat,
    lr.pickup_longitude as request_lng,
    CASE 
        WHEN mas.location_latitude IS NOT NULL AND mas.location_longitude IS NOT NULL THEN
            (6371 * acos(
                cos(radians(lr.pickup_latitude)) * 
                cos(radians(mas.location_latitude)) * 
                cos(radians(mas.location_longitude) - radians(lr.pickup_longitude)) + 
                sin(radians(lr.pickup_latitude)) * 
                sin(radians(mas.location_latitude))
            ))
        ELSE NULL
    END as distance_km,
    CASE 
        WHEN mas.location_latitude IS NOT NULL AND mas.location_longitude IS NOT NULL THEN
            CASE 
                WHEN (6371 * acos(
                    cos(radians(lr.pickup_latitude)) * 
                    cos(radians(mas.location_latitude)) * 
                    cos(radians(mas.location_longitude) - radians(lr.pickup_longitude)) + 
                    sin(radians(lr.pickup_latitude)) * 
                    sin(radians(mas.location_latitude))
                )) <= 10.0 THEN '✅ WITHIN 10KM RADIUS'
                ELSE '❌ OUTSIDE 10KM RADIUS'
            END
        ELSE '❌ NO LOCATION DATA'
    END as within_broadcast_radius
FROM user_profiles up
JOIN mechanic_availability_status mas ON mas.mechanic_id = up.id
CROSS JOIN latest_request lr
WHERE up.user_type = 'mechanic'
ORDER BY up.email;

-- STEP 6: Test broadcast function with current request
DO $$
DECLARE
    v_latest_request_id uuid;
    v_request_lat numeric;
    v_request_lng numeric;
    v_broadcast_result jsonb;
BEGIN
    -- Get latest pending request
    SELECT id, pickup_latitude, pickup_longitude
    INTO v_latest_request_id, v_request_lat, v_request_lng
    FROM service_requests 
    WHERE status = 'pending'
    ORDER BY created_at DESC
    LIMIT 1;
    
    IF v_latest_request_id IS NOT NULL THEN
        RAISE NOTICE '=== TESTING BROADCAST FUNCTION ===';
        RAISE NOTICE 'Testing with request: %', v_latest_request_id;
        RAISE NOTICE 'Request location: %, %', v_request_lat, v_request_lng;
        
        -- Clear existing routing for clean test
        DELETE FROM request_routing WHERE request_id = v_latest_request_id;
        
        -- Test broadcast function
        SELECT broadcast_service_request(
            v_latest_request_id::text,
            v_request_lat,
            v_request_lng,
            10.0,
            'test',
            false
        ) INTO v_broadcast_result;
        
        RAISE NOTICE 'Broadcast result: %', v_broadcast_result;
    ELSE
        RAISE NOTICE '=== NO PENDING REQUESTS TO TEST ===';
    END IF;
END $$;

-- STEP 7: Check if functions exist and have proper permissions
SELECT 
    '=== FUNCTION CHECK ===' as section,
    proname as function_name,
    pronargs as arg_count,
    proowner::regrole as owner,
    proacl as permissions
FROM pg_proc 
WHERE proname IN ('broadcast_service_request', 'accept_broadcast_request', 'accept_request_fifo')
ORDER BY proname;

-- STEP 8: Check triggers
SELECT 
    '=== TRIGGER CHECK ===' as section,
    trigger_schema,
    event_object_table as table_name,
    trigger_name,
    event_manipulation,
    action_timing,
    action_statement
FROM information_schema.triggers 
WHERE trigger_name LIKE '%broadcast%' OR trigger_name LIKE '%service_request%';

-- STEP 9: Final routing check after broadcast test
SELECT 
    '=== FINAL ROUTING CHECK ===' as section,
    rr.request_id,
    sr.status as request_status,
    rr.eligible_mechanic_id,
    mech.email as mechanic_email,
    mech.first_name,
    mech.last_name,
    rr.distance_km,
    rr.routing_type,
    rr.created_at
FROM request_routing rr
JOIN service_requests sr ON sr.id = rr.request_id
LEFT JOIN user_profiles mech ON mech.id = rr.eligible_mechanic_id
WHERE sr.status = 'pending'
ORDER BY rr.created_at DESC;

-- =====================================================
-- SUMMARY AND RECOMMENDATIONS
-- =====================================================
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '=== DIAGNOSTIC SUMMARY ===';
    RAISE NOTICE '';
    RAISE NOTICE 'This script checks:';
    RAISE NOTICE '1. Mechanic availability status and eligibility';
    RAISE NOTICE '2. Current service requests and their routing';
    RAISE NOTICE '3. Distance calculations between mechanics and requests';
    RAISE NOTICE '4. Function permissions and triggers';
    RAISE NOTICE '5. Tests the broadcast function';
    RAISE NOTICE '';
    RAISE NOTICE 'Look for:';
    RAISE NOTICE '- Both mechanics should be "✅ ELIGIBLE FOR BROADCASTS"';
    RAISE NOTICE '- Both mechanics should be "✅ WITHIN 10KM RADIUS"';
    RAISE NOTICE '- Request routing should show entries for both mechanics';
    RAISE NOTICE '- Broadcast function should return success with mechanics_notified > 1';
    RAISE NOTICE '';
END $$;