-- =====================================================
-- TEST: Manually test the UPDATE that's failing
-- =====================================================

-- First, check the current request
SELECT 
    id,
    status,
    assigned_mechanic_id,
    request_type,
    shop_id
FROM service_requests
WHERE id = '4648531c-2a22-49b2-aa2e-695307d63a82';

-- Test the UPDATE directly (this is what the function does)
-- This should trigger the validate_mechanic_shop_assignment trigger
UPDATE service_requests 
SET 
    assigned_mechanic_id = 'da0aade5-1e11-4901-898c-3fd67379262f',
    status = 'assigned',
    assigned_at = NOW(),
    updated_at = NOW()
WHERE id = '4648531c-2a22-49b2-aa2e-695307d63a82'
AND status = 'pending' 
AND assigned_mechanic_id IS NULL;

-- If this fails, we'll see the error from the trigger
-- If it succeeds, check the result
SELECT 
    id,
    status,
    assigned_mechanic_id,
    request_type,
    shop_id
FROM service_requests
WHERE id = '4648531c-2a22-49b2-aa2e-695307d63a82';
