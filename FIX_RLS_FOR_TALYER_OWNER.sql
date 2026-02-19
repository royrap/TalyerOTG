-- ========================================
-- 🔧 FIX RLS FOR TALYER OWNER (CORRECT user_type!)
-- ========================================
-- This uses the correct user_type: 'talyer_owner'
-- ========================================

-- ========================================
-- 1. ADD POLICY: Talyer owners can view ALL service requests
-- ========================================

DROP POLICY IF EXISTS "talyer_owners_view_all_requests" ON service_requests;

CREATE POLICY "talyer_owners_view_all_requests"
ON service_requests
FOR SELECT
USING (
  -- Allow if user owns the shop (DIRECT CHECK - no user_profiles JOIN to avoid recursion)
  EXISTS (
    SELECT 1 FROM shops s
    WHERE s.owner_id = auth.uid()
      AND s.id = service_requests.shop_id
  )
);

-- ========================================
-- 2. ADD POLICY: Talyer owners can view mechanic_job_history
-- ========================================

DROP POLICY IF EXISTS "talyer_owners_view_job_history" ON mechanic_job_history;

CREATE POLICY "talyer_owners_view_job_history"
ON mechanic_job_history
FOR SELECT
USING (
  -- Allow if user owns the shop (DIRECT CHECK - no user_profiles JOIN to avoid recursion)
  EXISTS (
    SELECT 1 FROM shops s
    WHERE s.owner_id = auth.uid()
      AND s.id = mechanic_job_history.shop_id
  )
);

-- ========================================
-- 3. ADD POLICY: Talyer owners can view their own shop
-- ========================================

DROP POLICY IF EXISTS "talyer_owners_view_own_shop" ON shops;

CREATE POLICY "talyer_owners_view_own_shop"
ON shops
FOR SELECT
USING (
  -- Allow if user owns this shop (DIRECT CHECK - no user_profiles to avoid recursion)
  owner_id = auth.uid()
);

-- ========================================
-- 4. ADD POLICY: Talyer owners can view shop_mechanics
-- ========================================

DROP POLICY IF EXISTS "talyer_owners_view_shop_mechanics" ON shop_mechanics;

CREATE POLICY "talyer_owners_view_shop_mechanics"
ON shop_mechanics
FOR SELECT
USING (
  -- Allow if user owns the shop (DIRECT CHECK - no user_profiles JOIN to avoid recursion)
  EXISTS (
    SELECT 1 FROM shops s
    WHERE s.owner_id = auth.uid()
      AND s.id = shop_mechanics.shop_id
  )
);

-- ========================================
-- 5. ADD POLICY: Talyer owners can view user_profiles (mechanics, etc.)
-- ========================================

DROP POLICY IF EXISTS "talyer_owners_view_user_profiles" ON user_profiles;

CREATE POLICY "talyer_owners_view_user_profiles"
ON user_profiles
FOR SELECT
USING (
  -- Talyer owners can see their own profile
  id = auth.uid()
  OR
  -- Talyer owners can see mechanics in their shop (DIRECT CHECK - no recursion)
  EXISTS (
    SELECT 1 FROM shop_mechanics sm
    WHERE sm.shop_id IN (
      SELECT id FROM shops WHERE owner_id = auth.uid()
    )
    AND sm.mechanic_id = user_profiles.id
  )
  OR
  -- Talyer owners can see customers who requested from their shop (DIRECT CHECK - no recursion)
  EXISTS (
    SELECT 1 FROM service_requests sr
    WHERE sr.shop_id IN (
      SELECT id FROM shops WHERE owner_id = auth.uid()
    )
    AND sr.customer_id = user_profiles.id
  )
);

-- ========================================
-- 6. VERIFY POLICIES CREATED
-- ========================================

SELECT 
  '=== ✅ TALYER OWNER POLICIES CREATED ===' as section;

SELECT 
  tablename,
  policyname,
  cmd,
  qual
FROM pg_policies
WHERE schemaname = 'public'
  AND policyname LIKE '%talyer_owner%'
ORDER BY tablename, policyname;

-- ========================================
-- 7. TEST IF TALYER OWNER CAN SEE DATA NOW
-- ========================================

SELECT 
  '=== 👤 CURRENT USER CHECK ===' as section;

SELECT 
  auth.uid() as user_id,
  up.user_type,
  up.first_name,
  up.last_name,
  CASE 
    WHEN up.user_type = 'talyer_owner' THEN '✅ IS TALYER OWNER'
    ELSE '❌ NOT TALYER OWNER'
  END as type_check
FROM user_profiles up
WHERE up.id = auth.uid();

SELECT 
  '=== 🧪 TEST: Can see service_requests? ===' as section;

SELECT 
  COUNT(*) as visible_requests,
  COUNT(CASE WHEN status = 'completed' THEN 1 END) as completed_requests
FROM service_requests;

SELECT 
  '=== 🧪 TEST: Can see mechanic_job_history? ===' as section;

SELECT 
  COUNT(*) as visible_history,
  COUNT(CASE WHEN job_status = 'completed' THEN 1 END) as completed_jobs
FROM mechanic_job_history;

SELECT 
  '=== 🧪 TEST: Detailed completed jobs ===' as section;

SELECT 
  sr.id,
  sr.title,
  sr.status,
  sr.final_price,
  sr.shop_earnings,
  sr.mechanic_earnings,
  sr.platform_fee,
  sr.completed_at,
  sr.shop_id,
  s.shop_name
FROM service_requests sr
INNER JOIN shops s ON s.id = sr.shop_id
WHERE sr.status = 'completed'
ORDER BY sr.completed_at DESC;

-- ========================================
-- SUCCESS MESSAGE
-- ========================================
DO $$
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ TALYER OWNER RLS POLICIES ADDED!';
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
    RAISE NOTICE 'Policies created for user_type = talyer_owner:';
    RAISE NOTICE '1. ✅ talyer_owners_view_all_requests';
    RAISE NOTICE '2. ✅ talyer_owners_view_job_history';
    RAISE NOTICE '3. ✅ talyer_owners_view_own_shop';
    RAISE NOTICE '4. ✅ talyer_owners_view_shop_mechanics';
    RAISE NOTICE '5. ✅ talyer_owners_view_user_profiles';
    RAISE NOTICE '';
    RAISE NOTICE 'Check test results above!';
    RAISE NOTICE 'If you see completed jobs → IT WORKED!';
    RAISE NOTICE '';
    RAISE NOTICE 'Now hot reload Flutter app!';
    RAISE NOTICE '========================================';
END $$;
