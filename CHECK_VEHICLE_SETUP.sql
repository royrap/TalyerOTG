-- ========================================
-- 🔍 CHECK: Vehicle Setup Diagnostic
-- ========================================
-- This checks if everything is set up correctly

DO $$
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE '🔍 VEHICLE SETUP DIAGNOSTIC';
    RAISE NOTICE '========================================';
END $$;

-- ========================================
-- CHECK 1: Does RPC function have vehicle fields?
-- ========================================

DO $$
DECLARE
    rpc_has_vehicle_fields BOOLEAN;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'CHECK 1: RPC Function Vehicle Fields';
    RAISE NOTICE '========================================';
    
    -- Check if function returns vehicle fields
    SELECT EXISTS (
        SELECT 1 
        FROM information_schema.routines 
        WHERE routine_schema = 'public' 
        AND routine_name = 'get_mechanic_job_history'
        AND routine_definition LIKE '%sr_vehicle_brand%'
    ) INTO rpc_has_vehicle_fields;
    
    IF rpc_has_vehicle_fields THEN
        RAISE NOTICE '✅ RPC function HAS vehicle fields';
    ELSE
        RAISE NOTICE '❌ RPC function MISSING vehicle fields';
        RAISE NOTICE '   → Run ADD_VEHICLE_TO_JOB_HISTORY_RPC.sql';
    END IF;
END $$;

-- ========================================
-- CHECK 2: Do service_requests have vehicle_id?
-- ========================================

DO $$
DECLARE
    total_requests INTEGER;
    requests_with_vehicles INTEGER;
    percentage NUMERIC;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'CHECK 2: Service Requests Vehicle Links';
    RAISE NOTICE '========================================';
    
    SELECT COUNT(*) INTO total_requests FROM service_requests;
    SELECT COUNT(vehicle_id) INTO requests_with_vehicles 
    FROM service_requests WHERE vehicle_id IS NOT NULL;
    
    IF total_requests > 0 THEN
        percentage := ROUND((requests_with_vehicles::DECIMAL / total_requests) * 100, 1);
    ELSE
        percentage := 0;
    END IF;
    
    RAISE NOTICE '   Total requests: %', total_requests;
    RAISE NOTICE '   With vehicles: % (%)', requests_with_vehicles, percentage || '%';
    
    IF requests_with_vehicles = 0 THEN
        RAISE NOTICE '❌ NO requests have vehicle_id';
        RAISE NOTICE '   → Uncomment UPDATE in FIX_LINK_VEHICLES_TO_REQUESTS.sql';
    ELSIF requests_with_vehicles < total_requests THEN
        RAISE NOTICE '⚠️  SOME requests missing vehicle_id';
        RAISE NOTICE '   → Uncomment UPDATE in FIX_LINK_VEHICLES_TO_REQUESTS.sql';
    ELSE
        RAISE NOTICE '✅ ALL requests have vehicle_id';
    END IF;
END $$;

-- ========================================
-- CHECK 3: Test RPC output with sample data
-- ========================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'CHECK 3: RPC Function Test Output';
    RAISE NOTICE '========================================';
END $$;

-- Test the RPC function
SELECT 
    job_title,
    sr_vehicle_brand,
    sr_vehicle_model,
    sr_vehicle_plate,
    CASE 
        WHEN sr_vehicle_brand IS NOT NULL THEN '✅ Has vehicle data'
        ELSE '❌ No vehicle data'
    END as vehicle_status
FROM get_mechanic_job_history()
ORDER BY completed_at DESC
LIMIT 5;

-- ========================================
-- CHECK 4: Sample mechanic_job_history with vehicles
-- ========================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'CHECK 4: Direct Query Test';
    RAISE NOTICE '========================================';
END $$;

-- Manually query to see if joins work
SELECT 
    mjh.job_title,
    sr.title as request_title,
    sr.vehicle_id,
    v.brand_name,
    v.model_name,
    v.plate_number,
    CASE 
        WHEN v.id IS NOT NULL THEN '✅ Vehicle found'
        WHEN sr.vehicle_id IS NULL THEN '⚠️  Request has no vehicle_id'
        ELSE '❌ Vehicle_id exists but vehicle not found'
    END as status
FROM mechanic_job_history mjh
LEFT JOIN service_requests sr ON sr.id = mjh.service_request_id
LEFT JOIN vehicles v ON v.id = sr.vehicle_id
WHERE mjh.job_status = 'completed'
ORDER BY mjh.completed_at DESC
LIMIT 5;

-- ========================================
-- SUMMARY & RECOMMENDATIONS
-- ========================================

DO $$
DECLARE
    rpc_has_vehicles BOOLEAN;
    requests_have_vehicles INTEGER;
    total_requests INTEGER;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE '📋 SUMMARY & NEXT STEPS';
    RAISE NOTICE '========================================';
    
    -- Check RPC
    SELECT EXISTS (
        SELECT 1 FROM information_schema.routines 
        WHERE routine_schema = 'public' 
        AND routine_name = 'get_mechanic_job_history'
        AND routine_definition LIKE '%sr_vehicle_brand%'
    ) INTO rpc_has_vehicles;
    
    -- Check data
    SELECT COUNT(*) INTO total_requests FROM service_requests;
    SELECT COUNT(vehicle_id) INTO requests_have_vehicles 
    FROM service_requests WHERE vehicle_id IS NOT NULL;
    
    RAISE NOTICE '';
    
    IF NOT rpc_has_vehicles THEN
        RAISE NOTICE '❌ STEP 1: Run ADD_VEHICLE_TO_JOB_HISTORY_RPC.sql first!';
    ELSE
        RAISE NOTICE '✅ STEP 1: RPC function is updated';
    END IF;
    
    IF requests_have_vehicles = 0 THEN
        RAISE NOTICE '❌ STEP 2: Uncomment UPDATE in FIX_LINK_VEHICLES_TO_REQUESTS.sql';
        RAISE NOTICE '           and run it to link vehicles to requests';
    ELSIF requests_have_vehicles < total_requests THEN
        RAISE NOTICE '⚠️  STEP 2: Some requests need vehicle links';
        RAISE NOTICE '           Run FIX_LINK_VEHICLES_TO_REQUESTS.sql again';
    ELSE
        RAISE NOTICE '✅ STEP 2: Requests are linked to vehicles';
    END IF;
    
    RAISE NOTICE '';
    RAISE NOTICE '🚀 STEP 3: Restart Flutter app:';
    RAISE NOTICE '   flutter clean';
    RAISE NOTICE '   flutter pub get';
    RAISE NOTICE '   flutter run';
    
    RAISE NOTICE '';
    RAISE NOTICE '🔍 STEP 4: Check console logs for 🚗 messages';
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
END $$;
