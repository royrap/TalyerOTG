-- =====================================================
-- TEST: Manually test accept_request_fifo function
-- =====================================================

-- First, let's see what we have
SELECT 
    rr.id as routing_id,
    rr.request_id,
    rr.routing_type,
    rr.eligible_mechanic_id,
    sr.request_type,
    sr.shop_id,
    sr.status,
    sr.assigned_mechanic_id,
    mas.shop_id as mechanic_shop_id,
    mas.mechanic_id
FROM request_routing rr
JOIN service_requests sr ON rr.request_id = sr.id
LEFT JOIN mechanic_availability_status mas ON rr.eligible_mechanic_id = mas.mechanic_id
WHERE sr.id = '4b22a8de-cf59-408b-8845-1fc3b33dd196'
ORDER BY rr.created_at DESC;

-- Test the function with actual values
-- Replace these with your actual values from the logs:
-- routing_id: e3c350bb-3a92-4711-82fc-6871b423d65f
-- mechanic_id: da0aade5-1e11-4901-898c-3fd67379262f

SELECT accept_request_fifo(
    'e3c350bb-3a92-4711-82fc-6871b423d65f',
    'da0aade5-1e11-4901-898c-3fd67379262f'
);

-- Check if anything changed
SELECT 
    id,
    status,
    assigned_mechanic_id,
    request_type,
    shop_id
FROM service_requests
WHERE id = '4b22a8de-cf59-408b-8845-1fc3b33dd196';

-- Check mechanic status
SELECT 
    mechanic_id,
    current_status,
    current_request_id,
    is_accepting_requests,
    shop_id
FROM mechanic_availability_status
WHERE mechanic_id = 'da0aade5-1e11-4901-898c-3fd67379262f';
