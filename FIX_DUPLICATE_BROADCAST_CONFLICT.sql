-- =====================================================
-- FIX: DUPLICATE KEY ERROR IN REQUEST_BROADCASTS
-- =====================================================
-- Problem: 2 conflicting broadcast systems causing duplicate entries
-- Solution: Disable the old auto-broadcast trigger, keep only shop routing
-- =====================================================

-- =====================================================
-- STEP 1: CHECK EXISTING TRIGGERS (RUN THIS FIRST TO SEE WHAT'S THERE)
-- =====================================================
SELECT 
    tgname as trigger_name,
    tgrelid::regclass as table_name,
    proname as function_name,
    tgenabled as is_enabled
FROM pg_trigger t
JOIN pg_proc p ON p.oid = t.tgfoid
WHERE tgrelid = 'service_requests'::regclass
AND tgname LIKE '%broadcast%'
ORDER BY tgname;

-- =====================================================
-- STEP 2: DISABLE AUTO-BROADCAST TRIGGER (RUN THIS ALONE)
-- =====================================================
-- This is the conflicting trigger that's causing duplicate inserts
ALTER TABLE service_requests 
DISABLE TRIGGER IF EXISTS trigger_auto_broadcast;

ALTER TABLE service_requests 
DISABLE TRIGGER IF EXISTS trigger_auto_broadcast_request;

ALTER TABLE service_requests 
DISABLE TRIGGER IF EXISTS on_service_request_broadcast;

-- =====================================================
-- STEP 3: VERIFY TRIGGERS (CHECK STATUS)
-- =====================================================
SELECT 
    tgname as trigger_name,
    tgrelid::regclass as table_name,
    CASE tgenabled
        WHEN 'O' THEN 'ENABLED'
        WHEN 'D' THEN 'DISABLED'
        WHEN 'R' THEN 'REPLICA'
        WHEN 'A' THEN 'ALWAYS'
    END as status
FROM pg_trigger
WHERE tgrelid = 'service_requests'::regclass
ORDER BY tgname;

-- =====================================================
-- STEP 4: CLEAN UP OLD DUPLICATE ENTRIES (RUN AFTER STEP 2)
-- =====================================================
-- Remove duplicate request_broadcasts entries that conflict with request_routing
DELETE FROM request_broadcasts rb
WHERE rb.id IN (
    SELECT rb2.id 
    FROM request_broadcasts rb2
    JOIN request_routing rr 
        ON rr.request_id = rb2.request_id 
        AND rr.eligible_mechanic_id = rb2.mechanic_id
    WHERE rb2.created_at > rr.created_at
);

-- =====================================================
-- STEP 5: UPDATE SHOP ROUTING FUNCTION TO AVOID CONFLICTS
-- =====================================================
-- Replace the function to NOT insert into request_broadcasts
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
            
            -- Insert routing entry (PRIMARY TABLE FOR REALTIME)
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
                
                RAISE NOTICE '✅ Routing created: % → %', v_routing_id, v_mechanic_record.email;
                    
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
                
                RAISE NOTICE '📱 Notification sent to %', v_mechanic_record.email;
                
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
-- STEP 6: TEST WITH NEW REQUEST
-- =====================================================
/*
-- After running steps 1-5, test with this:
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
    gen_random_uuid(),
    (SELECT id FROM user_profiles WHERE user_type = 'customer' LIMIT 1),
    (SELECT id FROM shops WHERE is_active = true LIMIT 1),
    '🧪 TEST - After Conflict Fix',
    'Testing after disabling auto-broadcast trigger',
    14.5995,
    120.9842,
    'Test Location, Manila',
    'pending',
    'shop_based',
    NOW()
);

-- Verify only request_routing entries created (no duplicates in request_broadcasts)
SELECT 
    'request_routing' as table_name,
    COUNT(*) as entries
FROM request_routing
WHERE request_id IN (SELECT id FROM service_requests WHERE title LIKE '%After Conflict Fix%')
UNION ALL
SELECT 
    'request_broadcasts' as table_name,
    COUNT(*) as entries
FROM request_broadcasts
WHERE request_id IN (SELECT id FROM service_requests WHERE title LIKE '%After Conflict Fix%');

-- Expected:
-- request_routing: 2 entries (Rafael + Yujiro)
-- request_broadcasts: 0 entries (disabled trigger)
*/

-- =====================================================
-- STEP 7: CHECK MECHANIC APP REALTIME SUBSCRIPTION
-- =====================================================
-- Make sure mechanic app is listening to request_routing table, NOT request_broadcasts
-- 
-- In lib/services/mechanic_request_service.dart, should have:
-- 
-- _supabase
--   .from('request_routing')  // ← Should be THIS table
--   .stream(primaryKey: ['id'])
--   .listen((data) { /* show popup */ });
-- 
-- NOT:
-- _supabase.from('request_broadcasts') ← Wrong table!
-- =====================================================

-- =====================================================
-- SUMMARY OF CHANGES:
-- =====================================================
-- 1. Disabled trigger_auto_broadcast (causes duplicate inserts)
-- 2. Updated handle_shop_based_routing() to only use request_routing
-- 3. Cleaned up duplicate entries
-- 4. Mechanic app should listen to request_routing table
-- 
-- Flow now:
-- Customer creates shop request
--   → handle_shop_based_routing() fires
--   → Inserts into request_routing (mechanics listen here)
--   → Inserts into notifications
--   → Mechanic app receives realtime update
--   → Popup appears! ✅
-- =====================================================
