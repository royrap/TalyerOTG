-- =====================================================
-- QUICK FIX: Calculate Earnings for Existing Data
-- =====================================================
-- Run this if you have completed jobs without earnings calculated
-- =====================================================

BEGIN;

-- Update mechanic_job_history with calculated earnings
UPDATE mechanic_job_history 
SET 
    mechanic_earnings = ROUND(COALESCE(total_amount, 0) * 0.75, 2),
    shop_earnings = ROUND(COALESCE(total_amount, 0) * 0.20, 2),
    platform_fee = ROUND(COALESCE(total_amount, 0) * 0.05, 2),
    fee_percentage_mechanic = 75.00,
    fee_percentage_shop = 20.00,
    fee_percentage_platform = 5.00,
    updated_at = NOW()
WHERE job_status = 'completed'
AND total_amount IS NOT NULL 
AND total_amount > 0 
AND (mechanic_earnings IS NULL OR mechanic_earnings = 0);

-- Update service_requests with calculated earnings
UPDATE service_requests 
SET 
    mechanic_earnings = ROUND(COALESCE(final_price, 0) * 0.75, 2),
    shop_earnings = ROUND(COALESCE(final_price, 0) * 0.20, 2),
    platform_fee = ROUND(COALESCE(final_price, 0) * 0.05, 2),
    fee_breakdown_calculated = TRUE,
    updated_at = NOW()
WHERE status = 'completed'
AND final_price IS NOT NULL 
AND final_price > 0 
AND (fee_breakdown_calculated = FALSE OR mechanic_earnings = 0);

-- Show results
SELECT 
    'Mechanic Job History:' as table_name,
    COUNT(*) as total_updated,
    SUM(mechanic_earnings) as total_mechanic_earnings,
    SUM(shop_earnings) as total_shop_earnings,
    SUM(platform_fee) as total_platform_fees
FROM mechanic_job_history
WHERE mechanic_earnings > 0;

SELECT 
    'Service Requests:' as table_name,
    COUNT(*) as total_updated,
    SUM(mechanic_earnings) as total_mechanic_earnings,
    SUM(shop_earnings) as total_shop_earnings,
    SUM(platform_fee) as total_platform_fees
FROM service_requests
WHERE mechanic_earnings > 0;

COMMIT;

-- =====================================================
-- SUCCESS MESSAGE
-- =====================================================
DO $$
BEGIN
    RAISE NOTICE '✅ Earnings calculated for existing completed jobs!';
    RAISE NOTICE '📊 Distribution: 75%% Mechanic | 20%% Shop | 5%% Platform';
END $$;
