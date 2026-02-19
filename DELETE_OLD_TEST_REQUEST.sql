-- =====================================================
-- DELETE OLD TEST REQUEST WITH NULL SHOP_ID
-- =====================================================
-- This request was created with the bug (using preferred_shop_id instead of shop_id)

-- First, check what we're deleting
SELECT 
    id,
    title,
    shop_id,
    preferred_shop_id,
    request_type,
    created_at
FROM service_requests
WHERE id = '1de8e29c-b015-44b1-95f6-8e6c49195b90';

-- Expected: shop_id = NULL, preferred_shop_id = cedc2e63...

-- Delete related records first
DELETE FROM request_routing 
WHERE request_id = '1de8e29c-b015-44b1-95f6-8e6c49195b90';

DELETE FROM notifications
WHERE data->>'request_id' = '1de8e29c-b015-44b1-95f6-8e6c49195b90';

-- Now delete the service request
DELETE FROM service_requests
WHERE id = '1de8e29c-b015-44b1-95f6-8e6c49195b90';

-- Verify deletion
SELECT COUNT(*) as remaining_requests
FROM service_requests
WHERE id = '1de8e29c-b015-44b1-95f6-8e6c49195b90';

-- Expected: 0

-- =====================================================
-- NOW: 
-- 1. FULLY RESTART CUSTOMER APP (press 'q' then run again)
-- 2. Create new shop-based request
-- 3. It will have shop_id populated correctly!
-- =====================================================
