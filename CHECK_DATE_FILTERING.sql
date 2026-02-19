-- ========================================
-- 🔍 CHECK DATE FILTERING ISSUE
-- ========================================
-- Dashboard shows ₱0.00 because it's filtering by TODAY
-- but jobs were completed YESTERDAY or earlier
-- ========================================

SELECT 
  '=== 📅 TODAY''S DATE AND TIMEZONE ===' as section;

SELECT 
  NOW() as current_timestamp,
  CURRENT_DATE as today_date,
  CURRENT_DATE::timestamp as today_start,
  (CURRENT_DATE + INTERVAL '1 day')::timestamp as tomorrow_start;

SELECT 
  '=== 📊 ALL COMPLETED JOBS WITH DATES ===' as section;

-- Show all completed jobs with their dates
SELECT 
  sr.id,
  sr.title,
  sr.status,
  sr.final_price,
  sr.mechanic_earnings,
  sr.shop_earnings,
  sr.platform_fee,
  sr.completed_at,
  sr.completed_at::date as completed_date,
  CURRENT_DATE as today,
  CASE 
    WHEN sr.completed_at::date = CURRENT_DATE THEN '✅ TODAY'
    WHEN sr.completed_at::date = CURRENT_DATE - INTERVAL '1 day' THEN '⚠️ YESTERDAY'
    ELSE '❌ OLDER'
  END as date_check,
  -- Mechanic info
  sr.assigned_mechanic_id,
  mech.first_name,
  mech.last_name
FROM service_requests sr
LEFT JOIN user_profiles mech ON mech.id = sr.assigned_mechanic_id
WHERE sr.status = 'completed'
ORDER BY sr.completed_at DESC;

SELECT 
  '=== 📊 MECHANIC JOB HISTORY DATES ===' as section;

-- Check mechanic_job_history dates
SELECT 
  mjh.id,
  mjh.job_title,
  mjh.job_status,
  mjh.total_amount,
  mjh.mechanic_earnings,
  mjh.completed_at,
  mjh.completed_at::date as completed_date,
  CURRENT_DATE as today,
  CASE 
    WHEN mjh.completed_at::date = CURRENT_DATE THEN '✅ TODAY'
    WHEN mjh.completed_at::date = CURRENT_DATE - INTERVAL '1 day' THEN '⚠️ YESTERDAY'
    ELSE '❌ OLDER'
  END as date_check,
  -- Mechanic
  mjh.mechanic_id,
  up.first_name,
  up.last_name
FROM mechanic_job_history mjh
LEFT JOIN user_profiles up ON up.id = mjh.mechanic_id
WHERE mjh.job_status = 'completed'
ORDER BY mjh.completed_at DESC;

SELECT 
  '=== 📈 EARNINGS BY DATE ===' as section;

-- Show earnings breakdown by date
SELECT 
  sr.completed_at::date as date,
  COUNT(*) as jobs_count,
  SUM(sr.final_price) as total_revenue,
  SUM(sr.mechanic_earnings) as total_mechanic_earnings,
  SUM(sr.shop_earnings) as total_shop_earnings,
  SUM(sr.platform_fee) as total_platform_fees
FROM service_requests sr
WHERE sr.status = 'completed'
  AND sr.completed_at IS NOT NULL
GROUP BY sr.completed_at::date
ORDER BY sr.completed_at::date DESC;

-- ========================================
-- SUMMARY
-- ========================================
DO $$
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE '🔍 DATE FILTERING CHECK COMPLETE';
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
    RAISE NOTICE 'Check the "date_check" column above:';
    RAISE NOTICE '  ✅ TODAY - Job completed today';
    RAISE NOTICE '  ⚠️ YESTERDAY - Job completed yesterday';
    RAISE NOTICE '  ❌ OLDER - Job completed earlier';
    RAISE NOTICE '';
    RAISE NOTICE 'If all jobs show YESTERDAY or OLDER:';
    RAISE NOTICE '  → Dashboard filtered by TODAY will show ₱0.00';
    RAISE NOTICE '  → Switch to WEEK or MONTH view to see data!';
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
END $$;
