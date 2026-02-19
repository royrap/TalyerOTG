-- ========================================
-- 🚨 FIX EARNINGS FOR YOUR COMPLETED JOB
-- ========================================
-- You have 1 completed job with ₱220.00 revenue
-- but earnings are not calculated (0 jobs with earnings data)
-- This will calculate: 75% Mechanic | 20% Shop | 5% Platform
-- ========================================

BEGIN;

-- ========================================
-- STEP 1: UPDATE service_requests
-- ========================================
-- Calculate earnings for completed jobs

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
  AND (shop_earnings IS NULL OR shop_earnings = 0 OR mechanic_earnings IS NULL OR mechanic_earnings = 0);

-- ========================================
-- STEP 2: UPDATE mechanic_job_history
-- ========================================
-- Calculate earnings for job history

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
  AND (mechanic_earnings IS NULL OR mechanic_earnings = 0 OR shop_earnings IS NULL OR shop_earnings = 0);

-- ========================================
-- VERIFY THE FIX
-- ========================================

-- Check service_requests
SELECT 
  '=== SERVICE REQUESTS - AFTER FIX ===' as section;

SELECT 
  id,
  status,
  final_price,
  shop_earnings,
  mechanic_earnings,
  platform_fee,
  -- Verify percentages
  ROUND((shop_earnings / final_price * 100)::numeric, 2) as shop_pct,
  ROUND((mechanic_earnings / final_price * 100)::numeric, 2) as mechanic_pct,
  ROUND((platform_fee / final_price * 100)::numeric, 2) as platform_pct,
  -- Verify total
  ROUND((shop_earnings + mechanic_earnings + platform_fee)::numeric, 2) as total_check,
  CASE 
    WHEN ABS((shop_earnings + mechanic_earnings + platform_fee) - final_price) < 0.01 
    THEN '✅ Correct'
    ELSE '❌ Mismatch'
  END as validation
FROM service_requests
WHERE status = 'completed'
  AND final_price > 0
ORDER BY completed_at DESC;

-- Summary
SELECT 
  '=== SUMMARY ===' as section;

SELECT 
  COUNT(*) as total_completed_jobs,
  COUNT(CASE WHEN shop_earnings > 0 AND mechanic_earnings > 0 THEN 1 END) as jobs_with_earnings,
  SUM(final_price) as total_revenue,
  SUM(shop_earnings) as total_shop_earnings,
  SUM(mechanic_earnings) as total_mechanic_earnings,
  SUM(platform_fee) as total_platform_fees
FROM service_requests
WHERE status = 'completed';

-- Expected for your ₱220.00 job:
SELECT 
  '=== EXPECTED BREAKDOWN FOR ₱220.00 ===' as section;

SELECT 
  220.00 as original_amount,
  ROUND(220.00 * 0.75, 2) as mechanic_should_be,  -- ₱165.00
  ROUND(220.00 * 0.20, 2) as shop_should_be,      -- ₱44.00
  ROUND(220.00 * 0.05, 2) as platform_should_be;  -- ₱11.00

COMMIT;

-- ========================================
-- SUCCESS MESSAGE
-- ========================================
DO $$
BEGIN
    RAISE NOTICE '✅ SUCCESS! Earnings calculated!';
    RAISE NOTICE '📊 For ₱220.00: Mechanic=₱165.00 | Shop=₱44.00 | Platform=₱11.00';
    RAISE NOTICE '🎉 Dashboard should now show data!';
END $$;
