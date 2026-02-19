-- ========================================
-- 🔍 DIAGNOSE MECHANIC JOB HISTORY ISSUE
-- ========================================

-- 1. Check if mechanic_job_history table has any data
SELECT COUNT(*) as total_job_history_records
FROM mechanic_job_history;

-- 2. Check for specific mechanic (replace with your mechanic ID)
SELECT COUNT(*) as jobs_for_mechanic
FROM mechanic_job_history
WHERE mechanic_id = 'da0aade5-1e11-4901-898c-3fd67379262f';  -- Your mechanic ID

-- 3. Check all service_requests for this mechanic
SELECT 
    id,
    status,
    created_at,
    customer_id,
    assigned_mechanic_id
FROM service_requests
WHERE assigned_mechanic_id = 'da0aade5-1e11-4901-898c-3fd67379262f'
ORDER BY created_at DESC
LIMIT 10;

-- 4. Test the RPC function directly
SELECT * FROM get_mechanic_job_history();

-- 5. Check if service_requests should have job_history entries
SELECT 
    sr.id as request_id,
    sr.status,
    sr.created_at,
    sr.completed_at,
    EXISTS(
        SELECT 1 FROM mechanic_job_history mjh 
        WHERE mjh.service_request_id = sr.id
    ) as has_job_history
FROM service_requests sr
WHERE sr.assigned_mechanic_id = 'da0aade5-1e11-4901-898c-3fd67379262f'
ORDER BY sr.created_at DESC
LIMIT 10;

DO $$
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE '📊 MECHANIC JOB HISTORY DIAGNOSTIC';
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
    RAISE NOTICE 'Check the results above to see:';
    RAISE NOTICE '1. Total records in mechanic_job_history table';
    RAISE NOTICE '2. Records for your specific mechanic';
    RAISE NOTICE '3. Service requests assigned to mechanic';
    RAISE NOTICE '4. Results from RPC function';
    RAISE NOTICE '5. Which service_requests have job_history entries';
    RAISE NOTICE '';
    RAISE NOTICE 'If mechanic_job_history is empty, we need to populate it!';
END $$;
