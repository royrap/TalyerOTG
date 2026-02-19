-- ============================================================================
-- DATABASE FUNCTION FIX FOR TALYER OWNER DASHBOARD
-- ============================================================================
-- This SQL script creates the missing database function that the talyer owner
-- service needs to fetch shop mechanics efficiently.
--
-- ERROR MESSAGE:
-- "Could not find the function public.get_shop_mechanics_for_owner without parameters"
--
-- STATUS: Optional - The app has fallback logic and works without this function,
-- but creating it will improve performance and eliminate console errors.
-- ============================================================================

-- Drop existing function if it exists
DROP FUNCTION IF EXISTS public.get_shop_mechanics_for_owner(UUID);

-- Create the function
CREATE OR REPLACE FUNCTION public.get_shop_mechanics_for_owner(owner_id_param UUID)
RETURNS TABLE (
  mechanic_id UUID,
  first_name CHARACTER VARYING,
  last_name CHARACTER VARYING,
  email CHARACTER VARYING,
  phone_number CHARACTER VARYING,
  profile_image_url TEXT,
  rating NUMERIC,
  total_reviews INTEGER,
  is_available BOOLEAN,
  current_status TEXT,
  shop_id UUID,
  shop_name CHARACTER VARYING,
  last_active_at TIMESTAMPTZ,
  specialties TEXT[],
  completed_jobs_count INTEGER,
  average_job_duration INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    -- Mechanic basic info
    up.id AS mechanic_id,
    up.first_name,
    up.last_name,
    up.email,
    up.phone_number,
    up.profile_image_url,
    up.rating,
    up.total_reviews,
    up.is_available,
    
    -- Mechanic status
    COALESCE(mas.current_status, 'offline'::text) AS current_status,
    
    -- Shop info
    s.id AS shop_id,
    s.shop_name,
    
    -- Activity tracking
    COALESCE(mas.last_active_at, up.updated_at) AS last_active_at,
    
    -- Mechanic details from shop_mechanics
    sm.specialties,
    
    -- Performance metrics
    COALESCE(
      (SELECT COUNT(*)::INTEGER 
       FROM mechanic_job_history mjh 
       WHERE mjh.mechanic_id = up.id 
         AND mjh.job_status = 'completed'
      ), 
      0
    ) AS completed_jobs_count,
    
    COALESCE(
      (SELECT AVG(job_duration_minutes)::INTEGER 
       FROM mechanic_job_history mjh 
       WHERE mjh.mechanic_id = up.id 
         AND mjh.job_status = 'completed'
         AND mjh.job_duration_minutes IS NOT NULL
      ), 
      0
    ) AS average_job_duration
    
  FROM user_profiles up
  
  -- Join with shops to get mechanics for this owner
  INNER JOIN shops s ON s.id = up.shop_id AND s.owner_id = owner_id_param
  
  -- Left join with mechanic availability status
  LEFT JOIN mechanic_availability_status mas ON mas.mechanic_id = up.id
  
  -- Left join with shop_mechanics for additional details
  LEFT JOIN shop_mechanics sm ON sm.mechanic_id = up.id AND sm.shop_id = s.id
  
  WHERE up.user_type = 'mechanic'
    AND up.status = 'active'
    AND s.is_active = true
  
  ORDER BY 
    -- Available mechanics first
    CASE WHEN up.is_available THEN 0 ELSE 1 END,
    -- Then by status (online, busy, offline)
    CASE 
      WHEN mas.current_status = 'available' THEN 0
      WHEN mas.current_status = 'busy' THEN 1
      WHEN mas.current_status = 'in_service' THEN 2
      ELSE 3
    END,
    -- Then by last activity
    COALESCE(mas.last_active_at, up.updated_at) DESC;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.get_shop_mechanics_for_owner(UUID) TO authenticated;

-- Add helpful comment
COMMENT ON FUNCTION public.get_shop_mechanics_for_owner(UUID) IS 
'Returns all mechanics assigned to shops owned by the specified talyer owner. 
Includes mechanic status, availability, performance metrics, and shop information.
Ordered by availability and last activity.';

-- ============================================================================
-- VERIFICATION QUERIES
-- ============================================================================

-- Test the function (replace with actual owner ID)
-- SELECT * FROM get_shop_mechanics_for_owner('your-owner-id-here');

-- Check function exists
SELECT 
  proname AS function_name,
  pg_get_function_arguments(oid) AS parameters,
  pg_get_functiondef(oid) AS definition
FROM pg_proc 
WHERE proname = 'get_shop_mechanics_for_owner';

-- ============================================================================
-- ADDITIONAL HELPER FUNCTIONS (OPTIONAL)
-- ============================================================================

-- Function to get mechanic performance summary
CREATE OR REPLACE FUNCTION public.get_mechanic_performance_summary(
  mechanic_id_param UUID,
  period_days INTEGER DEFAULT 30
)
RETURNS TABLE (
  total_jobs INTEGER,
  completed_jobs INTEGER,
  cancelled_jobs INTEGER,
  average_rating NUMERIC,
  total_earnings NUMERIC,
  average_job_duration INTEGER,
  on_time_completion_rate NUMERIC
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    COUNT(*)::INTEGER AS total_jobs,
    SUM(CASE WHEN job_status = 'completed' THEN 1 ELSE 0 END)::INTEGER AS completed_jobs,
    SUM(CASE WHEN job_status = 'cancelled' THEN 1 ELSE 0 END)::INTEGER AS cancelled_jobs,
    AVG(CASE WHEN rating IS NOT NULL THEN rating ELSE NULL END) AS average_rating,
    SUM(CASE WHEN job_status = 'completed' THEN mechanic_earnings ELSE 0 END) AS total_earnings,
    AVG(CASE WHEN job_status = 'completed' AND job_duration_minutes IS NOT NULL THEN job_duration_minutes ELSE NULL END)::INTEGER AS average_job_duration,
    (SUM(CASE WHEN job_status = 'completed' THEN 1 ELSE 0 END)::NUMERIC / NULLIF(COUNT(*)::NUMERIC, 0) * 100) AS on_time_completion_rate
  FROM mechanic_job_history
  WHERE mechanic_id = mechanic_id_param
    AND created_at >= NOW() - (period_days || ' days')::INTERVAL;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_mechanic_performance_summary(UUID, INTEGER) TO authenticated;

-- Function to get shop earnings summary
CREATE OR REPLACE FUNCTION public.get_shop_earnings_summary(
  shop_id_param UUID,
  start_date TIMESTAMPTZ DEFAULT NULL,
  end_date TIMESTAMPTZ DEFAULT NULL
)
RETURNS TABLE (
  total_revenue NUMERIC,
  shop_earnings NUMERIC,
  mechanic_earnings NUMERIC,
  platform_fees NUMERIC,
  completed_jobs_count INTEGER,
  average_job_value NUMERIC
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    SUM(total_amount) AS total_revenue,
    SUM(shop_earnings) AS shop_earnings,
    SUM(mechanic_earnings) AS mechanic_earnings,
    SUM(platform_fee) AS platform_fees,
    COUNT(*)::INTEGER AS completed_jobs_count,
    AVG(total_amount) AS average_job_value
  FROM mechanic_job_history
  WHERE shop_id = shop_id_param
    AND job_status = 'completed'
    AND (start_date IS NULL OR completed_at >= start_date)
    AND (end_date IS NULL OR completed_at <= end_date);
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_shop_earnings_summary(UUID, TIMESTAMPTZ, TIMESTAMPTZ) TO authenticated;

-- ============================================================================
-- USAGE EXAMPLES
-- ============================================================================

/*

-- Example 1: Get all mechanics for a shop owner
SELECT * FROM get_shop_mechanics_for_owner('19a8b4ca-f5f8-4b85-9147-5128d9651e04');

-- Example 2: Get mechanic performance for last 30 days
SELECT * FROM get_mechanic_performance_summary('mechanic-id-here', 30);

-- Example 3: Get shop earnings for current month
SELECT * FROM get_shop_earnings_summary(
  'shop-id-here', 
  DATE_TRUNC('month', NOW()),
  NOW()
);

-- Example 4: Get today's shop earnings
SELECT * FROM get_shop_earnings_summary(
  'shop-id-here',
  DATE_TRUNC('day', NOW()),
  NOW()
);

*/

-- ============================================================================
-- END OF SCRIPT
-- ============================================================================
