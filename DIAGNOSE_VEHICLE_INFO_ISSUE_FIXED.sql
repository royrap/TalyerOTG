-- ========================================
-- 🔍 DIAGNOSE VEHICLE INFO ISSUE (Supabase Compatible)
-- ========================================
-- Run this script to identify why vehicle info is not showing

DO $$
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE '🔍 VEHICLE INFO DIAGNOSTIC REPORT';
    RAISE NOTICE '========================================';
END $$;

-- ========================================
-- 1️⃣ CHECK RPC FUNCTION
-- ========================================

DO $$
DECLARE
    function_source TEXT;
    has_vehicle_brand BOOLEAN;
    has_vehicle_model BOOLEAN;
    has_vehicle_plate BOOLEAN;
    has_vehicle_join BOOLEAN;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '1️⃣ Checking if RPC function has vehicle fields...';
    
    -- Get function source code
    SELECT prosrc INTO function_source
    FROM pg_proc
    WHERE proname = 'get_mechanic_job_history';
    
    IF function_source IS NULL THEN
        RAISE NOTICE '❌ RPC function get_mechanic_job_history NOT FOUND!';
        RAISE NOTICE '   Solution: Run ADD_VEHICLE_TO_JOB_HISTORY_RPC.sql';
        RETURN;
    END IF;
    
    -- Check for vehicle fields
    has_vehicle_brand := function_source LIKE '%sr_vehicle_brand%';
    has_vehicle_model := function_source LIKE '%sr_vehicle_model%';
    has_vehicle_plate := function_source LIKE '%sr_vehicle_plate%';
    has_vehicle_join := function_source LIKE '%LEFT JOIN vehicles%';
    
    IF has_vehicle_brand AND has_vehicle_model AND has_vehicle_plate AND has_vehicle_join THEN
        RAISE NOTICE '✅ RPC function HAS vehicle fields!';
        RAISE NOTICE '   - sr_vehicle_brand: %', has_vehicle_brand;
        RAISE NOTICE '   - sr_vehicle_model: %', has_vehicle_model;
        RAISE NOTICE '   - sr_vehicle_plate: %', has_vehicle_plate;
        RAISE NOTICE '   - LEFT JOIN vehicles: %', has_vehicle_join;
    ELSE
        RAISE NOTICE '❌ RPC function MISSING vehicle fields!';
        RAISE NOTICE '   - sr_vehicle_brand: %', has_vehicle_brand;
        RAISE NOTICE '   - sr_vehicle_model: %', has_vehicle_model;
        RAISE NOTICE '   - sr_vehicle_plate: %', has_vehicle_plate;
        RAISE NOTICE '   - LEFT JOIN vehicles: %', has_vehicle_join;
        RAISE NOTICE '   Solution: Run ADD_VEHICLE_TO_JOB_HISTORY_RPC.sql';
    END IF;
END $$;

-- ========================================
-- 2️⃣ TEST RPC FUNCTION OUTPUT
-- ========================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE '2️⃣ Testing RPC function output (first 3 records)...';
END $$;

SELECT 
    job_title,
    sr_vehicle_brand,
    sr_vehicle_model,
    sr_vehicle_plate,
    CASE 
        WHEN sr_vehicle_brand IS NOT NULL THEN '✅ Has vehicle'
        ELSE '❌ No vehicle'
    END as status
FROM get_mechanic_job_history()
LIMIT 3;

-- ========================================
-- 3️⃣ CHECK SERVICE_REQUESTS DATA
-- ========================================

DO $$
DECLARE
    total_requests INTEGER;
    requests_with_vehicles INTEGER;
    requests_without_vehicles INTEGER;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE '3️⃣ Checking service_requests table for vehicle_id...';
    
    -- Count requests
    SELECT COUNT(*) INTO total_requests FROM service_requests;
    SELECT COUNT(vehicle_id) INTO requests_with_vehicles FROM service_requests WHERE vehicle_id IS NOT NULL;
    requests_without_vehicles := total_requests - requests_with_vehicles;
    
    RAISE NOTICE '';
    RAISE NOTICE '📊 Service Requests Statistics:';
    RAISE NOTICE '   Total requests: %', total_requests;
    RAISE NOTICE '   With vehicles: % (%%)', requests_with_vehicles, 
        CASE WHEN total_requests > 0 THEN ROUND((requests_with_vehicles::DECIMAL / total_requests) * 100, 1) ELSE 0 END;
    RAISE NOTICE '   Without vehicles: % (%%)', requests_without_vehicles,
        CASE WHEN total_requests > 0 THEN ROUND((requests_without_vehicles::DECIMAL / total_requests) * 100, 1) ELSE 0 END;
    RAISE NOTICE '';
    
    IF requests_without_vehicles > 0 THEN
        RAISE NOTICE '⚠️ ISSUE FOUND: Many service requests do NOT have vehicles assigned!';
        RAISE NOTICE '   This is likely why vehicle info is not showing.';
        RAISE NOTICE '';
        RAISE NOTICE '   Solutions:';
        RAISE NOTICE '   A) Update request creation to require vehicle selection';
        RAISE NOTICE '   B) Link existing requests to vehicles (see below)';
    ELSE
        RAISE NOTICE '✅ All service requests have vehicles assigned!';
    END IF;
END $$;

-- Show sample requests without vehicles
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE 'Sample requests WITHOUT vehicles:';
END $$;

SELECT 
    sr.id,
    sr.title,
    sr.customer_id,
    sr.vehicle_id,
    '❌ No vehicle' as status
FROM service_requests sr
WHERE sr.vehicle_id IS NULL
LIMIT 5;

-- ========================================
-- 4️⃣ CHECK MECHANIC_JOB_HISTORY
-- ========================================

DO $$
DECLARE
    total_jobs INTEGER;
    jobs_with_vehicle_in_request INTEGER;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE '4️⃣ Checking mechanic_job_history records...';
    
    -- Count jobs
    SELECT COUNT(*) INTO total_jobs FROM mechanic_job_history;
    
    -- Count jobs where service_request has vehicle_id
    SELECT COUNT(*) INTO jobs_with_vehicle_in_request
    FROM mechanic_job_history mjh
    INNER JOIN service_requests sr ON sr.id = mjh.service_request_id
    WHERE sr.vehicle_id IS NOT NULL;
    
    RAISE NOTICE '';
    RAISE NOTICE '📊 Job History Statistics:';
    RAISE NOTICE '   Total jobs: %', total_jobs;
    RAISE NOTICE '   Jobs with vehicles: % (%%)', jobs_with_vehicle_in_request,
        CASE WHEN total_jobs > 0 THEN ROUND((jobs_with_vehicle_in_request::DECIMAL / total_jobs) * 100, 1) ELSE 0 END;
    RAISE NOTICE '';
    
    IF jobs_with_vehicle_in_request = 0 AND total_jobs > 0 THEN
        RAISE NOTICE '❌ CRITICAL: NO jobs have vehicle data!';
        RAISE NOTICE '   Check if service_requests are being linked properly.';
    ELSIF jobs_with_vehicle_in_request < total_jobs THEN
        RAISE NOTICE '⚠️ Some jobs missing vehicle data.';
    ELSE
        RAISE NOTICE '✅ All jobs have vehicle data!';
    END IF;
END $$;

-- ========================================
-- 5️⃣ CHECK VEHICLES TABLE & RLS
-- ========================================

DO $$
DECLARE
    total_vehicles INTEGER;
    vehicle_policies INTEGER;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE '5️⃣ Checking vehicles table and RLS policies...';
    
    -- Count vehicles
    SELECT COUNT(*) INTO total_vehicles FROM vehicles;
    
    -- Count RLS policies on vehicles
    SELECT COUNT(*) INTO vehicle_policies
    FROM pg_policies
    WHERE tablename = 'vehicles';
    
    RAISE NOTICE '';
    RAISE NOTICE '📊 Vehicles Table:';
    RAISE NOTICE '   Total vehicles: %', total_vehicles;
    RAISE NOTICE '   RLS policies: %', vehicle_policies;
    RAISE NOTICE '';
    
    IF total_vehicles = 0 THEN
        RAISE NOTICE '❌ NO VEHICLES in database!';
        RAISE NOTICE '   Users need to add vehicles first.';
    END IF;
    
    IF vehicle_policies = 0 THEN
        RAISE NOTICE '⚠️ No RLS policies on vehicles table!';
        RAISE NOTICE '   This could cause access issues.';
    END IF;
END $$;

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE 'RLS Policies on vehicles table:';
END $$;

SELECT 
    policyname,
    cmd,
    qual
FROM pg_policies
WHERE tablename = 'vehicles';

-- ========================================
-- 6️⃣ SAMPLE DATA CHECK
-- ========================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE '6️⃣ Sample data check (JOIN test)...';
    RAISE NOTICE '';
    RAISE NOTICE 'Sample: mechanic_job_history → service_requests → vehicles';
END $$;

SELECT 
    mjh.job_title,
    sr.title as request_title,
    sr.vehicle_id,
    v.brand_name,
    v.model_name,
    v.plate_number,
    CASE 
        WHEN v.id IS NOT NULL THEN '✅ Vehicle linked'
        WHEN sr.vehicle_id IS NOT NULL THEN '⚠️ Vehicle ID exists but vehicle not found'
        ELSE '❌ No vehicle ID'
    END as status
FROM mechanic_job_history mjh
LEFT JOIN service_requests sr ON sr.id = mjh.service_request_id
LEFT JOIN vehicles v ON v.id = sr.vehicle_id
LIMIT 5;

-- ========================================
-- 7️⃣ SUMMARY & RECOMMENDATIONS
-- ========================================

DO $$
DECLARE
    rpc_has_vehicles BOOLEAN;
    total_requests INTEGER;
    requests_with_vehicles INTEGER;
    total_vehicles INTEGER;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE '📋 DIAGNOSTIC SUMMARY';
    RAISE NOTICE '========================================';
    
    -- Check RPC
    SELECT EXISTS (
        SELECT 1 FROM pg_proc 
        WHERE proname = 'get_mechanic_job_history' 
        AND prosrc LIKE '%sr_vehicle_brand%'
    ) INTO rpc_has_vehicles;
    
    -- Get counts
    SELECT COUNT(*) INTO total_requests FROM service_requests;
    SELECT COUNT(vehicle_id) INTO requests_with_vehicles FROM service_requests WHERE vehicle_id IS NOT NULL;
    SELECT COUNT(*) INTO total_vehicles FROM vehicles;
    
    RAISE NOTICE '';
    
    -- RPC Check
    IF rpc_has_vehicles THEN
        RAISE NOTICE '✅ RPC function is updated with vehicle fields';
    ELSE
        RAISE NOTICE '❌ RPC function NEEDS UPDATE!';
        RAISE NOTICE '   → Run: ADD_VEHICLE_TO_JOB_HISTORY_RPC.sql';
        RETURN;
    END IF;
    
    -- Data Check
    IF total_vehicles = 0 THEN
        RAISE NOTICE '❌ NO VEHICLES in database!';
        RAISE NOTICE '   → Users need to add vehicles in the app';
    ELSIF requests_with_vehicles = 0 AND total_requests > 0 THEN
        RAISE NOTICE '❌ Service requests NOT linked to vehicles!';
        RAISE NOTICE '   → Update request creation flow';
        RAISE NOTICE '   → OR run script to link existing requests';
    ELSIF requests_with_vehicles < total_requests THEN
        RAISE NOTICE '⚠️ Some requests missing vehicle links';
        RAISE NOTICE '   → % of % requests have vehicles', requests_with_vehicles, total_requests;
    ELSE
        RAISE NOTICE '✅ All requests have vehicles!';
    END IF;
    
    RAISE NOTICE '';
    RAISE NOTICE '🎯 NEXT STEPS:';
    
    IF NOT rpc_has_vehicles THEN
        RAISE NOTICE '   1. Run ADD_VEHICLE_TO_JOB_HISTORY_RPC.sql';
    END IF;
    
    IF total_vehicles = 0 THEN
        RAISE NOTICE '   2. Add vehicles in the mobile app';
    END IF;
    
    IF requests_with_vehicles < total_requests AND total_requests > 0 THEN
        RAISE NOTICE '   3. Link service_requests to vehicles';
        RAISE NOTICE '      See: LINK_REQUESTS_TO_VEHICLES.sql';
    END IF;
    
    RAISE NOTICE '   4. Restart Flutter app completely';
    RAISE NOTICE '   5. Check console logs for 🚗 messages';
    
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ Diagnostic complete!';
END $$;
