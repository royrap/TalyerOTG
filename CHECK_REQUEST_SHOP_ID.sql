-- =====================================================
-- CRITICAL: Check the ACTUAL service request data
-- =====================================================

-- Get complete details of the problematic request
SELECT 
    'Full Request Details' as info,
    sr.*
FROM service_requests sr
WHERE sr.id = 'd501e999-b0ae-4f29-b148-da499c78cfe4';

-- Check if there's a mismatch in the request_routing table
SELECT 
    'Routing Details' as info,
    rr.*
FROM request_routing rr
WHERE rr.request_id = 'd501e999-b0ae-4f29-b148-da499c78cfe4';

-- Key question: Is shop_id NULL in service_requests?
SELECT 
    CASE 
        WHEN sr.shop_id IS NULL THEN '❌ PROBLEM: shop_id is NULL in service_requests'
        ELSE '✅ OK: shop_id is set to: ' || sr.shop_id::text
    END as shop_id_status,
    sr.id as request_id,
    sr.request_type,
    sr.shop_id,
    sr.status
FROM service_requests sr
WHERE sr.id = 'd501e999-b0ae-4f29-b148-da499c78cfe4';
