-- =====================================================
-- TRIGGER NEW MECHANIC NOTIFICATION
-- =====================================================
-- Now that shop_id is fixed, let's trigger a fresh notification

-- Step 1: Delete old routing entries (already processed)
DELETE FROM request_routing 
WHERE request_id = '1de8e29c-b015-44b1-95f6-8e6c49195b90';

-- Step 2: Delete old notifications (already seen)
DELETE FROM notifications
WHERE data->>'request_id' = '1de8e29c-b015-44b1-95f6-8e6c49195b90';

-- Step 3: Manually trigger the routing function
-- This will create fresh routing entries and notifications
SELECT handle_shop_based_routing(
    '1de8e29c-b015-44b1-95f6-8e6c49195b90'::uuid,
    'cedc2e63-7785-4d61-a8f1-9f4ed8d254da'::uuid
);

-- Step 4: Verify new routing entries created
SELECT 
    rr.id,
    rr.eligible_mechanic_id,
    up.email as mechanic_email,
    rr.is_notified,
    rr.notified_at,
    rr.created_at
FROM request_routing rr
JOIN user_profiles up ON up.id = rr.eligible_mechanic_id
WHERE rr.request_id = '1de8e29c-b015-44b1-95f6-8e6c49195b90'
ORDER BY rr.created_at DESC;

-- Step 5: Verify new notifications created
SELECT 
    n.id,
    up.email as mechanic_email,
    n.title,
    n.type,
    n.read,
    n.created_at
FROM notifications n
JOIN user_profiles up ON up.id = n.user_id
WHERE n.data->>'request_id' = '1de8e29c-b015-44b1-95f6-8e6c49195b90'
ORDER BY n.created_at DESC;

-- Expected:
-- ✅ 2 new routing entries (Rafael + Yujiro)
-- ✅ 2 new notifications
-- ✅ Mechanic app should receive realtime event and show POPUP! 🎉

-- =====================================================
-- CHECK MECHANIC APP NOW - POPUP SHOULD APPEAR!
-- =====================================================
