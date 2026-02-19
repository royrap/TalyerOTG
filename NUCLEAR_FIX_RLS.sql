-- ========================================
-- 🔥 NUCLEAR OPTION: SIMPLE RLS ONLY
-- ========================================
-- Remove ALL cross-table checks to stop recursion
-- Keep ONLY simple, direct auth.uid() checks
-- ========================================

-- ========================================
-- STEP 1: DROP ALL user_profiles POLICIES
-- ========================================

DROP POLICY IF EXISTS "talyer_owners_view_mechanics" ON user_profiles;
DROP POLICY IF EXISTS "talyer_owners_view_user_profiles" ON user_profiles;
DROP POLICY IF EXISTS "user_profiles_view_self" ON user_profiles;
DROP POLICY IF EXISTS "user_profiles_update_self_only" ON user_profiles;
DROP POLICY IF EXISTS "user_profiles_insert_new" ON user_profiles;
DROP POLICY IF EXISTS "user_profiles_service_role_access" ON user_profiles;

-- Drop any remaining old policies
DROP POLICY IF EXISTS "Allow admins update user_profiles" ON user_profiles;
DROP POLICY IF EXISTS "Allow profile inserts" ON user_profiles;
DROP POLICY IF EXISTS "Service role can manage profiles" ON user_profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON user_profiles;
DROP POLICY IF EXISTS "Users can view own profile" ON user_profiles;
DROP POLICY IF EXISTS "allow_service_role_delete" ON user_profiles;
DROP POLICY IF EXISTS "user_profile_access" ON user_profiles;
DROP POLICY IF EXISTS "user_profile_self_update" ON user_profiles;
DROP POLICY IF EXISTS "user_profiles_allow_all" ON user_profiles;
DROP POLICY IF EXISTS "user_profiles_delete_self" ON user_profiles;
DROP POLICY IF EXISTS "user_profiles_delete_service_role" ON user_profiles;
DROP POLICY IF EXISTS "user_profiles_insert_own" ON user_profiles;
DROP POLICY IF EXISTS "user_profiles_policy" ON user_profiles;
DROP POLICY IF EXISTS "user_profiles_select_own" ON user_profiles;
DROP POLICY IF EXISTS "user_profiles_select_self" ON user_profiles;
DROP POLICY IF EXISTS "user_profiles_update_own" ON user_profiles;
DROP POLICY IF EXISTS "user_profiles_update_self" ON user_profiles;

-- ========================================
-- STEP 2: CREATE SUPER SIMPLE POLICIES (NO CROSS-TABLE CHECKS!)
-- ========================================

-- Policy 1: View own profile ONLY
CREATE POLICY "simple_view_own"
ON user_profiles
FOR SELECT
USING (id = auth.uid());

-- Policy 2: Update own profile ONLY
CREATE POLICY "simple_update_own"
ON user_profiles
FOR UPDATE
USING (id = auth.uid());

-- Policy 3: Insert own profile ONLY
CREATE POLICY "simple_insert_own"
ON user_profiles
FOR INSERT
WITH CHECK (id = auth.uid());

-- Policy 4: Service role full access
CREATE POLICY "simple_service_role"
ON user_profiles
FOR ALL
USING (auth.role() = 'service_role');

-- ========================================
-- STEP 3: TEMPORARILY DISABLE RLS ON user_profiles
-- ========================================
-- This is the NUCLEAR option - disable RLS completely for testing

-- ALTER TABLE user_profiles DISABLE ROW LEVEL SECURITY;

-- ========================================
-- STEP 4: VERIFY
-- ========================================

SELECT 
  '=== ✅ SIMPLE POLICIES CREATED ===' as section;

SELECT 
  policyname,
  cmd,
  qual::text as policy_definition
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename = 'user_profiles'
ORDER BY policyname;

SELECT 
  '=== 🔍 CHECK FOR DANGEROUS PATTERNS ===' as section;

SELECT 
  policyname,
  CASE 
    WHEN qual::text LIKE '%shop_mechanics%' THEN '❌ DANGER: Has shop_mechanics!'
    WHEN qual::text LIKE '%service_requests%' THEN '❌ DANGER: Has service_requests!'
    WHEN qual::text LIKE '%shops%' THEN '❌ DANGER: Has shops!'
    WHEN qual::text LIKE '%auth.uid()%' OR qual::text LIKE '%service_role%' THEN '✅ SAFE: Simple check'
    ELSE '❓ Unknown'
  END as safety_check
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename = 'user_profiles'
ORDER BY policyname;

-- ========================================
-- SUCCESS MESSAGE
-- ========================================
DO $$
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE '🔥 NUCLEAR OPTION APPLIED!';
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
    RAISE NOTICE 'Removed ALL cross-table policies';
    RAISE NOTICE 'Created 4 SUPER SIMPLE policies:';
    RAISE NOTICE '  1. simple_view_own - View own profile ONLY';
    RAISE NOTICE '  2. simple_update_own - Update own profile ONLY';
    RAISE NOTICE '  3. simple_insert_own - Insert own profile ONLY';
    RAISE NOTICE '  4. simple_service_role - Service role access';
    RAISE NOTICE '';
    RAISE NOTICE 'NO cross-table checks = NO recursion!';
    RAISE NOTICE '';
    RAISE NOTICE 'Trade-off: Talyer owners cannot see mechanics';
    RAISE NOTICE 'But at least NO INFINITE RECURSION!';
    RAISE NOTICE '';
    RAISE NOTICE 'If you need to see other profiles, we will';
    RAISE NOTICE 'need to do it in application code, not RLS.';
    RAISE NOTICE '========================================';
END $$;
