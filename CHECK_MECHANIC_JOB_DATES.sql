-- Check all date/time data for mechanic job history
-- Current date: October 6, 2025

-- Mechanic ID
-- da0aade5-1e11-4901-898c-3fd67379262f

-- 1. Check mechanic_job_history dates
SELECT 
  id,
  job_title,
  job_status,
  created_at,
  completed_at,
  cancelled_at,
  updated_at,
  -- Convert to local timezone (Asia/Manila = UTC+8)
  created_at AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Manila' as created_at_local,
  completed_at AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Manila' as completed_at_local,
  -- Check if dates are today
  DATE(created_at AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Manila') = CURRENT_DATE as is_today,
  -- Show age
  AGE(NOW(), created_at) as age_of_record
FROM mechanic_job_history
WHERE mechanic_id = 'da0aade5-1e11-4901-898c-3fd67379262f'
ORDER BY created_at DESC
LIMIT 20;

-- 2. Check service_requests dates for this mechanic
SELECT 
  id,
  title,
  status,
  created_at,
  completed_at,
  -- Convert to local timezone
  created_at AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Manila' as created_at_local,
  completed_at AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Manila' as completed_at_local,
  -- Check if dates are today
  DATE(created_at AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Manila') = CURRENT_DATE as is_today
FROM service_requests
WHERE assigned_mechanic_id = 'da0aade5-1e11-4901-898c-3fd67379262f'
ORDER BY created_at DESC
LIMIT 20;

-- 3. Check invoices dates
SELECT 
  id,
  invoice_number,
  status,
  created_at,
  paid_at,
  -- Convert to local timezone
  created_at AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Manila' as created_at_local,
  paid_at AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Manila' as paid_at_local,
  total_amount
FROM invoices
WHERE mechanic_id = 'da0aade5-1e11-4901-898c-3fd67379262f'
ORDER BY created_at DESC
LIMIT 20;

-- 4. Check what timezone database is using
SELECT current_setting('TIMEZONE') as database_timezone;

-- 5. Check current database time vs local time
SELECT 
  NOW() as utc_now,
  NOW() AT TIME ZONE 'Asia/Manila' as manila_now,
  CURRENT_DATE as date_today,
  CURRENT_TIMESTAMP as timestamp_now;

-- 6. Get today's jobs specifically (for dashboard "completed today")
SELECT 
  COUNT(*) as jobs_completed_today,
  SUM(CASE WHEN completed_at IS NOT NULL THEN 1 ELSE 0 END) as with_completion_date
FROM mechanic_job_history
WHERE mechanic_id = 'da0aade5-1e11-4901-898c-3fd67379262f'
  AND job_status = 'completed'
  AND DATE(completed_at AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Manila') = CURRENT_DATE;

-- 7. Check if there are any jobs with wrong dates (future dates)
SELECT 
  id,
  job_title,
  created_at,
  completed_at,
  created_at > NOW() as is_future_created,
  completed_at > NOW() as is_future_completed
FROM mechanic_job_history
WHERE mechanic_id = 'da0aade5-1e11-4901-898c-3fd67379262f'
  AND (created_at > NOW() OR completed_at > NOW());

-- 8. Compare mechanic_job_history with service_requests dates
SELECT 
  mjh.id as history_id,
  mjh.job_title,
  mjh.created_at as history_created,
  sr.created_at as request_created,
  mjh.completed_at as history_completed,
  sr.completed_at as request_completed,
  -- Show differences
  mjh.created_at - sr.created_at as created_diff,
  mjh.completed_at - sr.completed_at as completed_diff
FROM mechanic_job_history mjh
LEFT JOIN service_requests sr ON mjh.service_request_id = sr.id
WHERE mjh.mechanic_id = 'da0aade5-1e11-4901-898c-3fd67379262f'
ORDER BY mjh.created_at DESC
LIMIT 10;
