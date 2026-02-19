-- ============================================================================
-- FIX SECOND MECHANIC SHOP ASSIGNMENT
-- ============================================================================
-- Assign mechanic da0aade5-1e11-4901-898c-3fd67379262f to MechAid supply shop
-- ============================================================================

DO $$
DECLARE
  v_mechanic_id UUID := 'da0aade5-1e11-4901-898c-3fd67379262f';
  v_mechanic_record_id UUID;
  v_current_shop_id UUID;
  v_target_shop_id UUID := 'cedc2e63-7785-4d61-a8f1-9f4ed8d254da'; -- MechAid supply
BEGIN
  RAISE NOTICE '============================================================================';
  RAISE NOTICE 'FIXING SECOND MECHANIC SHOP ASSIGNMENT';
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
  UPDATE shop_mechanics
  SET is_active = false,
      updated_at = NOW()
  WHERE mechanic_id = v_mechanic_id
    AND is_active = true;

  RAISE NOTICE '✓ Deactivated previous shop_mechanics entries';

  INSERT INTO shop_mechanics (mechanic_id, shop_id, is_active, created_at, updated_at)
  VALUES (v_mechanic_id, v_target_shop_id, true, NOW(), NOW())
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
    INSERT INTO mechanic_availability_status (
      mechanic_id, status, shop_id, latitude, longitude, 
      is_accepting_requests, created_at, updated_at
    ) VALUES (
      v_mechanic_id, 'online', v_target_shop_id, 14.932127, 120.880688,
      true, NOW(), NOW()
    );
    RAISE NOTICE '✓ Created mechanic_availability_status with shop_id';
  ELSE
    RAISE NOTICE '✓ Updated mechanic_availability_status.shop_id to: %', v_target_shop_id;
  END IF;

  RAISE NOTICE '';
  RAISE NOTICE '============================================================================';
  RAISE NOTICE 'SUCCESS: Second mechanic now assigned to shop!';
  RAISE NOTICE '============================================================================';
END $$;

-- Verification Query
SELECT 
  '============================================================================' as divider
UNION ALL
SELECT 'VERIFICATION RESULTS - SECOND MECHANIC'
UNION ALL
SELECT '============================================================================'
UNION ALL
SELECT '  mechanics.shop_id: ' || COALESCE(m.shop_id::TEXT, 'NULL')
FROM mechanics m
WHERE m.user_id = 'da0aade5-1e11-4901-898c-3fd67379262f'
UNION ALL
SELECT '  shop_mechanics: ' || COALESCE(sm.shop_id::TEXT, 'NOT ASSIGNED')
FROM mechanics m
LEFT JOIN shop_mechanics sm ON sm.mechanic_id = m.user_id AND sm.is_active = true
WHERE m.user_id = 'da0aade5-1e11-4901-898c-3fd67379262f'
UNION ALL
SELECT '  mechanic_availability_status.shop_id: ' || COALESCE(mas.shop_id::TEXT, 'NULL')
FROM mechanic_availability_status mas
WHERE mas.mechanic_id = 'da0aade5-1e11-4901-898c-3fd67379262f'
UNION ALL
SELECT '============================================================================';

-- ============================================================================
-- Now you have TWO mechanics assigned to MechAid supply:
-- 1. e4cbf14b-5729-45ef-a124-1f2e05acad8c (yujirofuma28@gmail.com)
-- 2. da0aade5-1e11-4901-898c-3fd67379262f (current login)
--
-- Both can now accept requests from MechAid supply shop!
-- ============================================================================

-- ============================================================================
-- ADDITIONAL ASSIGNMENTS: Assign mechanics to another shop
-- ============================================================================
-- The user requested adding the following mechanics to shop:
--   shop_id: 5d963bdf-1879-4575-9375-df62b1ff3fe0
--   mechanics: a0b3d937-12ff-400c-9c60-ae5203f4e0ff, e4cbf14b-5729-45ef-a124-1f2e05acad8c
-- This will upsert entries in shop_mechanics (use mechanic user UUIDs as FK)

DO $$
DECLARE
  v_shop_id UUID := '5d963bdf-1879-4575-9375-df62b1ff3fe0';
  v_mech_a UUID := 'a0b3d937-12ff-400c-9c60-ae5203f4e0ff';
  v_mech_b UUID := 'e4cbf14b-5729-45ef-a124-1f2e05acad8c';
BEGIN
  RAISE NOTICE '============================================================================';
  RAISE NOTICE 'ADDING ADDITIONAL SHOP_ASSIGNMENTS';
  RAISE NOTICE 'Target shop: %', v_shop_id;
  RAISE NOTICE 'Mechanics: %, %', v_mech_a, v_mech_b;

  -- Upsert mechanic A
  INSERT INTO shop_mechanics (mechanic_id, shop_id, is_active, created_at, updated_at)
  VALUES (v_mech_a, v_shop_id, true, NOW(), NOW())
  ON CONFLICT (mechanic_id, shop_id)
  DO UPDATE SET is_active = true, updated_at = NOW();

  -- Upsert mechanic B
  INSERT INTO shop_mechanics (mechanic_id, shop_id, is_active, created_at, updated_at)
  VALUES (v_mech_b, v_shop_id, true, NOW(), NOW())
  ON CONFLICT (mechanic_id, shop_id)
  DO UPDATE SET is_active = true, updated_at = NOW();

  RAISE NOTICE '✓ Inserted/activated mechanics for shop %', v_shop_id;
END $$;

-- Verification for the additional assignments
SELECT 'ADDITIONAL ASSIGNMENT VERIFICATION' AS info;
SELECT mechanic_id, shop_id, is_active
FROM shop_mechanics
WHERE shop_id = '5d963bdf-1879-4575-9375-df62b1ff3fe0'
  AND mechanic_id IN (
    'a0b3d937-12ff-400c-9c60-ae5203f4e0ff',
    'e4cbf14b-5729-45ef-a124-1f2e05acad8c'
  );

-- ============================================================================
-- AUTO-ASSIGN TRIGGER: Ensure future mechanics are also assigned to these shops
-- ============================================================================
-- This trigger will automatically create/activate shop_mechanics entries for
-- any newly inserted row in `mechanics` using the mechanics.user_id as the FK.
-- Default shops: MechAid supply and the other shop provided by the user.
-- ============================================================================

CREATE OR REPLACE FUNCTION auto_assign_new_mechanic_to_default_shops()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  default_shops UUID[] := ARRAY[
    'cedc2e63-7785-4d61-a8f1-9f4ed8d254da', -- MechAid supply
    '5d963bdf-1879-4575-9375-df62b1ff3fe0'  -- Additional shop requested
  ];
  s UUID;
BEGIN
  -- Use NEW.user_id because shop_mechanics.mechanic_id references user_profiles.id
  FOREACH s IN ARRAY default_shops LOOP
    INSERT INTO shop_mechanics (mechanic_id, shop_id, is_active, created_at, updated_at)
    VALUES (NEW.user_id, s, true, NOW(), NOW())
    ON CONFLICT (mechanic_id, shop_id)
    DO UPDATE SET is_active = true, updated_at = NOW();
  END LOOP;

  RETURN NEW;
END;
$$;

-- Attach trigger to mechanics table
DROP TRIGGER IF EXISTS trg_auto_assign_mechanic ON mechanics;
CREATE TRIGGER trg_auto_assign_mechanic
AFTER INSERT ON mechanics
FOR EACH ROW
EXECUTE FUNCTION auto_assign_new_mechanic_to_default_shops();


