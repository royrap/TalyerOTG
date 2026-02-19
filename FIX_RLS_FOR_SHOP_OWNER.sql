-- ========================================
-- 🔧 FIX RLS POLICIES FOR SHOP OWNER DASHBOARD
-- ========================================
-- This adds missing policies so shop owners can see their data
-- ========================================

-- ========================================
-- 1. ADD POLICY: Shop owners can view their shop's service requests
-- ========================================

-- Drop if exists (to avoid errors if already exists)
DROP POLICY IF EXISTS "shop_owners_view_their_requests" ON service_requests;

-- Create policy for shop owners to view service_requests for their shop
CREATE POLICY "shop_owners_view_their_requests"
ON service_requests
FOR SELECT
USING (
  -- Shop owner can see requests for their shop
  EXISTS (
    SELECT 1 FROM shops
    WHERE shops.id = service_requests.shop_id
    AND shops.owner_id = auth.uid()
  )
);

-- ========================================
-- 2. ADD POLICY: Shop owners can view mechanic_job_history for their shop
-- ========================================

DROP POLICY IF EXISTS "shop_owners_view_job_history" ON mechanic_job_history;

CREATE POLICY "shop_owners_view_job_history"
ON mechanic_job_history
FOR SELECT
USING (
  -- Shop owner can see job history for their shop
  EXISTS (
    SELECT 1 FROM shops
    WHERE shops.id = mechanic_job_history.shop_id
    AND shops.owner_id = auth.uid()
  )
);

-- ========================================
-- 3. ADD POLICY: Shop owners can view their own shop
-- ========================================

DROP POLICY IF EXISTS "shop_owners_view_own_shop" ON shops;

CREATE POLICY "shop_owners_view_own_shop"
ON shops
FOR SELECT
USING (
  -- Shop owner can see their own shop
  owner_id = auth.uid()
);

-- ========================================
-- 4. ADD POLICY: Shop owners can view mechanics in their shop
-- ========================================

DROP POLICY IF EXISTS "shop_owners_view_shop_mechanics" ON shop_mechanics;

CREATE POLICY "shop_owners_view_shop_mechanics"
ON shop_mechanics
FOR SELECT
USING (
  -- Shop owner can see mechanics in their shop
  EXISTS (
    SELECT 1 FROM shops
    WHERE shops.id = shop_mechanics.shop_id
    AND shops.owner_id = auth.uid()
  )
);

-- ========================================
-- 5. VERIFY POLICIES WERE CREATED
-- ========================================

SELECT 
  '=== ✅ NEW POLICIES CREATED ===' as section;

SELECT 
  tablename,
  policyname,
  cmd,
  qual
FROM pg_policies
WHERE schemaname = 'public'
  AND policyname LIKE '%shop_owners%'
ORDER BY tablename, policyname;

-- ========================================
-- 6. TEST IF SHOP OWNER CAN NOW SEE DATA
-- ========================================

SELECT 
  '=== 🧪 TEST: Can shop owner see service_requests now? ===' as section;

SELECT 
  COUNT(*) as total_requests,
  COUNT(CASE WHEN status = 'completed' THEN 1 END) as completed_requests
FROM service_requests;

SELECT 
  '=== 🧪 TEST: Can shop owner see mechanic_job_history now? ===' as section;

SELECT 
  COUNT(*) as total_history,
  COUNT(CASE WHEN job_status = 'completed' THEN 1 END) as completed_jobs
FROM mechanic_job_history;

SELECT 
  '=== 🧪 TEST: Detailed completed jobs visible to shop owner ===' as section;

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
  AND s.owner_id = auth.uid()
ORDER BY sr.completed_at DESC;

-- ========================================
-- SUCCESS MESSAGE
-- ========================================
DO $$
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ RLS POLICIES ADDED FOR SHOP OWNERS!';
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
    RAISE NOTICE 'Policies created:';
    RAISE NOTICE '1. ✅ shop_owners_view_their_requests';
    RAISE NOTICE '2. ✅ shop_owners_view_job_history';
    RAISE NOTICE '3. ✅ shop_owners_view_own_shop';
    RAISE NOTICE '4. ✅ shop_owners_view_shop_mechanics';
    RAISE NOTICE '';
    RAISE NOTICE 'Check the test results above!';
    RAISE NOTICE 'If you see your completed jobs → RLS FIX WORKED!';
    RAISE NOTICE '';
    RAISE NOTICE 'Now hot reload your Flutter app and check dashboard!';
    RAISE NOTICE '========================================';
END $$;
