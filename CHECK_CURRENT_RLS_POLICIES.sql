-- ========================================
-- 🔍 CHECK CURRENT RLS POLICIES
-- ========================================
-- This will show what RLS policies are currently active
-- ========================================

SELECT 
  '=== 📋 ALL CURRENT POLICIES ON user_profiles ===' as section;

SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename = 'user_profiles'
ORDER BY policyname;

SELECT 
  '=== 🔍 LOOKING FOR TALYER_OWNER POLICIES ===' as section;

SELECT 
  tablename,
  policyname,
  cmd,
  LEFT(qual::text, 100) as policy_condition_preview
FROM pg_policies
WHERE schemaname = 'public'
  AND policyname LIKE '%talyer%'
ORDER BY tablename, policyname;

SELECT 
  '=== ⚠️ CHECK IF RLS IS ENABLED ===' as section;

SELECT 
  schemaname,
  tablename,
  rowsecurity as rls_enabled
FROM pg_tables
WHERE schemaname = 'public'
  AND tablename IN ('user_profiles', 'service_requests', 'mechanic_job_history', 'shops', 'shop_mechanics')
ORDER BY tablename;

-- ========================================
-- INSTRUCTIONS
-- ========================================
DO $$
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE '📋 CURRENT RLS STATUS';
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
    RAISE NOTICE 'If you see old policies (not talyer_owner):';
    RAISE NOTICE '  ❌ You need to run FIX_RLS_FOR_TALYER_OWNER.sql';
    RAISE NOTICE '';
    RAISE NOTICE 'If you see talyer_owner policies with JOINS:';
    RAISE NOTICE '  ❌ You have old version causing recursion';
    RAISE NOTICE '  ✅ Run the UPDATED FIX_RLS_FOR_TALYER_OWNER.sql';
    RAISE NOTICE '';
    RAISE NOTICE 'If you see talyer_owner policies with subqueries:';
    RAISE NOTICE '  ✅ Policies are correct!';
    RAISE NOTICE '  ❓ Check if there are OTHER conflicting policies';
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
END $$;
