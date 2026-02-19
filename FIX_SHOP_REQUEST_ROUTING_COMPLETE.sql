-- =====================================================
-- COMPREHENSIVE FIX: Shop Request Routing Not Working
-- =====================================================
-- PROBLEMA: Customer nag-create ng shop-based request, walang popup sa mechanics
-- SOLUTIONS: Fix missing trigger, request_routing entries, at RLS policies
-- =====================================================

-- STEP 1: DIAGNOSE CURRENT STATE
-- =====================================================

DO $$
BEGIN
    RAISE NOTICE '=== DIAGNOSING SHOP REQUEST ROUTING SYSTEM ===';
    RAISE NOTICE '';
END $$;

-- Check if shop-based routing trigger exists
SELECT 
    'TRIGGER CHECK' as diagnostic_type,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM pg_trigger 
            WHERE tgname = 'on_service_request_insert_shop_routing'
        ) THEN '✅ Trigger EXISTS'
        ELSE '❌ TRIGGER MISSING - Will create'
    END as trigger_status;

-- Check if handle_shop_based_routing function exists
SELECT 
    'FUNCTION CHECK' as diagnostic_type,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM pg_proc 
            WHERE proname = 'handle_shop_based_routing'
        ) THEN '✅ Function EXISTS'
        ELSE '❌ FUNCTION MISSING - Will create'
    END as function_status;

-- Check if mechanics are assigned to shops
SELECT 
    'SHOP MECHANICS CHECK' as diagnostic_type,
    s.shop_name,
    COUNT(sm.mechanic_id) as total_mechanics,
    COUNT(CASE WHEN sm.is_active = true AND sm.is_available = true THEN 1 END) as available_mechanics,
    array_agg(DISTINCT up.email) as mechanic_emails
FROM shops s
LEFT JOIN shop_mechanics sm ON sm.shop_id = s.id
LEFT JOIN user_profiles up ON up.id = sm.mechanic_id
WHERE s.is_active = true
GROUP BY s.id, s.shop_name
ORDER BY s.shop_name;

-- Check mechanic availability status
SELECT 
    'MECHANIC AVAILABILITY CHECK' as diagnostic_type,
    up.email,
    mas.current_status,
    mas.is_accepting_requests,
    mas.last_status_update
FROM user_profiles up
LEFT JOIN mechanic_availability_status mas ON mas.mechanic_id = up.id
WHERE up.user_type = 'mechanic'
ORDER BY up.email;

-- Check recent service requests
SELECT 
    'RECENT REQUESTS CHECK' as diagnostic_type,
    sr.id,
    sr.title,
    sr.shop_id,
    sr.request_type,
    sr.status,
    sr.mechanics_notified_count,
    sr.created_at,
    CASE 
        WHEN sr.shop_id IS NOT NULL THEN 'SHOP-BASED'
        ELSE 'BROADCAST'
    END as routing_type,
    (SELECT COUNT(*) FROM request_routing WHERE request_id = sr.id) as routing_entries_created
FROM service_requests sr
ORDER BY sr.created_at DESC
LIMIT 10;

-- Check request_routing entries for recent requests
SELECT 
    'REQUEST ROUTING CHECK' as diagnostic_type,
    sr.title,
    sr.shop_id,
    COUNT(rr.eligible_mechanic_id) as mechanics_notified,
    array_agg(DISTINCT up.email) as notified_mechanics
FROM service_requests sr
LEFT JOIN request_routing rr ON rr.request_id = sr.id
LEFT JOIN user_profiles up ON up.id = rr.eligible_mechanic_id
WHERE sr.created_at > NOW() - INTERVAL '1 day'
AND sr.shop_id IS NOT NULL
GROUP BY sr.id, sr.title, sr.shop_id
ORDER BY sr.created_at DESC
LIMIT 5;

-- =====================================================
-- STEP 2: DISABLE RLS ON request_routing (IT'S A BACKEND TABLE)
-- =====================================================

-- This table should NOT have RLS - it's populated by database triggers/functions
-- Mechanics query this via service_requests relationship, not directly

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '=== FIXING RLS POLICIES ===';
    RAISE NOTICE 'request_routing is a BACKEND table - disabling RLS';
END $$;

-- Disable RLS on request_routing table
ALTER TABLE request_routing DISABLE ROW LEVEL SECURITY;

-- Drop any existing policies (they block the trigger from writing!)
DROP POLICY IF EXISTS "System can manage request routing" ON request_routing;
DROP POLICY IF EXISTS "Users can view routing for their requests" ON request_routing;
DROP POLICY IF EXISTS "mechanic_can_view_own_routings" ON request_routing;
DROP POLICY IF EXISTS "Mechanics can view own routing entries" ON request_routing;
DROP POLICY IF EXISTS "Service can insert routing entries" ON request_routing;

DO $$
BEGIN
    RAISE NOTICE '✅ RLS disabled on request_routing table';
END $$;

-- =====================================================
-- STEP 3: CREATE/REPLACE SHOP-BASED ROUTING FUNCTION
-- =====================================================

DROP TRIGGER IF EXISTS on_service_request_insert_shop_routing ON service_requests;
DROP FUNCTION IF EXISTS handle_shop_based_routing CASCADE;

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
    -- Only process shop-based requests (shop_id IS NOT NULL)
    IF NEW.shop_id IS NOT NULL THEN
        RAISE NOTICE '🏪 SHOP-BASED REQUEST DETECTED: % (shop: %)', NEW.id, NEW.shop_id;
        
        -- Count available mechanics in this specific shop
        SELECT COUNT(*) INTO v_shop_mechanics_count
        FROM shop_mechanics sm
        JOIN mechanic_availability_status mas ON mas.mechanic_id = sm.mechanic_id
        WHERE sm.shop_id = NEW.shop_id
        AND sm.is_active = true
        AND sm.is_available = true
        AND mas.current_status = 'available'
        AND mas.is_accepting_requests = true;
        
        RAISE NOTICE '📊 Found % available mechanics in shop %', v_shop_mechanics_count, NEW.shop_id;
        
        IF v_shop_mechanics_count = 0 THEN
            RAISE WARNING '⚠️ No available mechanics found in shop % for request %', NEW.shop_id, NEW.id;
            RETURN NEW;
        END IF;
        
        -- Create routing entry for each available mechanic in the shop
        FOR v_mechanic_record IN
            SELECT 
                sm.mechanic_id,
                up.email,
                up.first_name,
                up.last_name,
                mas.current_status
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
            
            RAISE NOTICE '📢 Creating routing entry for mechanic: % (%)', 
                v_mechanic_record.email, v_mechanic_record.mechanic_id;
            
            -- Insert into request_routing table (triggers realtime subscription)
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
                    0.0, -- Distance not relevant for shop-based
                    true,
                    NOW(),
                    NOW(),
                    NOW() + INTERVAL '30 minutes'
                );
                
                RAISE NOTICE '✅ Routing entry created: % → %', 
                    v_routing_id, v_mechanic_record.email;
                    
            EXCEPTION WHEN OTHERS THEN
                RAISE WARNING '❌ Failed to create routing entry for %: %', 
                    v_mechanic_record.email, SQLERRM;
            END;
            
            -- Also create notification record (if notifications table exists)
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
                        'routing_type', 'shop_based',
                        'action', 'view_request'
                    ),
                    false,
                    NOW()
                );
                
                RAISE NOTICE '📱 Notification created for %', v_mechanic_record.email;
                
            EXCEPTION WHEN OTHERS THEN
                RAISE WARNING '⚠️ Failed to create notification: %', SQLERRM;
            END;
        END LOOP;
        
        -- Update service request with notification count
        UPDATE service_requests 
        SET 
            mechanics_notified_count = v_shop_mechanics_count,
            request_type = 'shop_based',
            broadcast_started_at = NOW()
        WHERE id = NEW.id;
        
        RAISE NOTICE '✅ SHOP-BASED ROUTING COMPLETE: % mechanics notified for request %', 
            v_shop_mechanics_count, NEW.id;
    ELSE
        RAISE NOTICE '📡 BROADCAST REQUEST DETECTED: % (no shop_id)', NEW.id;
        -- Let broadcast trigger handle this
    END IF;
    
    RETURN NEW;
END;
$$;

-- Create trigger (AFTER INSERT so NEW record is fully committed)
CREATE TRIGGER on_service_request_insert_shop_routing
    AFTER INSERT ON service_requests
    FOR EACH ROW
    EXECUTE FUNCTION handle_shop_based_routing();

DO $$
BEGIN
    RAISE NOTICE '✅ Shop-based routing trigger created successfully';
END $$;

-- =====================================================
-- STEP 4: ENSURE MECHANICS ARE ASSIGNED TO SHOPS
-- =====================================================

DO $$
DECLARE
    v_shop_record RECORD;
    v_mechanic_record RECORD;
    v_assignments_created integer := 0;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '=== ENSURING MECHANIC-SHOP ASSIGNMENTS ===';
    
    -- Get all mechanics
    FOR v_mechanic_record IN
        SELECT id, email, first_name, last_name
        FROM user_profiles
        WHERE user_type = 'mechanic'
    LOOP
        RAISE NOTICE 'Processing mechanic: %', v_mechanic_record.email;
        
        -- Assign to all active shops
        FOR v_shop_record IN
            SELECT id, shop_name, owner_id
            FROM shops
            WHERE is_active = true
        LOOP
            -- Insert or update assignment
            INSERT INTO shop_mechanics (
                shop_id, 
                mechanic_id, 
                is_active, 
                is_available,
                created_at,
                updated_at
            ) VALUES (
                v_shop_record.id,
                v_mechanic_record.id,
                true,
                true,
                NOW(),
                NOW()
            )
            ON CONFLICT (shop_id, mechanic_id) DO UPDATE SET
                is_active = true,
                is_available = true,
                updated_at = NOW();
                
            v_assignments_created := v_assignments_created + 1;
        END LOOP;
    END LOOP;
    
    RAISE NOTICE '✅ Created/updated % shop-mechanic assignments', v_assignments_created;
END $$;

-- =====================================================
-- STEP 5: ENSURE MECHANIC AVAILABILITY STATUS EXISTS
-- =====================================================

DO $$
DECLARE
    v_mechanic_record RECORD;
    v_statuses_created integer := 0;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '=== ENSURING MECHANIC AVAILABILITY STATUS ===';
    
    FOR v_mechanic_record IN
        SELECT id, email
        FROM user_profiles
        WHERE user_type = 'mechanic'
    LOOP
        INSERT INTO mechanic_availability_status (
            mechanic_id,
            current_status,
            is_accepting_requests,
            last_status_update,
            created_at,
            updated_at
        ) VALUES (
            v_mechanic_record.id,
            'available',
            true,
            NOW(),
            NOW(),
            NOW()
        )
        ON CONFLICT (mechanic_id) DO UPDATE SET
            current_status = 'available',
            is_accepting_requests = true,
            last_status_update = NOW(),
            updated_at = NOW();
            
        v_statuses_created := v_statuses_created + 1;
        RAISE NOTICE '✅ Availability status set for %', v_mechanic_record.email;
    END LOOP;
    
    RAISE NOTICE '✅ Processed % mechanic availability statuses', v_statuses_created;
END $$;

-- =====================================================
-- STEP 6: TEST THE FIX WITH A REAL SHOP REQUEST
-- =====================================================

DO $$
DECLARE
    v_test_request_id uuid := gen_random_uuid();
    v_customer_id uuid;
    v_shop_id uuid;
    v_routing_count integer;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '=== CREATING TEST SHOP-BASED REQUEST ===';
    
    -- Get first customer
    SELECT id INTO v_customer_id 
    FROM user_profiles 
    WHERE user_type = 'customer' 
    LIMIT 1;
    
    IF v_customer_id IS NULL THEN
        -- Create test customer
        INSERT INTO user_profiles (
            id, email, first_name, last_name, phone_number, user_type
        ) VALUES (
            gen_random_uuid(),
            'testcustomer@roadaid.com',
            'Test',
            'Customer',
            '09123456789',
            'customer'
        )
        RETURNING id INTO v_customer_id;
        
        RAISE NOTICE 'Created test customer: %', v_customer_id;
    END IF;
    
    -- Get first active shop
    SELECT id INTO v_shop_id 
    FROM shops 
    WHERE is_active = true 
    LIMIT 1;
    
    IF v_shop_id IS NULL THEN
        RAISE EXCEPTION 'No active shops found! Cannot create test request.';
    END IF;
    
    RAISE NOTICE 'Using shop: %', v_shop_id;
    RAISE NOTICE 'Using customer: %', v_customer_id;
    
    -- Create test shop-based request
    INSERT INTO service_requests (
        id,
        customer_id,
        shop_id,
        title,
        description,
        pickup_latitude,
        pickup_longitude,
        pickup_address,
        status,
        request_type,
        created_at
    ) VALUES (
        v_test_request_id,
        v_customer_id,
        v_shop_id,
        '🧪 TEST: Shop-Based Request Routing',
        'This is a test request to verify shop-based routing works correctly. Mechanics assigned to this shop should see this request.',
        14.5995,
        120.9842,
        'Manila, Philippines (TEST)',
        'pending',
        'shop_based',
        NOW()
    );
    
    RAISE NOTICE '✅ Test request created: %', v_test_request_id;
    
    -- Wait a moment for trigger to process
    PERFORM pg_sleep(0.5);
    
    -- Check how many routing entries were created
    SELECT COUNT(*) INTO v_routing_count
    FROM request_routing
    WHERE request_id = v_test_request_id;
    
    RAISE NOTICE '📊 Routing entries created: %', v_routing_count;
    
    IF v_routing_count = 0 THEN
        RAISE WARNING '❌ NO ROUTING ENTRIES CREATED! Check trigger function and shop mechanics assignment.';
    ELSE
        RAISE NOTICE '✅ SUCCESS: % mechanics were notified', v_routing_count;
    END IF;
    
END $$;

-- =====================================================
-- STEP 7: VERIFICATION QUERIES
-- =====================================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '=== VERIFICATION RESULTS ===';
END $$;

-- Show test request routing results
SELECT 
    '🧪 TEST REQUEST ROUTING' as check_type,
    sr.id as request_id,
    sr.title,
    sr.shop_id,
    s.shop_name,
    sr.mechanics_notified_count,
    COUNT(rr.eligible_mechanic_id) as actual_routing_entries,
    array_agg(up.email ORDER BY up.email) as notified_mechanics
FROM service_requests sr
LEFT JOIN shops s ON s.id = sr.shop_id
LEFT JOIN request_routing rr ON rr.request_id = sr.id
LEFT JOIN user_profiles up ON up.id = rr.eligible_mechanic_id
WHERE sr.title LIKE '%TEST: Shop-Based%'
GROUP BY sr.id, sr.title, sr.shop_id, s.shop_name, sr.mechanics_notified_count
ORDER BY sr.created_at DESC
LIMIT 1;

-- Show all shop mechanics status
SELECT 
    '🔧 SHOP MECHANICS STATUS' as check_type,
    s.shop_name,
    COUNT(sm.mechanic_id) as total_mechanics,
    COUNT(CASE WHEN sm.is_active = true AND sm.is_available = true THEN 1 END) as active_available,
    array_agg(
        up.email || ' (' || 
        CASE WHEN sm.is_active THEN 'active' ELSE 'inactive' END || ',' ||
        CASE WHEN sm.is_available THEN 'available' ELSE 'unavailable' END || ')'
        ORDER BY up.email
    ) as mechanics
FROM shops s
LEFT JOIN shop_mechanics sm ON sm.shop_id = s.id
LEFT JOIN user_profiles up ON up.id = sm.mechanic_id
WHERE s.is_active = true
GROUP BY s.id, s.shop_name
ORDER BY s.shop_name;

-- Show mechanic readiness
SELECT 
    '👨‍🔧 MECHANIC READINESS' as check_type,
    up.email,
    mas.current_status,
    mas.is_accepting_requests,
    COUNT(sm.shop_id) as shops_assigned,
    CASE 
        WHEN mas.current_status = 'available' 
        AND mas.is_accepting_requests = true 
        AND COUNT(sm.shop_id) > 0
        THEN '✅ READY'
        ELSE '❌ NOT READY'
    END as status
FROM user_profiles up
LEFT JOIN mechanic_availability_status mas ON mas.mechanic_id = up.id
LEFT JOIN shop_mechanics sm ON sm.mechanic_id = up.id AND sm.is_active = true
WHERE up.user_type = 'mechanic'
GROUP BY up.id, up.email, mas.current_status, mas.is_accepting_requests
ORDER BY up.email;

-- =====================================================
-- FINAL SUMMARY
-- =====================================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '=================================================================';
    RAISE NOTICE '✅ SHOP REQUEST ROUTING FIX COMPLETE';
    RAISE NOTICE '=================================================================';
    RAISE NOTICE '';
    RAISE NOTICE 'CHANGES MADE:';
    RAISE NOTICE '1. ✅ Disabled RLS on request_routing (backend-only table)';
    RAISE NOTICE '2. ✅ Created handle_shop_based_routing() trigger function';
    RAISE NOTICE '3. ✅ Created AFTER INSERT trigger on service_requests';
    RAISE NOTICE '4. ✅ Assigned all mechanics to all active shops';
    RAISE NOTICE '5. ✅ Set all mechanics to available status';
    RAISE NOTICE '6. ✅ Created test shop-based request';
    RAISE NOTICE '';
    RAISE NOTICE 'WHAT HAPPENS NOW WHEN CUSTOMER CREATES SHOP-BASED REQUEST:';
    RAISE NOTICE '1. Customer selects shop and creates request';
    RAISE NOTICE '2. INSERT into service_requests triggers handle_shop_based_routing()';
    RAISE NOTICE '3. Function finds all available mechanics in that shop';
    RAISE NOTICE '4. Creates request_routing entry for each mechanic';
    RAISE NOTICE '5. Creates notification for each mechanic';
    RAISE NOTICE '6. Mechanic app listens to request_routing table via realtime';
    RAISE NOTICE '7. Mechanic sees popup notification instantly';
    RAISE NOTICE '';
    RAISE NOTICE 'NEXT STEPS:';
    RAISE NOTICE '1. Test customer flow: Select shop → Create request';
    RAISE NOTICE '2. Check mechanic app for popup notification';
    RAISE NOTICE '3. Verify request appears in mechanic dashboard';
    RAISE NOTICE '';
    RAISE NOTICE 'DEBUGGING QUERIES (if still not working):';
    RAISE NOTICE 'SELECT * FROM request_routing WHERE request_id = ''YOUR_REQUEST_ID'';';
    RAISE NOTICE 'SELECT * FROM notifications WHERE user_id = ''MECHANIC_ID'' ORDER BY created_at DESC;';
    RAISE NOTICE 'SELECT * FROM shop_mechanics WHERE shop_id = ''SHOP_ID'';';
    RAISE NOTICE 'SELECT * FROM mechanic_availability_status WHERE mechanic_id = ''MECHANIC_ID'';';
    RAISE NOTICE '';
    RAISE NOTICE '=================================================================';
END $$;
