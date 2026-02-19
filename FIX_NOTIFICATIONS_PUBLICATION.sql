-- =====================================================
-- FIX: ADD NOTIFICATIONS TABLE TO REALTIME PUBLICATION
-- =====================================================

-- Add notifications table to realtime publication
ALTER PUBLICATION supabase_realtime ADD TABLE notifications;

-- Verify it's now published
SELECT tablename
FROM pg_publication_tables
WHERE pubname = 'supabase_realtime'
AND tablename IN ('request_routing', 'notifications', 'service_requests')
ORDER BY tablename;

-- Expected: All 3 tables should appear
-- ✅ notifications
-- ✅ request_routing  
-- ✅ service_requests

-- =====================================================
-- TEST AGAIN AFTER FIX
-- =====================================================

-- Create new test request
INSERT INTO service_requests (
    customer_id, shop_id, title, description,
    pickup_latitude, pickup_longitude, pickup_address,
    status, request_type
) VALUES (
    (SELECT id FROM user_profiles WHERE user_type = 'customer' LIMIT 1),
    (SELECT id FROM shops LIMIT 1),
    '🧪 AFTER PUBLICATION FIX - ' || NOW()::time::text,
    'Testing after adding notifications to publication',
    14.5995, 120.9842, 'Manila',
    'pending', 'shop_based'
);

-- Wait 2 seconds, then verify
SELECT 
    sr.title,
    sr.mechanics_notified_count,
    (SELECT COUNT(*) FROM request_routing WHERE request_id = sr.id) as routing_count,
    (SELECT COUNT(*) FROM notifications WHERE data->>'request_id' = sr.id::text) as notification_count,
    (SELECT array_agg(up.email) FROM request_routing rr 
     JOIN user_profiles up ON up.id = rr.eligible_mechanic_id 
     WHERE rr.request_id = sr.id) as notified_mechanics
FROM service_requests sr
WHERE sr.title LIKE '%AFTER PUBLICATION FIX%'
ORDER BY sr.created_at DESC
LIMIT 1;

-- Expected:
-- routing_count: 2
-- notification_count: 2
-- notified_mechanics: {rafaelpineda471@gmail.com, yujirofuma28@gmail.com}

-- =====================================================
-- NOW CHECK MECHANIC APP - POPUP SHOULD APPEAR! 🎉
-- =====================================================
