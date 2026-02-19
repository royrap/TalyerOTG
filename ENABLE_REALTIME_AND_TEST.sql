-- =====================================================
-- ENABLE REALTIME + FIX TEST QUERY
-- =====================================================

-- =====================================================
-- STEP 1: ENABLE REALTIME FOR ROUTING AND NOTIFICATIONS
-- =====================================================
-- This is CRITICAL for mechanic popup to work!

ALTER TABLE request_routing REPLICA IDENTITY FULL;
ALTER TABLE notifications REPLICA IDENTITY FULL;

-- Verify realtime is enabled
SELECT 
    pst.relname as table_name,
    CASE 
        WHEN pc.relreplident = 'd' THEN '❌ DEFAULT (no realtime)'
        WHEN pc.relreplident = 'f' THEN '✅ FULL (realtime enabled)'
    END as replica_identity
FROM pg_stat_user_tables pst
JOIN pg_class pc ON pc.oid = pst.relid
WHERE pst.relname IN ('request_routing', 'notifications')
ORDER BY pst.relname;

-- Expected: Both tables should show "✅ FULL (realtime enabled)"

-- =====================================================
-- STEP 2: TEST WITH NEW SHOP-BASED REQUEST
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
    '🧪 REALTIME TEST - ' || NOW()::text,
    'Testing after enabling realtime',
    14.5995,
    120.9842,
    'Test Location, Manila',
    'pending',
    'shop_based',
    NOW()
);

-- =====================================================
-- STEP 3: VERIFY ROUTING CREATED (FIXED QUERY)
-- =====================================================
WITH latest_test AS (
    SELECT id, title
    FROM service_requests
    WHERE title LIKE '%REALTIME TEST%'
    ORDER BY created_at DESC
    LIMIT 1
)
SELECT 
    sr.id,
    sr.title,
    s.shop_name,
    sr.mechanics_notified_count,
    
    -- Routing entries (SHOULD BE 2)
    (SELECT COUNT(*) FROM request_routing WHERE request_id = sr.id) as routing_entries,
    
    -- Mechanics notified
    (SELECT array_agg(up.email) FROM request_routing rr 
     JOIN user_profiles up ON up.id = rr.eligible_mechanic_id 
     WHERE rr.request_id = sr.id) as routing_mechanics,
    
    -- Broadcast entries (SHOULD BE 0)
    (SELECT COUNT(*) FROM request_broadcasts WHERE request_id = sr.id) as broadcast_entries,
    
    -- Notifications (SHOULD BE 2)
    (SELECT COUNT(*) FROM notifications 
     WHERE data->>'request_id' = sr.id::text) as notification_count
     
FROM service_requests sr
LEFT JOIN shops s ON s.id = sr.shop_id
WHERE sr.id = (SELECT id FROM latest_test)
ORDER BY sr.created_at DESC;

-- EXPECTED RESULTS:
-- routing_entries: 2 ✅
-- routing_mechanics: {rafaelpineda471@gmail.com, yujirofuma28@gmail.com}
-- broadcast_entries: 0 ✅
-- notification_count: 2 ✅

-- =====================================================
-- STEP 4: CHECK MECHANIC DEVICES NOW!
-- =====================================================
-- With realtime enabled, mechanics should NOW receive popup!
-- 
-- 1. Rafael's device → Should see popup ✅
-- 2. Yujiro's device → Should see popup ✅
-- 3. Check notification count in step 3 = 2
-- 4. First to accept gets the job

-- =====================================================
-- STEP 5: VERIFY REALTIME SUBSCRIPTIONS (DEBUGGING)
-- =====================================================
-- If popup STILL not appearing, check Supabase realtime settings

-- Check if realtime is enabled in Supabase project settings:
-- Dashboard → Settings → API → Realtime → Enable

-- Check if tables are published for realtime:
SELECT 
    schemaname,
    tablename
FROM pg_publication_tables
WHERE pubname = 'supabase_realtime'
AND tablename IN ('request_routing', 'notifications', 'service_requests')
ORDER BY tablename;

-- If tables NOT in publication, add them:
-- Dashboard → Database → Publications → supabase_realtime → Add tables

-- =====================================================
-- STEP 6: CHECK MECHANIC APP CONSOLE FOR ERRORS
-- =====================================================
-- If popup STILL not showing:
-- 1. Open mechanic app
-- 2. Check Flutter console for errors like:
--    - "Realtime connection failed"
--    - "Subscription error"
--    - "Channel error"
-- 3. Make sure mechanic is logged in
-- 4. Make sure app is in foreground (not background)

-- =====================================================
-- ADDITIONAL DEBUGGING QUERIES
-- =====================================================

-- Check if mechanics are online
SELECT 
    up.email,
    mas.current_status,
    mas.is_accepting_requests,
    mas.last_active_at,
    CASE 
        WHEN mas.last_active_at > NOW() - INTERVAL '5 minutes' THEN '🟢 ONLINE'
        ELSE '🔴 OFFLINE'
    END as status
FROM user_profiles up
LEFT JOIN mechanic_availability_status mas ON mas.mechanic_id = up.id
WHERE up.user_type = 'mechanic';

-- Check recent notifications sent
SELECT 
    n.id,
    up.email as mechanic,
    n.title,
    n.body,
    n.created_at,
    n.read,
    n.data->>'request_id' as request_id
FROM notifications n
JOIN user_profiles up ON up.id = n.user_id
WHERE n.created_at > NOW() - INTERVAL '10 minutes'
AND n.type = 'service_request'
ORDER BY n.created_at DESC;

-- Check routing entries created
SELECT 
    rr.id,
    up.email as mechanic,
    sr.title,
    rr.routing_type,
    rr.is_notified,
    rr.notified_at,
    rr.created_at
FROM request_routing rr
JOIN user_profiles up ON up.id = rr.eligible_mechanic_id
JOIN service_requests sr ON sr.id = rr.request_id
WHERE rr.created_at > NOW() - INTERVAL '10 minutes'
ORDER BY rr.created_at DESC;

-- =====================================================
-- SUMMARY OF WHAT WE FIXED:
-- =====================================================
-- 1. ✅ Updated trigger_auto_broadcast_request to SKIP shop requests
-- 2. ✅ Enabled REPLICA IDENTITY FULL on request_routing table
-- 3. ✅ Enabled REPLICA IDENTITY FULL on notifications table
-- 4. ✅ Fixed test query to handle multiple rows
-- 
-- Flow now (COMPLETE):
-- Customer creates shop request
--   → handle_shop_based_routing() fires (shop routing trigger)
--   → trigger_auto_broadcast_request() SKIPS (no conflict!)
--   → Inserts 2 entries into request_routing (realtime enabled!)
--   → Inserts 2 notifications
--   → Mechanic app receives realtime update via Supabase
--   → Popup appears on both mechanic devices! 🎉
-- =====================================================
