-- =====================================================
-- COMPLETE SUPABASE DIAGNOSTIC FOR SHOP ROUTING
-- =====================================================
-- This will check EVERYTHING that could prevent popups
-- =====================================================

-- =====================================================
-- SECTION 1: CHECK REALTIME SETTINGS
-- =====================================================
-- CRITICAL: Realtime must be enabled on these tables

SELECT 
    '🔍 REALTIME STATUS' as check_name,
    pst.relname as table_name,
    CASE 
        WHEN pc.relreplident = 'd' THEN '❌ DEFAULT (NO REALTIME)'
        WHEN pc.relreplident = 'f' THEN '✅ FULL (REALTIME ENABLED)'
        WHEN pc.relreplident = 'n' THEN '⚠️ NOTHING'
        WHEN pc.relreplident = 'i' THEN '⚠️ INDEX ONLY'
    END as replica_identity,
    CASE 
        WHEN pc.relreplident = 'f' THEN 'OK'
        ELSE '❌ FIX: ALTER TABLE ' || pst.relname || ' REPLICA IDENTITY FULL;'
    END as action_needed
FROM pg_stat_user_tables pst
JOIN pg_class pc ON pc.oid = pst.relid
WHERE pst.relname IN ('request_routing', 'notifications', 'service_requests')
ORDER BY pst.relname;

-- =====================================================
-- SECTION 2: CHECK REALTIME PUBLICATION
-- =====================================================
-- Tables must be published to supabase_realtime

SELECT 
    '🔍 PUBLICATION STATUS' as check_name,
    t.table_name,
    CASE 
        WHEN ppt.tablename IS NOT NULL THEN '✅ PUBLISHED'
        ELSE '❌ NOT PUBLISHED'
    END as publication_status,
    CASE 
        WHEN ppt.tablename IS NULL THEN '❌ FIX: Add table to supabase_realtime publication in Supabase Dashboard'
        ELSE 'OK'
    END as action_needed
FROM (
    VALUES 
        ('request_routing'),
        ('notifications'),
        ('service_requests')
) AS t(table_name)
LEFT JOIN pg_publication_tables ppt 
    ON ppt.tablename = t.table_name 
    AND ppt.pubname = 'supabase_realtime'
ORDER BY t.table_name;

-- =====================================================
-- SECTION 3: CHECK TRIGGERS
-- =====================================================
-- Both triggers must be enabled and working

SELECT 
    '🔍 TRIGGER STATUS' as check_name,
    t.tgname as trigger_name,
    p.proname as function_name,
    CASE t.tgenabled
        WHEN 'O' THEN '✅ ENABLED'
        WHEN 'D' THEN '❌ DISABLED'
        WHEN 'R' THEN '⚠️ REPLICA ONLY'
        WHEN 'A' THEN '✅ ALWAYS'
    END as status,
    CASE 
        WHEN t.tgenabled = 'O' OR t.tgenabled = 'A' THEN 'OK'
        ELSE '❌ FIX: ALTER TABLE service_requests ENABLE TRIGGER ' || t.tgname || ';'
    END as action_needed
FROM pg_trigger t
JOIN pg_proc p ON p.oid = t.tgfoid
WHERE t.tgrelid = 'service_requests'::regclass
AND p.proname IN ('handle_shop_based_routing', 'trigger_auto_broadcast_request')
ORDER BY t.tgname;

-- =====================================================
-- SECTION 4: CHECK RLS POLICIES
-- =====================================================
-- request_routing should have NO RLS or permissive policies

SELECT 
    '🔍 RLS STATUS' as check_name,
    c.relname as table_name,
    c.relrowsecurity as rls_enabled,
    CASE 
        WHEN c.relname = 'request_routing' AND c.relrowsecurity = true THEN '❌ RLS SHOULD BE DISABLED'
        WHEN c.relname = 'request_routing' AND c.relrowsecurity = false THEN '✅ RLS DISABLED (GOOD)'
        WHEN c.relname = 'notifications' AND c.relrowsecurity = true THEN '✅ RLS ENABLED (OK)'
        ELSE '✅ OK'
    END as status,
    CASE 
        WHEN c.relname = 'request_routing' AND c.relrowsecurity = true 
        THEN '❌ FIX: ALTER TABLE request_routing DISABLE ROW LEVEL SECURITY;'
        ELSE 'OK'
    END as action_needed
FROM pg_class c
WHERE c.relname IN ('request_routing', 'notifications', 'service_requests')
AND c.relkind = 'r'
ORDER BY c.relname;

-- =====================================================
-- SECTION 5: CHECK SHOP MECHANICS ASSIGNMENT
-- =====================================================
-- Mechanics must be assigned to shops

SELECT 
    '🔍 MECHANIC ASSIGNMENTS' as check_name,
    s.shop_name,
    COUNT(sm.mechanic_id) as total_mechanics,
    COUNT(CASE WHEN sm.is_active = true THEN 1 END) as active_mechanics,
    COUNT(CASE WHEN sm.is_available = true THEN 1 END) as available_mechanics,
    array_agg(up.email) as mechanic_emails,
    CASE 
        WHEN COUNT(sm.mechanic_id) = 0 THEN '❌ NO MECHANICS ASSIGNED'
        WHEN COUNT(CASE WHEN sm.is_active = true THEN 1 END) = 0 THEN '❌ NO ACTIVE MECHANICS'
        WHEN COUNT(CASE WHEN sm.is_available = true THEN 1 END) = 0 THEN '⚠️ NO AVAILABLE MECHANICS'
        ELSE '✅ OK'
    END as status
FROM shops s
LEFT JOIN shop_mechanics sm ON sm.shop_id = s.id
LEFT JOIN user_profiles up ON up.id = sm.mechanic_id
WHERE s.is_active = true
GROUP BY s.id, s.shop_name
ORDER BY s.shop_name;

-- =====================================================
-- SECTION 6: CHECK MECHANIC AVAILABILITY STATUS
-- =====================================================
-- Mechanics must be available and accepting requests

SELECT 
    '🔍 MECHANIC AVAILABILITY' as check_name,
    up.email,
    mas.current_status,
    mas.is_accepting_requests,
    mas.last_active_at,
    CASE 
        WHEN mas.mechanic_id IS NULL THEN '❌ NO AVAILABILITY RECORD'
        WHEN mas.current_status != 'available' THEN '⚠️ STATUS: ' || mas.current_status
        WHEN mas.is_accepting_requests = false THEN '❌ NOT ACCEPTING REQUESTS'
        WHEN mas.last_active_at < NOW() - INTERVAL '30 minutes' THEN '⚠️ INACTIVE FOR 30+ MIN'
        ELSE '✅ READY'
    END as status
FROM user_profiles up
LEFT JOIN mechanic_availability_status mas ON mas.mechanic_id = up.id
WHERE up.user_type = 'mechanic'
ORDER BY up.email;

-- =====================================================
-- SECTION 7: CHECK RECENT ROUTING ENTRIES
-- =====================================================
-- Verify if routing entries are being created

SELECT 
    '🔍 RECENT ROUTING ENTRIES' as check_name,
    COUNT(*) as total_entries_last_hour,
    COUNT(CASE WHEN rr.routing_type = 'shop_based' THEN 1 END) as shop_based_entries,
    COUNT(CASE WHEN rr.is_notified = true THEN 1 END) as notified_entries,
    array_agg(DISTINCT sr.title) as request_titles,
    CASE 
        WHEN COUNT(*) = 0 THEN '❌ NO ROUTING ENTRIES CREATED'
        WHEN COUNT(CASE WHEN rr.is_notified = true THEN 1 END) = 0 THEN '❌ NO NOTIFICATIONS SENT'
        ELSE '✅ ROUTING WORKING'
    END as status
FROM request_routing rr
LEFT JOIN service_requests sr ON sr.id = rr.request_id
WHERE rr.created_at > NOW() - INTERVAL '1 hour';

-- =====================================================
-- SECTION 8: CHECK RECENT NOTIFICATIONS
-- =====================================================
-- Verify if notifications are being created

SELECT 
    '🔍 RECENT NOTIFICATIONS' as check_name,
    COUNT(*) as total_notifications_last_hour,
    COUNT(CASE WHEN n.type = 'service_request' THEN 1 END) as service_request_notifications,
    COUNT(CASE WHEN n.read = false THEN 1 END) as unread_notifications,
    array_agg(DISTINCT up.email) as notified_mechanics,
    CASE 
        WHEN COUNT(*) = 0 THEN '❌ NO NOTIFICATIONS CREATED'
        WHEN COUNT(CASE WHEN n.type = 'service_request' THEN 1 END) = 0 THEN '❌ NO SERVICE REQUEST NOTIFICATIONS'
        ELSE '✅ NOTIFICATIONS WORKING'
    END as status
FROM notifications n
LEFT JOIN user_profiles up ON up.id = n.user_id
WHERE n.created_at > NOW() - INTERVAL '1 hour'
AND n.type = 'service_request';

-- =====================================================
-- SECTION 9: CHECK REQUEST BROADCASTS CONFLICTS
-- =====================================================
-- Verify no duplicate broadcasts for shop requests

SELECT 
    '🔍 BROADCAST CONFLICTS' as check_name,
    COUNT(*) as shop_requests_in_broadcasts,
    COUNT(CASE WHEN sr.shop_id IS NOT NULL THEN 1 END) as conflicting_entries,
    CASE 
        WHEN COUNT(CASE WHEN sr.shop_id IS NOT NULL THEN 1 END) > 0 
        THEN '⚠️ FOUND ' || COUNT(CASE WHEN sr.shop_id IS NOT NULL THEN 1 END) || ' CONFLICTING BROADCASTS'
        ELSE '✅ NO CONFLICTS'
    END as status
FROM request_broadcasts rb
LEFT JOIN service_requests sr ON sr.id = rb.request_id
WHERE rb.created_at > NOW() - INTERVAL '1 hour'
AND sr.request_type = 'shop_based';

-- =====================================================
-- SECTION 10: CHECK TRIGGER FUNCTIONS CODE
-- =====================================================
-- Verify trigger functions have correct logic

SELECT 
    '🔍 TRIGGER FUNCTION LOGIC' as check_name,
    p.proname as function_name,
    CASE 
        WHEN p.proname = 'handle_shop_based_routing' 
             AND p.prosrc LIKE '%request_routing%'
             AND p.prosrc LIKE '%notifications%' 
        THEN '✅ CORRECT LOGIC'
        WHEN p.proname = 'trigger_auto_broadcast_request' 
             AND p.prosrc LIKE '%NEW.shop_id IS NOT NULL%'
             AND p.prosrc LIKE '%RETURN NEW%' 
        THEN '✅ SKIPS SHOP REQUESTS'
        ELSE '⚠️ CHECK FUNCTION CODE'
    END as status,
    LENGTH(p.prosrc) as function_size_chars
FROM pg_proc p
WHERE p.proname IN ('handle_shop_based_routing', 'trigger_auto_broadcast_request')
ORDER BY p.proname;

-- =====================================================
-- SECTION 11: TEST REQUEST CREATION
-- =====================================================
-- Create a test request to verify entire flow

DO $$
DECLARE
    v_test_request_id uuid;
    v_routing_count integer;
    v_notification_count integer;
BEGIN
    -- Create test request
    INSERT INTO service_requests (
        id, customer_id, shop_id, title, description,
        pickup_latitude, pickup_longitude, pickup_address,
        status, request_type, created_at
    ) VALUES (
        gen_random_uuid(),
        (SELECT id FROM user_profiles WHERE user_type = 'customer' LIMIT 1),
        (SELECT id FROM shops WHERE is_active = true LIMIT 1),
        '🧪 DIAGNOSTIC TEST - ' || NOW()::text,
        'Automated diagnostic test',
        14.5995, 120.9842, 'Manila',
        'pending', 'shop_based', NOW()
    ) RETURNING id INTO v_test_request_id;
    
    -- Wait for triggers to fire
    PERFORM pg_sleep(2);
    
    -- Check routing entries created
    SELECT COUNT(*) INTO v_routing_count
    FROM request_routing
    WHERE request_id = v_test_request_id;
    
    -- Check notifications created
    SELECT COUNT(*) INTO v_notification_count
    FROM notifications
    WHERE data->>'request_id' = v_test_request_id::text;
    
    RAISE NOTICE '========================================';
    RAISE NOTICE '🧪 TEST REQUEST CREATED: %', v_test_request_id;
    RAISE NOTICE '📊 ROUTING ENTRIES: % (EXPECTED: 2)', v_routing_count;
    RAISE NOTICE '📱 NOTIFICATIONS: % (EXPECTED: 2)', v_notification_count;
    
    IF v_routing_count = 0 THEN
        RAISE NOTICE '❌ TRIGGER NOT FIRING - handle_shop_based_routing() not working';
    ELSIF v_routing_count < 2 THEN
        RAISE NOTICE '⚠️ ONLY % MECHANIC(S) NOTIFIED', v_routing_count;
    ELSE
        RAISE NOTICE '✅ ROUTING WORKING CORRECTLY';
    END IF;
    
    IF v_notification_count = 0 THEN
        RAISE NOTICE '❌ NOTIFICATIONS NOT CREATED';
    ELSIF v_notification_count < 2 THEN
        RAISE NOTICE '⚠️ ONLY % NOTIFICATION(S) CREATED', v_notification_count;
    ELSE
        RAISE NOTICE '✅ NOTIFICATIONS WORKING CORRECTLY';
    END IF;
    RAISE NOTICE '========================================';
END $$;

-- =====================================================
-- SECTION 12: VERIFY TEST RESULTS
-- =====================================================
-- Check the test request details

WITH latest_test AS (
    SELECT id, title, created_at
    FROM service_requests
    WHERE title LIKE '%DIAGNOSTIC TEST%'
    ORDER BY created_at DESC
    LIMIT 1
)
SELECT 
    '🔍 TEST VERIFICATION' as check_name,
    sr.id,
    sr.title,
    sr.mechanics_notified_count,
    (SELECT COUNT(*) FROM request_routing WHERE request_id = sr.id) as routing_entries,
    (SELECT array_agg(up.email) FROM request_routing rr 
     JOIN user_profiles up ON up.id = rr.eligible_mechanic_id 
     WHERE rr.request_id = sr.id) as notified_mechanics,
    (SELECT COUNT(*) FROM request_broadcasts WHERE request_id = sr.id) as broadcast_entries,
    (SELECT COUNT(*) FROM notifications WHERE data->>'request_id' = sr.id::text) as notification_count,
    CASE 
        WHEN (SELECT COUNT(*) FROM request_routing WHERE request_id = sr.id) = 0 
        THEN '❌ CRITICAL: NO ROUTING ENTRIES CREATED - TRIGGER NOT WORKING'
        WHEN (SELECT COUNT(*) FROM request_routing WHERE request_id = sr.id) < 2
        THEN '⚠️ WARNING: ONLY ' || (SELECT COUNT(*) FROM request_routing WHERE request_id = sr.id) || ' MECHANIC NOTIFIED'
        WHEN (SELECT COUNT(*) FROM request_broadcasts WHERE request_id = sr.id) > 0
        THEN '⚠️ WARNING: DUPLICATE BROADCAST ENTRIES FOUND'
        ELSE '✅ ALL CHECKS PASSED'
    END as status
FROM service_requests sr
WHERE sr.id = (SELECT id FROM latest_test);

-- =====================================================
-- SUMMARY OF ALL ISSUES FOUND
-- =====================================================
SELECT 
    '📋 SUMMARY' as check_name,
    'Run each section above to identify issues' as instruction,
    'Look for ❌ and ⚠️ symbols' as what_to_look_for,
    'Follow action_needed column for fixes' as how_to_fix;

-- =====================================================
-- COMMON FIXES TO APPLY
-- =====================================================
/*
-- If realtime is disabled:
ALTER TABLE request_routing REPLICA IDENTITY FULL;
ALTER TABLE notifications REPLICA IDENTITY FULL;

-- If RLS is enabled on request_routing:
ALTER TABLE request_routing DISABLE ROW LEVEL SECURITY;

-- If trigger is disabled:
ALTER TABLE service_requests ENABLE TRIGGER handle_shop_based_routing;

-- If mechanics not assigned:
INSERT INTO shop_mechanics (shop_id, mechanic_id, is_active, is_available)
SELECT s.id, m.id, true, true
FROM shops s
CROSS JOIN user_profiles m
WHERE s.is_active = true AND m.user_type = 'mechanic'
ON CONFLICT DO NOTHING;

-- If mechanics not available:
UPDATE mechanic_availability_status
SET current_status = 'available', is_accepting_requests = true
WHERE mechanic_id IN (SELECT id FROM user_profiles WHERE user_type = 'mechanic');
*/
