-- ========================================
-- 🔍 COMPLETE RLS DIAGNOSTIC
-- ========================================
-- Show EVERYTHING about RLS to find the problem
-- ========================================

SELECT '=== 📋 ALL TABLES WITH RLS STATUS ===' as section;

SELECT 
  schemaname,
  tablename,
  rowsecurity as rls_enabled,
  CASE 
    WHEN rowsecurity THEN '🔒 ENABLED'
    ELSE '🔓 DISABLED'
  END as status
FROM pg_tables
WHERE schemaname = 'public'
  AND tablename IN (
    'service_requests', 
    'mechanic_job_history', 
    'shops', 
    'shop_mechanics', 
    'user_profiles',
    'invoices',
    'payments'
  )
ORDER BY tablename;

SELECT '=== 📜 ALL RLS POLICIES ON service_requests ===' as section;

SELECT 
  policyname,
  cmd as command,
  permissive,
  roles,
  qual as using_expression
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename = 'service_requests'
ORDER BY policyname;

SELECT '=== 📜 ALL RLS POLICIES ON mechanic_job_history ===' as section;

SELECT 
  policyname,
  cmd as command,
  permissive,
  roles,
  qual as using_expression
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename = 'mechanic_job_history'
ORDER BY policyname;

SELECT '=== 📜 ALL RLS POLICIES ON shops ===' as section;

SELECT 
  policyname,
  cmd as command,
  permissive,
  roles,
  qual as using_expression
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename = 'shops'
ORDER BY policyname;

SELECT '=== 📜 ALL RLS POLICIES ON shop_mechanics ===' as section;

SELECT 
  policyname,
  cmd as command,
  permissive,
  roles,
  qual as using_expression
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename = 'shop_mechanics'
ORDER BY policyname;

SELECT '=== 👤 CURRENT USER INFO ===' as section;

SELECT 
  auth.uid() as current_user_id,
  up.user_type,
  up.first_name,
  up.last_name,
  up.email,
  up.id = auth.uid() as is_current_user
FROM user_profiles up
WHERE up.id = auth.uid();

SELECT '=== 🏪 CURRENT USER SHOP INFO ===' as section;

SELECT 
  s.id as shop_id,
  s.shop_name,
  s.owner_id,
  s.owner_id = auth.uid() as user_owns_this_shop,
  up.first_name as owner_first_name,
  up.last_name as owner_last_name
FROM shops s
INNER JOIN user_profiles up ON up.id = s.owner_id
WHERE s.owner_id = auth.uid();

SELECT '=== 🔍 CHECK IF SHOP EXISTS IN service_requests ===' as section;

-- Check what shop_id is in service_requests
SELECT DISTINCT
  sr.shop_id,
  s.shop_name,
  s.owner_id,
  s.owner_id = auth.uid() as owned_by_current_user
FROM service_requests sr
LEFT JOIN shops s ON s.id = sr.shop_id
WHERE sr.status = 'completed';

SELECT '=== 🧪 TEST: Direct query with RLS (should be filtered) ===' as section;

-- This query respects RLS policies
SELECT 
  COUNT(*) as visible_with_rls,
  COUNT(CASE WHEN status = 'completed' THEN 1 END) as completed_with_rls
FROM service_requests;

SELECT '=== 🧪 TEST: Query with explicit shop owner check ===' as section;

-- This query manually checks shop ownership
SELECT 
  sr.id,
  sr.title,
  sr.status,
  sr.final_price,
  sr.shop_id,
  s.shop_name,
  s.owner_id,
  s.owner_id = auth.uid() as owned_by_me
FROM service_requests sr
INNER JOIN shops s ON s.id = sr.shop_id
WHERE sr.status = 'completed'
ORDER BY sr.completed_at DESC;

SELECT '=== ⚠️ POTENTIAL ISSUES FOUND ===' as section;

-- Issue 1: Check if service_requests.shop_id is NULL
SELECT 
  'service_requests with NULL shop_id' as issue,
  COUNT(*) as count
FROM service_requests
WHERE status = 'completed' AND shop_id IS NULL;

-- Issue 2: Check if shops table is missing owner_id
SELECT 
  'shops with NULL owner_id' as issue,
  COUNT(*) as count
FROM shops
WHERE owner_id IS NULL;

-- Issue 3: Check if current user is actually a shop owner
SELECT 
  'Current user is NOT a shop owner' as issue,
  CASE WHEN EXISTS (
    SELECT 1 FROM shops WHERE owner_id = auth.uid()
  ) THEN 0 ELSE 1 END as count;

-- Issue 4: Check if user_type matches
SELECT 
  'Current user user_type is not talyer_owner' as issue,
  CASE WHEN EXISTS (
    SELECT 1 FROM user_profiles 
    WHERE id = auth.uid() AND user_type = 'talyer_owner'
  ) THEN 0 ELSE 1 END as count;

SELECT '=== 🔧 MANUAL POLICY CHECK ===' as section;

-- Manually test the policy condition
SELECT 
  sr.id,
  sr.shop_id,
  auth.uid() as current_user,
  s.owner_id as shop_owner,
  EXISTS (
    SELECT 1 FROM shops
    WHERE shops.id = sr.shop_id
    AND shops.owner_id = auth.uid()
  ) as policy_should_allow
FROM service_requests sr
LEFT JOIN shops s ON s.id = sr.shop_id
WHERE sr.status = 'completed';

-- ========================================
-- SUMMARY
-- ========================================
DO $$
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE '🔍 COMPLETE RLS DIAGNOSTIC DONE';
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
    RAISE NOTICE 'Check the results above for:';
    RAISE NOTICE '1. RLS enabled/disabled status';
    RAISE NOTICE '2. All existing policies';
    RAISE NOTICE '3. Current user info and shop ownership';
    RAISE NOTICE '4. Potential issues (NULL values, mismatches)';
    RAISE NOTICE '5. Manual policy condition test';
    RAISE NOTICE '';
    RAISE NOTICE 'Copy ALL results and send to me!';
    RAISE NOTICE '========================================';
END $$;
