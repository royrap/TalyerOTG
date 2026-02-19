-- ============================================
-- 🔍 DEBUG: Shop Isolation Not Working
-- ============================================
-- User selected "riza shop" but mechanic from MechAid was notified
-- Let's trace what happened

-- ============================================
-- STEP 1: Get the latest service request details
-- ============================================
SELECT 
  '🔍 LATEST SERVICE REQUEST' as check_type,
  id,
  customer_id,
  status,
  request_type,
  preferred_shop_id,
  broadcast_status,
  created_at
FROM service_requests
ORDER BY created_at DESC
LIMIT 1;

-- ============================================
-- STEP 2: Check what shop_id is stored (should be riza shop)
-- ============================================
SELECT 
  '🏪 SHOP DETAILS CHECK' as check_type,
  sr.id as request_id,
  sr.preferred_shop_id,
  s.shop_name,
  s.id as actual_shop_id
FROM service_requests sr
LEFT JOIN shops s ON s.id = sr.preferred_shop_id
ORDER BY sr.created_at DESC
LIMIT 1;

-- ============================================
-- STEP 3: Check who was notified
-- ============================================
SELECT 
  '📤 WHO WAS NOTIFIED' as check_type,
  rb.request_id,
  rb.mechanic_id,
  up.first_name || ' ' || up.last_name as mechanic_name,
  rb.shop_id,
  s.shop_name,
  rb.notification_sent_at
FROM request_broadcasts rb
JOIN user_profiles up ON up.id = rb.mechanic_id
LEFT JOIN shops s ON s.id = rb.shop_id
WHERE rb.request_id = (
  SELECT id FROM service_requests ORDER BY created_at DESC LIMIT 1
);

-- ============================================
-- STEP 4: Verify riza shop ID and mechanics
-- ============================================
SELECT 
  '🔍 RIZA SHOP DETAILS' as check_type,
  s.id as shop_id,
  s.shop_name,
  COUNT(sm.mechanic_id) as mechanic_count
FROM shops s
LEFT JOIN shop_mechanics sm ON sm.shop_id = s.id AND sm.is_active = true
WHERE s.shop_name ILIKE '%riza%'
GROUP BY s.id, s.shop_name;

-- ============================================
-- STEP 5: Verify MechAid shop ID and mechanics
-- ============================================
SELECT 
  '🔍 MECHAID SHOP DETAILS' as check_type,
  s.id as shop_id,
  s.shop_name,
  sm.mechanic_id,
  up.first_name || ' ' || up.last_name as mechanic_name,
  sm.is_available
FROM shops s
LEFT JOIN shop_mechanics sm ON sm.shop_id = s.id AND sm.is_active = true
LEFT JOIN user_profiles up ON up.id = sm.mechanic_id
WHERE s.shop_name ILIKE '%mechaid%';

-- ============================================
-- STEP 6: Check if trigger fired and what it did
-- ============================================
-- Run this query and check your Supabase logs for:
-- "🚀 ===== TRIGGER FIRED ====="
-- "🚀 Preferred Shop ID: [shop_id]"
-- "📊 ===== BROADCAST RESULT ====="

SELECT '⚠️ NOW CHECK SUPABASE LOGS FOR TRIGGER EXECUTION!' as reminder;

-- ============================================
-- CRITICAL QUESTION TO ANSWER:
-- ============================================
-- If preferred_shop_id is NULL in the latest service_request:
--   → Flutter is STILL not passing shopId correctly
--   → Need to check vehicle_details_screen.dart line 869 again
--
-- If preferred_shop_id has a value but wrong mechanics notified:
--   → Database function is not filtering correctly
--   → Check the broadcast function logic
-- ============================================
