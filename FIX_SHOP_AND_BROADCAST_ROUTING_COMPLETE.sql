-- =====================================================
-- FIX: SHOP-BASED ROUTING + BROADCAST DUPLICATE KEY
-- =====================================================
-- Issues to fix:
-- 1. Shop-based requests only notifying ONE mechanic instead of ALL
-- 2. Broadcast requests causing duplicate key errors in request_broadcasts
--
-- Root Causes:
-- 1. Shop routing function creates routing entries but broadcast trigger also fires
-- 2. Broadcast function tries to INSERT same (request_id, provider_id) twice
-- =====================================================

-- =====================================================
-- STEP 1: FIX BROADCAST TRIGGER - ADD ON CONFLICT
-- =====================================================

-- First, let's read the current broadcast function
DO $$
DECLARE
    v_func_def text;
BEGIN
    SELECT pg_get_functiondef(p.oid) INTO v_func_def
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE p.proname = 'broadcast_service_request_with_shop_filter'
    AND n.nspname = 'public';
    
    IF v_func_def IS NULL THEN
        RAISE NOTICE '⚠️ Function broadcast_service_request_with_shop_filter not found';
    ELSE
        RAISE NOTICE '✅ Found broadcast function';
    END IF;
END $$;

-- =====================================================
-- STEP 2: UPDATE BROADCAST FUNCTION WITH ON CONFLICT
-- =====================================================

-- Drop existing function first (required when changing return type)
DROP FUNCTION IF EXISTS broadcast_service_request_with_shop_filter(UUID) CASCADE;

CREATE OR REPLACE FUNCTION broadcast_service_request_with_shop_filter(p_request_id UUID)
RETURNS TABLE (
    provider_id UUID,
    provider_name TEXT,
    mechanic_count INTEGER
) 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_customer_lat DOUBLE PRECISION;
    v_customer_lng DOUBLE PRECISION;
    v_broadcast_radius_km DOUBLE PRECISION;
    v_shop_id UUID;
    v_is_broadcast BOOLEAN;
    v_provider_record RECORD;
    v_mechanics_count INTEGER;
    v_total_notified INTEGER := 0;
BEGIN
    RAISE NOTICE '📡 broadcast_service_request_with_shop_filter called for request: %', p_request_id;
    
    -- Get request details
    SELECT 
        sr.pickup_latitude,
        sr.pickup_longitude,
        sr.broadcast_radius_km,
        sr.shop_id,
        sr.is_broadcast_request
    INTO 
        v_customer_lat,
        v_customer_lng,
        v_broadcast_radius_km,
        v_shop_id,
        v_is_broadcast
    FROM service_requests sr
    WHERE sr.id = p_request_id;
    
    IF NOT FOUND THEN
        RAISE WARNING '❌ Request % not found', p_request_id;
        RETURN;
    END IF;
    
    -- ⚠️ SKIP IF SHOP-BASED REQUEST (handled by shop routing trigger)
    IF v_shop_id IS NOT NULL THEN
        RAISE NOTICE '⏭️ Skipping broadcast for shop-based request %', p_request_id;
        RETURN;
    END IF;
    
    IF NOT v_is_broadcast THEN
        RAISE NOTICE '⏭️ Not a broadcast request: %', p_request_id;
        RETURN;
    END IF;
    
    -- Use default radius if not specified
    v_broadcast_radius_km := COALESCE(v_broadcast_radius_km, 5.0);
    
    RAISE NOTICE '📍 Broadcasting to providers within % km of (%, %)', 
        v_broadcast_radius_km, v_customer_lat, v_customer_lng;
    
    -- Find nearby service providers (shops)
    FOR v_provider_record IN
        SELECT DISTINCT
            sp.id as provider_id,
            COALESCE(sp.company_name, sh.shop_name, 'Unknown Provider') as provider_name,
            sh.id as shop_id,
            sh.shop_name,
            up.current_latitude,
            up.current_longitude,
            ST_Distance(
                ST_MakePoint(up.current_longitude, up.current_latitude)::geography,
                ST_MakePoint(v_customer_lng, v_customer_lat)::geography
            ) / 1000.0 as distance_km
        FROM service_providers sp
        JOIN user_profiles up ON up.id = sp.user_id
        LEFT JOIN shops sh ON sh.owner_id = sp.user_id
        WHERE sp.is_verified = true
        AND sp.is_available = true  -- ✅ FIXED: Changed from sp.is_active to sp.is_available
        AND sh.is_active = true  -- ✅ ADDED: Check shop is active
        AND up.current_latitude IS NOT NULL
        AND up.current_longitude IS NOT NULL
        AND ST_DWithin(
            ST_MakePoint(up.current_longitude, up.current_latitude)::geography,
            ST_MakePoint(v_customer_lng, v_customer_lat)::geography,
            v_broadcast_radius_km * 1000
        )
        ORDER BY distance_km
        LIMIT 20
    LOOP
        -- Count available mechanics for this provider
        SELECT COUNT(*) INTO v_mechanics_count
        FROM shop_mechanics sm
        JOIN mechanic_availability_status mas ON mas.mechanic_id = sm.mechanic_id
        WHERE sm.shop_id = v_provider_record.shop_id
        AND sm.is_active = true
        AND mas.current_status = 'available'
        AND mas.is_accepting_requests = true;
        
        IF v_mechanics_count > 0 THEN
            RAISE NOTICE '📤 Broadcasting to provider: % (% mechanics available)', 
                v_provider_record.provider_name, v_mechanics_count;
            
            -- ✅ FIX: Use ON CONFLICT DO NOTHING to prevent duplicate key errors
            INSERT INTO request_broadcasts (
                id,
                request_id,
                provider_id,
                shop_id,
                distance_km,
                is_notified,
                notified_at,
                created_at
            ) VALUES (
                gen_random_uuid(),
                p_request_id,
                v_provider_record.provider_id,
                v_provider_record.shop_id,
                v_provider_record.distance_km,
                true,
                NOW(),
                NOW()
            )
            ON CONFLICT (request_id, provider_id) 
            DO NOTHING;  -- ✅ Skip if already exists
            
            -- Create routing entries for ALL available mechanics in this shop
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
            )
            SELECT 
                gen_random_uuid(),
                p_request_id,
                sm.mechanic_id,
                sm.shop_id,
                'broadcast',
                v_provider_record.distance_km,
                true,
                NOW(),
                NOW(),
                NOW() + INTERVAL '30 minutes'
            FROM shop_mechanics sm
            JOIN mechanic_availability_status mas ON mas.mechanic_id = sm.mechanic_id
            WHERE sm.shop_id = v_provider_record.shop_id
            AND sm.is_active = true
            AND mas.current_status = 'available'
            AND mas.is_accepting_requests = true
            ON CONFLICT (request_id, eligible_mechanic_id) 
            DO NOTHING;  -- ✅ Skip duplicates
            
            -- Create notifications for ALL available mechanics
            INSERT INTO notifications (
                id,
                user_id,
                title,
                body,
                type,
                data,
                read,
                created_at
            )
            SELECT 
                gen_random_uuid(),
                sm.mechanic_id,
                'New Broadcast Request',
                'A nearby customer needs assistance. Tap to view and accept.',
                'broadcast_request',
                jsonb_build_object(
                    'request_id', p_request_id,
                    'shop_id', sm.shop_id,
                    'distance_km', v_provider_record.distance_km,
                    'action', 'view_broadcast'
                ),
                false,
                NOW()
            FROM shop_mechanics sm
            JOIN mechanic_availability_status mas ON mas.mechanic_id = sm.mechanic_id
            WHERE sm.shop_id = v_provider_record.shop_id
            AND sm.is_active = true
            AND mas.current_status = 'available'
            AND mas.is_accepting_requests = true;
            
            v_total_notified := v_total_notified + v_mechanics_count;
            
            -- Return provider info
            provider_id := v_provider_record.provider_id;
            provider_name := v_provider_record.provider_name;
            mechanic_count := v_mechanics_count;
            RETURN NEXT;
        END IF;
    END LOOP;
    
    -- Update service request with notification count
    UPDATE service_requests 
    SET 
        mechanics_notified_count = v_total_notified,
        broadcast_started_at = NOW()
    WHERE id = p_request_id;
    
    RAISE NOTICE '✅ Broadcast complete: % mechanics notified for request %', 
        v_total_notified, p_request_id;
    
    RETURN;
END;
$$;

-- =====================================================
-- STEP 3: UPDATE SHOP ROUTING TO NOTIFY ALL MECHANICS
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
    v_notification_id uuid;
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
            -- Don't return - still set request type correctly
        END IF;
        
        -- ✅ CREATE ROUTING ENTRIES FOR **ALL** MECHANICS IN SHOP
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
            v_notification_id := gen_random_uuid();
            
            RAISE NOTICE '📢 Creating routing + notification for mechanic: % (%) - ID: %', 
                v_mechanic_record.first_name, 
                v_mechanic_record.email, 
                v_mechanic_record.mechanic_id;
            
            -- ✅ Insert into request_routing (with conflict handling)
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
                )
                ON CONFLICT (request_id, eligible_mechanic_id) 
                DO UPDATE SET
                    is_notified = true,
                    notified_at = NOW();
                
                RAISE NOTICE '✅ Routing entry created: % → % (%)', 
                    v_routing_id, 
                    v_mechanic_record.first_name,
                    v_mechanic_record.email;
                    
            EXCEPTION WHEN OTHERS THEN
                RAISE WARNING '❌ Failed to create routing entry for %: %', 
                    v_mechanic_record.email, SQLERRM;
            END;
            
            -- ✅ Create notification for THIS mechanic
            BEGIN
                INSERT INTO notifications (
                    id,
                    user_id,
                    title,
                    body,
                    type,
                    data,
                    read,
                    created_at
                ) VALUES (
                    v_notification_id,
                    v_mechanic_record.mechanic_id,
                    'New Shop Service Request',
                    'A customer selected your shop. Tap to view and accept.',
                    'shop_service_request',
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
                
                RAISE NOTICE '📱 Notification created: % for mechanic %', 
                    v_notification_id,
                    v_mechanic_record.email;
                
            EXCEPTION WHEN OTHERS THEN
                RAISE WARNING '⚠️ Failed to create notification for %: %', 
                    v_mechanic_record.email, 
                    SQLERRM;
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
        RAISE NOTICE '📡 BROADCAST REQUEST (no shop_id) - skipping shop routing: %', NEW.id;
    END IF;
    
    RETURN NEW;
END;
$$;

-- =====================================================
-- STEP 4: ENSURE TRIGGERS ARE PROPERLY SET
-- =====================================================

-- Drop and recreate shop routing trigger
DROP TRIGGER IF EXISTS on_service_request_insert_shop_routing ON service_requests;

CREATE TRIGGER on_service_request_insert_shop_routing
    AFTER INSERT ON service_requests
    FOR EACH ROW
    EXECUTE FUNCTION handle_shop_based_routing();

DO $$
BEGIN
    RAISE NOTICE '✅ Shop routing trigger recreated';
END $$;

-- =====================================================
-- STEP 5: UPDATE AUTO-BROADCAST TRIGGER
-- =====================================================

CREATE OR REPLACE FUNCTION trigger_auto_broadcast_request()
RETURNS TRIGGER AS $$
BEGIN
    -- ⚠️ SKIP AUTO-BROADCAST FOR SHOP-BASED REQUESTS
    IF NEW.shop_id IS NOT NULL THEN
        RAISE NOTICE '⏭️ Skipping auto-broadcast for shop-based request: %', NEW.id;
        RETURN NEW;
    END IF;
    
    -- Only broadcast if status is pending and it's marked as broadcast
    IF NEW.status = 'pending' AND NEW.is_broadcast_request = true THEN
        RAISE NOTICE '📡 Auto-broadcasting request: %', NEW.id;
        
        -- Call broadcast function
        PERFORM broadcast_service_request_with_shop_filter(NEW.id);
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- STEP 6: CLEAN UP DUPLICATE ENTRIES
-- =====================================================

-- Delete duplicate broadcast entries for shop-based requests
DELETE FROM request_broadcasts
WHERE request_id IN (
    SELECT id FROM service_requests 
    WHERE shop_id IS NOT NULL 
    AND request_type = 'shop_based'
)
AND created_at > NOW() - INTERVAL '7 days';

DO $$
BEGIN
    RAISE NOTICE '✅ Cleaned up duplicate broadcast entries for shop requests';
END $$;

-- =====================================================
-- STEP 7: VERIFY CURRENT STATE
-- =====================================================

-- Check existing shop-based requests
SELECT 
    sr.id,
    sr.title,
    sr.shop_id,
    s.shop_name,
    sr.mechanics_notified_count,
    (SELECT COUNT(*) FROM request_routing WHERE request_id = sr.id) as routing_count,
    (SELECT COUNT(*) FROM notifications WHERE data->>'request_id' = sr.id::text) as notification_count,
    (SELECT array_agg(up.email) 
     FROM request_routing rr 
     JOIN user_profiles up ON up.id = rr.eligible_mechanic_id 
     WHERE rr.request_id = sr.id) as notified_mechanics
FROM service_requests sr
LEFT JOIN shops s ON s.id = sr.shop_id
WHERE sr.shop_id IS NOT NULL
AND sr.created_at > NOW() - INTERVAL '1 day'
ORDER BY sr.created_at DESC
LIMIT 5;

-- =====================================================
-- STEP 8: TEST SHOP-BASED REQUEST
-- =====================================================

DO $$
DECLARE
    v_test_shop_id UUID;
    v_test_customer_id UUID;
    v_test_request_id UUID;
    v_mechanics_in_shop INT;
    v_routing_entries INT;
    v_notifications INT;
BEGIN
    RAISE NOTICE '🧪 Starting shop-based routing test...';
    
    -- Get a shop with mechanics
    SELECT s.id INTO v_test_shop_id
    FROM shops s
    WHERE EXISTS (
        SELECT 1 FROM shop_mechanics sm 
        WHERE sm.shop_id = s.id 
        AND sm.is_active = true
    )
    AND s.is_active = true
    LIMIT 1;
    
    IF v_test_shop_id IS NULL THEN
        RAISE WARNING '❌ No shop with active mechanics found for testing';
        RETURN;
    END IF;
    
    -- Count mechanics in shop
    SELECT COUNT(*) INTO v_mechanics_in_shop
    FROM shop_mechanics sm
    JOIN mechanic_availability_status mas ON mas.mechanic_id = sm.mechanic_id
    WHERE sm.shop_id = v_test_shop_id
    AND sm.is_active = true
    AND mas.current_status = 'available'
    AND mas.is_accepting_requests = true;
    
    RAISE NOTICE '📊 Test shop has % available mechanics', v_mechanics_in_shop;
    
    -- Get a customer
    SELECT id INTO v_test_customer_id
    FROM user_profiles
    WHERE user_type = 'customer'
    LIMIT 1;
    
    -- Create test request
    v_test_request_id := gen_random_uuid();
    
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
        is_broadcast_request,
        created_at
    ) VALUES (
        v_test_request_id,
        v_test_customer_id,
        v_test_shop_id,
        '🧪 TEST - All Mechanics Should Get This',
        'Testing shop routing to ALL mechanics',
        14.5995,
        120.9842,
        'Test Location',
        'pending',
        'shop_based',
        false,
        NOW()
    );
    
    -- Wait a moment for trigger
    PERFORM pg_sleep(1);
    
    -- Check routing entries
    SELECT COUNT(*) INTO v_routing_entries
    FROM request_routing
    WHERE request_id = v_test_request_id;
    
    -- Check notifications
    SELECT COUNT(*) INTO v_notifications
    FROM notifications
    WHERE data->>'request_id' = v_test_request_id::text;
    
    RAISE NOTICE '📊 Test Results:';
    RAISE NOTICE '  - Shop has % available mechanics', v_mechanics_in_shop;
    RAISE NOTICE '  - Created % routing entries', v_routing_entries;
    RAISE NOTICE '  - Created % notifications', v_notifications;
    
    IF v_routing_entries = v_mechanics_in_shop AND v_notifications = v_mechanics_in_shop THEN
        RAISE NOTICE '✅ TEST PASSED - All mechanics notified!';
    ELSE
        RAISE WARNING '❌ TEST FAILED - Expected %, got % routing and % notifications', 
            v_mechanics_in_shop, v_routing_entries, v_notifications;
    END IF;
    
    -- Clean up test request
    DELETE FROM notifications WHERE data->>'request_id' = v_test_request_id::text;
    DELETE FROM request_routing WHERE request_id = v_test_request_id;
    DELETE FROM service_requests WHERE id = v_test_request_id;
    
    RAISE NOTICE '🧹 Test request cleaned up';
END $$;

-- =====================================================
-- SUMMARY
-- =====================================================

DO $$
BEGIN
    RAISE NOTICE '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
    RAISE NOTICE '✅ FIX COMPLETE';
    RAISE NOTICE '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
    RAISE NOTICE '';
    RAISE NOTICE '🔧 Changes Made:';
    RAISE NOTICE '  1. ✅ Added ON CONFLICT DO NOTHING to broadcast function';
    RAISE NOTICE '  2. ✅ Shop routing now notifies ALL mechanics in shop';
    RAISE NOTICE '  3. ✅ Broadcast trigger skips shop-based requests';
    RAISE NOTICE '  4. ✅ Cleaned up duplicate entries';
    RAISE NOTICE '';
    RAISE NOTICE '📋 What to expect:';
    RAISE NOTICE '  - Shop requests → ALL mechanics in that shop get popup';
    RAISE NOTICE '  - Broadcast requests → No duplicate key errors';
    RAISE NOTICE '  - Both routing types work independently';
    RAISE NOTICE '';
    RAISE NOTICE '🧪 Next Steps:';
    RAISE NOTICE '  1. Create a new shop-based request from customer app';
    RAISE NOTICE '  2. ALL mechanics in that shop should see popup';
    RAISE NOTICE '  3. Create a broadcast request (no shop selected)';
    RAISE NOTICE '  4. Should work without duplicate key errors';
    RAISE NOTICE '';
    RAISE NOTICE '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
END $$;
