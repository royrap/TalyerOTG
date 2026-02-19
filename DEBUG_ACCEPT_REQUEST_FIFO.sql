-- =====================================================
-- DEBUG: Check what's happening in accept_request_fifo
-- =====================================================
-- Run this to see detailed debug information
-- =====================================================

-- Step 1: Check the current request and routing state
SELECT 
    'Current Request State' as info,
    sr.id as request_id,
    sr.status,
    sr.assigned_mechanic_id,
    sr.request_type,
    sr.shop_id,
    sr.created_at
FROM service_requests sr
WHERE sr.id = 'd501e999-b0ae-4f29-b148-da499c78cfe4';

-- Step 2: Check the routing entry
SELECT 
    'Routing Entry' as info,
    rr.id as routing_id,
    rr.request_id,
    rr.eligible_mechanic_id,
    rr.routing_type,
    rr.is_notified,
    rr.created_at
FROM request_routing rr
WHERE rr.id = '4eac3c4b-2d24-4cdf-92fc-d22ee91a74f3';

-- Step 3: Check mechanic shop assignment
SELECT 
    'Mechanic Shop Assignment' as info,
    mas.mechanic_id,
    mas.shop_id,
    mas.current_status,
    mas.is_accepting_requests
FROM mechanic_availability_status mas
WHERE mas.mechanic_id = 'da0aade5-1e11-4901-898c-3fd67379262f';

-- Step 4: Manually test the accept_request_fifo function with VERBOSE logging
DO $$
DECLARE
    v_result boolean;
BEGIN
    -- Enable detailed logging
    SET client_min_messages TO NOTICE;
    
    -- Call the function
    SELECT accept_request_fifo(
        '4eac3c4b-2d24-4cdf-92fc-d22ee91a74f3',
        'da0aade5-1e11-4901-898c-3fd67379262f'
    ) INTO v_result;
    
    RAISE NOTICE '========================================';
    RAISE NOTICE 'FINAL RESULT: %', v_result;
    RAISE NOTICE '========================================';
END $$;

-- Step 5: Check if the request was actually assigned
SELECT 
    'After Acceptance Attempt' as info,
    sr.id as request_id,
    sr.status,
    sr.assigned_mechanic_id,
    sr.assigned_at
FROM service_requests sr
WHERE sr.id = 'd501e999-b0ae-4f29-b148-da499c78cfe4';

-- Step 6: Check if routing entry was deleted
SELECT 
    'Routing Entry After' as info,
    COUNT(*) as routing_entries_remaining
FROM request_routing rr
WHERE rr.id = '4eac3c4b-2d24-4cdf-92fc-d22ee91a74f3';
