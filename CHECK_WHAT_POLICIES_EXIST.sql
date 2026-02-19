-- ========================================
-- 🔍 CHECK WHAT POLICIES ACTUALLY EXIST IN DATABASE
-- ========================================

SELECT 
  '=== 📋 CURRENT user_profiles POLICY ===' as section;

SELECT 
  policyname,
  cmd,
  qual::text as policy_definition
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename = 'user_profiles'
  AND policyname = 'talyer_owners_view_user_profiles';

SELECT 
  '=== 🔍 CHECK IF IT HAS "user_profiles up" JOIN (BAD!) ===' as section;

SELECT 
  policyname,
  CASE 
    WHEN qual::text LIKE '%user_profiles up%' THEN '❌ HAS user_profiles JOIN - WILL CAUSE RECURSION!'
    WHEN qual::text LIKE '%shop_mechanics sm%' AND qual::text LIKE '%service_requests sr%' THEN '✅ Uses subqueries - GOOD!'
    ELSE '❓ Unknown pattern'
  END as status,
  LENGTH(qual::text) as policy_length
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename = 'user_profiles'
  AND policyname = 'talyer_owners_view_user_profiles';

SELECT 
  '=== 🔍 CHECK service_requests POLICY ===' as section;

SELECT 
  policyname,
  CASE 
    WHEN qual::text LIKE '%user_profiles up%' THEN '❌ HAS user_profiles JOIN - WILL CAUSE RECURSION!'
    WHEN qual::text LIKE '%shops s%' AND qual::text NOT LIKE '%user_profiles%' THEN '✅ Direct shop check - GOOD!'
    ELSE '❓ Unknown pattern'
  END as status
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename = 'service_requests'
  AND policyname = 'talyer_owners_view_all_requests';

SELECT 
  '=== 🔍 CHECK shops POLICY ===' as section;

SELECT 
  policyname,
  qual::text as policy_definition,
  CASE 
    WHEN qual::text LIKE '%user_profiles%' THEN '❌ HAS user_profiles check - WILL CAUSE RECURSION!'
    WHEN qual::text LIKE '%owner_id = auth.uid()%' AND qual::text NOT LIKE '%user_profiles%' THEN '✅ Direct owner check - GOOD!'
    ELSE '❓ Unknown pattern'
  END as status
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename = 'shops'
  AND policyname = 'talyer_owners_view_own_shop';

-- ========================================
-- DIAGNOSIS
-- ========================================
DO $$
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE '🔍 DIAGNOSIS COMPLETE';
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
    RAISE NOTICE 'Check the results above:';
    RAISE NOTICE '';
    RAISE NOTICE 'If you see ❌ HAS user_profiles JOIN:';
    RAISE NOTICE '  → The policies are NOT updated yet!';
    RAISE NOTICE '  → You need to run FIX_RLS_FOR_TALYER_OWNER.sql again';
    RAISE NOTICE '';
    RAISE NOTICE 'If you see ✅ marks:';
    RAISE NOTICE '  → Policies are correct';
    RAISE NOTICE '  → Problem might be somewhere else';
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
END $$;
