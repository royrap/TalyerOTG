-- ====================================================================
-- SERVICE FEE TRACKING SCHEMA UPDATES
-- ====================================================================
-- Purpose: Track service fee payments separately from invoice payments
-- Date: October 7, 2025
-- ====================================================================

-- 1. Add service fee tracking columns to service_requests table
ALTER TABLE service_requests
ADD COLUMN IF NOT EXISTS service_fee_payment_id UUID REFERENCES payments(id),
ADD COLUMN IF NOT EXISTS service_fee_status TEXT DEFAULT 'unpaid'
  CHECK (service_fee_status IN ('unpaid', 'paid', 'refunded', 'failed')),
ADD COLUMN IF NOT EXISTS service_fee_amount DECIMAL(10, 2) DEFAULT 50.00,
ADD COLUMN IF NOT EXISTS service_fee_paid_at TIMESTAMP,
ADD COLUMN IF NOT EXISTS service_fee_payment_method TEXT
  CHECK (service_fee_payment_method IN ('gcash', 'paymaya', 'card', 'online'));

-- 2. Create index for faster queries
CREATE INDEX IF NOT EXISTS idx_service_requests_service_fee_status 
ON service_requests(service_fee_status);

CREATE INDEX IF NOT EXISTS idx_service_requests_service_fee_paid_at 
ON service_requests(service_fee_paid_at);

-- 3. Add completion tracking columns
ALTER TABLE service_requests
ADD COLUMN IF NOT EXISTS completed_at TIMESTAMP,
ADD COLUMN IF NOT EXISTS qr_scanned_at TIMESTAMP,
ADD COLUMN IF NOT EXISTS qr_scanned_by UUID REFERENCES auth.users(id),
ADD COLUMN IF NOT EXISTS completion_verified BOOLEAN DEFAULT FALSE;

-- 4. Create trigger to auto-set completion timestamp
CREATE OR REPLACE FUNCTION set_completion_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status = 'completed' AND OLD.status != 'completed' THEN
    NEW.completed_at = NOW();
    NEW.completion_verified = TRUE;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_set_completion_timestamp ON service_requests;
CREATE TRIGGER trigger_set_completion_timestamp
BEFORE UPDATE ON service_requests
FOR EACH ROW
EXECUTE FUNCTION set_completion_timestamp();

-- 5. Create view for service fee analytics
CREATE OR REPLACE VIEW service_fee_analytics AS
SELECT 
  DATE(service_fee_paid_at) as payment_date,
  COUNT(*) as total_payments,
  SUM(service_fee_amount) as total_amount,
  AVG(service_fee_amount) as avg_amount,
  service_fee_payment_method as payment_method,
  COUNT(CASE WHEN service_fee_status = 'paid' THEN 1 END) as successful_payments,
  COUNT(CASE WHEN service_fee_status = 'failed' THEN 1 END) as failed_payments,
  COUNT(CASE WHEN service_fee_status = 'refunded' THEN 1 END) as refunded_payments
FROM service_requests
WHERE service_fee_paid_at IS NOT NULL
GROUP BY DATE(service_fee_paid_at), service_fee_payment_method
ORDER BY payment_date DESC;

-- 6. Function to update service fee status
CREATE OR REPLACE FUNCTION update_service_fee_status(
  request_id_param UUID,
  payment_id_param UUID,
  status_param TEXT,
  payment_method_param TEXT DEFAULT NULL
)
RETURNS BOOLEAN AS $$
BEGIN
  UPDATE service_requests
  SET 
    service_fee_payment_id = payment_id_param,
    service_fee_status = status_param,
    service_fee_paid_at = CASE WHEN status_param = 'paid' THEN NOW() ELSE service_fee_paid_at END,
    service_fee_payment_method = COALESCE(payment_method_param, service_fee_payment_method),
    updated_at = NOW()
  WHERE id = request_id_param;
  
  RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

-- 7. Add RLS policies for service fee data
CREATE POLICY "Users can view their own service fee status"
ON service_requests FOR SELECT
USING (
  auth.uid() = customer_id OR 
  auth.uid() = provider_id OR
  auth.uid() IN (
    SELECT user_id FROM user_profiles WHERE user_type = 'admin'
  )
);

CREATE POLICY "System can update service fee status"
ON service_requests FOR UPDATE
USING (
  auth.uid() = customer_id OR
  auth.uid() IN (
    SELECT user_id FROM user_profiles WHERE user_type = 'admin'
  )
);

-- ====================================================================
-- VERIFICATION & TESTING
-- ====================================================================

-- Test 1: Check if columns were added
SELECT column_name, data_type, column_default
FROM information_schema.columns
WHERE table_name = 'service_requests'
  AND column_name LIKE '%service_fee%'
ORDER BY ordinal_position;

-- Test 2: Check trigger exists
SELECT trigger_name, event_manipulation, event_object_table
FROM information_schema.triggers
WHERE trigger_name = 'trigger_set_completion_timestamp';

-- Test 3: Check view was created
SELECT viewname FROM pg_views WHERE viewname = 'service_fee_analytics';

-- Test 4: Sample data check
SELECT 
  id,
  customer_id,
  service_fee_status,
  service_fee_amount,
  service_fee_paid_at,
  status
FROM service_requests
LIMIT 5;

-- ====================================================================
-- ROLLBACK (if needed)
-- ====================================================================

/*
-- Uncomment to rollback changes

DROP VIEW IF EXISTS service_fee_analytics;
DROP TRIGGER IF EXISTS trigger_set_completion_timestamp ON service_requests;
DROP FUNCTION IF EXISTS set_completion_timestamp();
DROP FUNCTION IF EXISTS update_service_fee_status(UUID, UUID, TEXT, TEXT);
DROP INDEX IF EXISTS idx_service_requests_service_fee_status;
DROP INDEX IF EXISTS idx_service_requests_service_fee_paid_at;

ALTER TABLE service_requests
DROP COLUMN IF EXISTS service_fee_payment_id,
DROP COLUMN IF EXISTS service_fee_status,
DROP COLUMN IF EXISTS service_fee_amount,
DROP COLUMN IF EXISTS service_fee_paid_at,
DROP COLUMN IF EXISTS service_fee_payment_method,
DROP COLUMN IF EXISTS completed_at,
DROP COLUMN IF EXISTS qr_scanned_at,
DROP COLUMN IF EXISTS qr_scanned_by,
DROP COLUMN IF EXISTS completion_verified;
*/

-- ====================================================================
-- COMPLETE ✅
-- ====================================================================

SELECT '✅ Service fee tracking schema updated successfully!' as status;
