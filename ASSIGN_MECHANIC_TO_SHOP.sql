-- =====================================================
-- ASSIGN MECHANIC TO SHOP
-- =====================================================
-- This assigns Rafael's mechanic account to a shop
-- so he can receive shop-based service requests

-- =====================================================
-- Step 1: Check available shops
-- =====================================================
SELECT 
    id as shop_id,
    shop_name,
    owner_id,
    shop_address,
    is_active,
    current_status
FROM shops
ORDER BY shop_name;

-- =====================================================
-- Step 2: Assign mechanic to a shop
-- =====================================================
-- Choose which shop you want (replace the shop_id below)
-- Option 1: MechAid supply
-- Option 2: riza store

-- Update mechanic_availability_status with shop assignment
UPDATE mechanic_availability_status
SET 
    shop_id = (
        SELECT id 
        FROM shops 
        WHERE shop_name = 'MechAid supply'  -- Change this to 'riza store' if you want the other shop
        LIMIT 1
    ),
    updated_at = now()
WHERE mechanic_id = 'da0aade5-1e11-4901-898c-3fd67379262f';

-- =====================================================
-- Step 3: Verify the assignment
-- =====================================================
SELECT 
    up.id as mechanic_id,
    up.first_name,
    up.last_name,
    mas.shop_id,
    s.shop_name,
    mas.current_status,
    mas.is_accepting_requests
FROM user_profiles up
INNER JOIN mechanic_availability_status mas ON up.id = mas.mechanic_id
LEFT JOIN shops s ON mas.shop_id = s.id
WHERE up.id = 'da0aade5-1e11-4901-898c-3fd67379262f';

-- =====================================================
-- Step 4: Also add to shop_mechanics table (for better tracking)
-- =====================================================
INSERT INTO shop_mechanics (
    shop_id,
    mechanic_id,
    role,
    is_active,
    is_available,
    joined_at
)
SELECT 
    s.id as shop_id,
    'da0aade5-1e11-4901-898c-3fd67379262f' as mechanic_id,
    'mechanic' as role,
    true as is_active,
    true as is_available,
    now() as joined_at
FROM shops s
WHERE s.shop_name = 'MechAid supply'  -- Change this to match Step 2
AND NOT EXISTS (
    SELECT 1 FROM shop_mechanics sm
    WHERE sm.mechanic_id = 'da0aade5-1e11-4901-898c-3fd67379262f'
    AND sm.shop_id = s.id
);

-- =====================================================
-- Step 5: Final verification
-- =====================================================
SELECT 
    sm.id,
    sm.shop_id,
    s.shop_name,
    sm.mechanic_id,
    up.first_name || ' ' || up.last_name as mechanic_name,
    sm.role,
    sm.is_active,
    sm.is_available
FROM shop_mechanics sm
INNER JOIN shops s ON sm.shop_id = s.id
INNER JOIN user_profiles up ON sm.mechanic_id = up.id
WHERE sm.mechanic_id = 'da0aade5-1e11-4901-898c-3fd67379262f';

-- =====================================================
-- TESTING: Create a shop-based request
-- =====================================================
-- After running the above, test by:
-- 1. Customer app: Click on "MechAid supply" shop card
-- 2. Select a service and submit
-- 3. Mechanic app: You should now see the popup! ✅

-- =====================================================
-- NOTES
-- =====================================================
-- ✅ Shop-based requests: Only mechanics assigned to that shop will see it
-- ✅ Location-based requests: Any available mechanic can see it (regardless of shop)
-- ✅ The trigger now properly enforces shop isolation for shop-based requests only
