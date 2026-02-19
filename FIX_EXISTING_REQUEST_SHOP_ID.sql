-- =====================================================
-- QUICK FIX: UPDATE OLD REQUEST TO USE SHOP_ID
-- =====================================================
-- This fixes the existing request by copying preferred_shop_id to shop_id

-- Check current state
SELECT 
    id,
    title,
    shop_id,
    preferred_shop_id,
    request_type
FROM service_requests
WHERE id = '1de8e29c-b015-44b1-95f6-8e6c49195b90';

-- Update: Copy preferred_shop_id to shop_id
UPDATE service_requests
SET shop_id = preferred_shop_id
WHERE id = '1de8e29c-b015-44b1-95f6-8e6c49195b90'
AND shop_id IS NULL
AND preferred_shop_id IS NOT NULL;

-- Verify the fix
SELECT 
    id,
    title,
    shop_id,
    preferred_shop_id,
    request_type
FROM service_requests
WHERE id = '1de8e29c-b015-44b1-95f6-8e6c49195b90';

-- Expected: shop_id = cedc2e63-7785-4d61-a8f1-9f4ed8d254da (same as preferred_shop_id)

-- =====================================================
-- NOW: Refresh mechanic app - popup should appear!
-- =====================================================
