-- ============================================
-- QUICK CHECK: What happened with the last request?
-- ============================================

-- 1. What shop_id was saved?
SELECT 
  'Latest Request' as info,
  request_type,
  preferred_shop_id,
  broadcast_status,
  created_at
FROM service_requests
ORDER BY created_at DESC
LIMIT 1;

-- 2. Show me the shop name
SELECT 
  'Shop Info' as info,
  s.shop_name,
  sr.preferred_shop_id
FROM service_requests sr
LEFT JOIN shops s ON s.id = sr.preferred_shop_id
ORDER BY sr.created_at DESC
LIMIT 1;

-- 3. Who got notified?
SELECT 
  'Notified Mechanics' as info,
  up.first_name || ' ' || up.last_name as mechanic_name,
  s.shop_name as their_shop
FROM request_broadcasts rb
JOIN user_profiles up ON up.id = rb.mechanic_id
LEFT JOIN shops s ON s.id = rb.shop_id
WHERE rb.request_id = (
  SELECT id FROM service_requests ORDER BY created_at DESC LIMIT 1
);
