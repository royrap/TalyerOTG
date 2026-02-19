-- =====================================================
-- MANUAL TRIGGER: CREATE ROUTING AND NOTIFICATIONS
-- =====================================================
-- Since handle_shop_based_routing() is a trigger function,
-- we'll manually create the routing entries and notifications

-- =====================================================
-- STEP 1: Clean up old entries
-- =====================================================

DELETE FROM request_routing 
WHERE request_id = '1de8e29c-b015-44b1-95f6-8e6c49195b90';

DELETE FROM notifications
WHERE data->>'request_id' = '1de8e29c-b015-44b1-95f6-8e6c49195b90';

-- =====================================================
-- STEP 2: Get shop mechanics for MechAid supply
-- =====================================================

SELECT 
    sm.mechanic_id,
    up.email,
    up.first_name,
    up.last_name,
    sm.is_active,
    mas.current_status,
    mas.is_accepting_requests
FROM shop_mechanics sm
JOIN user_profiles up ON up.id = sm.mechanic_id
LEFT JOIN mechanic_availability_status mas ON mas.mechanic_id = sm.mechanic_id
WHERE sm.shop_id = 'cedc2e63-7785-4d61-a8f1-9f4ed8d254da'
AND sm.is_active = true;

-- Expected: Rafael and Yujiro

-- =====================================================
-- STEP 3: Manually create routing entries
-- =====================================================

-- Insert routing entry for Rafael
INSERT INTO request_routing (
    request_id,
    eligible_mechanic_id,
    eligible_shop_id,
    routing_type,
    is_notified,
    notified_at,
    response_deadline
) VALUES (
    '1de8e29c-b015-44b1-95f6-8e6c49195b90',
    'da0aade5-1e11-4901-898c-3fd67379262f',  -- Rafael
    'cedc2e63-7785-4d61-a8f1-9f4ed8d254da',
    'shop_based',
    false,
    NOW(),
    NOW() + INTERVAL '30 minutes'
);

-- Insert routing entry for Yujiro
INSERT INTO request_routing (
    request_id,
    eligible_mechanic_id,
    eligible_shop_id,
    routing_type,
    is_notified,
    notified_at,
    response_deadline
) VALUES (
    '1de8e29c-b015-44b1-95f6-8e6c49195b90',
    '0f9bd950-5a9b-42c2-84c2-6dcb8c5fde04',  -- Yujiro
    'cedc2e63-7785-4d61-a8f1-9f4ed8d254da',
    'shop_based',
    false,
    NOW(),
    NOW() + INTERVAL '30 minutes'
);

-- =====================================================
-- STEP 4: Manually create notifications
-- =====================================================

-- Notification for Rafael
INSERT INTO notifications (
    user_id,
    title,
    body,
    type,
    data,
    read
) VALUES (
    'da0aade5-1e11-4901-898c-3fd67379262f',
    'New Service Request',
    'New shop-based service request from jules agultoxxx',
    'new_request',
    jsonb_build_object(
        'request_id', '1de8e29c-b015-44b1-95f6-8e6c49195b90',
        'customer_name', 'jules agultoxxx',
        'shop_id', 'cedc2e63-7785-4d61-a8f1-9f4ed8d254da',
        'request_type', 'shop_based',
        'title', 'rafael tune'
    ),
    false
);

-- Notification for Yujiro
INSERT INTO notifications (
    user_id,
    title,
    body,
    type,
    data,
    read
) VALUES (
    '0f9bd950-5a9b-42c2-84c2-6dcb8c5fde04',
    'New Service Request',
    'New shop-based service request from jules agultoxxx',
    'new_request',
    jsonb_build_object(
        'request_id', '1de8e29c-b015-44b1-95f6-8e6c49195b90',
        'customer_name', 'jules agultoxxx',
        'shop_id', 'cedc2e63-7785-4d61-a8f1-9f4ed8d254da',
        'request_type', 'shop_based',
        'title', 'rafael tune'
    ),
    false
);

-- =====================================================
-- STEP 5: Update service request mechanics_notified_count
-- =====================================================

UPDATE service_requests
SET mechanics_notified_count = 2
WHERE id = '1de8e29c-b015-44b1-95f6-8e6c49195b90';

-- =====================================================
-- STEP 6: Verify everything created
-- =====================================================

-- Check routing entries
SELECT 
    rr.id,
    rr.eligible_mechanic_id,
    up.email,
    rr.routing_type,
    rr.created_at
FROM request_routing rr
JOIN user_profiles up ON up.id = rr.eligible_mechanic_id
WHERE rr.request_id = '1de8e29c-b015-44b1-95f6-8e6c49195b90'
ORDER BY rr.created_at DESC;

-- Expected: 2 entries (Rafael + Yujiro)

-- Check notifications
SELECT 
    n.id,
    up.email,
    n.title,
    n.body,
    n.read,
    n.created_at
FROM notifications n
JOIN user_profiles up ON up.id = n.user_id
WHERE n.data->>'request_id' = '1de8e29c-b015-44b1-95f6-8e6c49195b90'
ORDER BY n.created_at DESC;

-- Expected: 2 notifications (Rafael + Yujiro)

-- Check service request
SELECT 
    id,
    title,
    shop_id,
    mechanics_notified_count,
    status
FROM service_requests
WHERE id = '1de8e29c-b015-44b1-95f6-8e6c49195b90';

-- Expected: mechanics_notified_count = 2

-- =====================================================
-- SUCCESS! CHECK MECHANIC APP NOW!
-- =====================================================
-- The notifications table is published to supabase_realtime
-- So the mechanic apps will receive the INSERT event immediately
-- and show the popup! 🎉

DO $$ 
BEGIN
    RAISE NOTICE '✅ Routing entries created: 2';
    RAISE NOTICE '✅ Notifications created: 2';
    RAISE NOTICE '🎯 Check mechanic app - popup should appear!';
END $$;
