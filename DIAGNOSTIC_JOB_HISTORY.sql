-- =====================================================
-- DIAGNOSTIC QUERIES FOR JOB HISTORY SYSTEM
-- =====================================================
-- Run this to diagnose why job history tables are empty

-- 1. Check if we have any completed/cancelled jobs to migrate
SELECT 'COMPLETED/CANCELLED JOBS ANALYSIS:' as check_type;

SELECT 
    sr.status,
    COUNT(*) as job_count,
    COUNT(CASE WHEN sr.assigned_mechanic_id IS NOT NULL THEN 1 END) as with_assigned_mechanic,
    COUNT(CASE WHEN sr.assigned_mechanic_id IS NULL THEN 1 END) as without_assigned_mechanic
FROM service_requests sr
WHERE sr.status IN ('completed', 'cancelled')
GROUP BY sr.status
ORDER BY sr.status;

-- 2. Show sample completed/cancelled jobs
SELECT 'SAMPLE COMPLETED/CANCELLED JOBS:' as check_type;

SELECT 
    sr.id,
    sr.title,
    sr.status,
    sr.customer_id,
    sr.assigned_mechanic_id,
    customer.first_name || ' ' || customer.last_name as customer_name,
    CASE 
        WHEN sr.assigned_mechanic_id IS NOT NULL 
        THEN mechanic.first_name || ' ' || mechanic.last_name
        ELSE 'No mechanic assigned'
    END as mechanic_name,
    sr.created_at,
    sr.updated_at
FROM service_requests sr
JOIN user_profiles customer ON customer.id = sr.customer_id
LEFT JOIN user_profiles mechanic ON mechanic.id = sr.assigned_mechanic_id
WHERE sr.status IN ('completed', 'cancelled')
ORDER BY sr.updated_at DESC
LIMIT 10;

-- 3. Check current job history table contents
SELECT 'CURRENT MECHANIC JOB HISTORY:' as check_type;

SELECT 
    COUNT(*) as total_entries
FROM mechanic_job_history
WHERE EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'mechanic_job_history');

SELECT 'CURRENT CUSTOMER JOB HISTORY:' as check_type;

SELECT 
    COUNT(*) as total_entries
FROM customer_job_history
WHERE EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'customer_job_history');

-- 4. Check if triggers are working by looking for recent activity
SELECT 'RECENT SERVICE REQUEST STATUS CHANGES:' as check_type;

SELECT 
    sr.id,
    sr.title,
    sr.status,
    sr.updated_at,
    'Should have triggered history creation' as note
FROM service_requests sr
WHERE sr.status IN ('completed', 'cancelled')
AND sr.updated_at >= NOW() - INTERVAL '1 hour'
ORDER BY sr.updated_at DESC
LIMIT 5;

-- 5. Manual trigger test - check what would be processed
SELECT 'JOBS THAT SHOULD BE IN HISTORY:' as check_type;

SELECT 
    sr.id as service_request_id,
    sr.title,
    sr.status,
    sr.customer_id,
    sr.assigned_mechanic_id,
    sr.created_at,
    sr.updated_at,
    CASE 
        WHEN sr.assigned_mechanic_id IS NOT NULL THEN 'Should be in mechanic history'
        ELSE 'Should only be in customer history'
    END as expected_location
FROM service_requests sr
WHERE sr.status IN ('completed', 'cancelled')
ORDER BY sr.updated_at DESC;

-- 6. Check if payment and review data exists for these jobs
SELECT 'PAYMENT DATA AVAILABILITY:' as check_type;

SELECT 
    'Jobs with Payments' as data_type,
    COUNT(DISTINCT p.request_id) as count
FROM payments p
JOIN service_requests sr ON sr.id = p.request_id
WHERE sr.status IN ('completed', 'cancelled')

UNION ALL

SELECT 
    'Jobs with Reviews' as data_type,
    COUNT(DISTINCT r.request_id) as count
FROM reviews r
JOIN service_requests sr ON sr.id = r.request_id
WHERE sr.status IN ('completed', 'cancelled');

-- 7. Final diagnosis
SELECT 'DIAGNOSIS SUMMARY:' as check_type;

WITH diagnosis AS (
    SELECT 
        (SELECT COUNT(*) FROM service_requests WHERE status IN ('completed', 'cancelled')) as total_completed_cancelled,
        (SELECT COUNT(*) FROM service_requests WHERE status IN ('completed', 'cancelled') AND assigned_mechanic_id IS NOT NULL) as with_mechanic,
        (SELECT COUNT(*) FROM mechanic_job_history) as mechanic_history_count,
        (SELECT COUNT(*) FROM customer_job_history) as customer_history_count
)
SELECT 
    CASE 
        WHEN total_completed_cancelled = 0 THEN 
            '❌ No completed/cancelled jobs exist - create some test data'
        WHEN mechanic_history_count = 0 AND customer_history_count = 0 THEN
            '⚠️ Jobs exist but history is empty - backfill process may have failed'
        WHEN mechanic_history_count < with_mechanic THEN
            '⚠️ Some mechanic history entries missing - partial backfill'
        WHEN customer_history_count < total_completed_cancelled THEN
            '⚠️ Some customer history entries missing - partial backfill'
        ELSE 
            '✅ History system appears to be working correctly'
    END as diagnosis,
    total_completed_cancelled as jobs_to_process,
    mechanic_history_count as current_mechanic_entries,
    customer_history_count as current_customer_entries
FROM diagnosis;