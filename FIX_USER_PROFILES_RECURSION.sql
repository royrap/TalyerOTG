-- ========================================
-- 🔧 FIX user_profiles INFINITE RECURSION
-- ========================================
-- Problem: Too many policies with user_profiles JOINs causing recursion
-- Solution: Clean up and use simple, non-recursive policies
-- ========================================

-- ========================================
-- STEP 1: DROP ALL EXISTING user_profiles POLICIES
-- ========================================

DROP POLICY IF EXISTS "Allow admins update user_profiles" ON user_profiles;
DROP POLICY IF EXISTS "Allow profile inserts" ON user_profiles;
DROP POLICY IF EXISTS "Service role can manage profiles" ON user_profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON user_profiles;
DROP POLICY IF EXISTS "Users can view own profile" ON user_profiles;
DROP POLICY IF EXISTS "allow_service_role_delete" ON user_profiles;
DROP POLICY IF EXISTS "talyer_owners_view_user_profiles" ON user_profiles;
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
-- STEP 2: CREATE SIMPLE, NON-RECURSIVE POLICIES
-- ========================================

-- Policy 1: Everyone can view their own profile
CREATE POLICY "user_profiles_view_self"
ON user_profiles
FOR SELECT
USING (id = auth.uid());

-- Policy 2: Everyone can update their own profile
CREATE POLICY "user_profiles_update_self_only"
ON user_profiles
FOR UPDATE
USING (id = auth.uid());

-- Policy 3: Allow profile creation (for new signups)
CREATE POLICY "user_profiles_insert_new"
ON user_profiles
FOR INSERT
WITH CHECK (id = auth.uid());

-- Policy 4: Service role full access (for backend operations)
CREATE POLICY "user_profiles_service_role_access"
ON user_profiles
FOR ALL
USING (auth.role() = 'service_role');

-- Policy 5: Talyer owners can see mechanics in their shop
CREATE POLICY "talyer_owners_view_mechanics"
ON user_profiles
FOR SELECT
USING (
  -- Own profile
  id = auth.uid()
  OR
  -- Mechanics in owned shops (NO user_profiles JOIN - direct check)
  EXISTS (
    SELECT 1 FROM shop_mechanics sm
    WHERE sm.shop_id IN (
      SELECT id FROM shops WHERE owner_id = auth.uid()
    )
    AND sm.mechanic_id = user_profiles.id
  )
  OR
  -- Customers who requested from owned shops (NO user_profiles JOIN - direct check)
  EXISTS (
    SELECT 1 FROM service_requests sr
    WHERE sr.shop_id IN (
      SELECT id FROM shops WHERE owner_id = auth.uid()
    )
    AND sr.customer_id = user_profiles.id
  )
);

-- ========================================
-- STEP 3: VERIFY NEW POLICIES
-- ========================================

SELECT 
  '=== ✅ NEW user_profiles POLICIES ===' as section;

SELECT 
  policyname,
  cmd,
  LEFT(qual::text, 100) as policy_preview
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename = 'user_profiles'
ORDER BY policyname;

-- ========================================
-- STEP 4: CHECK FOR RECURSION PATTERNS
-- ========================================

SELECT 
  '=== 🔍 CHECKING FOR RECURSION PATTERNS ===' as section;

SELECT 
  policyname,
  CASE 
    WHEN qual::text LIKE '%FROM user_profiles%' THEN '⚠️ WARNING: Has user_profiles subquery!'
    WHEN qual::text LIKE '%user_profiles up%' THEN '❌ ERROR: Has user_profiles JOIN!'
    ELSE '✅ SAFE'
  END as recursion_check
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
    RAISE NOTICE '✅ user_profiles POLICIES CLEANED UP!';
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
    RAISE NOTICE 'Removed 18+ old conflicting policies';
    RAISE NOTICE 'Created 5 simple, non-recursive policies:';
    RAISE NOTICE '  1. user_profiles_view_self';
    RAISE NOTICE '  2. user_profiles_update_self_only';
    RAISE NOTICE '  3. user_profiles_insert_new';
    RAISE NOTICE '  4. user_profiles_service_role_access';
    RAISE NOTICE '  5. talyer_owners_view_mechanics';
    RAISE NOTICE '';
    RAISE NOTICE 'All policies avoid recursion by:';
    RAISE NOTICE '  - Using auth.uid() directly (no JOINs)';
    RAISE NOTICE '  - Using subqueries instead of JOINs';
    RAISE NOTICE '';
    RAISE NOTICE 'Now run FIX_RLS_FOR_TALYER_OWNER.sql';
    RAISE NOTICE 'to add policies for other tables!';
    RAISE NOTICE '========================================';
END $$;
