-- ========================================
-- 🔧 FIX MECHANIC JOB HISTORY RLS
-- ========================================
-- Create SECURITY DEFINER function to get mechanic job history
-- with customer details (bypasses RLS)
-- ========================================

DROP FUNCTION IF EXISTS get_mechanic_job_history();

CREATE OR REPLACE FUNCTION get_mechanic_job_history()
RETURNS TABLE (
  -- Job history fields
  id uuid,
  mechanic_id uuid,
  service_request_id uuid,
  customer_id uuid,
  shop_id uuid,
  job_title text,
  job_description text,
  job_status text,
  completed_at timestamp with time zone,
  cancelled_at timestamp with time zone,
  total_amount numeric,
  rating numeric,
  review_text text,
  job_duration_minutes integer,
  created_at timestamp with time zone,
  updated_at timestamp with time zone,
  
  -- Customer details (from user_profiles) - use CAST to text to avoid type mismatch
  customer_first_name text,
  customer_last_name text,
  customer_phone_number text,
  customer_profile_image_url text,
  customer_email text,
  
  -- Service request details
  sr_title text,
  sr_description text,
  sr_pickup_address text,
  sr_pickup_latitude numeric,
  sr_pickup_longitude numeric,
  sr_service_type text,
  sr_created_at timestamp with time zone,
  sr_status text,
  sr_estimated_price numeric,
  sr_service_fee numeric,
  
  -- Shop details
  shop_name text,
  shop_address text,
  shop_phone text
)
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    mjh.id,
    mjh.mechanic_id,
    mjh.service_request_id,
    mjh.customer_id,
    mjh.shop_id,
    mjh.job_title,
    mjh.job_description,
    mjh.job_status,
    mjh.completed_at,
    mjh.cancelled_at,
    mjh.total_amount,
    mjh.rating,
    mjh.review_text,
    mjh.job_duration_minutes,
    mjh.created_at,
    mjh.updated_at,
    
    -- Customer details - CAST to text to avoid varchar size mismatch
    up.first_name::text as customer_first_name,
    up.last_name::text as customer_last_name,
    up.phone_number::text as customer_phone_number,
    up.profile_image_url::text as customer_profile_image_url,
    up.email::text as customer_email,
    
    -- Service request details
    sr.title::text as sr_title,
    sr.description::text as sr_description,
    sr.pickup_address::text as sr_pickup_address,
    sr.pickup_latitude,
    sr.pickup_longitude,
    sr.service_type::text as sr_service_type,
    sr.created_at as sr_created_at,
    sr.status::text as sr_status,
    sr.estimated_price,
    sr.service_fee,
    
    -- Shop details - CAST to text
    s.shop_name::text,
    s.shop_address::text,
    s.shop_phone::text
    
  FROM mechanic_job_history mjh
  LEFT JOIN user_profiles up ON up.id = mjh.customer_id
  LEFT JOIN service_requests sr ON sr.id = mjh.service_request_id
  LEFT JOIN shops s ON s.id = mjh.shop_id
  WHERE mjh.mechanic_id = auth.uid()
  ORDER BY mjh.created_at DESC;
END;
$$;

-- ========================================
-- TEST FUNCTION
-- ========================================

SELECT '=== 🧪 TEST: Get mechanic job history ===' as section;

SELECT 
  id,
  job_title,
  job_status,
  customer_first_name,
  customer_last_name,
  customer_phone_number,
  total_amount,
  rating,
  completed_at
FROM get_mechanic_job_history()
LIMIT 5;

-- ========================================
-- SUCCESS MESSAGE
-- ========================================
DO $$
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ MECHANIC JOB HISTORY FUNCTION CREATED!';
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
    RAISE NOTICE 'Created: get_mechanic_job_history()';
    RAISE NOTICE '';
    RAISE NOTICE 'This function:';
    RAISE NOTICE '  - Returns mechanic job history with customer details';
    RAISE NOTICE '  - Bypasses RLS (no recursion!)';
    RAISE NOTICE '  - Only shows jobs for current mechanic (secure!)';
    RAISE NOTICE '  - Includes customer name, phone, profile pic';
    RAISE NOTICE '';
    RAISE NOTICE 'Usage in Flutter:';
    RAISE NOTICE '  .rpc(''get_mechanic_job_history'')';
    RAISE NOTICE '========================================';
END $$;
