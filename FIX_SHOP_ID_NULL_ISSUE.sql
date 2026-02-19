-- =====================================================
-- FIX: Set shop_id for shop-based requests
-- =====================================================
-- Problem: shop_id is NULL for shop-based requests
-- This causes acceptance to fail
--
-- Solution: Update all pending shop-based requests to have shop_id

-- Step 1: Check current shop-based requests without shop_id
SELECT 
    sr.id,
    sr.request_type,
    sr.shop_id,
    sr.preferred_shop_id,
    sr.status,
    sr.created_at
FROM service_requests sr
WHERE sr.request_type = 'shop_based'
AND sr.shop_id IS NULL
AND sr.status IN ('pending', 'assigned')
ORDER BY sr.created_at DESC;

-- Step 2: Update shop-based requests - copy preferred_shop_id to shop_id
UPDATE service_requests
SET shop_id = preferred_shop_id
WHERE request_type = 'shop_based'
AND shop_id IS NULL
AND preferred_shop_id IS NOT NULL
AND status IN ('pending', 'assigned');

-- Step 3: For requests with routing entries, use the eligible_shop_id
UPDATE service_requests sr
SET shop_id = rr.eligible_shop_id
FROM request_routing rr
WHERE sr.id = rr.request_id
AND sr.request_type = 'shop_based'
AND sr.shop_id IS NULL
AND rr.eligible_shop_id IS NOT NULL
AND sr.status IN ('pending', 'assigned');

-- Step 4: Verify the fix
SELECT 
    sr.id,
    sr.request_type,
    sr.shop_id,
    sr.preferred_shop_id,
    sr.status,
    s.shop_name
FROM service_requests sr
LEFT JOIN shops s ON sr.shop_id = s.id
WHERE sr.request_type = 'shop_based'
AND sr.status IN ('pending', 'assigned')
ORDER BY sr.created_at DESC;

-- Step 5: Create a trigger to auto-set shop_id from preferred_shop_id
CREATE OR REPLACE FUNCTION auto_set_shop_id()
RETURNS TRIGGER AS $$
BEGIN
    -- For shop-based requests, ensure shop_id is set from preferred_shop_id
    IF NEW.request_type = 'shop_based' AND NEW.shop_id IS NULL AND NEW.preferred_shop_id IS NOT NULL THEN
        NEW.shop_id := NEW.preferred_shop_id;
        RAISE NOTICE 'Auto-set shop_id to % for shop-based request', NEW.shop_id;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS trigger_auto_set_shop_id ON service_requests;

-- Create the trigger
CREATE TRIGGER trigger_auto_set_shop_id
    BEFORE INSERT OR UPDATE ON service_requests
    FOR EACH ROW
    EXECUTE FUNCTION auto_set_shop_id();

COMMENT ON FUNCTION auto_set_shop_id IS 
'Automatically sets shop_id from preferred_shop_id for shop-based requests';

-- =====================================================
-- SUMMARY
-- =====================================================
-- 1. Updated existing shop-based requests with NULL shop_id ✅
-- 2. Created trigger to auto-set shop_id for future requests ✅
-- 3. Shop-based requests will now have shop_id populated ✅
