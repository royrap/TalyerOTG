-- =====================================================
-- TEST SCRIPT FOR MECHANIC BROADCAST FIX
-- Run this after applying MECHANIC_BROADCAST_FIX_COMPREHENSIVE.sql
-- =====================================================

-- STEP 1: Verify mechanic availability setup
DO $$
BEGIN
    RAISE NOTICE '=== VERIFYING MECHANIC SETUP ===';
END $$;

SELECT 
    '📋 Mechanic Status Check' as test_section,
    up.email,
    up.first_name,
    up.last_name,
    mas.current_status,
    mas.is_accepting_requests,
    CASE 
        WHEN mas.location_latitude IS NOT NULL THEN 'HAS LOCATION'
        ELSE 'NO LOCATION'
    END as location_status,
    mas.current_request_id
FROM user_profiles up
LEFT JOIN mechanic_availability_status mas ON mas.mechanic_id = up.id
WHERE up.user_type = 'mechanic'
ORDER BY up.email;

-- STEP 2: Test manual broadcast function
DO $$
DECLARE
    v_test_request_id uuid;
    v_result jsonb;
    v_routing_count integer;
    v_mechanic record;
BEGIN
    RAISE NOTICE '=== TESTING MANUAL BROADCAST ===';
    
    -- Create a test service request
    INSERT INTO service_requests (
        customer_id,
        vehicle_id,
        title,
        description,
        service_type,
        pickup_latitude,
        pickup_longitude,
        pickup_address,
        status,
        request_type,
        broadcast_radius_km,
        created_at
    )
    SELECT 
        up.id,
        (SELECT id FROM vehicles WHERE user_id = up.id LIMIT 1),
        'TEST REQUEST - All Mechanics Should See This',
        'This is a test request to verify that all mechanics receive notifications',
        'Mechanical Issue',
        14.5995, -- Manila coordinates
        120.9842,
        'Test Location, Manila, Philippines',
        'pending',
        'broadcast',
        50.0,
        NOW()
    FROM user_profiles up
    WHERE up.user_type = 'customer'
    LIMIT 1
    RETURNING id INTO v_test_request_id;
    
    IF v_test_request_id IS NULL THEN
        RAISE NOTICE '❌ No customer found to create test request';
        RETURN;
    END IF;
    
    RAISE NOTICE '✅ Created test request: %', v_test_request_id;
    
    -- Test manual broadcast
    SELECT manual_broadcast_request(v_test_request_id) INTO v_result;
    
    RAISE NOTICE '📡 Broadcast result: %', v_result;
    
    -- Check routing entries created
    SELECT COUNT(*) INTO v_routing_count
    FROM request_routing
    WHERE request_id = v_test_request_id;
    
    RAISE NOTICE '📊 Routing entries created: %', v_routing_count;
    
    -- Show mechanic assignments
    RAISE NOTICE '📋 MECHANICS ASSIGNED TO TEST REQUEST:';
    
    -- Use a cursor loop to display mechanic assignments
    FOR v_mechanic IN 
        SELECT 
            up.email,
            up.first_name,
            up.last_name,
            rr.distance_km,
            rr.is_notified
        FROM request_routing rr
        JOIN user_profiles up ON up.id = rr.eligible_mechanic_id
        WHERE rr.request_id = v_test_request_id
        ORDER BY rr.distance_km
    LOOP
        RAISE NOTICE '  - % % (%) - Distance: %km - Notified: %', 
            v_mechanic.first_name, 
            v_mechanic.last_name, 
            v_mechanic.email, 
            v_mechanic.distance_km,
            v_mechanic.is_notified;
    END LOOP;
    
    -- Clean up test data
    DELETE FROM request_routing WHERE request_id = v_test_request_id;
    DELETE FROM service_requests WHERE id = v_test_request_id;
    
    RAISE NOTICE '🧹 Test data cleaned up';
    
END $$;

-- STEP 3: Verify trigger is working
DO $$
BEGIN
    RAISE NOTICE '=== VERIFYING TRIGGER SETUP ===';
END $$;

SELECT 
    '🔧 Trigger Verification' as test_section,
    trigger_name,
    event_manipulation,
    action_timing,
    action_statement
FROM information_schema.triggers 
WHERE trigger_name LIKE '%broadcast%' 
AND event_object_table = 'service_requests';

-- STEP 4: Check for any existing pending requests and their routing
DO $$
BEGIN
    RAISE NOTICE '=== CHECKING EXISTING PENDING REQUESTS ===';
END $$;

SELECT 
    '📨 Pending Requests Routing' as test_section,
    sr.id as request_id,
    sr.title,
    sr.status,
    sr.request_type,
    sr.mechanics_notified_count,
    COUNT(rr.id) as actual_routing_entries,
    STRING_AGG(up.email, ', ') as mechanics_assigned
FROM service_requests sr
LEFT JOIN request_routing rr ON rr.request_id = sr.id
LEFT JOIN user_profiles up ON up.id = rr.eligible_mechanic_id
WHERE sr.status = 'pending'
GROUP BY sr.id, sr.title, sr.status, sr.request_type, sr.mechanics_notified_count
ORDER BY sr.created_at DESC
LIMIT 10;

-- STEP 5: Test that all mechanics have proper realtime channel access
DO $$
BEGIN
    RAISE NOTICE '=== TESTING REALTIME CHANNEL ACCESS ===';
END $$;

SELECT 
    '🔴 Realtime Access Check' as test_section,
    up.email,
    up.first_name,
    up.last_name,
    CASE 
        WHEN mas.mechanic_id IS NOT NULL THEN 'CAN LISTEN'
        ELSE 'NO ACCESS'
    END as realtime_status
FROM user_profiles up
LEFT JOIN mechanic_availability_status mas ON mas.mechanic_id = up.id
WHERE up.user_type = 'mechanic'
ORDER BY up.email;

-- STEP 6: Verify database functions exist
DO $$
BEGIN
    RAISE NOTICE '=== VERIFYING DATABASE FUNCTIONS ===';
END $$;

SELECT 
    '⚙️ Function Check' as test_section,
    routine_name,
    routine_type,
    data_type as return_type
FROM information_schema.routines 
WHERE routine_name IN (
    'broadcast_service_request_to_all_mechanics',
    'manual_broadcast_request',
    'trigger_broadcast_new_request'
)
ORDER BY routine_name;

-- STEP 7: Show summary of fix status
DO $$
DECLARE
    v_mechanic_count integer;
    v_available_count integer;
    v_function_count integer;
    v_trigger_count integer;
BEGIN
    RAISE NOTICE '=== FIX STATUS SUMMARY ===';
    
    -- Count mechanics
    SELECT COUNT(*) INTO v_mechanic_count
    FROM user_profiles
    WHERE user_type = 'mechanic';
    
    -- Count available mechanics
    SELECT COUNT(*) INTO v_available_count
    FROM mechanic_availability_status mas
    JOIN user_profiles up ON up.id = mas.mechanic_id
    WHERE up.user_type = 'mechanic'
    AND mas.is_accepting_requests = true
    AND mas.current_status = 'available';
    
    -- Count required functions
    SELECT COUNT(*) INTO v_function_count
    FROM information_schema.routines 
    WHERE routine_name IN (
        'broadcast_service_request_to_all_mechanics',
        'manual_broadcast_request',
        'trigger_broadcast_new_request'
    );
    
    -- Count triggers
    SELECT COUNT(*) INTO v_trigger_count
    FROM information_schema.triggers 
    WHERE trigger_name LIKE '%broadcast%' 
    AND event_object_table = 'service_requests';
    
    RAISE NOTICE '📊 SUMMARY:';
    RAISE NOTICE '  - Total mechanics: %', v_mechanic_count;
    RAISE NOTICE '  - Available mechanics: %', v_available_count;
    RAISE NOTICE '  - Required functions: % / 3', v_function_count;
    RAISE NOTICE '  - Broadcast triggers: %', v_trigger_count;
    
    IF v_available_count >= 2 AND v_function_count >= 3 AND v_trigger_count >= 1 THEN
        RAISE NOTICE '✅ MECHANIC BROADCAST FIX IS PROPERLY INSTALLED!';
        RAISE NOTICE '   ALL mechanics should now receive service requests.';
    ELSE
        RAISE NOTICE '❌ MECHANIC BROADCAST FIX HAS ISSUES:';
        IF v_available_count < 2 THEN
            RAISE NOTICE '     - Not enough available mechanics (need at least 2)';
        END IF;
        IF v_function_count < 3 THEN
            RAISE NOTICE '     - Missing database functions';
        END IF;
        IF v_trigger_count < 1 THEN
            RAISE NOTICE '     - Missing broadcast trigger';
        END IF;
    END IF;
END $$;