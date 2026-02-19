-- ============================================
-- 🔍 COMPLETE DIAGNOSTIC AND FIX
-- Run this entire file in Supabase SQL Editor
-- ============================================

-- STEP 1: Check latest request details
SELECT 
  '1️⃣ LATEST REQUEST' as check_section,
  sr.id as request_id,
  sr.title,
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

-- STEP 2: Check if shop ID exists and shop details
SELECT 
  '2️⃣ PREFERRED SHOP' as check_section,
  CASE 
    WHEN sr.preferred_shop_id IS NULL THEN '❌ NULL - Flutter not passing shopId!'
    ELSE '✅ Has shop ID'
  END as shop_id_status,
  sr.preferred_shop_id,
  s.shop_name,
  up.first_name || ' ' || up.last_name as owner_name,
  COUNT(sm.id) as total_mechanics_in_shop,
  COUNT(CASE WHEN sm.is_available = true THEN 1 END) as available_mechanics
FROM service_requests sr
LEFT JOIN shops s ON s.id = sr.preferred_shop_id
LEFT JOIN user_profiles up ON up.id = s.owner_id
LEFT JOIN shop_mechanics sm ON sm.shop_id = sr.preferred_shop_id
WHERE sr.id = (SELECT id FROM service_requests ORDER BY created_at DESC LIMIT 1)
GROUP BY sr.preferred_shop_id, s.shop_name, up.first_name, up.last_name;

-- STEP 3: Check ALL mechanics who received notification
SELECT 
  '3️⃣ WHO WAS NOTIFIED' as check_section,
  rb.mechanic_id,
  mech.first_name || ' ' || mech.last_name as mechanic_name,
  sm.shop_id as mechanic_belongs_to_shop_id,
  shop.shop_name as mechanic_shop_name,
  sr.preferred_shop_id as customer_selected_shop_id,
  selected_shop.shop_name as customer_selected_shop_name,
  CASE 
    WHEN sm.shop_id = sr.preferred_shop_id THEN '✅ CORRECT SHOP'
    WHEN sm.shop_id IS NULL THEN '⚠️ NOT IN ANY SHOP'
    ELSE '❌ WRONG SHOP!'
  END as validation,
  rb.distance_km,
  rb.notification_sent_at
FROM request_broadcasts rb
JOIN service_requests sr ON sr.id = rb.request_id
LEFT JOIN user_profiles mech ON mech.id = rb.mechanic_id
LEFT JOIN shop_mechanics sm ON sm.mechanic_id = rb.mechanic_id
LEFT JOIN shops shop ON shop.id = sm.shop_id
LEFT JOIN shops selected_shop ON selected_shop.id = sr.preferred_shop_id
WHERE rb.request_id = (SELECT id FROM service_requests ORDER BY created_at DESC LIMIT 1)
ORDER BY rb.notification_sent_at;

-- STEP 4: Count wrong notifications
SELECT 
  '4️⃣ WRONG NOTIFICATIONS COUNT' as check_section,
  COUNT(*) as total_wrong_notifications,
  string_agg(mech.first_name || ' ' || mech.last_name || ' (from ' || shop.shop_name || ')', ', ') as wrong_mechanics
FROM request_broadcasts rb
JOIN service_requests sr ON sr.id = rb.request_id
LEFT JOIN shop_mechanics sm ON sm.mechanic_id = rb.mechanic_id
LEFT JOIN shops shop ON shop.id = sm.shop_id
LEFT JOIN user_profiles mech ON mech.id = rb.mechanic_id
WHERE rb.request_id = (SELECT id FROM service_requests ORDER BY created_at DESC LIMIT 1)
  AND sm.shop_id != sr.preferred_shop_id;

-- STEP 5: Show all shops and their mechanics
SELECT 
  '5️⃣ ALL SHOPS & MECHANICS' as check_section,
  s.id as shop_id,
  s.shop_name,
  up.first_name || ' ' || up.last_name as owner_name,
  COUNT(sm.id) as total_mechanics,
  string_agg(mech.first_name || ' ' || mech.last_name, ', ') as mechanics_list
FROM shops s
LEFT JOIN user_profiles up ON up.id = s.owner_id
LEFT JOIN shop_mechanics sm ON sm.shop_id = s.id
LEFT JOIN user_profiles mech ON mech.id = sm.mechanic_id
GROUP BY s.id, s.shop_name, up.first_name, up.last_name
ORDER BY s.shop_name;

-- STEP 6: Final diagnosis
SELECT 
  '6️⃣ FINAL DIAGNOSIS' as check_section,
  CASE 
    WHEN sr.preferred_shop_id IS NULL THEN 
      '❌ CRITICAL: No shop ID in database - Flutter navigation fix did not work!'
    WHEN (SELECT COUNT(*) FROM request_broadcasts rb 
          JOIN shop_mechanics sm ON sm.mechanic_id = rb.mechanic_id 
          WHERE rb.request_id = sr.id 
          AND sr.preferred_shop_id IS NOT NULL 
          AND sm.shop_id != sr.preferred_shop_id) > 0 THEN 
      '❌ CRITICAL: SQL function is notifying wrong mechanics (different shops)!'
    WHEN sr.preferred_shop_id IS NOT NULL 
         AND (SELECT COUNT(*) FROM shop_mechanics WHERE shop_id = sr.preferred_shop_id) = 0
         AND sr.broadcast_status = 'no_mechanics_available'
         AND (SELECT COUNT(*) FROM request_broadcasts WHERE request_id = sr.id) = 0 THEN 
      '✅ SUCCESS: Everything working correctly!'
    ELSE 
      '⚠️ PARTIAL: Check results above for details'
  END as diagnosis,
  sr.id as request_id,
  sr.preferred_shop_id,
  sr.request_type,
  sr.broadcast_status,
  (SELECT COUNT(*) FROM request_broadcasts WHERE request_id = sr.id) as total_notified,
  (SELECT COUNT(*) FROM shop_mechanics WHERE shop_id = sr.preferred_shop_id) as mechanics_in_selected_shop
FROM service_requests sr
WHERE sr.id = (SELECT id FROM service_requests ORDER BY created_at DESC LIMIT 1);

-- ============================================
-- 🔧 SOLUTION: Fix the broadcast function
-- ============================================

-- This section shows what needs to be fixed in the SQL function
SELECT 
  '7️⃣ RECOMMENDED FIX' as check_section,
  'The broadcast function should ONLY notify mechanics from the preferred_shop_id' as issue,
  'Check FIX_SHOP_SPECIFIC_ROUTING.sql was installed correctly' as solution_file,
  'The function should filter: WHERE sm.shop_id = p_preferred_shop_id' as fix_detail;

-- ============================================
-- 🧪 TEST: Check if SQL function exists
-- ============================================
SELECT 
  '8️⃣ SQL FUNCTION CHECK' as check_section,
  p.proname as function_name,
  pg_get_function_identity_arguments(p.oid) as parameters,
  CASE 
    WHEN p.proname = 'broadcast_service_request_with_shop_filter' THEN '✅ Function exists'
    ELSE '⚠️ Different function'
  END as status
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public' 
  AND p.proname LIKE '%broadcast%'
ORDER BY p.proname;

-- ============================================
-- 🎯 QUICK SUMMARY
-- ============================================
SELECT 
  '🎯 QUICK SUMMARY' as final_check,
  (SELECT CASE 
    WHEN preferred_shop_id IS NULL THEN '❌ No shop ID - Flutter issue'
    ELSE '✅ Has shop ID: ' || preferred_shop_id::text
  END FROM service_requests ORDER BY created_at DESC LIMIT 1) as shop_id_check,
  
  (SELECT CASE 
    WHEN request_type = 'shop_based' THEN '✅ Shop-based mode'
    ELSE '❌ Wrong mode: ' || COALESCE(request_type, 'NULL')
  END FROM service_requests ORDER BY created_at DESC LIMIT 1) as request_type_check,
  
  (SELECT COUNT(*)::text || ' mechanics notified' 
   FROM request_broadcasts 
   WHERE request_id = (SELECT id FROM service_requests ORDER BY created_at DESC LIMIT 1)) as notification_count,
  
  (SELECT COUNT(*)::text || ' mechanics in selected shop' 
   FROM service_requests sr
   LEFT JOIN shop_mechanics sm ON sm.shop_id = sr.preferred_shop_id
   WHERE sr.id = (SELECT id FROM service_requests ORDER BY created_at DESC LIMIT 1)) as shop_mechanics_count,
  
  (SELECT CASE 
    WHEN COUNT(*) > 0 THEN '❌ ' || COUNT(*)::text || ' wrong mechanics notified!'
    ELSE '✅ No wrong notifications'
  END
   FROM request_broadcasts rb
   JOIN service_requests sr ON sr.id = rb.request_id
   LEFT JOIN shop_mechanics sm ON sm.mechanic_id = rb.mechanic_id
   WHERE rb.request_id = (SELECT id FROM service_requests ORDER BY created_at DESC LIMIT 1)
   AND sr.preferred_shop_id IS NOT NULL
   AND sm.shop_id != sr.preferred_shop_id) as wrong_notifications_check;
