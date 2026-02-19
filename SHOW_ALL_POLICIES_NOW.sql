-- ========================================
-- 🔍 SHOW ALL POLICIES RIGHT NOW
-- ========================================

SELECT 
  '=== 📋 ALL user_profiles POLICIES ===' as section;

SELECT 
  policyname,
  cmd,
  LEFT(qual::text, 150) as policy_snippet
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename = 'user_profiles'
ORDER BY policyname;

SELECT 
  '=== 🔍 COUNT POLICIES ===' as section;

SELECT 
  COUNT(*) as total_policies,
  COUNT(CASE WHEN qual::text LIKE '%shop_mechanics%' THEN 1 END) as has_shop_mechanics_check,
  COUNT(CASE WHEN qual::text LIKE '%service_requests%' THEN 1 END) as has_service_requests_check
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename = 'user_profiles';
