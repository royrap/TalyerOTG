-- =====================================================
-- CHECK DATA STATUS - Verify if earnings are being saved
-- =====================================================

-- 1. Check if there are completed jobs WITHOUT earnings calculated
SELECT 
    'Jobs without earnings calculation:' as check_type,
    COUNT(*) as total_completed_jobs,
    COUNT(*) FILTER (WHERE mechanic_earnings = 0 AND total_amount > 0) as jobs_without_mechanic_earnings,
    COUNT(*) FILTER (WHERE shop_earnings = 0 AND total_amount > 0) as jobs_without_shop_earnings,
    COUNT(*) FILTER (WHERE platform_fee = 0 AND total_amount > 0) as jobs_without_platform_fee
FROM mechanic_job_history
WHERE job_status = 'completed';

-- 2. Sample of completed jobs with their earnings
SELECT 
    id,
    job_title,
    total_amount,
    mechanic_earnings,
    shop_earnings,
    platform_fee,
    (mechanic_earnings + shop_earnings + platform_fee) as sum_check,
    CASE 
        WHEN total_amount > 0 AND mechanic_earnings = 0 THEN '❌ NOT CALCULATED'
        WHEN ABS(total_amount - (mechanic_earnings + shop_earnings + platform_fee)) < 0.01 THEN '✅ CORRECT'
        ELSE '⚠️ MISMATCH'
    END as status,
    completed_at
FROM mechanic_job_history
WHERE job_status = 'completed'
ORDER BY completed_at DESC
LIMIT 10;

-- 3. Check service_requests earnings
SELECT 
    'Service Requests Earnings Status:' as check_type,
    COUNT(*) as total_requests,
    COUNT(*) FILTER (WHERE fee_breakdown_calculated = true) as calculated_count,
    COUNT(*) FILTER (WHERE fee_breakdown_calculated = false AND final_price > 0) as needs_calculation,
    COUNT(*) FILTER (WHERE mechanic_earnings > 0) as has_mechanic_earnings,
    COUNT(*) FILTER (WHERE shop_earnings > 0) as has_shop_earnings,
    COUNT(*) FILTER (WHERE platform_fee > 0) as has_platform_fee
FROM service_requests
WHERE status = 'completed';

-- 4. Check if calculate_earnings_breakdown function exists
SELECT 
    routine_name,
    routine_type,
    'Function exists: ' || routine_name as status
FROM information_schema.routines
WHERE routine_name = 'calculate_earnings_breakdown'
AND routine_schema = 'public';

-- 5. Check if trigger exists
SELECT 
    trigger_name,
    event_object_table,
    action_timing,
    event_manipulation,
    'Trigger exists: ' || trigger_name as status
FROM information_schema.triggers
WHERE trigger_name = 'trg_update_earnings_on_completion'
AND trigger_schema = 'public';

-- =====================================================
-- INTERPRETATION:
-- =====================================================
-- If jobs_without_earnings > 0: Need to run UPDATE to calculate retroactively
-- If function doesn't exist: Need to deploy calculate_earnings_breakdown()
-- If trigger doesn't exist: Need to create auto-calculation trigger
-- =====================================================
