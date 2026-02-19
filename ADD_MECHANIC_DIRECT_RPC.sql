-- =====================================================
-- RPC Function: Add Mechanic Directly to Shop
-- =====================================================
-- This creates a mechanic account immediately without invitation process
-- Run this in your Supabase SQL Editor

CREATE OR REPLACE FUNCTION add_mechanic_to_shop(
  p_email TEXT,
  p_first_name TEXT,
  p_last_name TEXT,
  p_phone TEXT,
  p_specialization TEXT,
  p_years_experience INT,
  p_profile_image_url TEXT
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_shop_owner_id UUID;
  v_shop_id UUID;
  v_shop_name TEXT;
  v_shop_lat DOUBLE PRECISION;
  v_shop_lng DOUBLE PRECISION;
  v_new_mechanic_id UUID;
  v_temp_password TEXT;
BEGIN
  -- Get current user
  v_shop_owner_id := auth.uid();
  IF v_shop_owner_id IS NULL THEN
    RETURN json_build_object('success', FALSE, 'error', 'Not authenticated');
  END IF;

  -- Get shop info
  SELECT id, shop_name, latitude, longitude
  INTO v_shop_id, v_shop_name, v_shop_lat, v_shop_lng
  FROM shops
  WHERE owner_id = v_shop_owner_id
  LIMIT 1;

  IF v_shop_id IS NULL THEN
    RETURN json_build_object('success', FALSE, 'error', 'No shop found');
  END IF;

  -- Check if email exists
  IF EXISTS (SELECT 1 FROM auth.users WHERE email = p_email) THEN
    RETURN json_build_object('success', FALSE, 'error', 'Email already exists');
  END IF;

  -- Generate temp password and user ID
  v_temp_password := encode(gen_random_bytes(9), 'base64');
  v_temp_password := substring(v_temp_password, 1, 12);
  v_new_mechanic_id := gen_random_uuid();

  -- Insert into auth.users (requires proper permissions)
  -- NOTE: This may fail if RLS is too strict. Alternative: Use Supabase Auth API
  BEGIN
    INSERT INTO auth.users (
      id, email, encrypted_password, email_confirmed_at,
      raw_user_meta_data, created_at, updated_at
    ) VALUES (
      v_new_mechanic_id,
      p_email,
      crypt(v_temp_password, gen_salt('bf')),
      NOW(), -- Auto-confirm email
      jsonb_build_object(
        'first_name', p_first_name,
        'last_name', p_last_name,
        'user_type', 'mechanic',
        'talyer_owner_id', v_shop_owner_id,
        'shop_id', v_shop_id
      ),
      NOW(),
      NOW()
    );
  EXCEPTION WHEN OTHERS THEN
    RETURN json_build_object('success', FALSE, 'error', 'Failed to create auth user: ' || SQLERRM);
  END;

  -- Create user profile
  INSERT INTO user_profiles (
    id, first_name, last_name, email, phone_number,
    user_type, profile_image_url, status,
    password_change_required, first_login_completed,
    can_login, shop_id,
    current_latitude, current_longitude,
    created_at, updated_at
  ) VALUES (
    v_new_mechanic_id, p_first_name, p_last_name, p_email, p_phone,
    'mechanic', p_profile_image_url, 'active',
    TRUE, FALSE,
    TRUE, v_shop_id,
    v_shop_lat, v_shop_lng,
    NOW(), NOW()
  );

  -- Create service provider
  INSERT INTO service_providers (
    user_id, company_name, years_experience,
    service_radius, is_verified, is_available,
    current_latitude, current_longitude,
    status, rating, total_reviews,
    talyer_owner_id, shop_id,
    created_at, updated_at
  ) VALUES (
    v_new_mechanic_id, v_shop_name, p_years_experience,
    50.0, TRUE, TRUE,
    v_shop_lat, v_shop_lng,
    'offline', 0.00, 0,
    v_shop_owner_id, v_shop_id,
    NOW(), NOW()
  );

  -- Create shop mechanics entry
  INSERT INTO shop_mechanics (
    shop_id, mechanic_id, role,
    is_active, is_available, specialties,
    joined_at, created_at, updated_at
  ) VALUES (
    v_shop_id, v_new_mechanic_id, 'mechanic',
    TRUE, TRUE, ARRAY[p_specialization],
    NOW(), NOW(), NOW()
  );

  -- Store temporary password
  INSERT INTO temporary_passwords (
    user_id, email, temporary_password, password_hash,
    expires_at, is_active, password_type,
    created_by, created_at
  ) VALUES (
    v_new_mechanic_id, p_email, v_temp_password, v_temp_password,
    NOW() + INTERVAL '30 days', TRUE, 'mechanic_invitation',
    v_shop_owner_id, NOW()
  );

  -- Return success
  RETURN json_build_object(
    'success', TRUE,
    'mechanic_id', v_new_mechanic_id,
    'email', p_email,
    'temporary_password', v_temp_password,
    'message', 'Mechanic added successfully'
  );

EXCEPTION WHEN OTHERS THEN
  RETURN json_build_object('success', FALSE, 'error', SQLERRM);
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION add_mechanic_to_shop TO authenticated;

-- =====================================================
-- TESTING
-- =====================================================
-- Test the function:
-- SELECT * FROM add_mechanic_to_shop(
--   'testmechanic@example.com',
--   'Juan',
--   'Dela Cruz',
--   '+639123456789',
--   'Engine Specialist',
--   5,
--   'https://example.com/image.jpg'
-- );
