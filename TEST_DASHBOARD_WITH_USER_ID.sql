-- ========================================
-- 🧪 TEST VERSION: Dashboard Stats with User ID Parameter
-- ========================================
-- For testing in SQL Editor - accepts user_id as parameter
-- ========================================

-- Drop test function if exists
DROP FUNCTION IF EXISTS test_dashboard_stats(uuid);

CREATE OR REPLACE FUNCTION test_dashboard_stats(test_user_id uuid)
RETURNS TABLE (
  -- Shop Info
  shop_id uuid,
  shop_name text,
  shop_address text,
  shop_phone text,
  shop_status text,
  
  -- Mechanic Stats
  total_mechanics bigint,
  available_mechanics bigint,
  busy_mechanics bigint,
  
  -- Job Stats
  total_jobs bigint,
  active_jobs bigint,
  completed_jobs bigint,
  pending_requests bigint,
  
  -- Earnings Stats
  total_earnings numeric,
  today_earnings numeric,
  this_week_earnings numeric,
  this_month_earnings numeric,
  
  -- Customer Stats
  total_customers bigint,
  active_customers_today bigint,
  
  -- Rating Stats
  average_shop_rating numeric,
  total_shop_reviews integer
)
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
  v_shop_id uuid;
BEGIN
  -- Use provided test_user_id instead of auth.uid()
  SELECT s.id INTO v_shop_id
  FROM shops s
  WHERE s.owner_id = test_user_id;
  
  IF v_shop_id IS NULL THEN
    RAISE EXCEPTION 'No shop found for user ID: %', test_user_id;
  END IF;
  
  RETURN QUERY
  SELECT 
    -- Shop Info
    s.id as shop_id,
    s.shop_name::text,
    s.shop_address::text,
    s.shop_phone::text,
    s.current_status::text,
    
    -- Mechanic Stats
    (SELECT COUNT(*) FROM shop_mechanics sm WHERE sm.shop_id = s.id AND sm.is_active = true) as total_mechanics,
    (SELECT COUNT(*) FROM shop_mechanics sm 
     INNER JOIN mechanic_availability_status mas ON mas.mechanic_id = sm.mechanic_id
     WHERE sm.shop_id = s.id AND sm.is_active = true AND sm.is_available = true 
       AND mas.current_status = 'available') as available_mechanics,
    (SELECT COUNT(*) FROM shop_mechanics sm 
     INNER JOIN mechanic_availability_status mas ON mas.mechanic_id = sm.mechanic_id
     WHERE sm.shop_id = s.id AND sm.is_active = true 
       AND mas.current_status IN ('busy', 'in_service')) as busy_mechanics,
    
    -- Job Stats
    (SELECT COUNT(*) FROM service_requests sr WHERE sr.shop_id = s.id) as total_jobs,
    (SELECT COUNT(*) FROM service_requests sr 
     WHERE sr.shop_id = s.id 
       AND sr.status IN ('accepted', 'assigned', 'in_progress', 'mechanic_assigned')) as active_jobs,
    (SELECT COUNT(*) FROM service_requests sr 
     WHERE sr.shop_id = s.id AND sr.status = 'completed') as completed_jobs,
    (SELECT COUNT(*) FROM service_requests sr 
     WHERE sr.shop_id = s.id AND sr.status = 'pending') as pending_requests,
    
    -- Earnings Stats
    COALESCE((SELECT SUM(mjh.shop_earnings) 
              FROM mechanic_job_history mjh 
              WHERE mjh.shop_id = s.id AND mjh.job_status = 'completed'), 0) as total_earnings,
    COALESCE((SELECT SUM(mjh.shop_earnings) 
              FROM mechanic_job_history mjh 
              WHERE mjh.shop_id = s.id AND mjh.job_status = 'completed'
                AND DATE(mjh.completed_at) = CURRENT_DATE), 0) as today_earnings,
    COALESCE((SELECT SUM(mjh.shop_earnings) 
              FROM mechanic_job_history mjh 
              WHERE mjh.shop_id = s.id AND mjh.job_status = 'completed'
                AND mjh.completed_at >= DATE_TRUNC('week', CURRENT_DATE)), 0) as this_week_earnings,
    COALESCE((SELECT SUM(mjh.shop_earnings) 
              FROM mechanic_job_history mjh 
              WHERE mjh.shop_id = s.id AND mjh.job_status = 'completed'
                AND mjh.completed_at >= DATE_TRUNC('month', CURRENT_DATE)), 0) as this_month_earnings,
    
    -- Customer Stats
    (SELECT COUNT(DISTINCT sr.customer_id) 
     FROM service_requests sr 
     WHERE sr.shop_id = s.id) as total_customers,
    (SELECT COUNT(DISTINCT sr.customer_id) 
     FROM service_requests sr 
     WHERE sr.shop_id = s.id 
       AND DATE(sr.created_at) = CURRENT_DATE) as active_customers_today,
    
    -- Rating Stats
    COALESCE(s.rating, 0) as average_shop_rating,
    COALESCE(s.total_reviews, 0) as total_shop_reviews
    
  FROM shops s
  WHERE s.id = v_shop_id;
END;
$$;

-- ========================================
-- 🧪 TEST WITH ACTUAL USER IDs
-- ========================================

SELECT '=== 📋 List of Talyer Owners ===' as section;

SELECT 
  up.id as owner_id,
  up.first_name || ' ' || up.last_name as owner_name,
  up.email,
  s.shop_name,
  s.id as shop_id
FROM user_profiles up
LEFT JOIN shops s ON s.owner_id = up.id
WHERE up.user_type = 'talyer_owner'
ORDER BY up.first_name;

SELECT '';
SELECT '=== 🧪 TEST: Dashboard Stats for "riza store" owner ===' as section;

-- Test with riza store owner: 98543023-1960-4f70-b76a-d700ea70976c
SELECT * FROM test_dashboard_stats('98543023-1960-4f70-b76a-d700ea70976c');

SELECT '';
SELECT '=== 🧪 TEST: Dashboard Stats for "MechAid supply" owner ===' as section;

-- Test with MechAid supply owner: 19a8b4ca-f5f8-4b85-9147-5128d9651e04
SELECT * FROM test_dashboard_stats('19a8b4ca-f5f8-4b85-9147-5128d9651e04');

-- ========================================
-- SUCCESS MESSAGE
-- ========================================
DO $$
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ TEST FUNCTION CREATED!';
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
    RAISE NOTICE 'This test function works in SQL Editor:';
    RAISE NOTICE '  test_dashboard_stats(user_id)';
    RAISE NOTICE '';
    RAISE NOTICE 'The real functions will work from Flutter app:';
    RAISE NOTICE '  get_talyer_owner_dashboard_stats()';
    RAISE NOTICE '  get_talyer_owner_mechanic_stats()';
    RAISE NOTICE '  get_talyer_owner_customers()';
    RAISE NOTICE '  etc.';
    RAISE NOTICE '';
    RAISE NOTICE 'Test results shown above!';
    RAISE NOTICE '========================================';
END $$;
