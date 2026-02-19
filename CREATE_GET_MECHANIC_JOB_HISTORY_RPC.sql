-- ========================================
-- 🔧 CREATE get_mechanic_job_history RPC FUNCTION
-- ========================================
-- This function allows mechanics to query their job history with customer data
-- Uses SECURITY DEFINER to bypass RLS restrictions

CREATE OR REPLACE FUNCTION public.get_mechanic_job_history()
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
  completed_at timestamptz,
  cancelled_at timestamptz,
  total_amount numeric,
  rating numeric,
  review_text text,
  job_duration_minutes integer,
  created_at timestamptz,
  updated_at timestamptz,
  mechanic_earnings numeric,
  shop_earnings numeric,
  platform_fee numeric,
  
  -- Customer details (flattened)
  customer_first_name text,
  customer_last_name text,
  customer_phone_number text,
  customer_profile_image_url text,
  customer_email text,
  
  -- Service request details (flattened)
  sr_title text,
  sr_description text,
  sr_pickup_address text,
  sr_pickup_latitude numeric,
  sr_pickup_longitude numeric,
  sr_service_type text,
  sr_created_at timestamptz,
  sr_status text,
  sr_estimated_price numeric,
  sr_service_fee numeric,
  
  -- Shop details (flattened)
  shop_name text,
  shop_address text,
  shop_phone text
)
LANGUAGE plpgsql
SECURITY DEFINER  -- Bypasses RLS!
SET search_path = public
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
    mjh.mechanic_earnings,
    mjh.shop_earnings,
    mjh.platform_fee,
    
    -- Customer details (cast to text)
    up.first_name::text,
    up.last_name::text,
    up.phone_number::text,
    up.profile_image_url,
    up.email::text,
    
    -- Service request details (cast to text)
    sr.title::text,
    sr.description,
    sr.pickup_address,
    sr.pickup_latitude,
    sr.pickup_longitude,
    sr.service_type::text,
    sr.created_at,
    sr.status::text,
    sr.estimated_price,
    sr.service_fee,
    
    -- Shop details (cast to text)
    s.shop_name::text,
    s.shop_address,
    s.shop_phone
    
  FROM mechanic_job_history mjh
  LEFT JOIN user_profiles up ON up.id = mjh.customer_id
  LEFT JOIN service_requests sr ON sr.id = mjh.service_request_id
  LEFT JOIN shops s ON s.id = mjh.shop_id
  WHERE mjh.mechanic_id = auth.uid()  -- Only current mechanic's jobs
  ORDER BY mjh.created_at DESC;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.get_mechanic_job_history() TO authenticated;

-- ========================================
-- 📊 VERIFICATION
-- ========================================
SELECT 
    proname as function_name,
    prosecdef as is_security_definer,
    provolatile as volatility
FROM pg_proc
WHERE proname = 'get_mechanic_job_history';

DO $$
BEGIN
    RAISE NOTICE '✅ RPC function get_mechanic_job_history created!';
    RAISE NOTICE '🔐 SECURITY DEFINER enabled - bypasses RLS restrictions';
    RAISE NOTICE '📌 Mechanics can now query their job history with customer data';
END $$;
