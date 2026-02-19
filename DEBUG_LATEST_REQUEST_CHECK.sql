-- 🔍 DEBUG: Check Latest Service Request After Navigation Fix
-- Run this to see if shopId is now being passed correctly

-- ============================================
-- 1. LATEST REQUEST DETAILS
-- ============================================
SELECT
  '📋 LATEST REQUEST' as check_type,
  id,
  customer_id,
  preferred_shop_id,
  request_type,
  broadcast_status,
  status,
  title,
  created_at
FROM service_requests
ORDER BY created_at DESC
LIMIT 1;

-- ============================================
-- 2. SHOP ID CHECK
-- ============================================
SELECT
  '🏪 SHOP ID STATUS' as check_type,
  CASE 
    WHEN preferred_shop_id IS NULL THEN '❌ NULL - Shop ID not passed!'
    ELSE '✅ Has shop ID: ' || preferred_shop_id::text
  END as shop_id_status,
  preferred_shop_id
FROM service_requests
ORDER BY created_at DESC
LIMIT 1;

-- ============================================
-- 3. REQUEST TYPE CHECK
-- ============================================
SELECT
  '📡 REQUEST TYPE' as check_type,
  CASE 
    WHEN request_type = 'broadcast' THEN '❌ BROADCAST MODE (should be shop_based)'
    WHEN request_type = 'shop_based' THEN '✅ SHOP-BASED MODE (correct!)'
    ELSE '⚠️ UNKNOWN: ' || COALESCE(request_type, 'NULL')
  END as type_status,
  request_type
FROM service_requests
ORDER BY created_at DESC
LIMIT 1;

-- ============================================
-- 4. BROADCAST STATUS CHECK
-- ============================================
SELECT
  '🔔 BROADCAST STATUS' as check_type,
  CASE 
    WHEN broadcast_status = 'broadcasting' THEN '❌ BROADCASTING (wrong!)'
    WHEN broadcast_status = 'no_mechanics_available' THEN '✅ NO MECHANICS AVAILABLE (correct!)'
    WHEN broadcast_status = 'completed' THEN '✅ COMPLETED'
    ELSE '⚠️ ' || COALESCE(broadcast_status, 'NULL')
  END as status_check,
  broadcast_status
FROM service_requests
ORDER BY created_at DESC
LIMIT 1;

-- ============================================
-- 5. NOTIFICATIONS SENT
-- ============================================
SELECT
  '📬 NOTIFICATIONS' as check_type,
  COUNT(*) as mechanics_notified,
  CASE 
    WHEN COUNT(*) = 0 THEN '✅ No mechanics notified (correct for shop with 0 mechanics)'
    WHEN COUNT(*) > 0 THEN '❌ ' || COUNT(*)::text || ' mechanics notified (should be 0!)'
  END as notification_status,
  array_agg(mechanic_id) as notified_mechanic_ids
FROM request_broadcasts
WHERE request_id = (SELECT id FROM service_requests ORDER BY created_at DESC LIMIT 1);

-- ============================================
-- 6. IF SHOP ID EXISTS, CHECK SHOP MECHANICS COUNT
-- ============================================
SELECT
  '👷 SHOP MECHANICS' as check_type,
  sr.preferred_shop_id,
  s.shop_name,
  COUNT(sm.id) as mechanics_count,
  COUNT(CASE WHEN sm.is_available = true THEN 1 END) as available_mechanics,
  CASE 
    WHEN COUNT(sm.id) = 0 THEN '✅ Correct: Shop has 0 mechanics'
    WHEN COUNT(sm.id) > 0 THEN '⚠️ Shop has ' || COUNT(sm.id)::text || ' mechanics'
  END as mechanics_status
FROM service_requests sr
LEFT JOIN shops s ON s.id = sr.preferred_shop_id
LEFT JOIN shop_mechanics sm ON sm.shop_id = sr.preferred_shop_id
WHERE sr.id = (SELECT id FROM service_requests ORDER BY created_at DESC LIMIT 1)
GROUP BY sr.preferred_shop_id, s.shop_name;

-- ============================================
-- 7. SUMMARY VERDICT
-- ============================================
SELECT
  '⚖️ FINAL VERDICT' as check_type,
  CASE 
    WHEN sr.preferred_shop_id IS NULL THEN 
      '❌ FAILED: Shop ID is NULL - Navigation fix not working!'
    WHEN sr.request_type = 'broadcast' THEN 
      '❌ FAILED: Still in broadcast mode instead of shop_based!'
    WHEN sr.broadcast_status = 'broadcasting' THEN 
      '❌ FAILED: Still broadcasting to all mechanics!'
    WHEN (SELECT COUNT(*) FROM request_broadcasts WHERE request_id = sr.id) > 0 THEN 
      '❌ FAILED: Mechanics were notified when they should not be!'
    WHEN sr.preferred_shop_id IS NOT NULL 
         AND sr.request_type = 'shop_based' 
         AND sr.broadcast_status = 'no_mechanics_available' 
         AND (SELECT COUNT(*) FROM request_broadcasts WHERE request_id = sr.id) = 0 THEN 
      '✅ SUCCESS: Everything working correctly!'
    ELSE 
      '⚠️ PARTIAL: Check individual tests above'
  END as verdict,
  sr.id as request_id,
  sr.preferred_shop_id,
  sr.request_type,
  sr.broadcast_status,
  (SELECT COUNT(*) FROM request_broadcasts WHERE request_id = sr.id) as notifications_sent
FROM service_requests sr
ORDER BY sr.created_at DESC
LIMIT 1;

-- ============================================
-- 8. CONSOLE LOG DATA
-- ============================================
SELECT
  '📝 FOR DEBUG LOGS' as check_type,
  'Check Flutter console for these debug logs:' as instruction,
  '1. "🏪 Navigating to ShopServicesScreen with shopData"' as log1,
  '2. "🔍 DEBUG - preSelectedMechanic data"' as log2,
  '3. "🔍 EnhancedServiceRequestService.createServiceRequestWithStatus"' as log3,
  '4. "📝 Data to INSERT into database"' as log4;
