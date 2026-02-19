-- ========================================
-- 🚗 ADD VEHICLE INFO TO get_mechanic_job_history RPC
-- ========================================
-- This updates the RPC function to include vehicle information
-- in job history so mechanics and customers can see which vehicle was serviced

-- Drop the existing function
DROP FUNCTION IF EXISTS public.get_mechanic_job_history();

-- Recreate with vehicle fields added
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
  
  -- 🚗 Vehicle details (NEW!)
  sr_vehicle_brand text,
  sr_vehicle_model text,
  sr_vehicle_plate text,
  
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
    
    -- 🚗 Vehicle details (NEW!)
    v.brand_name::text,
    v.model_name::text,
    v.plate_number::text,
    
    -- Shop details (cast to text)
    s.shop_name::text,
    s.shop_address,
    s.shop_phone
    
  FROM mechanic_job_history mjh
  LEFT JOIN user_profiles up ON up.id = mjh.customer_id
  LEFT JOIN service_requests sr ON sr.id = mjh.service_request_id
  LEFT JOIN vehicles v ON v.id = sr.vehicle_id  -- 🚗 Join with vehicles table
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
    RAISE NOTICE '✅ RPC function get_mechanic_job_history updated with vehicle info!';
    RAISE NOTICE '🚗 Now includes: vehicle brand, model, and plate number';
    RAISE NOTICE '🔐 SECURITY DEFINER enabled - bypasses RLS restrictions';
    RAISE NOTICE '📌 Mechanics can now see which vehicle was serviced in each job';
END $$;

-- Test query to verify vehicle data is returned
DO $$
DECLARE
    record_count INTEGER;
    vehicle_count INTEGER;
BEGIN
    -- Count total records
    SELECT COUNT(*) INTO record_count FROM get_mechanic_job_history();
    
    -- Count records with vehicle data
    SELECT COUNT(*) INTO vehicle_count 
    FROM get_mechanic_job_history()
    WHERE sr_vehicle_brand IS NOT NULL;
    
    RAISE NOTICE '📊 Test Results:';
    RAISE NOTICE '   Total job history records: %', record_count;
    RAISE NOTICE '   Records with vehicle data: %', vehicle_count;
    
    IF vehicle_count > 0 THEN
        RAISE NOTICE '✅ Vehicle data is being returned!';
    ELSE
        RAISE NOTICE '⚠️ No vehicle data found - this is OK if no jobs have vehicles assigned';
    END IF;
END $$;
