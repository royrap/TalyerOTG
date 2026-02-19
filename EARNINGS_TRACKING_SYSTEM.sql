-- =====================================================
-- EARNINGS TRACKING SYSTEM - Angkas Style Fee Distribution
-- =====================================================
-- Implements fee breakdown: 75% mechanic, 20% shop, 5% platform
-- Enhances both mechanic_job_history and service_requests tables
-- =====================================================

BEGIN;

-- =====================================================
-- PART 1: ADD EARNINGS FIELDS TO MECHANIC_JOB_HISTORY
-- =====================================================

-- Add earnings breakdown fields to mechanic_job_history table
ALTER TABLE mechanic_job_history 
ADD COLUMN IF NOT EXISTS mechanic_earnings DECIMAL(10,2) DEFAULT 0.00,
ADD COLUMN IF NOT EXISTS shop_earnings DECIMAL(10,2) DEFAULT 0.00,
ADD COLUMN IF NOT EXISTS platform_fee DECIMAL(10,2) DEFAULT 0.00,
ADD COLUMN IF NOT EXISTS fee_percentage_mechanic DECIMAL(5,2) DEFAULT 75.00,
ADD COLUMN IF NOT EXISTS fee_percentage_shop DECIMAL(5,2) DEFAULT 20.00,
ADD COLUMN IF NOT EXISTS fee_percentage_platform DECIMAL(5,2) DEFAULT 5.00;

-- Update existing records with calculated earnings (retroactive)
UPDATE mechanic_job_history 
SET 
    mechanic_earnings = ROUND(COALESCE(total_amount, 0) * 0.75, 2),
    shop_earnings = ROUND(COALESCE(total_amount, 0) * 0.20, 2),
    platform_fee = ROUND(COALESCE(total_amount, 0) * 0.05, 2),
    fee_percentage_mechanic = 75.00,
    fee_percentage_shop = 20.00,
    fee_percentage_platform = 5.00,
    updated_at = NOW()
WHERE total_amount IS NOT NULL 
AND total_amount > 0 
AND (mechanic_earnings IS NULL OR mechanic_earnings = 0);

-- =====================================================
-- PART 2: ADD EARNINGS FIELDS TO SERVICE_REQUESTS
-- =====================================================

-- Add earnings breakdown fields to service_requests table
ALTER TABLE service_requests 
ADD COLUMN IF NOT EXISTS mechanic_earnings DECIMAL(10,2) DEFAULT 0.00,
ADD COLUMN IF NOT EXISTS shop_earnings DECIMAL(10,2) DEFAULT 0.00,
ADD COLUMN IF NOT EXISTS platform_fee DECIMAL(10,2) DEFAULT 0.00,
ADD COLUMN IF NOT EXISTS fee_breakdown_calculated BOOLEAN DEFAULT FALSE;

-- =====================================================
-- PART 3: CREATE EARNINGS CALCULATION FUNCTION
-- =====================================================

CREATE OR REPLACE FUNCTION calculate_earnings_breakdown(
    p_total_amount DECIMAL(10,2),
    p_mechanic_percentage DECIMAL(5,2) DEFAULT 75.00,
    p_shop_percentage DECIMAL(5,2) DEFAULT 20.00,
    p_platform_percentage DECIMAL(5,2) DEFAULT 5.00
)
RETURNS TABLE (
    mechanic_earnings DECIMAL(10,2),
    shop_earnings DECIMAL(10,2),
    platform_fee DECIMAL(10,2)
) AS $$
BEGIN
    RETURN QUERY SELECT
        ROUND(p_total_amount * (p_mechanic_percentage / 100.0), 2)::DECIMAL(10,2),
        ROUND(p_total_amount * (p_shop_percentage / 100.0), 2)::DECIMAL(10,2),
        ROUND(p_total_amount * (p_platform_percentage / 100.0), 2)::DECIMAL(10,2);
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- PART 4: CREATE SHOP EARNINGS VIEW
-- =====================================================

CREATE OR REPLACE VIEW v_shop_earnings AS
SELECT 
    s.id as shop_id,
    s.shop_name,
    s.owner_id as shop_owner_id,
    COUNT(mjh.id) as total_completed_jobs,
    SUM(mjh.total_amount) as total_revenue,
    SUM(mjh.shop_earnings) as total_shop_earnings,
    SUM(mjh.platform_fee) as total_platform_fees,
    AVG(mjh.rating) as average_rating,
    MIN(mjh.completed_at) as first_job_date,
    MAX(mjh.completed_at) as last_job_date
FROM shops s
LEFT JOIN mechanic_job_history mjh ON mjh.shop_id = s.id 
    AND mjh.job_status = 'completed' 
    AND mjh.completed_at IS NOT NULL
GROUP BY s.id, s.shop_name, s.owner_id;

-- =====================================================
-- PART 5: CREATE MECHANIC EARNINGS VIEW
-- =====================================================

CREATE OR REPLACE VIEW v_mechanic_earnings AS
SELECT 
    up.id as mechanic_id,
    up.first_name,
    up.last_name,
    up.email,
    up.shop_id,
    s.shop_name,
    COUNT(mjh.id) as total_completed_jobs,
    SUM(mjh.total_amount) as total_revenue,
    SUM(mjh.mechanic_earnings) as total_mechanic_earnings,
    SUM(mjh.shop_earnings) as total_contributed_to_shop,
    AVG(mjh.rating) as average_rating,
    MIN(mjh.completed_at) as first_job_date,
    MAX(mjh.completed_at) as last_job_date
FROM user_profiles up
LEFT JOIN mechanic_job_history mjh ON mjh.mechanic_id = up.id 
    AND mjh.job_status = 'completed' 
    AND mjh.completed_at IS NOT NULL
LEFT JOIN shops s ON s.id = up.shop_id
WHERE up.user_type = 'mechanic'
GROUP BY up.id, up.first_name, up.last_name, up.email, up.shop_id, s.shop_name;

-- =====================================================
-- PART 6: UPDATE TRIGGER FOR AUTOMATIC EARNINGS CALCULATION
-- =====================================================

CREATE OR REPLACE FUNCTION update_earnings_on_completion()
RETURNS TRIGGER AS $$
DECLARE
    v_earnings_breakdown RECORD;
BEGIN
    -- Only calculate earnings when job is completed and has a total_amount
    IF NEW.job_status = 'completed' 
       AND NEW.total_amount IS NOT NULL 
       AND NEW.total_amount > 0 
       AND (OLD.job_status != 'completed' OR OLD.total_amount IS NULL OR OLD.total_amount != NEW.total_amount) THEN
       
        -- Calculate earnings breakdown
        SELECT * INTO v_earnings_breakdown 
        FROM calculate_earnings_breakdown(NEW.total_amount);
        
        -- Update the earnings fields
        NEW.mechanic_earnings = v_earnings_breakdown.mechanic_earnings;
        NEW.shop_earnings = v_earnings_breakdown.shop_earnings;
        NEW.platform_fee = v_earnings_breakdown.platform_fee;
        NEW.updated_at = NOW();
        
        -- Also update service_requests table if linked
        UPDATE service_requests 
        SET 
            mechanic_earnings = v_earnings_breakdown.mechanic_earnings,
            shop_earnings = v_earnings_breakdown.shop_earnings,
            platform_fee = v_earnings_breakdown.platform_fee,
            fee_breakdown_calculated = TRUE,
            updated_at = NOW()
        WHERE id = NEW.service_request_id;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for automatic earnings calculation
DROP TRIGGER IF EXISTS trg_update_earnings_on_completion ON mechanic_job_history;
CREATE TRIGGER trg_update_earnings_on_completion
    BEFORE UPDATE ON mechanic_job_history
    FOR EACH ROW
    EXECUTE FUNCTION update_earnings_on_completion();

-- =====================================================
-- PART 7: CREATE EARNINGS SUMMARY FUNCTIONS
-- =====================================================

-- Function to get mechanic earnings summary
CREATE OR REPLACE FUNCTION get_mechanic_earnings_summary(p_mechanic_id UUID)
RETURNS TABLE (
    total_jobs BIGINT,
    total_earnings DECIMAL(10,2),
    this_month_earnings DECIMAL(10,2),
    this_week_earnings DECIMAL(10,2),
    today_earnings DECIMAL(10,2),
    average_rating DECIMAL(2,1)
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*)::BIGINT as total_jobs,
        COALESCE(SUM(mjh.mechanic_earnings), 0)::DECIMAL(10,2) as total_earnings,
        COALESCE(SUM(CASE 
            WHEN mjh.completed_at >= date_trunc('month', CURRENT_DATE) 
            THEN mjh.mechanic_earnings 
            ELSE 0 
        END), 0)::DECIMAL(10,2) as this_month_earnings,
        COALESCE(SUM(CASE 
            WHEN mjh.completed_at >= date_trunc('week', CURRENT_DATE) 
            THEN mjh.mechanic_earnings 
            ELSE 0 
        END), 0)::DECIMAL(10,2) as this_week_earnings,
        COALESCE(SUM(CASE 
            WHEN mjh.completed_at >= CURRENT_DATE 
            THEN mjh.mechanic_earnings 
            ELSE 0 
        END), 0)::DECIMAL(10,2) as today_earnings,
        COALESCE(AVG(mjh.rating), 0)::DECIMAL(2,1) as average_rating
    FROM mechanic_job_history mjh
    WHERE mjh.mechanic_id = p_mechanic_id
    AND mjh.job_status = 'completed'
    AND mjh.completed_at IS NOT NULL;
END;
$$ LANGUAGE plpgsql;

-- Function to get shop owner earnings summary
CREATE OR REPLACE FUNCTION get_shop_earnings_summary(p_shop_owner_id UUID)
RETURNS TABLE (
    total_jobs BIGINT,
    total_shop_earnings DECIMAL(10,2),
    this_month_earnings DECIMAL(10,2),
    this_week_earnings DECIMAL(10,2),
    today_earnings DECIMAL(10,2),
    number_of_mechanics BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(mjh.id)::BIGINT as total_jobs,
        COALESCE(SUM(mjh.shop_earnings), 0)::DECIMAL(10,2) as total_shop_earnings,
        COALESCE(SUM(CASE 
            WHEN mjh.completed_at >= date_trunc('month', CURRENT_DATE) 
            THEN mjh.shop_earnings 
            ELSE 0 
        END), 0)::DECIMAL(10,2) as this_month_earnings,
        COALESCE(SUM(CASE 
            WHEN mjh.completed_at >= date_trunc('week', CURRENT_DATE) 
            THEN mjh.shop_earnings 
            ELSE 0 
        END), 0)::DECIMAL(10,2) as this_week_earnings,
        COALESCE(SUM(CASE 
            WHEN mjh.completed_at >= CURRENT_DATE 
            THEN mjh.shop_earnings 
            ELSE 0 
        END), 0)::DECIMAL(10,2) as today_earnings,
        COUNT(DISTINCT mjh.mechanic_id)::BIGINT as number_of_mechanics
    FROM shops s
    JOIN mechanic_job_history mjh ON mjh.shop_id = s.id
    WHERE s.owner_id = p_shop_owner_id
    AND mjh.job_status = 'completed'
    AND mjh.completed_at IS NOT NULL
    GROUP BY s.owner_id;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- PART 8: VERIFICATION AND TESTING
-- =====================================================

-- Test the earnings calculation function
SELECT 
    'Earnings Test for ₱1000' as test_case,
    mechanic_earnings,
    shop_earnings,
    platform_fee,
    (mechanic_earnings + shop_earnings + platform_fee) as total_check
FROM calculate_earnings_breakdown(1000.00);

-- Verify existing data has been updated
SELECT 
    COUNT(*) as total_records,
    COUNT(*) FILTER (WHERE mechanic_earnings > 0) as records_with_earnings,
    SUM(total_amount) as total_revenue,
    SUM(mechanic_earnings) as total_mechanic_earnings,
    SUM(shop_earnings) as total_shop_earnings,
    SUM(platform_fee) as total_platform_fees
FROM mechanic_job_history 
WHERE job_status = 'completed' AND total_amount > 0;

-- Display success messages
DO $$
BEGIN
    RAISE NOTICE '✅ EARNINGS TRACKING SYSTEM DEPLOYED SUCCESSFULLY';
    RAISE NOTICE '📊 Fee Distribution: 75%% Mechanic | 20%% Shop | 5%% Platform';
    RAISE NOTICE '🎯 Mechanic and Shop Owner earnings are now tracked separately';
    RAISE NOTICE '🔧 Automatic calculation triggers activated for future jobs';
END $$;

COMMIT;