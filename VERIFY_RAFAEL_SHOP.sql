-- =====================================================
-- VERIFY MECHANIC RAFAEL PINEDA SHOP ASSIGNMENT
-- =====================================================

-- Check Rafael's shop assignment
SELECT 
    'Rafael Pineda Shop Assignment' as info,
    mas.mechanic_id,
    mas.shop_id,
    s.shop_name,
    mas.current_status,
    mas.is_accepting_requests
FROM mechanic_availability_status mas
LEFT JOIN shops s ON mas.shop_id = s.id
WHERE mas.mechanic_id = 'da0aade5-1e11-4901-898c-3fd67379262f';

-- Check if Rafael is in shop_mechanics table
SELECT 
    'Rafael in shop_mechanics' as info,
    sm.mechanic_id,
    sm.shop_id,
    s.shop_name,
    sm.is_active,
    sm.joined_at
FROM shop_mechanics sm
LEFT JOIN shops s ON sm.shop_id = s.id
WHERE sm.mechanic_id = 'da0aade5-1e11-4901-898c-3fd67379262f';

-- Check the request shop
SELECT 
    'Request Shop' as info,
    sr.id as request_id,
    sr.shop_id,
    s.shop_name,
    sr.request_type
FROM service_requests sr
LEFT JOIN shops s ON sr.shop_id = s.id
WHERE sr.id = 'd501e999-b0ae-4f29-b148-da499c78cfe4';

-- CRITICAL CHECK: Does Rafael belong to the same shop as the request?
SELECT 
    CASE 
        WHEN mas.shop_id = sr.shop_id THEN '✅ MATCH: Rafael belongs to request shop'
        WHEN mas.shop_id IS NULL THEN '❌ Rafael has NO shop assigned'
        ELSE '❌ MISMATCH: Rafael does NOT belong to request shop'
    END as shop_match_status,
    mas.shop_id as rafael_shop,
    sr.shop_id as request_shop,
    mas_shop.shop_name as rafael_shop_name,
    req_shop.shop_name as request_shop_name
FROM mechanic_availability_status mas
CROSS JOIN service_requests sr
LEFT JOIN shops mas_shop ON mas.shop_id = mas_shop.id
LEFT JOIN shops req_shop ON sr.shop_id = req_shop.id
WHERE mas.mechanic_id = 'da0aade5-1e11-4901-898c-3fd67379262f'
AND sr.id = 'd501e999-b0ae-4f29-b148-da499c78cfe4';
