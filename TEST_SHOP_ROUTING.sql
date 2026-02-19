-- =====================================================
-- TEST SHOP-BASED REQUEST ROUTING
-- =====================================================
-- Run this to create a test request and verify notifications

-- STEP 1: Create a test shop-based request
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
    '🧪 TEST - Shop Request Routing',
    'Testing if mechanics receive notifications',
    14.5995,
    120.9842,
    'Test Location, Manila',
    'pending',
    'shop_based',
    NOW()
);

-- STEP 2: Verify routing entries were created
SELECT 
    sr.id as request_id,
    sr.title,
    sr.shop_id,
    s.shop_name,
    sr.mechanics_notified_count,
    sr.broadcast_started_at,
    COUNT(rr.id) as routing_entries_created,
    array_agg(up.email) as notified_mechanics
FROM service_requests sr
LEFT JOIN shops s ON s.id = sr.shop_id
LEFT JOIN request_routing rr ON rr.request_id = sr.id
LEFT JOIN user_profiles up ON up.id = rr.eligible_mechanic_id
WHERE sr.title LIKE '%TEST%'
GROUP BY sr.id, sr.title, sr.shop_id, s.shop_name, sr.mechanics_notified_count, sr.broadcast_started_at
ORDER BY sr.created_at DESC
LIMIT 1;

-- STEP 3: Check notification entries
SELECT 
    n.id,
    up.email as mechanic_email,
    n.title,
    n.body,
    n.type,
    n.read,
    n.created_at,
    n.data->>'request_id' as request_id,
    n.data->>'routing_type' as routing_type
FROM notifications n
JOIN user_profiles up ON up.id = n.user_id
WHERE n.data->>'request_id' IN (
    SELECT id::text FROM service_requests WHERE title LIKE '%TEST%'
)
ORDER BY n.created_at DESC;

-- STEP 4: Check request_routing details
SELECT 
    rr.id as routing_id,
    sr.title as request_title,
    up.email as mechanic_email,
    rr.routing_type,
    rr.is_notified,
    rr.notified_at,
    rr.response_deadline,
    rr.response_status
FROM request_routing rr
JOIN service_requests sr ON sr.id = rr.request_id
JOIN user_profiles up ON up.id = rr.eligible_mechanic_id
WHERE sr.title LIKE '%TEST%'
ORDER BY rr.created_at DESC;

-- =====================================================
-- EXPECTED RESULTS:
-- =====================================================
-- STEP 2: Should show 2 routing entries (Rafael + Yujiro)
-- STEP 3: Should show 2 notifications
-- STEP 4: Should show routing_type = 'shop_based', is_notified = true
-- =====================================================

-- =====================================================
-- IF RESULTS ARE CORRECT:
-- =====================================================
-- 1. Both mechanics should receive popup notification on their devices
-- 2. Request should appear in mechanic dashboard
-- 3. First to accept gets the job
-- =====================================================
