-- ========================================
-- 🚀 COMPLETE FIX: Run These in Order
-- ========================================

-- ========================================
-- STEP 1: Update RPC Function (if not done yet)
-- ========================================

-- Drop the existing function
DROP FUNCTION IF EXISTS public.get_mechanic_job_history();

-- Recreate with vehicle fields
CREATE OR REPLACE FUNCTION public.get_mechanic_job_history()
RETURNS TABLE (
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
  customer_first_name text,
  customer_last_name text,
  customer_phone_number text,
  customer_profile_image_url text,
  customer_email text,
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
  sr_vehicle_brand text,
  sr_vehicle_model text,
  sr_vehicle_plate text,
  shop_name text,
  shop_address text,
  shop_phone text
)
LANGUAGE plpgsql
SECURITY DEFINER
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
    up.first_name::text,
    up.last_name::text,
    up.phone_number::text,
    up.profile_image_url::text,
    up.email::text,
    sr.title::text,
    sr.description::text,
    sr.pickup_address::text,
    sr.pickup_latitude,
    sr.pickup_longitude,
    sr.service_type::text,
    sr.created_at,
    sr.status::text,
    sr.estimated_price,
    sr.service_fee,
    v.brand_name::text,
    v.model_name::text,
    v.plate_number::text,
    s.shop_name::text,
    s.shop_address::text,
    s.shop_phone::text
  FROM mechanic_job_history mjh
  LEFT JOIN user_profiles up ON up.id = mjh.customer_id
  LEFT JOIN service_requests sr ON sr.id = mjh.service_request_id
  LEFT JOIN vehicles v ON v.id = sr.vehicle_id
  LEFT JOIN shops s ON s.id = mjh.shop_id;
END;
$$;

-- ========================================
-- STEP 2: Link service_requests to vehicles
-- ========================================

DO $$
DECLARE
    rows_updated INTEGER;
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE '🚗 LINKING SERVICE REQUESTS TO VEHICLES';
    RAISE NOTICE '========================================';
    
    -- Update with primary vehicles
    UPDATE service_requests sr
    SET vehicle_id = (
        SELECT id FROM vehicles 
        WHERE user_id = sr.customer_id 
        AND is_primary = true
        LIMIT 1
    )
    WHERE sr.vehicle_id IS NULL
    AND EXISTS (
        SELECT 1 FROM vehicles 
        WHERE user_id = sr.customer_id 
        AND is_primary = true
    );
    
    GET DIAGNOSTICS rows_updated = ROW_COUNT;
    RAISE NOTICE '✅ Linked % requests to primary vehicles', rows_updated;
    
    -- Update with latest vehicles
    UPDATE service_requests sr
    SET vehicle_id = (
        SELECT id FROM vehicles 
        WHERE user_id = sr.customer_id 
        ORDER BY created_at DESC
        LIMIT 1
    )
    WHERE sr.vehicle_id IS NULL
    AND EXISTS (
        SELECT 1 FROM vehicles WHERE user_id = sr.customer_id
    );
    
    GET DIAGNOSTICS rows_updated = ROW_COUNT;
    RAISE NOTICE '✅ Linked % requests to latest vehicles', rows_updated;
END $$;

-- ========================================
-- STEP 3: Verify the fix
-- ========================================

DO $$
DECLARE
    total_requests INTEGER;
    requests_with_vehicles INTEGER;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE '📊 VERIFICATION';
    RAISE NOTICE '========================================';
    
    SELECT COUNT(*) INTO total_requests FROM service_requests;
    SELECT COUNT(vehicle_id) INTO requests_with_vehicles 
    FROM service_requests WHERE vehicle_id IS NOT NULL;
    
    RAISE NOTICE '';
    RAISE NOTICE '   Total requests: %', total_requests;
    RAISE NOTICE '   With vehicles: % (% percent)', requests_with_vehicles,
        CASE WHEN total_requests > 0 THEN ROUND((requests_with_vehicles::DECIMAL / total_requests) * 100, 1) ELSE 0 END;
    
    IF requests_with_vehicles = total_requests THEN
        RAISE NOTICE '';
        RAISE NOTICE '🎉 SUCCESS! All requests have vehicles!';
    END IF;
    
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
END $$;

-- Test query
SELECT 
    sr.id as request_id,
    sr.title,
    sr.vehicle_id,
    v.brand_name,
    v.model_name,
    v.plate_number,
    '✅ Linked!' as status
FROM service_requests sr
INNER JOIN vehicles v ON v.id = sr.vehicle_id
ORDER BY sr.created_at DESC
LIMIT 5;

-- ========================================
-- FINAL NOTES
-- ========================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE '🚀 NEXT STEPS:';
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
    RAISE NOTICE '1. Run in PowerShell:';
    RAISE NOTICE '   flutter clean';
    RAISE NOTICE '   flutter pub get';
    RAISE NOTICE '   flutter run';
    RAISE NOTICE '';
    RAISE NOTICE '2. Check mechanic job history - should show vehicles';
    RAISE NOTICE '3. Check customer service history - should show vehicles';
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
END $$;
