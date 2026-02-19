-- =====================================================
-- SHOP-BASED ROUTING FIX PARA SA YUJIRO VISIBILITY
-- =====================================================

-- STEP 1: Check current shop mechanics setup
-- =====================================================
SELECT 
    'CURRENT SHOP MECHANICS STATUS' as check_type,
    s.shop_name,
    s.id as shop_id,
    s.owner_id,
    so.email as shop_owner_email,
    COUNT(sm.mechanic_id) as total_mechanics,
    array_agg(
        up.email || ' (active: ' || sm.is_active || ', available: ' || sm.is_available || ')'
        ORDER BY up.email
    ) as mechanics_status
FROM shops s
LEFT JOIN user_profiles so ON so.id = s.owner_id
LEFT JOIN shop_mechanics sm ON sm.shop_id = s.id
LEFT JOIN user_profiles up ON up.id = sm.mechanic_id
WHERE s.is_active = true
GROUP BY s.id, s.shop_name, s.owner_id, so.email
ORDER BY s.shop_name;

-- STEP 2: Ensure both mechanics are added to ALL shops
-- =====================================================

-- Get all active shops
DO $$
DECLARE
    shop_record RECORD;
    yujiro_id uuid;
    rafael_id uuid;
BEGIN
    -- Get mechanic IDs
    SELECT id INTO yujiro_id FROM user_profiles WHERE email = 'yujirofuma28@gmail.com';
    SELECT id INTO rafael_id FROM user_profiles WHERE email = 'rafaelpineda471@gmail.com';
    
    RAISE NOTICE 'Adding both mechanics to all active shops...';
    RAISE NOTICE 'Yujiro ID: %', yujiro_id;
    RAISE NOTICE 'Rafael ID: %', rafael_id;
    
    -- Loop through all active shops
    FOR shop_record IN 
        SELECT id, shop_name, owner_id FROM shops WHERE is_active = true
    LOOP
        RAISE NOTICE 'Processing shop: % (ID: %)', shop_record.shop_name, shop_record.id;
        
        -- Add Yujiro to shop
        INSERT INTO shop_mechanics (shop_id, mechanic_id, is_active, is_available, created_at, updated_at)
        VALUES (shop_record.id, yujiro_id, true, true, NOW(), NOW())
        ON CONFLICT (shop_id, mechanic_id) DO UPDATE SET
            is_active = true,
            is_available = true,
            updated_at = NOW();
            
        -- Add Rafael to shop
        INSERT INTO shop_mechanics (shop_id, mechanic_id, is_active, is_available, created_at, updated_at)
        VALUES (shop_record.id, rafael_id, true, true, NOW(), NOW())
        ON CONFLICT (shop_id, mechanic_id) DO UPDATE SET
            is_active = true,
            is_available = true,
            updated_at = NOW();
            
        RAISE NOTICE 'Added both mechanics to shop: %', shop_record.shop_name;
    END LOOP;
    
    RAISE NOTICE 'Shop mechanics setup completed!';
END $$;

-- STEP 3: Create comprehensive shop-based routing trigger
-- =====================================================

-- Drop existing trigger if exists
DROP TRIGGER IF EXISTS on_service_request_insert_shop_routing ON service_requests;
DROP FUNCTION IF EXISTS handle_shop_based_routing();

-- Create new shop-based routing function
CREATE OR REPLACE FUNCTION handle_shop_based_routing()
RETURNS TRIGGER AS $$
DECLARE
    v_shop_mechanics_count integer;
    v_mechanic_record RECORD;
    v_notification_payload jsonb;
BEGIN
    -- Only handle shop-based requests (shop_id is NOT NULL)
    IF NEW.shop_id IS NOT NULL THEN
        RAISE NOTICE 'Processing shop-based request: % for shop: %', NEW.id, NEW.shop_id;
        
        -- Count available mechanics in the shop
        SELECT COUNT(*) INTO v_shop_mechanics_count
        FROM shop_mechanics sm
        JOIN mechanic_availability_status mas ON mas.mechanic_id = sm.mechanic_id
        WHERE sm.shop_id = NEW.shop_id
        AND sm.is_active = true
        AND sm.is_available = true
        AND mas.current_status = 'available'
        AND mas.is_accepting_requests = true;
        
        RAISE NOTICE 'Found % available mechanics in shop', v_shop_mechanics_count;
        
        -- Update request with shop mechanic count
        UPDATE service_requests 
        SET mechanics_notified_count = v_shop_mechanics_count,
            request_type = 'shop_based'
        WHERE id = NEW.id;
        
        -- Create notifications for all shop mechanics
        FOR v_mechanic_record IN
            SELECT 
                sm.mechanic_id,
                up.email,
                up.first_name,
                up.last_name,
                mas.current_status,
                mas.is_accepting_requests
            FROM shop_mechanics sm
            JOIN user_profiles up ON up.id = sm.mechanic_id
            JOIN mechanic_availability_status mas ON mas.mechanic_id = sm.mechanic_id
            WHERE sm.shop_id = NEW.shop_id
            AND sm.is_active = true
            AND sm.is_available = true
            AND mas.current_status = 'available'
            AND mas.is_accepting_requests = true
        LOOP
            RAISE NOTICE 'Notifying mechanic: % (%)', v_mechanic_record.email, v_mechanic_record.mechanic_id;
            
            -- Create notification record in request_routing table
            INSERT INTO request_routing (
                request_id,
                eligible_mechanic_id,
                routing_type,
                distance_km,
                is_notified,
                created_at,
                shop_id
            ) VALUES (
                NEW.id,
                v_mechanic_record.mechanic_id,
                'shop_based',
                0.0, -- Shop-based requests don't need distance calculation
                true,
                NOW(),
                NEW.shop_id
            );
            
            -- Create realtime notification payload
            v_notification_payload := jsonb_build_object(
                'type', 'new_service_request',
                'request_id', NEW.id,
                'shop_id', NEW.shop_id,
                'mechanic_id', v_mechanic_record.mechanic_id,
                'title', NEW.title,
                'description', NEW.description,
                'pickup_address', NEW.pickup_address,
                'pickup_latitude', NEW.pickup_latitude,
                'pickup_longitude', NEW.pickup_longitude,
                'routing_type', 'shop_based',
                'customer_name', (
                    SELECT COALESCE(first_name || ' ' || last_name, email)
                    FROM user_profiles WHERE id = NEW.customer_id
                ),
                'timestamp', NOW()
            );
            
            -- Send realtime notification
            PERFORM pg_notify(
                'mechanic_channel_' || v_mechanic_record.mechanic_id::text,
                v_notification_payload::text
            );
            
            RAISE NOTICE 'Sent notification to mechanic: %', v_mechanic_record.email;
        END LOOP;
        
        RAISE NOTICE 'Shop-based routing completed for request: %', NEW.id;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for shop-based routing
CREATE TRIGGER on_service_request_insert_shop_routing
    AFTER INSERT ON service_requests
    FOR EACH ROW
    EXECUTE FUNCTION handle_shop_based_routing();

-- STEP 4: Test the fix with a shop-based request
-- =====================================================

DO $$
DECLARE
    v_customer_id uuid;
    v_test_shop_id uuid;
    v_test_request_id uuid := gen_random_uuid();
    v_yujiro_id uuid;
    v_rafael_id uuid;
BEGIN
    -- Get mechanic IDs
    SELECT id INTO v_yujiro_id FROM user_profiles WHERE email = 'yujirofuma28@gmail.com';
    SELECT id INTO v_rafael_id FROM user_profiles WHERE email = 'rafaelpineda471@gmail.com';
    
    -- Get or create customer
    SELECT id INTO v_customer_id FROM user_profiles WHERE user_type = 'customer' LIMIT 1;
    
    IF v_customer_id IS NULL THEN
        INSERT INTO user_profiles (id, email, first_name, last_name, phone_number, user_type)
        VALUES (gen_random_uuid(), 'testcustomer@gmail.com', 'Test', 'Customer', '09123456789', 'customer')
        ON CONFLICT (email) DO UPDATE SET user_type = 'customer'
        RETURNING id INTO v_customer_id;
    END IF;
    
    -- Get or create test shop
    SELECT id INTO v_test_shop_id FROM shops WHERE shop_name = 'Test Auto Repair Shop' LIMIT 1;
    
    IF v_test_shop_id IS NULL THEN
        INSERT INTO shops (id, owner_id, shop_name, shop_address, latitude, longitude, is_active)
        VALUES (gen_random_uuid(), v_yujiro_id, 'Test Auto Repair Shop', 'Manila Test Location', 14.5995, 120.9842, true)
        RETURNING id INTO v_test_shop_id;
        
        RAISE NOTICE 'Created test shop with ID: %', v_test_shop_id;
    END IF;
    
    -- Ensure both mechanics are in the shop
    INSERT INTO shop_mechanics (shop_id, mechanic_id, is_active, is_available)
    VALUES 
        (v_test_shop_id, v_yujiro_id, true, true),
        (v_test_shop_id, v_rafael_id, true, true)
    ON CONFLICT (shop_id, mechanic_id) DO UPDATE SET
        is_active = true,
        is_available = true;
    
    -- Create test request with shop selected
    INSERT INTO service_requests (
        id,
        customer_id,
        title,
        description,
        pickup_latitude,
        pickup_longitude,
        pickup_address,
        shop_id,
        status,
        request_type
    ) VALUES (
        v_test_request_id,
        v_customer_id,
        'SHOP TEST: Both Mechanics Should See This',
        'Car engine trouble - shop selected, both Yujiro and Rafael should receive this',
        14.5995,
        120.9842,
        'Manila Test Location',
        v_test_shop_id,
        'pending',
        'shop_based'
    );
    
    RAISE NOTICE '';
    RAISE NOTICE '=== SHOP-BASED TEST REQUEST CREATED ===';
    RAISE NOTICE 'Request ID: %', v_test_request_id;
    RAISE NOTICE 'Shop ID: %', v_test_shop_id;
    RAISE NOTICE 'Customer ID: %', v_customer_id;
    RAISE NOTICE 'This should trigger notifications to BOTH Yujiro and Rafael';
    
END $$;

-- STEP 5: Verify the fix worked
-- =====================================================

-- Check routing results for the test request
SELECT 
    'SHOP ROUTING VERIFICATION' as test_type,
    sr.title,
    sr.shop_id,
    s.shop_name,
    sr.mechanics_notified_count,
    COUNT(rr.eligible_mechanic_id) as actual_mechanics_notified,
    array_agg(up.email ORDER BY up.email) as mechanics_notified
FROM service_requests sr
LEFT JOIN shops s ON s.id = sr.shop_id
LEFT JOIN request_routing rr ON rr.request_id = sr.id AND rr.routing_type = 'shop_based'
LEFT JOIN user_profiles up ON up.id = rr.eligible_mechanic_id
WHERE sr.title LIKE 'SHOP TEST:%'
GROUP BY sr.id, sr.title, sr.shop_id, s.shop_name, sr.mechanics_notified_count
ORDER BY sr.created_at DESC
LIMIT 1;

-- Check all shop mechanics status
SELECT 
    'ALL SHOP MECHANICS STATUS' as check_type,
    s.shop_name,
    COUNT(sm.mechanic_id) as total_mechanics,
    COUNT(CASE WHEN sm.is_active = true AND sm.is_available = true THEN 1 END) as active_mechanics,
    array_agg(
        up.email || ' (active:' || sm.is_active || ',avail:' || sm.is_available || ')'
        ORDER BY up.email
    ) as mechanic_details
FROM shops s
LEFT JOIN shop_mechanics sm ON sm.shop_id = s.id
LEFT JOIN user_profiles up ON up.id = sm.mechanic_id
WHERE s.is_active = true
GROUP BY s.id, s.shop_name
ORDER BY s.shop_name;

-- Final check: Both mechanics should be ready
SELECT 
    'MECHANIC READINESS CHECK' as check_type,
    up.email,
    mas.current_status,
    mas.is_accepting_requests,
    COUNT(sm.shop_id) as assigned_shops,
    CASE 
        WHEN mas.current_status = 'available' 
        AND mas.is_accepting_requests = true 
        AND COUNT(sm.shop_id) > 0
        THEN '✅ READY FOR SHOP REQUESTS'
        ELSE '❌ NOT READY: ' || 
             CASE 
                WHEN mas.current_status != 'available' THEN 'STATUS_' || mas.current_status
                WHEN mas.is_accepting_requests = false THEN 'NOT_ACCEPTING'
                WHEN COUNT(sm.shop_id) = 0 THEN 'NO_SHOP_ASSIGNMENT'
                ELSE 'UNKNOWN_ISSUE'
             END
    END as shop_request_readiness
FROM user_profiles up
LEFT JOIN mechanic_availability_status mas ON mas.mechanic_id = up.id
LEFT JOIN shop_mechanics sm ON sm.mechanic_id = up.id AND sm.is_active = true
WHERE up.email IN ('yujirofuma28@gmail.com', 'rafaelpineda471@gmail.com')
GROUP BY up.id, up.email, mas.current_status, mas.is_accepting_requests
ORDER BY up.email;

RAISE NOTICE '';
RAISE NOTICE '=== SHOP-BASED ROUTING FIX COMPLETE ===';
RAISE NOTICE '1. Both mechanics added to all active shops';
RAISE NOTICE '2. Shop-based routing trigger created';
RAISE NOTICE '3. Test request created with shop selection';
RAISE NOTICE '4. Verify both mechanics receive shop-based requests now';
RAISE NOTICE '5. Check your mobile app - both should see shop requests';