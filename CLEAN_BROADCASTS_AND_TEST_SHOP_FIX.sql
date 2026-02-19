-- =====================================================
-- FIX: CLEAN UP BROADCAST DUPLICATES AND ORPHANS
-- =====================================================

-- Step 1: Check for existing duplicate broadcasts
SELECT 
    rb.request_id,
    rb.provider_id,
    sr.title,
    sr.status,
    rb.notification_sent_at,
    COUNT(*) as duplicate_count
FROM request_broadcasts rb
LEFT JOIN service_requests sr ON sr.id = rb.request_id
GROUP BY rb.request_id, rb.provider_id, sr.title, sr.status, rb.notification_sent_at
HAVING COUNT(*) > 1
ORDER BY rb.notification_sent_at DESC;

-- Step 2: Check for orphaned broadcasts (request doesn't exist)
SELECT 
    rb.id,
    rb.request_id,
    rb.provider_id,
    rb.notification_sent_at
FROM request_broadcasts rb
LEFT JOIN service_requests sr ON sr.id = rb.request_id
WHERE sr.id IS NULL
ORDER BY rb.notification_sent_at DESC;

-- Step 3: Delete orphaned broadcast entries
DELETE FROM request_broadcasts
WHERE request_id NOT IN (
    SELECT id FROM service_requests
);

-- Step 4: Keep only the most recent broadcast per (request_id, provider_id)
DELETE FROM request_broadcasts rb1
WHERE EXISTS (
    SELECT 1 FROM request_broadcasts rb2
    WHERE rb2.request_id = rb1.request_id
    AND rb2.provider_id = rb1.provider_id
    AND rb2.notification_sent_at > rb1.notification_sent_at
);

-- Step 5: Verify cleanup
SELECT COUNT(*) as remaining_broadcasts
FROM request_broadcasts;

SELECT 
    request_id,
    provider_id,
    COUNT(*) as count
FROM request_broadcasts
GROUP BY request_id, provider_id
HAVING COUNT(*) > 1;

-- Expected: 0 duplicates after cleanup

-- =====================================================
-- NOW TEST SHOP-BASED REQUEST WITH ALL FIXES
-- =====================================================

-- 1. First, run FIX_LOCATION_FUNCTION_SHOP_ID.sql to update the function

-- 2. Then test with Rafael's mechanic ID
SELECT 
    request_id,
    title,
    request_type,
    distance_km,
    is_eligible
FROM get_nearby_requests_for_mechanic(
    'da0aade5-1e11-4901-898c-3fd67379262f'::uuid,
    14.9321157,
    120.8807151,
    50.0
);

-- Expected: Should see shop-based request with is_eligible = true

-- 3. Check routing entries exist
SELECT 
    rr.id,
    rr.eligible_mechanic_id,
    up.email,
    rr.routing_type,
    rr.is_notified,
    rr.created_at
FROM request_routing rr
JOIN user_profiles up ON up.id = rr.eligible_mechanic_id
WHERE rr.request_id = '1de8e29c-b015-44b1-95f6-8e6c49195b90'
ORDER BY rr.created_at DESC;

-- 4. Check notifications exist
SELECT 
    n.id,
    up.email,
    n.title,
    n.read,
    n.created_at
FROM notifications n
JOIN user_profiles up ON up.id = n.user_id
WHERE n.data->>'request_id' = '1de8e29c-b015-44b1-95f6-8e6c49195b90'
ORDER BY n.created_at DESC;

-- =====================================================
-- FINAL STEP: TRIGGER FRESH NOTIFICATIONS
-- =====================================================

-- If routing/notifications exist but mechanic didn't see them, delete and recreate

-- Delete old routing
DELETE FROM request_routing 
WHERE request_id = '1de8e29c-b015-44b1-95f6-8e6c49195b90';

-- Delete old notifications
DELETE FROM notifications
WHERE data->>'request_id' = '1de8e29c-b015-44b1-95f6-8e6c49195b90';

-- Trigger fresh routing
SELECT handle_shop_based_routing(
    '1de8e29c-b015-44b1-95f6-8e6c49195b90'::uuid,
    'cedc2e63-7785-4d61-a8f1-9f4ed8d254da'::uuid
);

-- Verify fresh entries created
SELECT 
    'Routing entries' as type,
    COUNT(*) as count
FROM request_routing
WHERE request_id = '1de8e29c-b015-44b1-95f6-8e6c49195b90'

UNION ALL

SELECT 
    'Notifications' as type,
    COUNT(*) as count
FROM notifications
WHERE data->>'request_id' = '1de8e29c-b015-44b1-95f6-8e6c49195b90';

-- Expected: 2 routing entries, 2 notifications

-- =====================================================
-- NOW CHECK MECHANIC APP - POPUP SHOULD APPEAR! 🎉
-- =====================================================
