-- =====================================================
-- ASSIGN MECHANIC TO SHOP (AGAIN)
-- =====================================================
-- Problem: mechanic_availability_status.shop_id is NULL
-- This causes shop-based requests to fail
--
-- Solution: Set the shop_id for the mechanic

-- Step 1: Check current status
SELECT 
    mechanic_id,
    shop_id,
    current_status,
    is_accepting_requests
FROM mechanic_availability_status
WHERE mechanic_id = 'da0aade5-1e11-4901-898c-3fd67379262f';

-- Step 2: Update mechanic_availability_status with shop_id
UPDATE mechanic_availability_status
SET shop_id = 'cedc2e63-7785-4d61-a8f1-9f4ed8d254da'  -- MechAid supply
WHERE mechanic_id = 'da0aade5-1e11-4901-898c-3fd67379262f';

-- Step 3: Verify the update
SELECT 
    mechanic_id,
    shop_id,
    current_status,
    is_accepting_requests
FROM mechanic_availability_status
WHERE mechanic_id = 'da0aade5-1e11-4901-898c-3fd67379262f';

-- Step 4: Check if entry exists in shop_mechanics
SELECT 
    shop_id,
    mechanic_id,
    role,
    is_active
FROM shop_mechanics
WHERE mechanic_id = 'da0aade5-1e11-4901-898c-3fd67379262f';

-- Step 5: If no entry exists in shop_mechanics, insert it
-- (If entry exists, this will fail with duplicate key error - that's OK!)
INSERT INTO shop_mechanics (shop_id, mechanic_id, role, is_active)
VALUES (
    'cedc2e63-7785-4d61-a8f1-9f4ed8d254da',  -- MechAid supply
    'da0aade5-1e11-4901-898c-3fd67379262f',  -- Your mechanic ID
    'mechanic',
    true
)
ON CONFLICT (shop_id, mechanic_id) DO UPDATE
SET is_active = true;

-- Step 6: Final verification
SELECT 
    mas.mechanic_id,
    mas.shop_id as availability_shop_id,
    sm.shop_id as shop_mechanics_shop_id,
    sm.role,
    sm.is_active,
    s.shop_name
FROM mechanic_availability_status mas
LEFT JOIN shop_mechanics sm ON mas.mechanic_id = sm.mechanic_id
LEFT JOIN shops s ON mas.shop_id = s.id
WHERE mas.mechanic_id = 'da0aade5-1e11-4901-898c-3fd67379262f';

-- =====================================================
-- SUMMARY
-- =====================================================
-- After running this:
-- 1. mechanic_availability_status.shop_id should be set ✅
-- 2. shop_mechanics entry should exist ✅
-- 3. Mechanic can now accept shop-based requests ✅
