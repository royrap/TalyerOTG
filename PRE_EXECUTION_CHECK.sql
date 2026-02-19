-- =====================================================
-- PRE-EXECUTION VALIDATION FOR JOB HISTORY SYSTEM
-- =====================================================
-- Run this BEFORE executing COMPLETE_CONNECTION_FIX.sql
-- This checks what will be processed by the job history system

-- 1. Check current system state
SELECT '🔍 CURRENT SYSTEM STATE:' as check_type;

-- Check if job history tables already exist
SELECT 
    'Job History Tables' as component,
    CASE 
        WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'mechanic_job_history')
        AND EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'customer_job_history') 
        THEN '✅ Already Created'
        ELSE '❌ Not Created Yet'
    END as status;

-- 2. Count completed/cancelled jobs that need history entries
SELECT '📊 JOBS THAT NEED HISTORY TRACKING:' as check_type;

SELECT 
    sr.status,
    COUNT(*) as job_count,
    COUNT(CASE WHEN sr.assigned_mechanic_id IS NOT NULL THEN 1 END) as with_mechanic_assigned
FROM service_requests sr
WHERE sr.status IN ('completed', 'cancelled')
GROUP BY sr.status
ORDER BY sr.status;

-- 3. Show sample completed jobs that will be processed
SELECT '📋 SAMPLE COMPLETED JOBS TO BE ADDED TO HISTORY:' as check_type;

SELECT 
    sr.id,
    sr.title,
    sr.status,
    sr.created_at,
    sr.updated_at,
    customer.first_name || ' ' || customer.last_name as customer_name,
    CASE 
        WHEN sr.assigned_mechanic_id IS NOT NULL THEN mechanic.first_name || ' ' || mechanic.last_name
        ELSE 'No mechanic assigned'
    END as mechanic_name
FROM service_requests sr
JOIN user_profiles customer ON customer.id = sr.customer_id
LEFT JOIN user_profiles mechanic ON mechanic.id = sr.assigned_mechanic_id
WHERE sr.status IN ('completed', 'cancelled')
ORDER BY sr.updated_at DESC
LIMIT 10;

-- 4. Check payment and review data availability
SELECT '💰 PAYMENT & REVIEW DATA AVAILABILITY:' as check_type;

SELECT 
    'Jobs with Payment Data' as data_type,
    COUNT(DISTINCT p.service_request_id) as count
FROM service_requests sr
JOIN payments p ON p.service_request_id = sr.id
WHERE sr.status IN ('completed', 'cancelled')

UNION ALL

SELECT 
    'Jobs with Review Data' as data_type,
    COUNT(DISTINCT r.service_request_id) as count
FROM service_requests sr
JOIN reviews r ON r.service_request_id = sr.id
WHERE sr.status IN ('completed', 'cancelled')

UNION ALL

SELECT 
    'Total Completed/Cancelled Jobs' as data_type,
    COUNT(*) as count
FROM service_requests sr
WHERE sr.status IN ('completed', 'cancelled');

-- 5. Check mechanics and their shop connections
SELECT '🔧 MECHANIC-SHOP CONNECTIONS STATUS:' as check_type;

SELECT 
    'Mechanics with Shop Connections' as connection_type,
    COUNT(*) as count
FROM user_profiles up
JOIN shop_mechanics sm ON sm.mechanic_id = up.id AND sm.is_active = true
WHERE up.user_type = 'mechanic'

UNION ALL

SELECT 
    'Total Mechanics' as connection_type,
    COUNT(*) as count
FROM user_profiles up
WHERE up.user_type = 'mechanic'

UNION ALL

SELECT 
    'Mechanics without Shop Connections' as connection_type,
    COUNT(*) as count
FROM user_profiles up
LEFT JOIN shop_mechanics sm ON sm.mechanic_id = up.id AND sm.is_active = true
WHERE up.user_type = 'mechanic' AND sm.id IS NULL;

-- 6. Estimate what will be created
SELECT '📈 ESTIMATED JOB HISTORY ENTRIES TO BE CREATED:' as check_type;

WITH job_estimates AS (
    SELECT 
        COUNT(*) as total_completed_cancelled,
        COUNT(CASE WHEN sr.assigned_mechanic_id IS NOT NULL THEN 1 END) as with_mechanic
    FROM service_requests sr
    WHERE sr.status IN ('completed', 'cancelled')
)
SELECT 
    'Mechanic Job History Entries' as entry_type,
    with_mechanic as estimated_count,
    'One entry per completed/cancelled job with assigned mechanic' as description
FROM job_estimates

UNION ALL

SELECT 
    'Customer Job History Entries' as entry_type,
    total_completed_cancelled as estimated_count,
    'One entry per completed/cancelled job' as description
FROM job_estimates;

-- 7. System readiness check
SELECT '✅ SYSTEM READINESS CHECK:' as check_type;

SELECT 
    CASE 
        WHEN (SELECT COUNT(*) FROM service_requests WHERE status IN ('completed', 'cancelled')) > 0 THEN
            '✅ System has completed/cancelled jobs to process'
        ELSE 
            '⚠️ No completed/cancelled jobs found'
    END as readiness_status

UNION ALL

SELECT 
    CASE 
        WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'service_requests') THEN
            '✅ Core tables exist (service_requests, user_profiles)'
        ELSE 
            '❌ Core tables missing'
    END as readiness_status

UNION ALL

SELECT 
    CASE 
        WHEN NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'mechanic_job_history') THEN
            '✅ Ready for job history system creation'
        ELSE 
            '⚠️ Job history tables already exist - will update existing data'
    END as readiness_status;

-- Final message
SELECT '🚀 NEXT STEPS:' as action_required;
SELECT 
    'Execute COMPLETE_CONNECTION_FIX.sql to create job history system and process all completed/cancelled jobs' as instruction;