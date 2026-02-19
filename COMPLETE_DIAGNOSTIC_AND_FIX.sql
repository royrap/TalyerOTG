-- ============================================
-- 🔍 COMPLETE DIAGNOSTIC: Check Latest Request
-- ============================================

-- SECTION 1: Latest Request Full Details
SELECT 
  '📋 1. LATEST REQUEST' as section,
  sr.id,
  sr.title,
  sr.customer_id,
  sr.preferred_shop_id,
  sr.request_type,
  sr.broadcast_status,
  sr.status,
  sr.notified_providers_count,
  sr.created_at,
  up.first_name || ' ' || up.last_name as customer_name
FROM service_requests sr
LEFT JOIN user_profiles up ON up.id = sr.customer_id
ORDER BY sr.created_at DESC
LIMIT 1;

-- SECTION 2: Shop Details (if preferred_shop_id exists)
SELECT 
  '🏪 2. SHOP DETAILS' as section,
  s.id as shop_id,
  s.shop_name,
  s.owner_id,
  up.first_name || ' ' || up.last_name as owner_name,
  COUNT(sm.id) as total_mechanics,
  COUNT(CASE WHEN sm.is_available = true THEN 1 END) as available_mechanics
FROM service_requests sr
LEFT JOIN shops s ON s.id = sr.preferred_shop_id
LEFT JOIN user_profiles up ON up.id = s.owner_id
LEFT JOIN shop_mechanics sm ON sm.shop_id = s.id
WHERE sr.id = (SELECT id FROM service_requests ORDER BY created_at DESC LIMIT 1)
GROUP BY s.id, s.shop_name, s.owner_id, up.first_name, up.last_name;

-- SECTION 3: Mechanics Who Were Notified
SELECT 
  '📬 3. NOTIFIED MECHANICS' as section,
  rb.id as broadcast_id,
  rb.mechanic_id,
  up.first_name || ' ' || up.last_name as mechanic_name,
  up.user_type,
  sm.shop_id as mechanic_shop_id,
  s.shop_name as mechanic_shop_name,
  rb.distance_km,
  rb.notification_sent_at,
  rb.response_status,
  CASE 
    WHEN sm.shop_id = sr.preferred_shop_id THEN '✅ CORRECT: Same shop'
    WHEN sm.shop_id IS NULL THEN '⚠️ Not assigned to any shop'
    WHEN sm.shop_id != sr.preferred_shop_id THEN '❌ WRONG: Different shop!'
    ELSE '⚠️ Unknown'
  END as notification_validity
FROM request_broadcasts rb
JOIN service_requests sr ON sr.id = rb.request_id
LEFT JOIN user_profiles up ON up.id = rb.mechanic_id
LEFT JOIN shop_mechanics sm ON sm.mechanic_id = rb.mechanic_id
LEFT JOIN shops s ON s.id = sm.shop_id
WHERE rb.request_id = (SELECT id FROM service_requests ORDER BY created_at DESC LIMIT 1)
ORDER BY rb.notification_sent_at;

-- SECTION 4: All Mechanics in the Preferred Shop
SELECT 
  '👷 4. MECHANICS IN PREFERRED SHOP' as section,
  sr.preferred_shop_id as shop_id,
  s.shop_name,
  COUNT(sm.id) as total_mechanics,
  string_agg(up.first_name || ' ' || up.last_name, ', ') as mechanic_names,
  string_agg(sm.mechanic_id::text, ', ') as mechanic_ids
FROM service_requests sr
LEFT JOIN shops s ON s.id = sr.preferred_shop_id
LEFT JOIN shop_mechanics sm ON sm.shop_id = sr.preferred_shop_id
LEFT JOIN user_profiles up ON up.id = sm.mechanic_id
WHERE sr.id = (SELECT id FROM service_requests ORDER BY created_at DESC LIMIT 1)
GROUP BY sr.preferred_shop_id, s.shop_name;

-- SECTION 5: Diagnostic Summary
SELECT 
  '⚖️ 5. DIAGNOSTIC SUMMARY' as section,
  CASE 
    WHEN sr.preferred_shop_id IS NULL THEN '❌ CRITICAL: No shop ID - navigation not working'
    ELSE '✅ Has shop ID: ' || sr.preferred_shop_id::text
  END as shop_id_status,
  CASE 
    WHEN sr.request_type = 'broadcast' THEN '❌ WRONG: Using broadcast mode'
    WHEN sr.request_type = 'shop_based' THEN '✅ CORRECT: Using shop_based mode'
    ELSE '⚠️ Unknown: ' || COALESCE(sr.request_type, 'NULL')
  END as request_type_status,
  CASE 
    WHEN sr.broadcast_status = 'broadcasting' THEN '❌ WRONG: Still broadcasting'
    WHEN sr.broadcast_status = 'no_mechanics_available' THEN '✅ CORRECT: No mechanics available'
    ELSE '⚠️ Status: ' || COALESCE(sr.broadcast_status, 'NULL')
  END as broadcast_status_check,
  (SELECT COUNT(*) FROM request_broadcasts WHERE request_id = sr.id) as total_notifications_sent,
  (SELECT COUNT(*) FROM shop_mechanics WHERE shop_id = sr.preferred_shop_id) as mechanics_in_shop,
  CASE 
    WHEN (SELECT COUNT(*) FROM request_broadcasts rb 
          JOIN shop_mechanics sm ON sm.mechanic_id = rb.mechanic_id 
          WHERE rb.request_id = sr.id AND sm.shop_id != sr.preferred_shop_id) > 0 
    THEN '❌ CRITICAL: Wrong mechanics notified!'
    WHEN (SELECT COUNT(*) FROM request_broadcasts WHERE request_id = sr.id) = 0 
    THEN '✅ CORRECT: No mechanics notified'
    ELSE '⚠️ Check notifications above'
  END as notification_validity
FROM service_requests sr
WHERE sr.id = (SELECT id FROM service_requests ORDER BY created_at DESC LIMIT 1);

-- SECTION 6: Final Verdict
SELECT 
  '🎯 6. FINAL VERDICT' as section,
  CASE 
    WHEN sr.preferred_shop_id IS NULL THEN 
      '❌ FAILED: Shop ID not being passed from Flutter app'
    WHEN sr.request_type != 'shop_based' THEN 
      '❌ FAILED: Request type is not shop_based'
    WHEN (SELECT COUNT(*) FROM shop_mechanics WHERE shop_id = sr.preferred_shop_id) = 0 
         AND sr.broadcast_status != 'no_mechanics_available' THEN 
      '❌ FAILED: SQL function not detecting empty shop'
    WHEN (SELECT COUNT(*) FROM request_broadcasts rb 
          JOIN shop_mechanics sm ON sm.mechanic_id = rb.mechanic_id 
          WHERE rb.request_id = sr.id AND sm.shop_id != sr.preferred_shop_id) > 0 THEN 
      '❌ FAILED: Wrong mechanics were notified (from different shops)'
    WHEN sr.preferred_shop_id IS NOT NULL 
         AND sr.request_type = 'shop_based'
         AND (SELECT COUNT(*) FROM shop_mechanics WHERE shop_id = sr.preferred_shop_id) = 0
         AND sr.broadcast_status = 'no_mechanics_available'
         AND (SELECT COUNT(*) FROM request_broadcasts WHERE request_id = sr.id) = 0 THEN 
      '✅ SUCCESS: Everything working correctly!'
    ELSE 
      '⚠️ PARTIAL: Some issues detected, check sections above'
  END as verdict,
  sr.id as request_id,
  sr.created_at
FROM service_requests sr
WHERE sr.id = (SELECT id FROM service_requests ORDER BY created_at DESC LIMIT 1);

-- ============================================
-- 📊 BONUS: All Shops and Their Mechanics
-- ============================================
SELECT 
  '📊 BONUS: ALL SHOPS' as section,
  s.id as shop_id,
  s.shop_name,
  up.first_name || ' ' || up.last_name as owner_name,
  COUNT(sm.id) as total_mechanics,
  string_agg(mech.first_name || ' ' || mech.last_name, ', ') as mechanics
FROM shops s
LEFT JOIN user_profiles up ON up.id = s.owner_id
LEFT JOIN shop_mechanics sm ON sm.shop_id = s.id
LEFT JOIN user_profiles mech ON mech.id = sm.mechanic_id
GROUP BY s.id, s.shop_name, up.first_name, up.last_name
ORDER BY s.shop_name;
