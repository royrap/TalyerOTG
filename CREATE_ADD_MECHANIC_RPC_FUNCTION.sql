-- =====================================================
-- RPC Function to Add Mechanic to Shop
-- =====================================================
-- This function allows shop owners to add mechanics to their shop
-- It handles user creation, profile setup, and all necessary table entries
-- Usage: SELECT * FROM add_mechanic_to_shop('email@example.com', 'John', 'Doe', '+639123456789', 'Engine Specialist', 5, 'https://...');

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
SECURITY DEFINER -- Runs with function owner's permissions (bypasses RLS)
AS $$
DECLARE
  v_shop_owner_id UUID;
  v_shop_id UUID;
  v_shop_name TEXT;
  v_shop_lat DOUBLE PRECISION;
  v_shop_lng DOUBLE PRECISION;
  v_new_mechanic_id UUID;
  v_temp_password TEXT;
  v_password_hash TEXT;
  v_verification_token TEXT;
BEGIN
  -- Get the current authenticated user (shop owner)
  v_shop_owner_id := auth.uid();
  
  IF v_shop_owner_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Verify this user is a shop owner and get their shop
  SELECT id, shop_name, latitude, longitude
  INTO v_shop_id, v_shop_name, v_shop_lat, v_shop_lng
  FROM shops
  WHERE owner_id = v_shop_owner_id
  LIMIT 1;

  IF v_shop_id IS NULL THEN
    RAISE EXCEPTION 'No shop found for current user';
  END IF;

  -- Check if email already exists
  IF EXISTS (SELECT 1 FROM auth.users WHERE email = p_email) THEN
    RAISE EXCEPTION 'A user with this email already exists';
  END IF;

  -- Generate a temporary password (12 random characters)
  v_temp_password := encode(gen_random_bytes(9), 'base64');
  v_temp_password := substring(v_temp_password, 1, 12);

  -- Generate password hash (bcrypt with cost 10)
  v_password_hash := crypt(v_temp_password, gen_salt('bf', 10));

  -- Generate verification token
  v_verification_token := encode(gen_random_bytes(32), 'hex');

  -- Create auth user using INSERT (since we don't have admin API access in SQL)
  -- NOTE: This requires the 'pgsodium' extension and proper permissions
  INSERT INTO auth.users (
    instance_id,
    id,
    aud,
    role,
    email,
    encrypted_password,
    email_confirmed_at,
    raw_app_meta_data,
    raw_user_meta_data,
    created_at,
    updated_at,
    confirmation_token,
    email_change,
    email_change_token_new,
    recovery_token
  ) VALUES (
    '00000000-0000-0000-0000-000000000000',
    gen_random_uuid(),
    'authenticated',
    'authenticated',
    p_email,
    v_password_hash,
    NULL, -- Email not confirmed yet
    jsonb_build_object('provider', 'email', 'providers', ARRAY['email']),
    jsonb_build_object(
      'first_name', p_first_name, 
      'last_name', p_last_name, 
      'user_type', 'mechanic',
      'talyer_owner_id', v_shop_owner_id,
      'shop_id', v_shop_id
    ),
    NOW(),
    NOW(),
    v_verification_token,
    '',
    '',
    ''
  )
  RETURNING id INTO v_new_mechanic_id;

  -- Create user profile
  INSERT INTO user_profiles (
    id,
    first_name,
    last_name,
    email,
    phone_number,
    user_type,
    profile_image_url,
    status,
    password_change_required,
    first_login_completed,
    requires_email_verification,
    can_login,
    shop_id,
    current_latitude,
    current_longitude,
    created_at,
    updated_at
  ) VALUES (
    v_new_mechanic_id,
    p_first_name,
    p_last_name,
    p_email,
    p_phone,
    'mechanic',
    p_profile_image_url,
    'active',
    TRUE,
    FALSE,
    TRUE,
    FALSE, -- Cannot login until email verified
    v_shop_id,
    v_shop_lat,
    v_shop_lng,
    NOW(),
    NOW()
  );

  -- Create service provider entry
  INSERT INTO service_providers (
    user_id,
    company_name,
    years_experience,
    service_radius,
    is_verified,
    is_available,
    current_latitude,
    current_longitude,
    status,
    rating,
    total_reviews,
    talyer_owner_id,
    shop_id,
    created_at,
    updated_at
  ) VALUES (
    v_new_mechanic_id,
    v_shop_name,
    p_years_experience,
    50.0,
    TRUE,
    TRUE,
    v_shop_lat,
    v_shop_lng,
    'offline',
    0.00,
    0,
    v_shop_owner_id,
    v_shop_id,
    NOW(),
    NOW()
  );

  -- Create shop mechanics entry
  INSERT INTO shop_mechanics (
    shop_id,
    mechanic_id,
    role,
    is_active,
    is_available,
    specialties,
    joined_at,
    created_at,
    updated_at
  ) VALUES (
    v_shop_id,
    v_new_mechanic_id,
    'mechanic',
    TRUE,
    TRUE,
    ARRAY[p_specialization],
    NOW(),
    NOW(),
    NOW()
  );

  -- Store temporary password
  INSERT INTO temporary_passwords (
    user_id,
    email,
    temporary_password,
    password_hash,
    expires_at,
    is_active,
    password_type,
    created_by,
    created_at
  ) VALUES (
    v_new_mechanic_id,
    p_email,
    v_temp_password,
    v_temp_password, -- Store plaintext for email (in production, only send via email, don't store)
    NOW() + INTERVAL '7 days',
    TRUE,
    'mechanic_invitation',
    v_shop_owner_id,
    NOW()
  );

  -- Create email verification token
  INSERT INTO email_verification_tokens (
    user_id,
    new_email,
    token,
    token_type,
    expires_at,
    is_active,
    created_at
  ) VALUES (
    v_new_mechanic_id,
    p_email,
    v_verification_token,
    'registration',
    NOW() + INTERVAL '7 days',
    TRUE,
    NOW()
  );

  -- Create email notification (to be sent by a background job)
  INSERT INTO email_notifications (
    recipient_user_id,
    sender_user_id,
    email_type,
    recipient_email,
    subject,
    body,
    priority,
    created_at
  ) VALUES (
    v_new_mechanic_id,
    v_shop_owner_id,
    'welcome_mechanic',
    p_email,
    'Welcome to ' || v_shop_name || ' - RoadAid Mechanic Account',
    'Hello ' || p_first_name || ' ' || p_last_name || E',\n\n' ||
    'Welcome to ' || v_shop_name || E'!\n\n' ||
    'You have been added as a mechanic.\n\n' ||
    'Your login credentials:\n' ||
    'Email: ' || p_email || E'\n' ||
    'Temporary Password: ' || v_temp_password || E'\n\n' ||
    E'IMPORTANT STEPS:\n' ||
    E'1. Verify your email by clicking the verification link (sent separately)\n' ||
    E'2. Download the RoadAid Mechanic App\n' ||
    E'3. Login with your credentials\n' ||
    E'4. You will be required to change your password on first login\n\n' ||
    'Please complete these steps within 7 days.\n\n' ||
    'Welcome to the team!\n\n' ||
    'Best regards,\n' ||
    'RoadAid Team',
    'high',
    NOW()
  );

  -- Return success response with mechanic ID and temporary password
  RETURN json_build_object(
    'success', TRUE,
    'mechanic_id', v_new_mechanic_id,
    'email', p_email,
    'temporary_password', v_temp_password,
    'message', 'Mechanic added successfully'
  );

EXCEPTION
  WHEN OTHERS THEN
    -- Return error response
    RETURN json_build_object(
      'success', FALSE,
      'error', SQLERRM
    );
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION add_mechanic_to_shop TO authenticated;

-- =====================================================
-- USAGE EXAMPLE:
-- =====================================================
-- SELECT * FROM add_mechanic_to_shop(
--   'mechanic@example.com',
--   'Juan',
--   'Dela Cruz',
--   '+639123456789',
--   'Engine Specialist',
--   5,
--   'https://storage.supabase.co/path/to/image.jpg'
-- );
