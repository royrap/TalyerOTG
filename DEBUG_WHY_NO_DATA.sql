-- ========================================
-- 🔍 EXACT DEBUG - WHY NO DATA SHOWING
-- ========================================
-- Let's check EXACTLY what data exists and what queries should return
-- ========================================

SELECT 
  '=== 🕐 CURRENT TIME AND DATE INFO ===' as section;

SELECT 
  NOW() as database_current_time_utc,
  CURRENT_DATE as database_current_date,
  NOW()::date as today_in_utc,
  NOW() AT TIME ZONE 'Asia/Manila' as manila_time,
  (NOW() AT TIME ZONE 'Asia/Manila')::date as manila_date;

SELECT 
  '=== 📊 ALL COMPLETED JOBS ===' as section;

-- Show ALL completed jobs regardless of date
SELECT 
  sr.id,
  sr.title,
  sr.status,
  sr.final_price,
  sr.shop_earnings,
  sr.mechanic_earnings,
  sr.platform_fee,
  sr.completed_at as completed_at_utc,
  sr.completed_at AT TIME ZONE 'Asia/Manila' as completed_at_manila,
  sr.completed_at::date as completed_date_utc,
  (sr.completed_at AT TIME ZONE 'Asia/Manila')::date as completed_date_manila,
  sr.shop_id,
  sr.assigned_mechanic_id,
  -- Mechanic info
  up.first_name,
  up.last_name,
  up.email
FROM service_requests sr
LEFT JOIN user_profiles up ON up.id = sr.assigned_mechanic_id
WHERE sr.status = 'completed'
ORDER BY sr.completed_at DESC;

SELECT 
  '=== 📊 ALL MECHANIC JOB HISTORY ===' as section;

-- Show ALL from mechanic_job_history
SELECT 
  mjh.id,
  mjh.job_title,
  mjh.job_status,
  mjh.total_amount,
  mjh.mechanic_earnings,
  mjh.shop_earnings,
  mjh.platform_fee,
  mjh.completed_at as completed_at_utc,
  mjh.completed_at AT TIME ZONE 'Asia/Manila' as completed_at_manila,
  mjh.completed_at::date as completed_date_utc,
  (mjh.completed_at AT TIME ZONE 'Asia/Manila')::date as completed_date_manila,
  mjh.mechanic_id,
  mjh.shop_id,
  -- Mechanic
  up.first_name,
  up.last_name,
  -- Shop
  s.shop_name
FROM mechanic_job_history mjh
LEFT JOIN user_profiles up ON up.id = mjh.mechanic_id
LEFT JOIN shops s ON s.id = mjh.shop_id
WHERE mjh.job_status = 'completed'
ORDER BY mjh.completed_at DESC;

SELECT 
  '=== 🏪 YOUR SHOP INFO ===' as section;

-- Get your shop details
SELECT 
  s.id as shop_id,
  s.shop_name,
  s.owner_id,
  up.first_name as owner_first_name,
  up.last_name as owner_last_name,
  up.email as owner_email
FROM shops s
INNER JOIN user_profiles up ON up.id = s.owner_id
WHERE up.user_type = 'talyer_owner';

SELECT 
  '=== 🔧 MECHANICS IN SHOP ===' as section;

-- Get all mechanics in shop
SELECT 
  sm.shop_id,
  sm.mechanic_id,
  sm.is_active,
  sm.is_available,
  up.first_name,
  up.last_name,
  up.email,
  s.shop_name
FROM shop_mechanics sm
INNER JOIN user_profiles up ON up.id = sm.mechanic_id
INNER JOIN shops s ON s.id = sm.shop_id
WHERE sm.is_active = true;

SELECT 
  '=== ⚠️ POTENTIAL ISSUES ===' as section;

-- Check if jobs have shop_id matching your shop
SELECT 
  'Jobs without shop_id' as issue,
  COUNT(*) as count
FROM service_requests
WHERE status = 'completed' AND shop_id IS NULL;

-- Check if jobs have wrong shop_id
SELECT 
  'Jobs with shop_id not matching any shop' as issue,
  COUNT(*) as count
FROM service_requests sr
LEFT JOIN shops s ON s.id = sr.shop_id
WHERE sr.status = 'completed' AND sr.shop_id IS NOT NULL AND s.id IS NULL;

-- Check if mechanic_job_history has shop_id
SELECT 
  'Job history without shop_id' as issue,
  COUNT(*) as count
FROM mechanic_job_history
WHERE job_status = 'completed' AND shop_id IS NULL;

SELECT 
  '=== 🔍 SIMULATE FLUTTER QUERY ===' as section;

-- Simulate what Flutter queries for "today" in UTC
WITH today_utc AS (
  SELECT 
    DATE_TRUNC('day', NOW()) as start_of_today_utc
)
SELECT 
  'Simulated Flutter Query - TODAY in UTC' as query_type,
  (SELECT start_of_today_utc FROM today_utc) as filter_start_date;

-- Jobs that match today UTC
SELECT 
  sr.id,
  sr.title,
  sr.final_price,
  sr.completed_at,
  CASE 
    WHEN sr.completed_at >= DATE_TRUNC('day', NOW()) THEN '✅ MATCHES TODAY UTC'
    ELSE '❌ BEFORE TODAY UTC'
  END as matches_today_filter
FROM service_requests sr
WHERE sr.status = 'completed'
ORDER BY sr.completed_at DESC;

-- Jobs that match today MANILA TIME
WITH today_manila AS (
  SELECT 
    DATE_TRUNC('day', NOW() AT TIME ZONE 'Asia/Manila') as start_of_today_manila
)
SELECT 
  sr.id,
  sr.title,
  sr.final_price,
  sr.completed_at AT TIME ZONE 'Asia/Manila' as completed_at_manila,
  CASE 
    WHEN sr.completed_at AT TIME ZONE 'Asia/Manila' >= (SELECT start_of_today_manila FROM today_manila) THEN '✅ MATCHES TODAY MANILA'
    ELSE '❌ BEFORE TODAY MANILA'
  END as matches_manila_filter
FROM service_requests sr
WHERE sr.status = 'completed'
ORDER BY sr.completed_at DESC;

-- ========================================
-- SUMMARY
-- ========================================
DO $$
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE '🔍 DEBUG COMPLETE - CHECK RESULTS ABOVE';
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
    RAISE NOTICE 'Look for:';
    RAISE NOTICE '1. Check completed_date_utc vs completed_date_manila';
    RAISE NOTICE '2. Check if shop_id matches your shop';
    RAISE NOTICE '3. Check "matches_today_filter" column';
    RAISE NOTICE '4. Verify mechanic names are present';
    RAISE NOTICE '';
    RAISE NOTICE 'Copy ALL results and send to me!';
    RAISE NOTICE '========================================';
END $$;
