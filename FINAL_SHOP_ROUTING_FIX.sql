-- =====================================================
-- FINAL FIX: SHOP-BASED REQUEST ROUTING
-- =====================================================
-- Root cause: Auto-broadcast trigger conflicts with shop routing
-- Solution: Disable auto-broadcast for shop-based requests only
-- =====================================================

-- =====================================================
-- STEP 1: CHECK EXISTING AUTO-BROADCAST TRIGGER FUNCTION
-- =====================================================
SELECT 
    proname as function_name,
    prosrc as function_code
FROM pg_proc
WHERE proname LIKE '%broadcast%'
AND proname LIKE '%auto%';

-- =====================================================
-- STEP 2: DISABLE AUTO-BROADCAST TRIGGER (IF IT EXISTS)
-- =====================================================
-- Option A: Disable the trigger completely
DO $$
BEGIN
    -- Check if trigger exists, then disable it
    IF EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trigger_auto_broadcast_request') THEN
        EXECUTE 'ALTER TABLE service_requests DISABLE TRIGGER trigger_auto_broadcast_request';
        RAISE NOTICE '✅ Disabled trigger_auto_broadcast_request';
    END IF;
    
    IF EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trigger_auto_broadcast') THEN
        EXECUTE 'ALTER TABLE service_requests DISABLE TRIGGER trigger_auto_broadcast';
        RAISE NOTICE '✅ Disabled trigger_auto_broadcast';
    END IF;
END $$;

-- OR

-- Option B: Update function to skip shop-based requests (RECOMMENDED)
CREATE OR REPLACE FUNCTION trigger_auto_broadcast_request()
RETURNS TRIGGER AS $$
BEGIN
    -- ⚠️ SKIP AUTO-BROADCAST FOR SHOP-BASED REQUESTS
    -- Shop-based requests are handled by handle_shop_based_routing()
    IF NEW.shop_id IS NOT NULL THEN
        RAISE NOTICE '⏭️ Skipping auto-broadcast for shop-based request: %', NEW.id;
        RETURN NEW;
    END IF;
    
    -- Continue with broadcast logic for non-shop requests
    IF NEW.status = 'pending' AND NEW.request_type = 'broadcast' THEN
        RAISE NOTICE '📡 Auto-broadcasting request: %', NEW.id;
        
        -- Call broadcast function (original logic)
        PERFORM broadcast_service_request_with_shop_filter(NEW.id);
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- STEP 3: CLEAN UP OLD DUPLICATE ENTRIES
-- =====================================================
-- Delete duplicate broadcast entries for shop-based requests
DELETE FROM request_broadcasts
WHERE request_id IN (
    SELECT id FROM service_requests 
    WHERE shop_id IS NOT NULL 
    AND request_type = 'shop_based'
)
AND created_at > NOW() - INTERVAL '1 day'; -- Only recent duplicates

-- =====================================================
-- STEP 4: VERIFY TRIGGER STATUS
-- =====================================================
SELECT 
    t.tgname as trigger_name,
    t.tgrelid::regclass as table_name,
    p.proname as function_name,
    CASE t.tgenabled
        WHEN 'O' THEN '✅ ENABLED'
        WHEN 'D' THEN '❌ DISABLED'
    END as status
FROM pg_trigger t
JOIN pg_proc p ON p.oid = t.tgfoid
WHERE t.tgrelid = 'service_requests'::regclass
AND (p.proname LIKE '%broadcast%' OR p.proname LIKE '%routing%')
ORDER BY t.tgname;

-- Expected:
-- trigger_auto_broadcast_request: ✅ ENABLED (but skips shop requests)
-- on_service_request_insert_shop_routing: ✅ ENABLED

-- =====================================================
-- STEP 5: TEST WITH SHOP-BASED REQUEST
-- =====================================================
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
    '🧪 FINAL TEST - Shop Request',
    'Testing after fixing broadcast conflict',
    14.5995,
    120.9842,
    'Test Location, Manila',
    'pending',
    'shop_based',
    NOW()
);

-- =====================================================
-- STEP 6: VERIFY CORRECT ROUTING (NO DUPLICATES)
-- =====================================================
SELECT 
    sr.id,
    sr.title,
    sr.shop_id,
    s.shop_name,
    sr.mechanics_notified_count,
    
    -- Check request_routing (SHOULD HAVE 2 entries)
    (SELECT COUNT(*) FROM request_routing WHERE request_id = sr.id) as routing_entries,
    (SELECT array_agg(up.email) FROM request_routing rr 
     JOIN user_profiles up ON up.id = rr.eligible_mechanic_id 
     WHERE rr.request_id = sr.id) as routing_mechanics,
    
    -- Check request_broadcasts (SHOULD BE 0 for shop requests)
    (SELECT COUNT(*) FROM request_broadcasts WHERE request_id = sr.id) as broadcast_entries,
    
    -- Check notifications (SHOULD HAVE 2)
    (SELECT COUNT(*) FROM notifications 
     WHERE data->>'request_id' = sr.id::text) as notification_count
     
FROM service_requests sr
LEFT JOIN shops s ON s.id = sr.shop_id
WHERE sr.title LIKE '%FINAL TEST%'
ORDER BY sr.created_at DESC
LIMIT 1;

-- EXPECTED RESULTS:
-- routing_entries: 2 (Rafael + Yujiro)
-- routing_mechanics: {rafaelpineda471@gmail.com, yujirofuma28@gmail.com}
-- broadcast_entries: 0 (none, because shop-based)
-- notification_count: 2

-- =====================================================
-- STEP 7: CHECK MECHANIC DEVICES FOR POPUP
-- =====================================================
-- After running above test:
-- 1. Check Rafael's device → Should see popup ✅
-- 2. Check Yujiro's device → Should see popup ✅
-- 3. Both should see request in dashboard
-- 4. First to accept gets the job

-- If popup STILL not appearing, check:
-- - Is mechanic app running and in foreground?
-- - Is mechanic logged in?
-- - Check app console for realtime connection errors
-- - Verify FCM token registered in notifications table

-- =====================================================
-- DEBUGGING QUERIES (IF POPUP STILL NOT APPEARING)
-- =====================================================

-- Check if mechanics are subscribed to realtime
SELECT 
    up.email,
    mas.current_status,
    mas.is_accepting_requests,
    mas.last_active_at,
    CASE 
        WHEN mas.last_active_at > NOW() - INTERVAL '5 minutes' THEN '🟢 ONLINE'
        WHEN mas.last_active_at > NOW() - INTERVAL '30 minutes' THEN '🟡 RECENTLY ONLINE'
        ELSE '🔴 OFFLINE'
    END as connection_status
FROM user_profiles up
LEFT JOIN mechanic_availability_status mas ON mas.mechanic_id = up.id
WHERE up.user_type = 'mechanic'
ORDER BY mas.last_active_at DESC;

-- Check notification delivery
SELECT 
    n.id,
    up.email as mechanic,
    n.title,
    n.created_at,
    n.read,
    n.data->>'request_id' as request_id,
    n.data->>'routing_type' as routing_type
FROM notifications n
JOIN user_profiles up ON up.id = n.user_id
WHERE n.created_at > NOW() - INTERVAL '10 minutes'
AND n.type = 'service_request'
ORDER BY n.created_at DESC;

-- Check realtime publication settings
SELECT 
    pst.schemaname,
    pst.relname as table_name,
    CASE 
        WHEN pc.relreplident = 'd' THEN '❌ DEFAULT (no realtime)'
        WHEN pc.relreplident = 'f' THEN '✅ FULL (realtime enabled)'
        WHEN pc.relreplident = 'n' THEN '⚠️ NOTHING'
        WHEN pc.relreplident = 'i' THEN '⚠️ INDEX ONLY'
    END as replica_identity
FROM pg_stat_user_tables pst
JOIN pg_class pc ON pc.oid = pst.relid
WHERE pst.relname IN ('request_routing', 'notifications', 'service_requests')
ORDER BY pst.relname;

-- If replica_identity is 'DEFAULT', enable realtime with:
-- ALTER TABLE request_routing REPLICA IDENTITY FULL;
-- ALTER TABLE notifications REPLICA IDENTITY FULL;
