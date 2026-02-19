-- ========================================
-- 🔧 CREATE SECURITY DEFINER FUNCTIONS
-- ========================================
-- These functions bypass RLS to avoid recursion
-- But still check ownership to maintain security
-- ========================================

-- ========================================
-- FUNCTION 1: Get mechanics for talyer owner's shop
-- ========================================

-- Drop existing function first to allow return type change
DROP FUNCTION IF EXISTS get_shop_mechanics_for_owner();

CREATE OR REPLACE FUNCTION get_shop_mechanics_for_owner()
RETURNS TABLE (
  mechanic_id uuid,
  first_name varchar,
  last_name varchar,
  email varchar,
  phone_number varchar,
  profile_image_url text,
  rating numeric,
  total_reviews integer,
  specialties text[],
  hourly_rate numeric,
  is_active boolean,
  is_available boolean,
  shop_id uuid,
  shop_name varchar
)
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    up.id as mechanic_id,
    up.first_name,
    up.last_name,
    up.email,
    up.phone_number,
    up.profile_image_url,
    up.rating,
    up.total_reviews,
    sm.specialties,
    sm.hourly_rate,
    sm.is_active,
    sm.is_available,
    s.id as shop_id,
    s.shop_name
  FROM user_profiles up
  INNER JOIN shop_mechanics sm ON sm.mechanic_id = up.id
  INNER JOIN shops s ON s.id = sm.shop_id
  WHERE s.owner_id = auth.uid()
  ORDER BY up.first_name, up.last_name;
END;
$$;

-- ========================================
-- FUNCTION 2: Get customers who requested from talyer owner's shop
-- ========================================

CREATE OR REPLACE FUNCTION get_shop_customers_for_owner()
RETURNS TABLE (
  customer_id uuid,
  first_name varchar,
  last_name varchar,
  email varchar,
  phone_number varchar,
  total_requests bigint,
  total_completed bigint
)
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    up.id as customer_id,
    up.first_name,
    up.last_name,
    up.email,
    up.phone_number,
    COUNT(sr.id) as total_requests,
    COUNT(CASE WHEN sr.status = 'completed' THEN 1 END) as total_completed
  FROM user_profiles up
  INNER JOIN service_requests sr ON sr.customer_id = up.id
  INNER JOIN shops s ON s.id = sr.shop_id
  WHERE s.owner_id = auth.uid()
  GROUP BY up.id, up.first_name, up.last_name, up.email, up.phone_number
  ORDER BY up.first_name, up.last_name;
END;
$$;

-- ========================================
-- FUNCTION 3: Get user profile by ID (for talyer owner viewing mechanics/customers)
-- ========================================

CREATE OR REPLACE FUNCTION get_user_profile_for_owner(profile_user_id uuid)
RETURNS TABLE (
  id uuid,
  first_name varchar,
  last_name varchar,
  email varchar,
  phone_number varchar,
  user_type varchar,
  profile_picture_url text
)
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
  -- Check if requesting user owns a shop that this user is connected to
  IF EXISTS (
    SELECT 1 FROM shops s
    INNER JOIN shop_mechanics sm ON sm.shop_id = s.id
    WHERE s.owner_id = auth.uid()
      AND sm.mechanic_id = profile_user_id
  ) OR EXISTS (
    SELECT 1 FROM shops s
    INNER JOIN service_requests sr ON sr.shop_id = s.id
    WHERE s.owner_id = auth.uid()
      AND sr.customer_id = profile_user_id
  ) OR profile_user_id = auth.uid() THEN
    RETURN QUERY
    SELECT 
      up.id,
      up.first_name,
      up.last_name,
      up.email,
      up.phone_number,
      up.user_type,
      up.profile_picture_url
    FROM user_profiles up
    WHERE up.id = profile_user_id;
  END IF;
END;
$$;

-- ========================================
-- VERIFY FUNCTIONS CREATED
-- ========================================

SELECT 
  '=== ✅ SECURITY DEFINER FUNCTIONS CREATED ===' as section;

SELECT 
  routine_name,
  routine_type,
  security_type
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND routine_name IN (
    'get_shop_mechanics_for_owner',
    'get_shop_customers_for_owner',
    'get_user_profile_for_owner'
  )
ORDER BY routine_name;

-- ========================================
-- TEST FUNCTIONS
-- ========================================

SELECT 
  '=== 🧪 TEST: Get mechanics for current user ===' as section;

SELECT * FROM get_shop_mechanics_for_owner();

SELECT 
  '=== 🧪 TEST: Get customers for current user ===' as section;

SELECT * FROM get_shop_customers_for_owner();

-- ========================================
-- SUCCESS MESSAGE
-- ========================================
DO $$
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ SECURITY DEFINER FUNCTIONS CREATED!';
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
    RAISE NOTICE 'Created 3 functions that bypass RLS:';
    RAISE NOTICE '  1. get_shop_mechanics_for_owner()';
    RAISE NOTICE '  2. get_shop_customers_for_owner()';
    RAISE NOTICE '  3. get_user_profile_for_owner(uuid)';
    RAISE NOTICE '';
    RAISE NOTICE 'These functions:';
    RAISE NOTICE '  - Bypass RLS (no recursion!)';
    RAISE NOTICE '  - Still check ownership (secure!)';
    RAISE NOTICE '  - Can be called from Flutter app';
    RAISE NOTICE '';
    RAISE NOTICE 'Usage in Flutter:';
    RAISE NOTICE '  .rpc(''get_shop_mechanics_for_owner'')';
    RAISE NOTICE '  .rpc(''get_shop_customers_for_owner'')';
    RAISE NOTICE '========================================';
END $$;
