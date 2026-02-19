-- =====================================================
-- ROUTING ANALYSIS AND FIX PARA SA MECHANIC VISIBILITY
-- Checking kung paano naka-save ang requests at kung working ang routing
-- =====================================================

-- PART 1: CHECK CURRENT REQUEST ROUTING STATUS
-- =====================================================

-- Check lahat ng pending requests at kung saan sila nakaroute
SELECT 
    'CURRENT REQUESTS ROUTING' as analysis_type,
    sr.id,
    sr.title,
    sr.shop_id,
    sr.request_type,
    sr.broadcast_radius_km,
    sr.mechanics_notified_count,
    sr.broadcast_timestamp,
    sr.status,
    CASE 
        WHEN sr.shop_id IS NOT NULL THEN 'SHOP-BASED: ' || s.shop_name
        WHEN sr.shop_id IS NULL THEN 'BROADCAST TO ALL MECHANICS'
        ELSE 'UNKNOWN'
    END as routing_method,
    sr.created_at
FROM service_requests sr
LEFT JOIN shops s ON s.id = sr.shop_id
WHERE sr.status = 'pending'
ORDER BY sr.created_at DESC
LIMIT 10;

-- Check kung may shop mechanics available para sa shop-based requests
SELECT 
    'SHOP MECHANICS AVAILABILITY' as analysis_type,
    s.shop_name,
    s.id as shop_id,
    COUNT(sm.mechanic_id) as total_mechanics,
    COUNT(CASE WHEN mas.current_status = 'available' AND mas.is_accepting_requests = true THEN 1 END) as available_mechanics,
    array_agg(up.email ORDER BY up.email) as mechanic_emails
FROM shops s
LEFT JOIN shop_mechanics sm ON sm.shop_id = s.id AND sm.is_active = true
LEFT JOIN user_profiles up ON up.id = sm.mechanic_id
LEFT JOIN mechanic_availability_status mas ON mas.mechanic_id = sm.mechanic_id
GROUP BY s.id, s.shop_name
ORDER BY s.shop_name;

-- Check broadcast routing entries
SELECT 
    'CURRENT BROADCAST ROUTING' as analysis_type,
    rr.request_id,
    sr.title,
    rr.eligible_mechanic_id,
    up.email as mechanic_email,
    up.first_name,
    up.last_name,
    rr.distance_km,
    rr.routing_type,
    rr.is_notified,
    rr.created_at
FROM request_routing rr
JOIN service_requests sr ON sr.id = rr.request_id
LEFT JOIN user_profiles up ON up.id = rr.eligible_mechanic_id
WHERE sr.status = 'pending'
ORDER BY rr.request_id, rr.distance_km;

-- PART 2: MECHANIC AVAILABILITY STATUS CHECK
-- =====================================================

-- Check both mechanics' availability status
SELECT 
    'MECHANIC AVAILABILITY CHECK' as analysis_type,
    up.email,
    up.first_name,
    up.last_name,
    up.user_type,
    mas.current_status,
    mas.is_accepting_requests,
    mas.location_latitude,
    mas.location_longitude,
    mas.shop_id,
    mas.current_request_id,
    s.shop_name,
    CASE 
        WHEN mas.is_accepting_requests = true 
        AND mas.current_status = 'available'
        AND mas.location_latitude IS NOT NULL
        AND mas.location_longitude IS NOT NULL
        AND mas.current_request_id IS NULL
        THEN '✅ READY FOR REQUESTS'
        ELSE '❌ NOT READY - ' || 
             CASE 
                WHEN mas.is_accepting_requests = false THEN 'NOT_ACCEPTING'
                WHEN mas.current_status != 'available' THEN 'STATUS_' || mas.current_status
                WHEN mas.location_latitude IS NULL THEN 'NO_LOCATION'
                WHEN mas.current_request_id IS NOT NULL THEN 'HAS_ACTIVE_REQUEST'
                ELSE 'UNKNOWN_ISSUE'
             END
    END as readiness_status
FROM user_profiles up
LEFT JOIN mechanic_availability_status mas ON mas.mechanic_id = up.id
LEFT JOIN shops s ON s.id = mas.shop_id
WHERE up.email IN ('yujirofuma28@gmail.com', 'rafaelpineda471@gmail.com')
ORDER BY up.email;

-- PART 3: FIX MECHANIC SETUP FOR BOTH SCENARIOS
-- =====================================================

-- Ensure both mechanics are properly configured
INSERT INTO mechanic_availability_status (
    mechanic_id,
    current_status,
    is_accepting_requests,
    location_latitude,
    location_longitude,
    last_status_update,
    created_at,
    updated_at,
    shop_id,
    current_request_id
)
SELECT 
    up.id,
    'available'::text,
    true,
    CASE 
        WHEN up.email = 'yujirofuma28@gmail.com' THEN 14.5995
        WHEN up.email = 'rafaelpineda471@gmail.com' THEN 14.5996
        ELSE 14.5997
    END,
    CASE 
        WHEN up.email = 'yujirofuma28@gmail.com' THEN 120.9842
        WHEN up.email = 'rafaelpineda471@gmail.com' THEN 120.9843
        ELSE 120.9844
    END,
    NOW(),
    NOW(),
    NOW(),
    NULL, -- No shop assignment = independent mechanics
    NULL  -- No current request
FROM user_profiles up
WHERE up.email IN ('yujirofuma28@gmail.com', 'rafaelpineda471@gmail.com')
ON CONFLICT (mechanic_id) DO UPDATE SET
    current_status = 'available',
    is_accepting_requests = true,
    location_latitude = EXCLUDED.location_latitude,
    location_longitude = EXCLUDED.location_longitude,
    last_status_update = NOW(),
    updated_at = NOW(),
    shop_id = NULL,  -- Make sure they're independent mechanics
    current_request_id = NULL;

-- PART 4: CREATE TEST REQUESTS FOR BOTH SCENARIOS
-- =====================================================

-- Test Scenario 1: Customer DOESN'T select shop (should broadcast to both mechanics)
DO $$
DECLARE
    v_customer_id uuid;
    v_test_request_1 uuid := gen_random_uuid();
    v_broadcast_result jsonb;
BEGIN
    -- Get a customer ID
    SELECT id INTO v_customer_id FROM user_profiles WHERE user_type = 'customer' LIMIT 1;
    
    IF v_customer_id IS NULL THEN
        RAISE NOTICE 'No customer found, creating test customer...';
        -- Create test customer if none exists
        INSERT INTO auth.users (id, email) VALUES (gen_random_uuid(), 'testcustomer@gmail.com')
        ON CONFLICT (email) DO NOTHING;
        
        INSERT INTO user_profiles (id, email, first_name, last_name, phone_number, user_type)
        SELECT au.id, 'testcustomer@gmail.com', 'Test', 'Customer', '09123456789', 'customer'
        FROM auth.users au WHERE au.email = 'testcustomer@gmail.com'
        ON CONFLICT (email) DO NOTHING;
        
        SELECT id INTO v_customer_id FROM user_profiles WHERE email = 'testcustomer@gmail.com';
    END IF;
    
    -- Create test request WITHOUT shop (should broadcast)
    INSERT INTO service_requests (
        id,
        customer_id,
        title,
        description,
        pickup_latitude,
        pickup_longitude,
        shop_id,  -- NULL = broadcast to all mechanics
        status,
        request_type,
        broadcast_radius_km
    ) VALUES (
        v_test_request_1,
        v_customer_id,
        'TEST: No Shop Selected - Should Broadcast to Both Mechanics',
        'Emergency brake repair - both mechanics should see this',
        14.5995,  -- Manila coordinates near both mechanics
        120.9842,
        NULL,     -- No shop selected
        'pending',
        'broadcast',
        10.0      -- 10km radius
    );
    
    RAISE NOTICE '';
    RAISE NOTICE '=== TEST REQUEST 1 CREATED (NO SHOP) ===';
    RAISE NOTICE 'Request ID: %', v_test_request_1;
    RAISE NOTICE 'Should broadcast to both mechanics within 10km';
    
    -- The trigger should automatically broadcast this
    -- But let's also manually test the broadcast function
    SELECT broadcast_service_request(
        v_test_request_1::text,
        14.5995,
        120.9842,
        10.0
    ) INTO v_broadcast_result;
    
    RAISE NOTICE 'Manual broadcast result: %', v_broadcast_result;
END $$;

-- Test Scenario 2: Customer SELECTS a shop (should go to shop mechanics only)
DO $$
DECLARE
    v_customer_id uuid;
    v_test_request_2 uuid := gen_random_uuid();
    v_test_shop_id uuid;
    v_shop_owner_id uuid;
BEGIN
    -- Get customer
    SELECT id INTO v_customer_id FROM user_profiles WHERE user_type = 'customer' LIMIT 1;
    
    -- Create test shop if none exists
    SELECT id INTO v_shop_owner_id FROM user_profiles 
    WHERE user_type = 'talyer_owner' OR email = 'yujirofuma28@gmail.com' LIMIT 1;
    
    IF v_shop_owner_id IS NULL THEN
        -- Use yujiro as shop owner for testing
        SELECT id INTO v_shop_owner_id FROM user_profiles WHERE email = 'yujirofuma28@gmail.com';
        
        -- Update yujiro to be shop owner
        UPDATE user_profiles SET user_type = 'talyer_owner' WHERE id = v_shop_owner_id;
    END IF;
    
    -- Create test shop
    INSERT INTO shops (id, owner_id, shop_name, shop_address, latitude, longitude, is_active)
    VALUES (
        gen_random_uuid(),
        v_shop_owner_id,
        'Test Auto Shop',
        'Manila Test Location',
        14.5995,
        120.9842,
        true
    )
    ON CONFLICT (owner_id) DO UPDATE SET
        shop_name = 'Test Auto Shop',
        is_active = true
    RETURNING id INTO v_test_shop_id;
    
    -- Get shop id if already exists
    IF v_test_shop_id IS NULL THEN
        SELECT id INTO v_test_shop_id FROM shops WHERE owner_id = v_shop_owner_id;
    END IF;
    
    -- Add both mechanics to this shop
    INSERT INTO shop_mechanics (shop_id, mechanic_id, is_active, is_available)
    SELECT v_test_shop_id, up.id, true, true
    FROM user_profiles up
    WHERE up.email IN ('yujirofuma28@gmail.com', 'rafaelpineda471@gmail.com')
    ON CONFLICT (shop_id, mechanic_id) DO UPDATE SET
        is_active = true,
        is_available = true;
    
    -- Create test request WITH shop (should go to shop mechanics only)
    INSERT INTO service_requests (
        id,
        customer_id,
        title,
        description,
        pickup_latitude,
        pickup_longitude,
        shop_id,  -- Specific shop selected
        status,
        request_type
    ) VALUES (
        v_test_request_2,
        v_customer_id,
        'TEST: Shop Selected - Should Go to Shop Mechanics Only',
        'Oil change service - only shop mechanics should see this',
        14.5995,
        120.9842,
        v_test_shop_id,  -- Specific shop
        'pending',
        'shop_based'
    );
    
    RAISE NOTICE '';
    RAISE NOTICE '=== TEST REQUEST 2 CREATED (WITH SHOP) ===';
    RAISE NOTICE 'Request ID: %', v_test_request_2;
    RAISE NOTICE 'Shop ID: %', v_test_shop_id;
    RAISE NOTICE 'Should go to shop mechanics only';
END $$;

-- PART 5: VERIFY ROUTING RESULTS
-- =====================================================

-- Check results ng test requests
SELECT 
    'TEST RESULTS - BROADCAST ROUTING' as test_type,
    sr.title,
    sr.shop_id,
    sr.request_type,
    COUNT(rr.id) as mechanics_routed,
    array_agg(up.email ORDER BY up.email) as mechanics_notified
FROM service_requests sr
LEFT JOIN request_routing rr ON rr.request_id = sr.id
LEFT JOIN user_profiles up ON up.id = rr.eligible_mechanic_id
WHERE sr.title LIKE 'TEST:%'
AND sr.shop_id IS NULL  -- Broadcast requests
GROUP BY sr.id, sr.title, sr.shop_id, sr.request_type
ORDER BY sr.created_at DESC;

-- Check shop-based routing
SELECT 
    'TEST RESULTS - SHOP ROUTING' as test_type,
    sr.title,
    sr.shop_id,
    s.shop_name,
    sr.request_type,
    COUNT(sm.mechanic_id) as available_shop_mechanics,
    array_agg(up.email ORDER BY up.email) as shop_mechanics
FROM service_requests sr
LEFT JOIN shops s ON s.id = sr.shop_id
LEFT JOIN shop_mechanics sm ON sm.shop_id = sr.shop_id AND sm.is_active = true
LEFT JOIN user_profiles up ON up.id = sm.mechanic_id
WHERE sr.title LIKE 'TEST:%'
AND sr.shop_id IS NOT NULL  -- Shop-based requests
GROUP BY sr.id, sr.title, sr.shop_id, s.shop_name, sr.request_type
ORDER BY sr.created_at DESC;

-- PART 6: DIAGNOSTIC QUERIES PARA SA DEBUGGING
-- =====================================================

-- Query para makita kung working ang broadcast system
CREATE OR REPLACE VIEW mechanic_broadcast_readiness AS
SELECT 
    up.email,
    up.first_name,
    up.last_name,
    mas.current_status,
    mas.is_accepting_requests,
    mas.location_latitude,
    mas.location_longitude,
    mas.shop_id,
    mas.current_request_id,
    CASE 
        WHEN mas.is_accepting_requests = true 
        AND mas.current_status = 'available'
        AND mas.location_latitude IS NOT NULL
        AND mas.location_longitude IS NOT NULL
        AND mas.current_request_id IS NULL
        THEN 'READY_FOR_BROADCAST'
        ELSE 'NOT_READY'
    END as broadcast_eligibility,
    -- Calculate distance from test location (Manila)
    CASE 
        WHEN mas.location_latitude IS NOT NULL AND mas.location_longitude IS NOT NULL THEN
            (6371 * acos(
                cos(radians(14.5995)) * 
                cos(radians(mas.location_latitude)) * 
                cos(radians(mas.location_longitude) - radians(120.9842)) + 
                sin(radians(14.5995)) * 
                sin(radians(mas.location_latitude))
            ))
        ELSE NULL
    END as distance_from_manila_km
FROM user_profiles up
LEFT JOIN mechanic_availability_status mas ON mas.mechanic_id = up.id
WHERE up.user_type = 'mechanic';

-- Query para makita kung working ang shop routing
CREATE OR REPLACE VIEW shop_mechanic_availability AS
SELECT 
    s.shop_name,
    s.id as shop_id,
    s.is_active as shop_active,
    COUNT(sm.mechanic_id) as total_mechanics,
    COUNT(CASE WHEN sm.is_active = true AND sm.is_available = true THEN 1 END) as active_mechanics,
    COUNT(CASE WHEN mas.current_status = 'available' AND mas.is_accepting_requests = true THEN 1 END) as available_mechanics,
    array_agg(
        CASE WHEN sm.is_active = true THEN 
            up.email || ' (' || COALESCE(mas.current_status, 'no_status') || ')'
        END
        ORDER BY up.email
    ) as mechanic_details
FROM shops s
LEFT JOIN shop_mechanics sm ON sm.shop_id = s.id
LEFT JOIN user_profiles up ON up.id = sm.mechanic_id
LEFT JOIN mechanic_availability_status mas ON mas.mechanic_id = sm.mechanic_id
GROUP BY s.id, s.shop_name, s.is_active
ORDER BY s.shop_name;

-- Final status check
SELECT 'FINAL STATUS CHECK' as check_type;
SELECT * FROM mechanic_broadcast_readiness WHERE email IN ('yujirofuma28@gmail.com', 'rafaelpineda471@gmail.com');
SELECT * FROM shop_mechanic_availability WHERE total_mechanics > 0;

RAISE NOTICE '';
RAISE NOTICE '=== ROUTING ANALYSIS COMPLETE ===';
RAISE NOTICE '1. Check mechanic_broadcast_readiness view for broadcast eligibility';
RAISE NOTICE '2. Check shop_mechanic_availability view for shop routing';
RAISE NOTICE '3. Look for TEST requests in the output above';
RAISE NOTICE '4. Both mechanics should be READY_FOR_BROADCAST';
RAISE NOTICE '5. If shop created, both should appear in shop mechanics';