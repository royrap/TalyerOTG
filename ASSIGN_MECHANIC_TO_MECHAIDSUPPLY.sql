-- =========================================================================
-- QUICK FIX: Assign Your Mechanic to MechAid Supply Shop
-- =========================================================================
-- Mechanic User ID: e4cbf14b-5729-45ef-a124-1f2e05acad8c
-- Shop ID: cedc2e63-7785-4d61-a8f1-9f4ed8d254da (MechAid supply)
-- =========================================================================

-- Step 1: Check if mechanic exists in mechanics table
SELECT 
    m.id as mechanic_id,
    m.user_id,
    up.first_name || ' ' || up.last_name as mechanic_name,
    'Mechanic record exists ✅' as status
FROM mechanics m
INNER JOIN user_profiles up ON m.user_id = up.id
WHERE m.user_id = 'e4cbf14b-5729-45ef-a124-1f2e05acad8c';

-- If above returns NO ROWS, run QUICK_POPULATE_MECHANICS.sql first!

-- Step 2: Assign mechanic to shop
DO $$
DECLARE
    v_mechanic_id UUID;
    v_shop_id UUID := 'cedc2e63-7785-4d61-a8f1-9f4ed8d254da'; -- MechAid supply
    v_user_id UUID := 'e4cbf14b-5729-45ef-a124-1f2e05acad8c';
BEGIN
    -- Get mechanic ID from mechanics table
    SELECT id INTO v_mechanic_id
    FROM mechanics
    WHERE user_id = v_user_id;
    
    IF v_mechanic_id IS NULL THEN
        RAISE EXCEPTION '❌ Mechanic not found! Run QUICK_POPULATE_MECHANICS.sql first';
    END IF;
    
    RAISE NOTICE '✅ Mechanic ID: %', v_mechanic_id;
    
    -- Check if already assigned
    IF EXISTS (
        SELECT 1 FROM shop_mechanics 
        WHERE mechanic_id = v_mechanic_id 
        AND shop_id = v_shop_id
    ) THEN
        -- Already assigned, just make sure it's active
        UPDATE shop_mechanics 
        SET is_active = true
        WHERE mechanic_id = v_mechanic_id 
        AND shop_id = v_shop_id;
        
        RAISE NOTICE '✅ Mechanic already assigned to shop - updated to active';
    ELSE
        -- Insert new assignment
        INSERT INTO shop_mechanics (mechanic_id, shop_id, is_active, joined_at)
        VALUES (v_mechanic_id, v_shop_id, true, NOW());
        
        RAISE NOTICE '✅ Mechanic assigned to MechAid supply shop!';
    END IF;
END $$;

-- Step 3: Verify the assignment
SELECT 
    m.id as mechanic_id,
    m.user_id,
    up.first_name || ' ' || up.last_name as mechanic_name,
    s.id as shop_id,
    s.shop_name,
    sm.is_active,
    CASE 
        WHEN sm.is_active = true THEN '✅ Can accept MechAid supply requests'
        ELSE '❌ Cannot accept requests'
    END as acceptance_status
FROM mechanics m
INNER JOIN user_profiles up ON m.user_id = up.id
INNER JOIN shop_mechanics sm ON sm.mechanic_id = m.id
INNER JOIN shops s ON s.id = sm.shop_id
WHERE m.user_id = 'e4cbf14b-5729-45ef-a124-1f2e05acad8c'
AND s.id = 'cedc2e63-7785-4d61-a8f1-9f4ed8d254da';

-- Step 4: Check mechanic availability status
SELECT 
    mas.mechanic_id,
    up.first_name || ' ' || up.last_name as name,
    mas.current_status,
    mas.is_accepting_requests,
    CASE 
        WHEN mas.current_status = 'available' AND mas.is_accepting_requests = true 
        THEN '✅ Ready to receive requests'
        ELSE '❌ Not available'
    END as ready_status
FROM mechanic_availability_status mas
INNER JOIN user_profiles up ON mas.mechanic_id = up.id
WHERE mas.mechanic_id = 'e4cbf14b-5729-45ef-a124-1f2e05acad8c';

-- =========================================================================
-- FINAL CHECKS
-- =========================================================================

-- Show all shop assignments for this mechanic
SELECT 
    'Shop Assignments:' as check_type,
    COUNT(*) as count,
    STRING_AGG(s.shop_name, ', ') as shops
FROM shop_mechanics sm
INNER JOIN shops s ON s.id = sm.shop_id
INNER JOIN mechanics m ON m.id = sm.mechanic_id
WHERE m.user_id = 'e4cbf14b-5729-45ef-a124-1f2e05acad8c'
AND sm.is_active = true;

-- =========================================================================
-- SUCCESS MESSAGE
-- =========================================================================
SELECT '✅ Mechanic assigned to MechAid supply!' as status;
SELECT 'Now restart your Flutter app and test acceptance' as next_step;

/*
DEPLOYMENT ORDER:
================
1. ✅ Run QUICK_POPULATE_MECHANICS.sql (if mechanics table is empty)
2. ✅ Run FIX_SHOP_ISOLATION_COMPLETE.sql (for shop filtering)
3. ✅ Run THIS FILE (assign mechanic to shop)
4. ✅ Restart Flutter app
5. ✅ Test: Customer creates request for MechAid supply
6. ✅ Mechanic should be able to accept! ✅

EXPECTED RESULT:
================
- Mechanic sees request from MechAid supply ✅
- Mechanic can accept request ✅
- No "Shop isolation violation" error ✅
*/
