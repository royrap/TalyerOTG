-- =====================================================
-- JOB HISTORY VALIDATION QUERIES
-- =====================================================
-- Run these queries to validate the job history system

-- 1. Check if job history tables exist
SELECT 'JOB HISTORY TABLES STATUS:' as check_type;
SELECT 
    table_name,
    CASE WHEN table_name IS NOT NULL THEN '✅ EXISTS' ELSE '❌ MISSING' END as status
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name IN ('mechanic_job_history', 'customer_job_history');

-- 2. Check job history counts
SELECT 'JOB HISTORY COUNTS:' as check_type;

-- Check if tables exist first before querying them
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'mechanic_job_history') THEN
        RAISE NOTICE '✅ mechanic_job_history table exists';
        PERFORM 1; -- Tables exist, queries below will work
    ELSE
        RAISE NOTICE '❌ mechanic_job_history table does not exist - run COMPLETE_CONNECTION_FIX.sql first';
        RETURN; -- Exit early if tables don't exist
    END IF;
END $$;

-- Only run if tables exist
SELECT 
    'Mechanic Job History' as history_type,
    COUNT(*) as total_entries,
    COUNT(CASE WHEN job_status = 'completed' THEN 1 END) as completed_jobs,
    COUNT(CASE WHEN job_status = 'cancelled' THEN 1 END) as cancelled_jobs
FROM mechanic_job_history
WHERE EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'mechanic_job_history')

UNION ALL

SELECT 
    'Customer Job History' as history_type,
    COUNT(*) as total_entries,
    COUNT(CASE WHEN job_status = 'completed' THEN 1 END) as completed_jobs,
    COUNT(CASE WHEN job_status = 'cancelled' THEN 1 END) as cancelled_jobs
FROM customer_job_history
WHERE EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'customer_job_history');

-- 3. Check for missing history entries (completed/cancelled jobs not in history)
SELECT 'MISSING MECHANIC HISTORY ENTRIES:' as check_type;
SELECT 
    CASE 
        WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'mechanic_job_history') THEN
            'Tables exist - checking for missing entries'
        ELSE 
            'Job history tables not created yet - run COMPLETE_CONNECTION_FIX.sql first'
    END as status;

-- Only check if tables exist
SELECT 
    sr.id as service_request_id,
    sr.title,
    sr.status,
    mechanic.first_name || ' ' || mechanic.last_name as mechanic_name,
    sr.updated_at
FROM service_requests sr
JOIN user_profiles mechanic ON mechanic.id = sr.assigned_mechanic_id
WHERE sr.status IN ('completed', 'cancelled')
AND sr.assigned_mechanic_id IS NOT NULL
AND NOT EXISTS (
    SELECT 1 FROM mechanic_job_history mjh 
    WHERE mjh.service_request_id = sr.id 
    AND mjh.mechanic_id = sr.assigned_mechanic_id
)
AND EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'mechanic_job_history')
ORDER BY sr.updated_at DESC;

SELECT 'MISSING CUSTOMER HISTORY ENTRIES:' as check_type;
SELECT 
    sr.id as service_request_id,
    sr.title,
    sr.status,
    customer.first_name || ' ' || customer.last_name as customer_name,
    sr.updated_at
FROM service_requests sr
JOIN user_profiles customer ON customer.id = sr.customer_id
WHERE sr.status IN ('completed', 'cancelled')
AND NOT EXISTS (
    SELECT 1 FROM customer_job_history cjh 
    WHERE cjh.service_request_id = sr.id 
    AND cjh.customer_id = sr.customer_id
)
AND EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'customer_job_history')
ORDER BY sr.updated_at DESC;

-- 4. Sample mechanic job history
SELECT 'SAMPLE MECHANIC JOB HISTORY:' as check_type;

-- Check if view exists first
SELECT 
    CASE 
        WHEN EXISTS (SELECT 1 FROM information_schema.views WHERE table_name = 'v_mechanic_job_history') THEN
            'View exists - showing sample data'
        ELSE 
            'v_mechanic_job_history view not created yet - run COMPLETE_CONNECTION_FIX.sql first'
    END as status;

-- Only show data if view exists
SELECT 
    mjh.mechanic_id,
    mechanic.first_name || ' ' || mechanic.last_name as mechanic_name,
    customer.first_name || ' ' || customer.last_name as customer_name,
    mjh.job_title,
    CASE 
        WHEN mjh.job_status = 'completed' THEN '✅ Completed'
        WHEN mjh.job_status = 'cancelled' THEN '❌ Cancelled'
        ELSE mjh.job_status
    END as status_display,
    mjh.total_amount,
    mjh.rating,
    mjh.completed_at,
    s.shop_name
FROM mechanic_job_history mjh
JOIN user_profiles mechanic ON mechanic.id = mjh.mechanic_id
JOIN user_profiles customer ON customer.id = mjh.customer_id
LEFT JOIN shops s ON s.id = mjh.shop_id
WHERE EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'mechanic_job_history')
ORDER BY mjh.completed_at DESC
LIMIT 10;

-- 5. Sample customer job history
SELECT 'SAMPLE CUSTOMER JOB HISTORY:' as check_type;
SELECT 
    cjh.customer_id,
    customer.first_name || ' ' || customer.last_name as customer_name,
    cjh.job_title,
    CASE 
        WHEN cjh.job_status = 'completed' THEN '✅ Completed'
        WHEN cjh.job_status = 'cancelled' THEN '❌ Cancelled'
        ELSE cjh.job_status
    END as status_display,
    cjh.mechanic_name,
    cjh.shop_name,
    cjh.total_amount,
    cjh.rating,
    cjh.completed_at
FROM customer_job_history cjh
JOIN user_profiles customer ON customer.id = cjh.customer_id
WHERE EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'customer_job_history')
ORDER BY cjh.completed_at DESC
LIMIT 10;

-- 6. Check triggers exist
SELECT 'JOB HISTORY TRIGGERS STATUS:' as check_type;
SELECT 
    t.tgname as trigger_name,
    c.relname as table_name,
    CASE WHEN t.tgname IS NOT NULL THEN '✅ EXISTS' ELSE '❌ MISSING' END as status
FROM (VALUES 
    ('trg_service_request_history', 'service_requests')
) AS expected_triggers(tname, tablename)
LEFT JOIN pg_trigger t ON t.tgname = expected_triggers.tname
LEFT JOIN pg_class c ON c.oid = t.tgrelid AND c.relname = expected_triggers.tablename;

-- 7. Check functions exist
SELECT 'JOB HISTORY FUNCTIONS STATUS:' as check_type;
SELECT 
    p.proname as function_name,
    CASE WHEN p.proname IS NOT NULL THEN '✅ EXISTS' ELSE '❌ MISSING' END as status
FROM (VALUES 
    ('add_job_to_history')
) AS expected_functions(fname)
LEFT JOIN pg_proc p ON p.proname = expected_functions.fname;

-- 8. Job history statistics by mechanic
SELECT 'TOP MECHANICS BY COMPLETED JOBS:' as check_type;

-- Only show stats if tables exist
SELECT 
    mjh.mechanic_id,
    up.first_name || ' ' || up.last_name as mechanic_name,
    COUNT(*) as total_jobs,
    COUNT(CASE WHEN mjh.job_status = 'completed' THEN 1 END) as completed_jobs,
    COUNT(CASE WHEN mjh.job_status = 'cancelled' THEN 1 END) as cancelled_jobs,
    AVG(mjh.rating) as average_rating,
    SUM(mjh.total_amount) as total_earnings
FROM mechanic_job_history mjh
JOIN user_profiles up ON up.id = mjh.mechanic_id
WHERE EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'mechanic_job_history')
GROUP BY mjh.mechanic_id, up.first_name, up.last_name
ORDER BY completed_jobs DESC
LIMIT 10;

-- 9. Job history statistics by customer
SELECT 'TOP CUSTOMERS BY SERVICE USAGE:' as check_type;
SELECT 
    cjh.customer_id,
    up.first_name || ' ' || up.last_name as customer_name,
    COUNT(*) as total_requests,
    COUNT(CASE WHEN cjh.job_status = 'completed' THEN 1 END) as completed_requests,
    COUNT(CASE WHEN cjh.job_status = 'cancelled' THEN 1 END) as cancelled_requests,
    SUM(cjh.total_amount) as total_spent
FROM customer_job_history cjh
JOIN user_profiles up ON up.id = cjh.customer_id
WHERE EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'customer_job_history')
GROUP BY cjh.customer_id, up.first_name, up.last_name
ORDER BY completed_requests DESC
LIMIT 10;

-- 10. Final validation summary
SELECT 'JOB HISTORY SYSTEM HEALTH:' as check_type;

-- Check if tables exist before trying to count
SELECT 
    CASE 
        WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'mechanic_job_history')
        AND EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'customer_job_history') THEN
            'Job history tables exist - calculating coverage'
        ELSE 
            'Job history tables not created yet - run COMPLETE_CONNECTION_FIX.sql first'
    END as system_status;

-- Only calculate coverage if tables exist
WITH history_stats AS (
    SELECT 
        CASE 
            WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'mechanic_job_history') 
            THEN (SELECT COUNT(*) FROM mechanic_job_history) 
            ELSE 0 
        END as mechanic_entries,
        CASE 
            WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'customer_job_history') 
            THEN (SELECT COUNT(*) FROM customer_job_history) 
            ELSE 0 
        END as customer_entries,
        (SELECT COUNT(*) FROM service_requests WHERE status IN ('completed', 'cancelled')) as total_completed_cancelled
)
SELECT 
    'Mechanic History Coverage' as metric,
    CASE 
        WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'mechanic_job_history') THEN
            ROUND((mechanic_entries::numeric / GREATEST(total_completed_cancelled, 1)) * 100, 2) || '%'
        ELSE 
            'N/A - Tables not created'
    END as percentage
FROM history_stats

UNION ALL

SELECT 
    'Customer History Coverage' as metric,
    CASE 
        WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'customer_job_history') THEN
            ROUND((customer_entries::numeric / GREATEST(total_completed_cancelled, 1)) * 100, 2) || '%'
        ELSE 
            'N/A - Tables not created'
    END as percentage
FROM history_stats;