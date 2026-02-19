-- ========================================
-- SHOP OWNER DASHBOARD DATA VERIFICATION
-- ========================================
-- Run these queries in Supabase SQL Editor to verify your data

-- ========================================
-- 1. CHECK SERVICE_REQUESTS TABLE
-- ========================================
-- Verify completed jobs have earnings data populated

SELECT 
  '=== SERVICE REQUESTS - COMPLETED JOBS ===' as section;

SELECT 
  sr.id,
  sr.shop_id,
  sr.status,
  sr.final_price,
  sr.shop_earnings,
  sr.mechanic_earnings,
  sr.platform_fee,
  sr.completed_at,
  sr.created_at,
  -- Verify percentages
  CASE 
    WHEN sr.final_price > 0 THEN 
      ROUND((sr.shop_earnings / sr.final_price * 100)::numeric, 2)
    ELSE 0 
  END as shop_percentage_actual,
  CASE 
    WHEN sr.final_price > 0 THEN 
      ROUND((sr.mechanic_earnings / sr.final_price * 100)::numeric, 2)
    ELSE 0 
  END as mechanic_percentage_actual,
  CASE 
    WHEN sr.final_price > 0 THEN 
      ROUND((sr.platform_fee / sr.final_price * 100)::numeric, 2)
    ELSE 0 
  END as platform_percentage_actual
FROM service_requests sr
WHERE sr.status = 'completed'
  AND sr.shop_id IS NOT NULL
ORDER BY sr.completed_at DESC
LIMIT 10;

-- ========================================
-- 2. COUNT COMPLETED JOBS WITH EARNINGS
-- ========================================

SELECT 
  '=== COMPLETED JOBS COUNT ===' as section;

SELECT 
  COUNT(*) as total_completed_jobs,
  COUNT(CASE WHEN final_price > 0 THEN 1 END) as jobs_with_final_price,
  COUNT(CASE WHEN shop_earnings > 0 THEN 1 END) as jobs_with_shop_earnings,
  COUNT(CASE WHEN mechanic_earnings > 0 THEN 1 END) as jobs_with_mechanic_earnings,
  COUNT(CASE WHEN platform_fee > 0 THEN 1 END) as jobs_with_platform_fee,
  COUNT(CASE WHEN final_price IS NULL OR final_price = 0 THEN 1 END) as jobs_missing_earnings
FROM service_requests
WHERE status = 'completed'
  AND shop_id IS NOT NULL;

-- ========================================
-- 3. TOTAL EARNINGS SUMMARY (ALL TIME)
-- ========================================

SELECT 
  '=== TOTAL EARNINGS - ALL TIME ===' as section;

SELECT 
  COUNT(*) as total_completed_jobs,
  SUM(final_price) as total_revenue,
  SUM(shop_earnings) as total_shop_earnings,
  SUM(mechanic_earnings) as total_mechanic_earnings,
  SUM(platform_fee) as total_platform_fees,
  ROUND(AVG(final_price)::numeric, 2) as average_job_value
FROM service_requests
WHERE status = 'completed'
  AND shop_id IS NOT NULL;

-- ========================================
-- 4. EARNINGS BY SHOP (Top 5 Shops)
-- ========================================

SELECT 
  '=== EARNINGS BY SHOP (TOP 5) ===' as section;

SELECT 
  s.id as shop_id,
  s.shop_name,
  COUNT(sr.id) as completed_jobs,
  SUM(sr.final_price) as total_revenue,
  SUM(sr.shop_earnings) as shop_earnings,
  SUM(sr.mechanic_earnings) as mechanic_earnings,
  SUM(sr.platform_fee) as platform_fees
FROM shops s
LEFT JOIN service_requests sr ON sr.shop_id = s.id AND sr.status = 'completed'
WHERE s.is_active = true
GROUP BY s.id, s.shop_name
ORDER BY total_revenue DESC NULLS LAST
LIMIT 5;

-- ========================================
-- 5. CHECK MECHANIC_JOB_HISTORY TABLE
-- ========================================

SELECT 
  '=== MECHANIC JOB HISTORY - COMPLETED JOBS ===' as section;

SELECT 
  mjh.id,
  mjh.mechanic_id,
  mjh.shop_id,
  mjh.job_status,
  mjh.total_amount,
  mjh.mechanic_earnings,
  mjh.shop_earnings,
  mjh.platform_fee,
  mjh.rating,
  mjh.completed_at,
  -- Verify percentages
  mjh.fee_percentage_mechanic,
  mjh.fee_percentage_shop,
  mjh.fee_percentage_platform
FROM mechanic_job_history mjh
WHERE mjh.job_status = 'completed'
ORDER BY mjh.completed_at DESC
LIMIT 10;

-- ========================================
-- 6. MECHANIC PERFORMANCE SUMMARY
-- ========================================

SELECT 
  '=== MECHANIC PERFORMANCE SUMMARY ===' as section;

SELECT 
  up.id as mechanic_id,
  up.first_name || ' ' || up.last_name as mechanic_name,
  COUNT(mjh.id) as total_jobs,
  COUNT(CASE WHEN mjh.job_status = 'completed' THEN 1 END) as completed_jobs,
  SUM(mjh.mechanic_earnings) as total_mechanic_earnings,
  SUM(mjh.shop_earnings) as total_shop_earnings,
  ROUND(AVG(mjh.rating)::numeric, 2) as average_rating,
  ROUND((COUNT(CASE WHEN mjh.job_status = 'completed' THEN 1 END)::numeric / 
    NULLIF(COUNT(mjh.id), 0) * 100), 2) as completion_rate_percent
FROM user_profiles up
INNER JOIN mechanic_job_history mjh ON mjh.mechanic_id = up.id
WHERE up.user_type = 'mechanic'
GROUP BY up.id, up.first_name, up.last_name
ORDER BY total_mechanic_earnings DESC
LIMIT 10;

-- ========================================
-- 7. TODAY'S STATS (Replace date as needed)
-- ========================================

SELECT 
  '=== TODAY STATS (Change date to current) ===' as section;

SELECT 
  COUNT(*) as total_jobs_today,
  COUNT(CASE WHEN status = 'completed' THEN 1 END) as completed_today,
  COUNT(CASE WHEN status IN ('accepted', 'in_progress', 'assigned', 'inspection_started') THEN 1 END) as active_today,
  SUM(CASE WHEN status = 'completed' THEN final_price ELSE 0 END) as revenue_today,
  SUM(CASE WHEN status = 'completed' THEN shop_earnings ELSE 0 END) as shop_earnings_today,
  SUM(CASE WHEN status = 'completed' THEN mechanic_earnings ELSE 0 END) as mechanic_earnings_today,
  SUM(CASE WHEN status = 'completed' THEN platform_fee ELSE 0 END) as platform_fees_today
FROM service_requests
WHERE shop_id IS NOT NULL
  AND DATE(created_at) = CURRENT_DATE;  -- Change to specific date if needed

-- ========================================
-- 8. THIS WEEK'S STATS
-- ========================================

SELECT 
  '=== THIS WEEK STATS ===' as section;

SELECT 
  COUNT(*) as total_jobs_week,
  COUNT(CASE WHEN status = 'completed' THEN 1 END) as completed_week,
  SUM(CASE WHEN status = 'completed' THEN final_price ELSE 0 END) as revenue_week,
  SUM(CASE WHEN status = 'completed' THEN shop_earnings ELSE 0 END) as shop_earnings_week,
  SUM(CASE WHEN status = 'completed' THEN mechanic_earnings ELSE 0 END) as mechanic_earnings_week
FROM service_requests
WHERE shop_id IS NOT NULL
  AND created_at >= DATE_TRUNC('week', CURRENT_DATE);

-- ========================================
-- 9. CHECK FOR MISSING/NULL EARNINGS
-- ========================================

SELECT 
  '=== JOBS WITH MISSING EARNINGS DATA ===' as section;

SELECT 
  sr.id,
  sr.shop_id,
  sr.status,
  sr.final_price,
  sr.shop_earnings,
  sr.mechanic_earnings,
  sr.platform_fee,
  sr.completed_at,
  CASE 
    WHEN sr.final_price IS NULL OR sr.final_price = 0 THEN 'Missing final_price'
    WHEN sr.shop_earnings IS NULL OR sr.shop_earnings = 0 THEN 'Missing shop_earnings'
    WHEN sr.mechanic_earnings IS NULL OR sr.mechanic_earnings = 0 THEN 'Missing mechanic_earnings'
    WHEN sr.platform_fee IS NULL OR sr.platform_fee = 0 THEN 'Missing platform_fee'
    ELSE 'Unknown issue'
  END as issue
FROM service_requests sr
WHERE sr.status = 'completed'
  AND sr.shop_id IS NOT NULL
  AND (
    sr.final_price IS NULL OR sr.final_price = 0 OR
    sr.shop_earnings IS NULL OR sr.shop_earnings = 0 OR
    sr.mechanic_earnings IS NULL OR sr.mechanic_earnings = 0 OR
    sr.platform_fee IS NULL OR sr.platform_fee = 0
  )
ORDER BY sr.completed_at DESC
LIMIT 20;

-- ========================================
-- 10. CHECK INVOICES TABLE
-- ========================================

SELECT 
  '=== INVOICES - PAID STATUS ===' as section;

SELECT 
  inv.id,
  inv.invoice_number,
  inv.request_id,
  inv.status,
  inv.subtotal,
  inv.platform_fee,
  inv.total_amount,
  inv.talyer_net_amount,
  inv.provider_net_amount,
  inv.paid_at,
  inv.completed_at
FROM invoices inv
WHERE inv.status IN ('paid', 'completed')
ORDER BY inv.paid_at DESC
LIMIT 10;

-- ========================================
-- 11. VERIFY FEE BREAKDOWN CALCULATION
-- ========================================

SELECT 
  '=== FEE BREAKDOWN VERIFICATION ===' as section;

SELECT 
  sr.id,
  sr.final_price,
  sr.shop_earnings,
  sr.mechanic_earnings,
  sr.platform_fee,
  -- Expected values based on percentages
  ROUND((sr.final_price * 0.20)::numeric, 2) as expected_shop_earnings,
  ROUND((sr.final_price * 0.75)::numeric, 2) as expected_mechanic_earnings,
  ROUND((sr.final_price * 0.05)::numeric, 2) as expected_platform_fee,
  -- Check if actual matches expected
  CASE 
    WHEN ABS(sr.shop_earnings - (sr.final_price * 0.20)) < 0.01 THEN '✅ Match'
    ELSE '❌ Mismatch'
  END as shop_earnings_check,
  CASE 
    WHEN ABS(sr.mechanic_earnings - (sr.final_price * 0.75)) < 0.01 THEN '✅ Match'
    ELSE '❌ Mismatch'
  END as mechanic_earnings_check,
  CASE 
    WHEN ABS(sr.platform_fee - (sr.final_price * 0.05)) < 0.01 THEN '✅ Match'
    ELSE '❌ Mismatch'
  END as platform_fee_check
FROM service_requests sr
WHERE sr.status = 'completed'
  AND sr.shop_id IS NOT NULL
  AND sr.final_price > 0
ORDER BY sr.completed_at DESC
LIMIT 10;

-- ========================================
-- 12. ONGOING SERVICES CHECK
-- ========================================

SELECT 
  '=== ONGOING SERVICES ===' as section;

SELECT 
  sr.id,
  sr.shop_id,
  sr.title,
  sr.status,
  sr.created_at,
  sr.assigned_mechanic_id,
  up.first_name || ' ' || up.last_name as customer_name
FROM service_requests sr
LEFT JOIN user_profiles up ON up.id = sr.customer_id
WHERE sr.shop_id IS NOT NULL
  AND sr.status IN ('pending', 'accepted', 'in_progress', 'assigned', 'inspection_started')
ORDER BY sr.created_at DESC
LIMIT 10;

-- ========================================
-- SUMMARY
-- ========================================

SELECT 
  '=== VERIFICATION SUMMARY ===' as section;

SELECT 
  'Total Shops' as metric,
  COUNT(*) as value
FROM shops
WHERE is_active = true

UNION ALL

SELECT 
  'Total Mechanics',
  COUNT(*)
FROM user_profiles
WHERE user_type = 'mechanic'
  AND status = 'active'

UNION ALL

SELECT 
  'Completed Jobs (All Time)',
  COUNT(*)
FROM service_requests
WHERE status = 'completed'

UNION ALL

SELECT 
  'Jobs with Earnings Data',
  COUNT(*)
FROM service_requests
WHERE status = 'completed'
  AND shop_earnings > 0
  AND mechanic_earnings > 0

UNION ALL

SELECT 
  'Total Revenue (All Time)',
  COALESCE(SUM(final_price), 0)
FROM service_requests
WHERE status = 'completed';
