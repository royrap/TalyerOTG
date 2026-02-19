-- ============================================================================
-- FIX MECHANIC SHOP ASSIGNMENT
-- ============================================================================
-- This script fixes the mechanic's shop assignment to match incoming requests.
-- Your code is CORRECT - the database data is wrong!
-- ============================================================================

-- Step 1: Find the mechanic's current shop assignment
DO $$
DECLARE
  v_mechanic_id UUID := 'e4cbf14b-5729-45ef-a124-1f2e05acad8c';
  v_mechanic_record_id UUID;
  v_current_shop_id UUID;
  v_target_shop_id UUID := 'cedc2e63-7785-4d61-a8f1-9f4ed8d254da'; -- MechAid supply
BEGIN
  RAISE NOTICE '============================================================================';
  RAISE NOTICE 'FIXING MECHANIC SHOP ASSIGNMENT';
  RAISE NOTICE '============================================================================';
  RAISE NOTICE 'Mechanic User ID: %', v_mechanic_id;
  RAISE NOTICE 'Target Shop ID: %', v_target_shop_id;
  RAISE NOTICE '';

  -- Get mechanics table record ID
  SELECT id, shop_id INTO v_mechanic_record_id, v_current_shop_id
  FROM mechanics
  WHERE user_id = v_mechanic_id;

  IF v_mechanic_record_id IS NULL THEN
    RAISE EXCEPTION 'Mechanic record not found for user_id: %', v_mechanic_id;
  END IF;

  RAISE NOTICE '✓ Found mechanic record ID: %', v_mechanic_record_id;
  RAISE NOTICE '  Current shop_id: %', COALESCE(v_current_shop_id::TEXT, 'NULL');
  RAISE NOTICE '';

  -- Step 2: Update mechanics table shop_id
  UPDATE mechanics
  SET shop_id = v_target_shop_id,
      updated_at = NOW()
  WHERE id = v_mechanic_record_id;

  RAISE NOTICE '✓ Updated mechanics.shop_id to: %', v_target_shop_id;

  -- Step 3: Update or insert into shop_mechanics (junction table)
  -- Note: shop_mechanics.mechanic_id references user_profiles.id (user UUID), not mechanics.id
  -- First, deactivate any existing assignments
  UPDATE shop_mechanics
  SET is_active = false,
      updated_at = NOW()
  WHERE mechanic_id = v_mechanic_id  -- Use user_id, not mechanic record id
    AND is_active = true;

  RAISE NOTICE '✓ Deactivated previous shop_mechanics entries';

  -- Insert or update the new assignment (use user_id for FK constraint)
  INSERT INTO shop_mechanics (mechanic_id, shop_id, is_active, created_at, updated_at)
  VALUES (v_mechanic_id, v_target_shop_id, true, NOW(), NOW())  -- Use user_id
  ON CONFLICT (mechanic_id, shop_id)
  DO UPDATE SET
    is_active = true,
    updated_at = NOW();

  RAISE NOTICE '✓ Assigned mechanic to shop in shop_mechanics table';
  RAISE NOTICE '';

  -- Step 4: Update mechanic_availability_status
  UPDATE mechanic_availability_status
  SET shop_id = v_target_shop_id,
      updated_at = NOW()
  WHERE mechanic_id = v_mechanic_id;

  IF NOT FOUND THEN
    -- Create if doesn't exist
    INSERT INTO mechanic_availability_status (
      mechanic_id, status, shop_id, latitude, longitude, 
      is_accepting_requests, created_at, updated_at
    ) VALUES (
      v_mechanic_id, 'online', v_target_shop_id, 14.932146, 120.8807434,
      true, NOW(), NOW()
    );
    RAISE NOTICE '✓ Created mechanic_availability_status with shop_id';
  ELSE
    RAISE NOTICE '✓ Updated mechanic_availability_status.shop_id to: %', v_target_shop_id;
  END IF;

  RAISE NOTICE '';
  RAISE NOTICE '============================================================================';
  RAISE NOTICE 'SUCCESS: Mechanic now assigned to shop!';
  RAISE NOTICE '============================================================================';
END $$;

-- Verification Query
SELECT 
  '============================================================================' as divider
UNION ALL
SELECT 'VERIFICATION RESULTS'
UNION ALL
SELECT '============================================================================'
UNION ALL
SELECT 'Mechanic Shop Assignment:'
UNION ALL
SELECT '  mechanics.shop_id: ' || COALESCE(m.shop_id::TEXT, 'NULL')
FROM mechanics m
WHERE m.user_id = 'e4cbf14b-5729-45ef-a124-1f2e05acad8c'
UNION ALL
SELECT '  shop_mechanics: ' || COALESCE(sm.shop_id::TEXT, 'NOT ASSIGNED')
FROM mechanics m
LEFT JOIN shop_mechanics sm ON sm.mechanic_id = m.user_id AND sm.is_active = true
WHERE m.user_id = 'e4cbf14b-5729-45ef-a124-1f2e05acad8c'
UNION ALL
SELECT '  mechanic_availability_status.shop_id: ' || COALESCE(mas.shop_id::TEXT, 'NULL')
FROM mechanic_availability_status mas
WHERE mas.mechanic_id = 'e4cbf14b-5729-45ef-a124-1f2e05acad8c'
UNION ALL
SELECT '============================================================================';

-- ============================================================================
-- WHAT THIS DOES:
-- 1. Updates mechanics.shop_id to the target shop
-- 2. Creates/updates shop_mechanics junction table entry
-- 3. Updates mechanic_availability_status.shop_id
-- 4. Verifies the changes
--
-- RESULT:
-- ✅ Mechanic can now accept requests from the assigned shop
-- ✅ Mechanic won't see requests from other shops (shop isolation enforced)
-- ✅ Your Flutter code will work correctly (it's already correct!)
-- ============================================================================
