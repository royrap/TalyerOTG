-- Comprehensive Date/Time Verification for Mechanic Data
-- Run this in Supabase SQL Editor to verify all dates are correct

-- Current mechanic ID
-- da0aade5-1e11-4901-898c-3fd67379262f

-- ==============================================
-- 1. CHECK DATABASE TIMEZONE SETTINGS
-- ==============================================
SELECT 
  current_setting('TIMEZONE') as database_timezone,
  NOW() as utc_now,
  NOW() AT TIME ZONE 'Asia/Manila' as manila_now,
  CURRENT_DATE as date_today_utc,
  (NOW() AT TIME ZONE 'Asia/Manila')::date as date_today_manila;

-- ==============================================
-- 2. CHECK TODAY'S JOBS (Should match app)
-- ==============================================
SELECT 
  'TODAY''S COMPLETED JOBS' as check_name,
  COUNT(*) as count,
  STRING_AGG(job_title, ', ') as job_titles
FROM mechanic_job_history
WHERE mechanic_id = 'da0aade5-1e11-4901-898c-3fd67379262f'
  AND job_status = 'completed'
  AND DATE(completed_at AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Manila') = 
      (NOW() AT TIME ZONE 'Asia/Manila')::date;

-- ==============================================
-- 3. CHECK TODAY'S EARNINGS (Should match app)
-- ==============================================
SELECT 
  'TODAY''S PAID INVOICES' as check_name,
  COUNT(*) as invoice_count,
  SUM(total_amount) as total_earnings
FROM invoices
WHERE mechanic_id = 'da0aade5-1e11-4901-898c-3fd67379262f'
  AND status = 'paid'
  AND DATE(paid_at AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Manila') = 
      (NOW() AT TIME ZONE 'Asia/Manila')::date;

-- ==============================================
-- 4. VIEW ALL MECHANIC JOBS WITH PROPER DATES
-- ==============================================
SELECT 
  id,
  job_title,
  job_status,
  -- UTC timestamps (as stored)
  created_at as created_utc,
  completed_at as completed_utc,
  -- Manila timestamps (converted)
  created_at AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Manila' as created_manila,
  completed_at AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Manila' as completed_manila,
  -- Date classification
  CASE 
    WHEN DATE(completed_at AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Manila') = 
         (NOW() AT TIME ZONE 'Asia/Manila')::date 
    THEN 'Today'
    WHEN DATE(completed_at AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Manila') = 
         (NOW() AT TIME ZONE 'Asia/Manila')::date - 1 
    THEN 'Yesterday'
    ELSE TO_CHAR(completed_at AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Manila', 'YYYY-MM-DD')
  END as date_label,
  -- Time in 12-hour format
  TO_CHAR(completed_at AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Manila', 'HH12:MI AM') as time_manila,
  total_amount
FROM mechanic_job_history
WHERE mechanic_id = 'da0aade5-1e11-4901-898c-3fd67379262f'
ORDER BY completed_at DESC NULLS LAST, created_at DESC
LIMIT 20;

-- ==============================================
-- 5. CHECK FOR DATE INCONSISTENCIES
-- ==============================================
SELECT 
  'FUTURE DATES CHECK' as check_name,
  COUNT(*) as count_with_future_dates
FROM mechanic_job_history
WHERE mechanic_id = 'da0aade5-1e11-4901-898c-3fd67379262f'
  AND (
    created_at > NOW() 
    OR completed_at > NOW()
  );

-- ==============================================
-- 6. COMPARE WITH SERVICE REQUESTS
-- ==============================================
SELECT 
  mjh.id as history_id,
  mjh.job_title,
  mjh.job_status,
  -- History dates (Manila)
  mjh.created_at AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Manila' as history_created_manila,
  mjh.completed_at AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Manila' as history_completed_manila,
  -- Service request dates (Manila)
  sr.created_at AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Manila' as request_created_manila,
  sr.completed_at AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Manila' as request_completed_manila,
  -- Check if they match
  mjh.created_at = sr.created_at as created_match,
  mjh.completed_at = sr.completed_at as completed_match
FROM mechanic_job_history mjh
LEFT JOIN service_requests sr ON mjh.service_request_id = sr.id
WHERE mjh.mechanic_id = 'da0aade5-1e11-4901-898c-3fd67379262f'
ORDER BY mjh.created_at DESC
LIMIT 10;

-- ==============================================
-- 7. RECENT ACTIVITY SUMMARY
-- ==============================================
SELECT 
  'LAST 7 DAYS' as period,
  COUNT(*) as total_jobs,
  COUNT(CASE WHEN job_status = 'completed' THEN 1 END) as completed,
  COUNT(CASE WHEN job_status = 'cancelled' THEN 1 END) as cancelled,
  SUM(total_amount) as total_amount
FROM mechanic_job_history
WHERE mechanic_id = 'da0aade5-1e11-4901-898c-3fd67379262f'
  AND created_at >= (NOW() AT TIME ZONE 'Asia/Manila' - INTERVAL '7 days')
UNION ALL
SELECT 
  'THIS MONTH' as period,
  COUNT(*) as total_jobs,
  COUNT(CASE WHEN job_status = 'completed' THEN 1 END) as completed,
  COUNT(CASE WHEN job_status = 'cancelled' THEN 1 END) as cancelled,
  SUM(total_amount) as total_amount
FROM mechanic_job_history
WHERE mechanic_id = 'da0aade5-1e11-4901-898c-3fd67379262f'
  AND DATE_TRUNC('month', created_at AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Manila') = 
      DATE_TRUNC('month', (NOW() AT TIME ZONE 'Asia/Manila')::date);

-- ==============================================
-- 8. INVOICE DATES CHECK
-- ==============================================
SELECT 
  id,
  invoice_number,
  status,
  -- UTC timestamps
  created_at as created_utc,
  paid_at as paid_utc,
  -- Manila timestamps
  created_at AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Manila' as created_manila,
  paid_at AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Manila' as paid_manila,
  -- Date label
  CASE 
    WHEN DATE(paid_at AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Manila') = 
         (NOW() AT TIME ZONE 'Asia/Manila')::date 
    THEN 'Today'
    WHEN DATE(paid_at AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Manila') = 
         (NOW() AT TIME ZONE 'Asia/Manila')::date - 1 
    THEN 'Yesterday'
    ELSE TO_CHAR(paid_at AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Manila', 'YYYY-MM-DD')
  END as date_label,
  total_amount
FROM invoices
WHERE mechanic_id = 'da0aade5-1e11-4901-898c-3fd67379262f'
  AND status = 'paid'
ORDER BY paid_at DESC
LIMIT 10;

-- ==============================================
-- 9. DASHBOARD STATS (Should match Flutter app)
-- ==============================================
WITH today_manila AS (
  SELECT (NOW() AT TIME ZONE 'Asia/Manila')::date as today
)
SELECT 
  -- Active jobs
  (SELECT COUNT(*) 
   FROM service_requests 
   WHERE assigned_mechanic_id = 'da0aade5-1e11-4901-898c-3fd67379262f'
     AND status IN ('accepted', 'in_progress', 'provider_en_route', 'work_in_progress')
  ) as active_jobs,
  
  -- Completed today
  (SELECT COUNT(*) 
   FROM mechanic_job_history 
   WHERE mechanic_id = 'da0aade5-1e11-4901-898c-3fd67379262f'
     AND job_status = 'completed'
     AND DATE(completed_at AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Manila') = (SELECT today FROM today_manila)
  ) as completed_today,
  
  -- Earnings today
  (SELECT COALESCE(SUM(total_amount), 0)
   FROM invoices
   WHERE mechanic_id = 'da0aade5-1e11-4901-898c-3fd67379262f'
     AND status = 'paid'
     AND DATE(paid_at AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Manila') = (SELECT today FROM today_manila)
  ) as earnings_today,
  
  -- Average rating
  (SELECT COALESCE(AVG(rating), 0)
   FROM mechanic_job_history
   WHERE mechanic_id = 'da0aade5-1e11-4901-898c-3fd67379262f'
     AND rating IS NOT NULL
  ) as average_rating,
  
  -- Total completed
  (SELECT COUNT(*)
   FROM mechanic_job_history
   WHERE mechanic_id = 'da0aade5-1e11-4901-898c-3fd67379262f'
     AND job_status = 'completed'
  ) as total_completed,
  
  -- Total earnings
  (SELECT COALESCE(SUM(total_amount), 0)
   FROM invoices
   WHERE mechanic_id = 'da0aade5-1e11-4901-898c-3fd67379262f'
     AND status = 'paid'
  ) as total_earnings;

-- ==============================================
-- EXPECTED RESULTS:
-- ==============================================
-- 1. Database timezone should be UTC
-- 2. TODAY'S COMPLETED JOBS should match Flutter dashboard
-- 3. TODAY'S PAID INVOICES should match earnings amount
-- 4. All Manila timestamps should be UTC+8 hours
-- 5. Date labels should be "Today" for today's jobs
-- 6. No jobs should have future dates
-- 7. Dashboard stats should match what you see in the app
