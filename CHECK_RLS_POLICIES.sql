-- ========================================
-- 🔍 CHECK RLS POLICIES - SHOP OWNER ACCESS
-- ========================================
-- Checking if Row Level Security is blocking shop owner queries
-- ========================================

SELECT 
  '=== 🔒 RLS STATUS ===' as section;

-- Check if RLS is enabled on important tables
SELECT 
  schemaname,
  tablename,
  rowsecurity as rls_enabled
FROM pg_tables
WHERE schemaname = 'public'
  AND tablename IN ('service_requests', 'mechanic_job_history', 'shops', 'shop_mechanics', 'user_profiles')
ORDER BY tablename;

SELECT 
  '=== 📜 RLS POLICIES FOR service_requests ===' as section;

-- Show all RLS policies for service_requests
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
  AND tablename = 'service_requests'
ORDER BY policyname;

SELECT 
  '=== 📜 RLS POLICIES FOR mechanic_job_history ===' as section;

-- Show all RLS policies for mechanic_job_history
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
  AND tablename = 'mechanic_job_history'
ORDER BY policyname;

SELECT 
  '=== 📜 RLS POLICIES FOR shops ===' as section;

-- Show all RLS policies for shops
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
  AND tablename = 'shops'
ORDER BY policyname;

SELECT 
  '=== 🧪 TEST QUERY AS AUTHENTICATED USER ===' as section;

-- Test if current user can see service_requests
SELECT 
  'Can see service_requests?' as test,
  COUNT(*) as visible_rows,
  COUNT(CASE WHEN status = 'completed' THEN 1 END) as completed_rows
FROM service_requests;

-- Test if current user can see mechanic_job_history
SELECT 
  'Can see mechanic_job_history?' as test,
  COUNT(*) as visible_rows,
  COUNT(CASE WHEN job_status = 'completed' THEN 1 END) as completed_rows
FROM mechanic_job_history;

-- Test if current user can see shops
SELECT 
  'Can see shops?' as test,
  COUNT(*) as visible_rows
FROM shops;

SELECT 
  '=== 🔍 CHECK SHOP OWNER ACCESS ===' as section;

-- Check if authenticated user is a shop owner
SELECT 
  auth.uid() as current_user_id,
  up.user_type,
  up.first_name,
  up.last_name,
  up.email,
  s.id as shop_id,
  s.shop_name
FROM user_profiles up
LEFT JOIN shops s ON s.owner_id = up.id
WHERE up.id = auth.uid();

SELECT 
  '=== 🔍 SPECIFIC QUERY TEST ===' as section;

-- Try the exact query Flutter uses
SELECT 
  sr.id,
  sr.title,
  sr.final_price,
  sr.shop_earnings,
  sr.mechanic_earnings,
  sr.platform_fee,
  sr.completed_at,
  sr.shop_id
FROM service_requests sr
INNER JOIN shops s ON s.id = sr.shop_id
INNER JOIN user_profiles up ON up.id = s.owner_id
WHERE sr.status = 'completed'
  AND up.id = auth.uid()  -- Current logged-in user
  AND sr.completed_at >= DATE_TRUNC('day', NOW());

-- ========================================
-- SUMMARY
-- ========================================
DO $$
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE '🔒 RLS POLICY CHECK COMPLETE';
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
    RAISE NOTICE 'Look for:';
    RAISE NOTICE '1. rls_enabled = true/false';
    RAISE NOTICE '2. Policy "qual" column shows access rules';
    RAISE NOTICE '3. visible_rows count - should match actual data';
    RAISE NOTICE '4. shop_id from current user should match jobs';
    RAISE NOTICE '';
    RAISE NOTICE 'If visible_rows = 0 but data exists → RLS IS BLOCKING!';
    RAISE NOTICE '========================================';
END $$;
