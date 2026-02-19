-- ========================================
-- AUTO-CALCULATE EARNINGS TRIGGER
-- ========================================
-- This trigger automatically calculates earnings
-- whenever a job is marked as 'completed'
-- Prevents the issue of missing earnings data
-- ========================================

-- ========================================
-- FUNCTION: Calculate Earnings on Completion
-- ========================================
CREATE OR REPLACE FUNCTION calculate_earnings_on_completion()
RETURNS TRIGGER AS $$
BEGIN
  -- Only calculate if job is being completed (status changes to 'completed')
  -- and final_price exists
  IF NEW.status = 'completed' AND NEW.final_price IS NOT NULL AND NEW.final_price > 0 THEN
    
    -- Calculate earnings breakdown (75% / 20% / 5%)
    NEW.mechanic_earnings := ROUND(NEW.final_price * 0.75, 2);
    NEW.shop_earnings := ROUND(NEW.final_price * 0.20, 2);
    NEW.platform_fee := ROUND(NEW.final_price * 0.05, 2);
    NEW.fee_breakdown_calculated := TRUE;
    NEW.updated_at := NOW();
    
    RAISE NOTICE '✅ Earnings calculated for request %: Mechanic=%, Shop=%, Platform=%', 
      NEW.id, NEW.mechanic_earnings, NEW.shop_earnings, NEW.platform_fee;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ========================================
-- TRIGGER: Auto-calculate on status change
-- ========================================
DROP TRIGGER IF EXISTS trigger_calculate_earnings_on_completion ON service_requests;

CREATE TRIGGER trigger_calculate_earnings_on_completion
BEFORE UPDATE ON service_requests
FOR EACH ROW
WHEN (NEW.status = 'completed' AND (OLD.status IS DISTINCT FROM 'completed'))
EXECUTE FUNCTION calculate_earnings_on_completion();

-- ========================================
-- FUNCTION: Calculate Earnings for Job History
-- ========================================
CREATE OR REPLACE FUNCTION calculate_job_history_earnings()
RETURNS TRIGGER AS $$
BEGIN
  -- Calculate earnings when job history record is inserted or updated
  IF NEW.job_status = 'completed' AND NEW.total_amount IS NOT NULL AND NEW.total_amount > 0 THEN
    
    -- Calculate earnings breakdown (75% / 20% / 5%)
    NEW.mechanic_earnings := ROUND(NEW.total_amount * 0.75, 2);
    NEW.shop_earnings := ROUND(NEW.total_amount * 0.20, 2);
    NEW.platform_fee := ROUND(NEW.total_amount * 0.05, 2);
    
    -- Set fee percentages
    NEW.fee_percentage_mechanic := 75.00;
    NEW.fee_percentage_shop := 20.00;
    NEW.fee_percentage_platform := 5.00;
    
    NEW.updated_at := NOW();
    
    RAISE NOTICE '✅ Job history earnings calculated for %: Mechanic=%, Shop=%, Platform=%', 
      NEW.id, NEW.mechanic_earnings, NEW.shop_earnings, NEW.platform_fee;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ========================================
-- TRIGGER: Auto-calculate for mechanic_job_history
-- ========================================
DROP TRIGGER IF EXISTS trigger_calculate_job_history_earnings ON mechanic_job_history;

CREATE TRIGGER trigger_calculate_job_history_earnings
BEFORE INSERT OR UPDATE ON mechanic_job_history
FOR EACH ROW
WHEN (NEW.job_status = 'completed')
EXECUTE FUNCTION calculate_job_history_earnings();

-- ========================================
-- VERIFY TRIGGERS ARE ACTIVE
-- ========================================
SELECT 
  trigger_name,
  event_object_table as table_name,
  action_timing,
  event_manipulation as event,
  action_statement as function
FROM information_schema.triggers
WHERE trigger_schema = 'public'
  AND trigger_name LIKE '%earnings%'
ORDER BY event_object_table, trigger_name;

-- ========================================
-- TEST THE TRIGGERS
-- ========================================
-- Run this to test if triggers work correctly:

DO $$
DECLARE
  test_request_id uuid;
BEGIN
  -- Create a test service request
  INSERT INTO service_requests (
    id,
    customer_id,
    title,
    description,
    pickup_latitude,
    pickup_longitude,
    status,
    final_price,
    shop_id,
    service_type
  ) VALUES (
    gen_random_uuid(),
    (SELECT id FROM user_profiles WHERE user_type = 'customer' LIMIT 1),
    'Test Earnings Calculation',
    'Testing auto-calculation trigger',
    14.5995,
    120.9842,
    'in_progress',
    1000.00,
    (SELECT id FROM shops LIMIT 1),
    'Battery Replacement'
  )
  RETURNING id INTO test_request_id;
  
  -- Update to completed - this should trigger earnings calculation
  UPDATE service_requests 
  SET status = 'completed',
      completed_at = NOW()
  WHERE id = test_request_id;
  
  -- Check if earnings were calculated
  IF EXISTS (
    SELECT 1 FROM service_requests 
    WHERE id = test_request_id 
      AND mechanic_earnings = 750.00 
      AND shop_earnings = 200.00 
      AND platform_fee = 50.00
  ) THEN
    RAISE NOTICE '✅ TRIGGER TEST PASSED! Earnings calculated correctly: M=750, S=200, P=50';
  ELSE
    RAISE EXCEPTION '❌ TRIGGER TEST FAILED! Earnings not calculated correctly';
  END IF;
  
  -- Cleanup test data (delete related records first due to foreign keys)
  DELETE FROM customer_job_history WHERE service_request_id = test_request_id;
  DELETE FROM mechanic_job_history WHERE service_request_id = test_request_id;
  DELETE FROM service_history WHERE request_id = test_request_id;
  DELETE FROM service_requests WHERE id = test_request_id;
  
  RAISE NOTICE '🎉 Trigger test completed and cleaned up!';
END $$;

-- ========================================
-- SUCCESS MESSAGE
-- ========================================
DO $$
BEGIN
    RAISE NOTICE '✅ Auto-earnings triggers installed successfully!';
    RAISE NOTICE '📊 Future completed jobs will auto-calculate: 75%% | 20%% | 5%%';
    RAISE NOTICE '🎉 No more missing earnings data!';
END $$;
