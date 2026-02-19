-- =====================================================
-- QUICK DIAGNOSTIC - RUN SECTIONS ONE BY ONE
-- =====================================================
-- Copy and run each section individually to see results
-- =====================================================

-- =====================================================
-- SECTION 1: REALTIME STATUS (RUN THIS FIRST)
-- =====================================================
SELECT 
    pst.relname as table_name,
    CASE 
        WHEN pc.relreplident = 'd' THEN '❌ NO REALTIME'
        WHEN pc.relreplident = 'f' THEN '✅ REALTIME OK'
    END as status
FROM pg_stat_user_tables pst
JOIN pg_class pc ON pc.oid = pst.relid
WHERE pst.relname IN ('request_routing', 'notifications')
ORDER BY pst.relname;

-- EXPECTED: Both should show "✅ REALTIME OK"
-- IF ❌: Run this fix:
-- ALTER TABLE request_routing REPLICA IDENTITY FULL;
-- ALTER TABLE notifications REPLICA IDENTITY FULL;

-- =====================================================
-- SECTION 2: TRIGGER STATUS (RUN THIS SECOND)
-- =====================================================
SELECT 
    t.tgname as trigger_name,
    CASE t.tgenabled
        WHEN 'O' THEN '✅ ENABLED'
        WHEN 'D' THEN '❌ DISABLED'
    END as status
FROM pg_trigger t
JOIN pg_proc p ON p.oid = t.tgfoid
WHERE t.tgrelid = 'service_requests'::regclass
AND p.proname = 'handle_shop_based_routing';

-- EXPECTED: "✅ ENABLED"
-- IF ❌ DISABLED: Run this fix:
-- ALTER TABLE service_requests ENABLE TRIGGER on_service_request_insert_shop_routing;

-- =====================================================
-- SECTION 3: MECHANIC STATUS (RUN THIS THIRD)
-- =====================================================
SELECT 
    up.email,
    mas.current_status,
    mas.is_accepting_requests,
    COUNT(sm.shop_id) as shops_assigned
FROM user_profiles up
LEFT JOIN mechanic_availability_status mas ON mas.mechanic_id = up.id
LEFT JOIN shop_mechanics sm ON sm.mechanic_id = up.id AND sm.is_active = true
WHERE up.user_type = 'mechanic'
GROUP BY up.email, mas.current_status, mas.is_accepting_requests;

-- EXPECTED: 
-- current_status = 'available'
-- is_accepting_requests = true
-- shops_assigned >= 1

-- =====================================================
-- SECTION 4: CREATE TEST REQUEST (RUN THIS FOURTH)
-- =====================================================
INSERT INTO service_requests (
    customer_id, shop_id, title, description,
    pickup_latitude, pickup_longitude, pickup_address,
    status, request_type
) VALUES (
    (SELECT id FROM user_profiles WHERE user_type = 'customer' LIMIT 1),
    (SELECT id FROM shops LIMIT 1),
    '🧪 QUICK TEST ' || NOW()::time::text,
    'Quick diagnostic test',
    14.5995, 120.9842, 'Manila',
    'pending', 'shop_based'
);

-- Wait 2 seconds, then run next section

-- =====================================================
-- SECTION 5: CHECK TEST RESULTS (RUN THIS LAST)
-- =====================================================
SELECT 
    sr.title,
    sr.mechanics_notified_count,
    (SELECT COUNT(*) FROM request_routing WHERE request_id = sr.id) as routing_count,
    (SELECT COUNT(*) FROM notifications WHERE data->>'request_id' = sr.id::text) as notification_count,
    (SELECT array_agg(up.email) FROM request_routing rr 
     JOIN user_profiles up ON up.id = rr.eligible_mechanic_id 
     WHERE rr.request_id = sr.id) as notified_mechanics
FROM service_requests sr
WHERE sr.title LIKE '%QUICK TEST%'
ORDER BY sr.created_at DESC
LIMIT 1;

-- EXPECTED RESULTS:
-- mechanics_notified_count: 2
-- routing_count: 2
-- notification_count: 2
-- notified_mechanics: {rafaelpineda471@gmail.com, yujirofuma28@gmail.com}

-- IF routing_count = 0:
-- ❌ TRIGGER NOT WORKING

-- IF routing_count > 0 but NO POPUP:
-- ❌ REALTIME NOT ENABLED or APP NOT SUBSCRIBED

-- =====================================================
-- SECTION 6: CHECK REALTIME PUBLICATION
-- =====================================================
SELECT tablename
FROM pg_publication_tables
WHERE pubname = 'supabase_realtime'
AND tablename IN ('request_routing', 'notifications')
ORDER BY tablename;

-- EXPECTED: 2 rows (request_routing, notifications)
-- IF MISSING: Go to Supabase Dashboard → Database → Publications
--             → supabase_realtime → Add tables

-- =====================================================
-- IF ALL ABOVE PASS BUT STILL NO POPUP:
-- =====================================================
-- Check these in your mechanic app:

-- 1. Is mechanic logged in? ✅
-- 2. Is app in foreground? ✅
-- 3. Check Flutter console for errors
-- 4. Is location permission granted? ✅
-- 5. Is notification permission granted? ✅

-- Run this to check app connection:
SELECT 
    up.email,
    mas.last_active_at,
    NOW() - mas.last_active_at as inactive_duration
FROM user_profiles up
JOIN mechanic_availability_status mas ON mas.mechanic_id = up.id
WHERE up.user_type = 'mechanic'
ORDER BY mas.last_active_at DESC;

-- If inactive_duration > 5 minutes:
-- Mechanic app is not updating location/status
-- App might be closed or not running properly
