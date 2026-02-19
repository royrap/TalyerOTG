-- =====================================================
-- TEST: Manually call accept_request_fifo with logging
-- =====================================================
-- This will show us EXACTLY where the function is failing
-- =====================================================

-- Use the most recent request from the logs: b9e0d0a6-1345-4abe-8ec6-c72cc231d4b5
-- Routing ID: 5cdede57-2703-4154-9e75-768ea8923135
-- Mechanic: e4cbf14b-5729-45ef-a124-1f2e05acad8c (Yuji Fuma)

-- First, verify the current state
SELECT 
    '1. Request State' as step,
    sr.id,
    sr.status,
    sr.assigned_mechanic_id,
    sr.request_type,
    sr.shop_id,
    s.shop_name
FROM service_requests sr
LEFT JOIN shops s ON sr.shop_id = s.id
WHERE sr.id = 'b9e0d0a6-1345-4abe-8ec6-c72cc231d4b5';

SELECT 
    '2. Routing State' as step,
    rr.*
FROM request_routing rr
WHERE rr.id = '5cdede57-2703-4154-9e75-768ea8923135';

SELECT 
    '3. Mechanic Shop' as step,
    mas.mechanic_id,
    mas.shop_id,
    s.shop_name
FROM mechanic_availability_status mas
LEFT JOIN shops s ON mas.shop_id = s.id
WHERE mas.mechanic_id = 'e4cbf14b-5729-45ef-a124-1f2e05acad8c';

-- Now test the function with VERBOSE logging
DO $$
DECLARE
    v_result boolean;
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE 'TESTING accept_request_fifo';
    RAISE NOTICE '========================================';
    
    SELECT accept_request_fifo(
        '5cdede57-2703-4154-9e75-768ea8923135',
        'e4cbf14b-5729-45ef-a124-1f2e05acad8c'
    ) INTO v_result;
    
    RAISE NOTICE '========================================';
    RAISE NOTICE 'RESULT: %', v_result;
    RAISE NOTICE '========================================';
END $$;

-- Check what happened
SELECT 
    '4. Request After Accept' as step,
    sr.id,
    sr.status,
    sr.assigned_mechanic_id
FROM service_requests sr
WHERE sr.id = 'b9e0d0a6-1345-4abe-8ec6-c72cc231d4b5';

SELECT 
    '5. Routing After Accept' as step,
    CASE 
        WHEN COUNT(*) = 0 THEN 'Routing deleted (SUCCESS)'
        ELSE 'Routing still exists (FAILED)'
    END as routing_status,
    COUNT(*) as count
FROM request_routing rr
WHERE rr.id = '5cdede57-2703-4154-9e75-768ea8923135';
