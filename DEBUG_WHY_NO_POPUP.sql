-- =====================================================
-- DEBUG: CHECK WHY POPUP NOT APPEARING
-- =====================================================

-- =====================================================
-- STEP 1: CHECK IF SERVICE REQUEST EXISTS
-- =====================================================

SELECT 
    id,
    title,
    customer_id,
    shop_id,
    status,
    request_type,
    created_at
FROM service_requests
WHERE id = '1de8e29c-b015-44b1-95f6-8e6c49195b90';

-- If this returns 0 rows, the request was deleted!

-- =====================================================
-- STEP 2: CHECK ALL SERVICE REQUESTS
-- =====================================================

SELECT 
    id,
    title,
    customer_id,
    shop_id,
    status,
    request_type,
    created_at
FROM service_requests
WHERE customer_id = '1779a3d6-7308-45ec-aeae-cc3909d6cc03'  -- Jules
ORDER BY created_at DESC
LIMIT 5;

-- Find the actual request ID

-- =====================================================
-- STEP 3: CHECK ROUTING ENTRIES
-- =====================================================

SELECT 
    rr.id,
    rr.request_id,
    rr.eligible_mechanic_id,
    up.email,
    up.first_name,
    rr.routing_type,
    rr.is_notified,
    rr.created_at
FROM request_routing rr
JOIN user_profiles up ON up.id = rr.eligible_mechanic_id
ORDER BY rr.created_at DESC
LIMIT 10;

-- Check if routing entries exist for ANY request

-- =====================================================
-- STEP 4: CHECK NOTIFICATIONS
-- =====================================================

SELECT 
    n.id,
    n.user_id,
    up.email,
    up.first_name,
    n.title,
    n.body,
    n.type,
    n.read,
    n.data->>'request_id' as request_id,
    n.created_at
FROM notifications n
JOIN user_profiles up ON up.id = n.user_id
WHERE up.user_type = 'mechanic'
ORDER BY n.created_at DESC
LIMIT 10;

-- Check if notifications exist for mechanics

-- =====================================================
-- STEP 5: CHECK NOTIFICATIONS PUBLICATION
-- =====================================================

SELECT tablename
FROM pg_publication_tables
WHERE pubname = 'supabase_realtime'
AND tablename = 'notifications';

-- Expected: Should return 'notifications'

-- =====================================================
-- STEP 6: CHECK MECHANIC AVAILABILITY
-- =====================================================

SELECT 
    mas.mechanic_id,
    up.email,
    up.first_name,
    mas.current_status,
    mas.is_accepting_requests,
    mas.last_status_update
FROM mechanic_availability_status mas
JOIN user_profiles up ON up.id = mas.mechanic_id
WHERE mas.mechanic_id IN (
    'da0aade5-1e11-4901-898c-3fd67379262f',  -- Rafael
    '0f9bd950-5a9b-42c2-84c2-6dcb8c5fde04'   -- Yujiro
);

-- Check if mechanics are available

-- =====================================================
-- STEP 7: CHECK SHOP MECHANICS
-- =====================================================

SELECT 
    sm.id,
    sm.shop_id,
    sh.shop_name,
    sm.mechanic_id,
    up.email,
    up.first_name,
    sm.is_active
FROM shop_mechanics sm
JOIN user_profiles up ON up.id = sm.mechanic_id
JOIN shops sh ON sh.id = sm.shop_id
WHERE sm.shop_id = 'cedc2e63-7785-4d61-a8f1-9f4ed8d254da';

-- Verify shop mechanics are linked correctly

-- =====================================================
-- STEP 8: CREATE TEST NOTIFICATION RIGHT NOW
-- =====================================================

-- Delete any existing test notifications
DELETE FROM notifications
WHERE user_id = 'da0aade5-1e11-4901-898c-3fd67379262f'
AND title LIKE 'TEST%';

-- Insert test notification for Rafael
INSERT INTO notifications (
    user_id,
    title,
    body,
    type,
    data,
    read
) VALUES (
    'da0aade5-1e11-4901-898c-3fd67379262f',
    'TEST - Check Realtime Now!',
    'If you see this popup, realtime is working!',
    'test',
    jsonb_build_object(
        'test', true,
        'timestamp', NOW()::text
    ),
    false
)
RETURNING id, title, created_at;

-- Expected: Should return the new notification ID
-- Mechanic app should show popup IMMEDIATELY if realtime is working

-- =====================================================
-- DIAGNOSTIC SUMMARY
-- =====================================================

DO $$ 
BEGIN
    RAISE NOTICE '🔍 Check Results:';
    RAISE NOTICE '1. Does service request exist?';
    RAISE NOTICE '2. Are there routing entries?';
    RAISE NOTICE '3. Are there notifications?';
    RAISE NOTICE '4. Is notifications table published?';
    RAISE NOTICE '5. Are mechanics available?';
    RAISE NOTICE '6. Are shop mechanics linked?';
    RAISE NOTICE '7. TEST notification inserted - CHECK MECHANIC APP NOW!';
END $$;
