-- =====================================================
-- CLEANUP: Remove duplicate/wrong shop_mechanics entries
-- =====================================================
-- Problem: Mechanic has 2 entries in shop_mechanics
-- One pointing to wrong shop (riza store)
-- One pointing to correct shop (MechAid supply)
--
-- Solution: Keep only the MechAid supply entry

-- Step 1: See all entries
SELECT 
    shop_id,
    mechanic_id,
    role,
    is_active,
    created_at
FROM shop_mechanics
WHERE mechanic_id = 'da0aade5-1e11-4901-898c-3fd67379262f'
ORDER BY created_at;

-- Step 2: Delete the wrong entry (riza store)
DELETE FROM shop_mechanics
WHERE mechanic_id = 'da0aade5-1e11-4901-898c-3fd67379262f'
AND shop_id = '5d963bdf-1879-4575-9375-df62b1ff3fe0';

-- Step 3: Verify only correct entry remains
SELECT 
    shop_id,
    mechanic_id,
    role,
    is_active
FROM shop_mechanics
WHERE mechanic_id = 'da0aade5-1e11-4901-898c-3fd67379262f';

-- Step 4: Final check - should see only MechAid supply
SELECT 
    mas.mechanic_id,
    mas.shop_id as availability_shop_id,
    sm.shop_id as shop_mechanics_shop_id,
    sm.role,
    sm.is_active,
    s.shop_name
FROM mechanic_availability_status mas
LEFT JOIN shop_mechanics sm ON mas.mechanic_id = sm.mechanic_id AND mas.shop_id = sm.shop_id
LEFT JOIN shops s ON mas.shop_id = s.id
WHERE mas.mechanic_id = 'da0aade5-1e11-4901-898c-3fd67379262f';

-- =====================================================
-- Now try to accept the request again!
-- =====================================================
-- The mechanic should now be properly assigned to only one shop
