-- =====================================================
-- CHECK EARNINGS SYSTEM STATUS
-- =====================================================
-- Run this in Supabase SQL Editor to check if earnings system is deployed
-- =====================================================

-- 1. Check if earnings columns exist in mechanic_job_history
SELECT 
    column_name, 
    data_type, 
    column_default
FROM information_schema.columns
WHERE table_name = 'mechanic_job_history'
AND column_name IN ('mechanic_earnings', 'shop_earnings', 'platform_fee', 'fee_percentage_mechanic', 'fee_percentage_shop', 'fee_percentage_platform')
ORDER BY column_name;

-- 2. Check if earnings columns exist in service_requests
SELECT 
    column_name, 
    data_type, 
    column_default
FROM information_schema.columns
WHERE table_name = 'service_requests'
AND column_name IN ('mechanic_earnings', 'shop_earnings', 'platform_fee', 'fee_breakdown_calculated')
ORDER BY column_name;

-- 3. Check if calculate_earnings_breakdown function exists
SELECT 
    routine_name,
    routine_type,
    data_type as return_type
FROM information_schema.routines
WHERE routine_name IN ('calculate_earnings_breakdown', 'update_earnings_on_completion', 'get_mechanic_earnings_summary', 'get_shop_earnings_summary')
ORDER BY routine_name;

-- 4. Check if trigger exists
SELECT 
    trigger_name,
    event_manipulation,
    event_object_table,
    action_statement
FROM information_schema.triggers
WHERE trigger_name = 'trg_update_earnings_on_completion';

-- 5. Check actual data - see if any jobs have earnings calculated
SELECT 
    COUNT(*) as total_jobs,
    COUNT(*) FILTER (WHERE mechanic_earnings > 0) as jobs_with_mechanic_earnings,
    COUNT(*) FILTER (WHERE shop_earnings > 0) as jobs_with_shop_earnings,
    COUNT(*) FILTER (WHERE platform_fee > 0) as jobs_with_platform_fee,
    SUM(total_amount) as total_revenue,
    SUM(mechanic_earnings) as total_mechanic_earnings,
    SUM(shop_earnings) as total_shop_earnings,
    SUM(platform_fee) as total_platform_fees
FROM mechanic_job_history
WHERE job_status = 'completed';

-- 6. Sample recent jobs with earnings breakdown
SELECT 
    id,
    mechanic_id,
    job_title,
    total_amount,
    mechanic_earnings,
    shop_earnings,
    platform_fee,
    (mechanic_earnings + shop_earnings + platform_fee) as calculated_total,
    completed_at
FROM mechanic_job_history
WHERE job_status = 'completed'
AND total_amount > 0
ORDER BY completed_at DESC
LIMIT 5;

-- 7. Check earnings views
SELECT 
    table_name,
    view_definition
FROM information_schema.views
WHERE table_name IN ('v_shop_earnings', 'v_mechanic_earnings');

-- =====================================================
-- RESULTS INTERPRETATION:
-- =====================================================
-- ✅ If you see columns returned in queries 1 & 2: Columns exist
-- ✅ If you see functions in query 3: Functions deployed
-- ✅ If you see trigger in query 4: Auto-calculation enabled
-- ❌ If queries return empty: You need to run EARNINGS_TRACKING_SYSTEM.sql
-- =====================================================
