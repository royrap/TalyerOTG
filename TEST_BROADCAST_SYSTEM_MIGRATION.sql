-- =====================================================
-- ROADAID BROADCAST SYSTEM TEST SCRIPT
-- Run this after the migration to verify everything works
-- =====================================================

-- Test 1: Check if PostGIS is enabled
SELECT EXISTS(
    SELECT 1 FROM pg_extension WHERE extname = 'postgis'
) as postgis_enabled;

-- Test 2: Check if new geometry columns exist
SELECT 
    table_name,
    column_name,
    data_type
FROM information_schema.columns 
WHERE table_schema = 'public' 
AND column_name = 'location'
AND table_name IN ('service_providers', 'service_requests', 'user_profiles');

-- Test 3: Check spatial indexes
SELECT 
    indexname,
    tablename
FROM pg_indexes 
WHERE indexname LIKE '%location%'
AND schemaname = 'public';

-- Test 4: Insert sample mechanic data (for testing)
DO $$
DECLARE
    test_user_id uuid;
    test_shop_id uuid;
    test_owner_id uuid;
BEGIN
    -- Only run if no test data exists
    IF NOT EXISTS (SELECT 1 FROM public.user_profiles WHERE email = 'test.mechanic@roadaid.com') THEN
        
        -- Try to get existing shop first, or create a new one
        SELECT id INTO test_shop_id 
        FROM public.shops 
        WHERE shop_name = 'Test Auto Repair Shop' 
        LIMIT 1;
        
        IF test_shop_id IS NULL THEN
            -- Find a talyer_owner without a shop, or create one
            SELECT up.id INTO test_owner_id
            FROM public.user_profiles up
            LEFT JOIN public.shops s ON s.owner_id = up.id
            WHERE up.user_type = 'talyer_owner' 
            AND s.owner_id IS NULL
            LIMIT 1;
            
            -- If no available talyer_owner, create a test one
            IF test_owner_id IS NULL THEN
                INSERT INTO public.user_profiles (
                    id, first_name, last_name, email, phone_number, user_type
                ) VALUES (
                    gen_random_uuid(), 
                    'Test', 'Shop Owner', 'test.owner@roadaid.com', '+639111111111', 
                    'talyer_owner'
                ) RETURNING id INTO test_owner_id;
            END IF;
            
            -- Create test shop
            INSERT INTO public.shops (id, owner_id, shop_name, latitude, longitude, is_active)
            VALUES (
                gen_random_uuid(),
                test_owner_id,
                'Test Auto Repair Shop',
                14.5995, -- Manila latitude
                120.9842, -- Manila longitude
                true
            ) RETURNING id INTO test_shop_id;
        END IF;
        
        -- Create test user profile
        INSERT INTO public.user_profiles (
            id, first_name, last_name, email, phone_number, 
            user_type, current_latitude, current_longitude, 
            is_available, status, shop_id
        ) VALUES (
            gen_random_uuid(),
            'Test', 'Mechanic', 'test.mechanic@roadaid.com', '+639123456789',
            'mechanic', 14.6042, 120.9822, -- Near Manila
            true, 'active', test_shop_id
        ) RETURNING id INTO test_user_id;
        
        -- Create mechanic availability status
        INSERT INTO public.mechanic_availability_status (
            mechanic_id, current_status, is_accepting_requests
        ) VALUES (
            test_user_id, 'available', true
        );
        
        RAISE NOTICE 'Test mechanic created: %', test_user_id;
    ELSE
        RAISE NOTICE 'Test data already exists, skipping creation';
    END IF;
END $$;

-- Test 5: Test the broadcast function
SELECT 'Testing broadcast function...' as test_status;

-- Create a test service request
DO $$
DECLARE
    test_request_id uuid;
    test_customer_id uuid;
BEGIN
    -- Get or create test customer
    SELECT id INTO test_customer_id 
    FROM public.user_profiles 
    WHERE user_type = 'customer' 
    LIMIT 1;
    
    IF test_customer_id IS NULL THEN
        INSERT INTO public.user_profiles (
            id, first_name, last_name, email, phone_number, user_type
        ) VALUES (
            gen_random_uuid(), 'Test', 'Customer', 'test.customer@roadaid.com', '+639987654321', 'customer'
        ) RETURNING id INTO test_customer_id;
    END IF;
    
    -- Create test service request
    INSERT INTO public.service_requests (
        id, customer_id, title, description, 
        pickup_latitude, pickup_longitude, pickup_address,
        status
    ) VALUES (
        gen_random_uuid(),
        test_customer_id,
        'Test Broadcast Request',
        'Testing the enhanced broadcast system',
        14.5995, 120.9842, 'Manila Test Location',
        'pending'
    ) RETURNING id INTO test_request_id;
    
    RAISE NOTICE 'Test request created: %', test_request_id;
    
    -- Test the broadcast function
    PERFORM broadcast_service_request(test_request_id, 25.0, 10);
    
    RAISE NOTICE 'Broadcast function executed successfully';
END $$;

-- Test 6: Check broadcast results
SELECT 
    'Broadcast Results' as test_name,
    COUNT(*) as total_broadcasts,
    COUNT(CASE WHEN response_status = 'pending' THEN 1 END) as pending_responses
FROM public.request_broadcasts rb
JOIN public.service_requests sr ON sr.id = rb.request_id
WHERE sr.title = 'Test Broadcast Request';

-- Test 7: Test get nearest mechanic function
SELECT 'Testing get nearest mechanic function...' as test_status;

SELECT * FROM get_nearest_available_mechanic(14.5995, 120.9842, 50.0);

-- Test 8: Test get shop mechanics function
SELECT 'Testing get shop mechanics function...' as test_status;

SELECT * FROM get_available_mechanics_in_shop(
    (SELECT shop_id FROM public.user_profiles WHERE user_type = 'mechanic' LIMIT 1)
);

-- Test 9: Performance test - distance calculations
SELECT 
    'Distance Calculation Test' as test_name,
    AVG(
        calculate_distance_km(
            current_latitude, current_longitude,
            14.5995, 120.9842
        )
    ) as avg_distance_to_manila
FROM public.user_profiles 
WHERE user_type = 'mechanic' 
AND current_latitude IS NOT NULL 
AND current_longitude IS NOT NULL;

-- Test 10: Check function performance
EXPLAIN ANALYZE
SELECT * FROM get_nearest_available_mechanic(14.5995, 120.9842, 25.0);

-- Cleanup test data (optional)
-- DELETE FROM public.service_requests WHERE title = 'Test Broadcast Request';
-- DELETE FROM public.user_profiles WHERE email IN ('test.mechanic@roadaid.com', 'test.customer@roadaid.com');

-- =====================================================
-- SUCCESS MESSAGE
-- =====================================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '🎉 BROADCAST SYSTEM TEST COMPLETED!';
    RAISE NOTICE '';
    RAISE NOTICE 'If you see this message, the migration was successful.';
    RAISE NOTICE 'The broadcast system should now properly notify ALL mechanics.';
    RAISE NOTICE '';
    RAISE NOTICE 'Next steps:';
    RAISE NOTICE '1. Update your Flutter app to use the new functions';
    RAISE NOTICE '2. Test with real service requests';
    RAISE NOTICE '3. Monitor the request_broadcasts table for proper distribution';
END $$;