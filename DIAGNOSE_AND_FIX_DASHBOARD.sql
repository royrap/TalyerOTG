-- ========================================
-- 🔍 DIAGNOSE AND FIX DASHBOARD ISSUES
-- ========================================
-- Issue 1: Mechanic names showing "null null"
-- Issue 2: Earnings showing ₱0.00 despite completed jobs
-- ========================================

-- ========================================
-- PART 1: CHECK MECHANICS IN SHOP
-- ========================================

SELECT 
  '=== 🔧 MECHANICS IN YOUR SHOP ===' as section;

-- Check all mechanics linked to your shop
SELECT 
  up.id as mechanic_id,
  up.first_name,
  up.last_name,
  up.email,
  up.user_type,
  up.shop_id,
  s.shop_name,
  sm.is_active as active_in_shop,
  sm.is_available,
  sm.joined_at
FROM user_profiles up
LEFT JOIN shop_mechanics sm ON sm.mechanic_id = up.id
LEFT JOIN shops s ON s.id = up.shop_id
WHERE up.user_type = 'mechanic'
  AND (up.shop_id IS NOT NULL OR sm.shop_id IS NOT NULL)
ORDER BY up.first_name, up.last_name;

-- ========================================
-- PART 2: CHECK COMPLETED JOBS DATA
-- ========================================

SELECT 
  '=== 📊 COMPLETED JOBS DATA ===' as section;

-- Check service_requests with full details
SELECT 
  sr.id,
  sr.status,
  sr.completed_at,
  sr.final_price,
  sr.mechanic_earnings,
  sr.shop_earnings,
  sr.platform_fee,
  sr.fee_breakdown_calculated,
  -- Mechanic info
  sr.assigned_mechanic_id,
  mech.first_name as mechanic_first,
  mech.last_name as mechanic_last,
  mech.email as mechanic_email,
  -- Shop info
  sr.shop_id,
  s.shop_name,
  -- Customer info
  cust.first_name as customer_first,
  cust.last_name as customer_last
FROM service_requests sr
LEFT JOIN user_profiles mech ON mech.id = sr.assigned_mechanic_id
LEFT JOIN shops s ON s.id = sr.shop_id
LEFT JOIN user_profiles cust ON cust.id = sr.customer_id
WHERE sr.status = 'completed'
ORDER BY sr.completed_at DESC;

-- ========================================
-- PART 3: CHECK MECHANIC JOB HISTORY
-- ========================================

SELECT 
  '=== 📜 MECHANIC JOB HISTORY ===' as section;

SELECT 
  mjh.id,
  mjh.job_title,
  mjh.job_status,
  mjh.completed_at,
  mjh.total_amount,
  mjh.mechanic_earnings,
  mjh.shop_earnings,
  mjh.platform_fee,
  -- Mechanic info
  mjh.mechanic_id,
  up.first_name as mechanic_first,
  up.last_name as mechanic_last,
  -- Shop info
  mjh.shop_id,
  s.shop_name
FROM mechanic_job_history mjh
LEFT JOIN user_profiles up ON up.id = mjh.mechanic_id
LEFT JOIN shops s ON s.id = mjh.shop_id
WHERE mjh.job_status = 'completed'
ORDER BY mjh.completed_at DESC;

-- ========================================
-- PART 4: IDENTIFY PROBLEMS
-- ========================================

SELECT 
  '=== ⚠️ PROBLEMS FOUND ===' as section;

-- Problem 1: Completed jobs without mechanic assigned
SELECT 
  'Jobs without mechanic assigned' as problem,
  COUNT(*) as count
FROM service_requests
WHERE status = 'completed'
  AND assigned_mechanic_id IS NULL;

-- Problem 2: Completed jobs without earnings
SELECT 
  'Jobs without earnings calculated' as problem,
  COUNT(*) as count
FROM service_requests
WHERE status = 'completed'
  AND final_price IS NOT NULL
  AND final_price > 0
  AND (mechanic_earnings IS NULL OR mechanic_earnings = 0);

-- Problem 3: Mechanics with null names
SELECT 
  'Mechanics with NULL first_name or last_name' as problem,
  COUNT(*) as count
FROM user_profiles
WHERE user_type = 'mechanic'
  AND (first_name IS NULL OR last_name IS NULL OR first_name = 'null' OR last_name = 'null');

-- ========================================
-- PART 5: FIX EARNINGS
-- ========================================

SELECT 
  '=== 💰 FIXING EARNINGS NOW ===' as section;

-- Update service_requests earnings
UPDATE service_requests 
SET 
    mechanic_earnings = ROUND(COALESCE(final_price, 0) * 0.75, 2),
    shop_earnings = ROUND(COALESCE(final_price, 0) * 0.20, 2),
    platform_fee = ROUND(COALESCE(final_price, 0) * 0.05, 2),
    fee_breakdown_calculated = TRUE,
    updated_at = NOW()
WHERE status = 'completed'
  AND final_price IS NOT NULL 
  AND final_price > 0 
  AND (shop_earnings IS NULL OR shop_earnings = 0 OR mechanic_earnings IS NULL OR mechanic_earnings = 0)
RETURNING 
  id,
  final_price,
  mechanic_earnings,
  shop_earnings,
  platform_fee;

-- Update mechanic_job_history earnings
UPDATE mechanic_job_history 
SET 
    mechanic_earnings = ROUND(COALESCE(total_amount, 0) * 0.75, 2),
    shop_earnings = ROUND(COALESCE(total_amount, 0) * 0.20, 2),
    platform_fee = ROUND(COALESCE(total_amount, 0) * 0.05, 2),
    fee_percentage_mechanic = 75.00,
    fee_percentage_shop = 20.00,
    fee_percentage_platform = 5.00,
    updated_at = NOW()
WHERE job_status = 'completed'
  AND total_amount IS NOT NULL 
  AND total_amount > 0 
  AND (mechanic_earnings IS NULL OR mechanic_earnings = 0 OR shop_earnings IS NULL OR shop_earnings = 0)
RETURNING 
  id,
  total_amount,
  mechanic_earnings,
  shop_earnings,
  platform_fee;

-- ========================================
-- PART 6: VERIFY FIXES
-- ========================================

SELECT 
  '=== ✅ VERIFICATION AFTER FIX ===' as section;

-- Summary of fixed jobs
SELECT 
  COUNT(*) as total_completed_jobs,
  COUNT(CASE WHEN shop_earnings > 0 THEN 1 END) as jobs_with_shop_earnings,
  COUNT(CASE WHEN mechanic_earnings > 0 THEN 1 END) as jobs_with_mechanic_earnings,
  COUNT(CASE WHEN assigned_mechanic_id IS NOT NULL THEN 1 END) as jobs_with_mechanic_assigned,
  SUM(final_price) as total_revenue,
  SUM(shop_earnings) as total_shop_earnings,
  SUM(mechanic_earnings) as total_mechanic_earnings,
  SUM(platform_fee) as total_platform_fees
FROM service_requests
WHERE status = 'completed';

-- ========================================
-- PART 7: INSTRUCTIONS FOR NULL MECHANICS
-- ========================================

DO $$
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ EARNINGS FIXED!';
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
    RAISE NOTICE '⚠️ IF YOU SEE "null null" FOR MECHANIC NAMES:';
    RAISE NOTICE '';
    RAISE NOTICE '1. Your completed jobs may not have assigned_mechanic_id';
    RAISE NOTICE '2. Check the results above in COMPLETED JOBS DATA section';
    RAISE NOTICE '3. If mechanic_first and mechanic_last are NULL, you need to:';
    RAISE NOTICE '   - Assign a mechanic to those jobs, OR';
    RAISE NOTICE '   - Create mechanic profiles with proper first_name/last_name';
    RAISE NOTICE '';
    RAISE NOTICE '📋 NEXT STEPS:';
    RAISE NOTICE '1. Look at the output above';
    RAISE NOTICE '2. Copy the mechanic_id values that show NULL names';
    RAISE NOTICE '3. Tell me the IDs so I can fix them';
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
END $$;
