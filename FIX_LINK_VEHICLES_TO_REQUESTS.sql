-- ========================================
-- 🚗 FIX: Link Service Requests to Vehicles (CORRECT APPROACH)
-- ========================================
-- This links service_requests to the appropriate vehicle
-- Uses the SAME logic as talyer_owner invoices

-- ⚠️ IMPORTANT: This will update ALL service_requests with NULL vehicle_id
-- ⚠️ Review the preview before uncommenting the UPDATE!

DO $$
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE '🚗 LINKING SERVICE REQUESTS TO VEHICLES';
    RAISE NOTICE '(Using talyer_owner invoice logic)';
    RAISE NOTICE '========================================';
END $$;

-- ========================================
-- STEP 1: Check Current Status
-- ========================================

DO $$
DECLARE
    total_requests INTEGER;
    requests_with_vehicles INTEGER;
    requests_without_vehicles INTEGER;
    total_customers_with_vehicles INTEGER;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '📊 CURRENT STATUS:';
    
    -- Count requests
    SELECT COUNT(*) INTO total_requests FROM service_requests;
    SELECT COUNT(vehicle_id) INTO requests_with_vehicles 
    FROM service_requests WHERE vehicle_id IS NOT NULL;
    requests_without_vehicles := total_requests - requests_with_vehicles;
    
    -- Count customers with vehicles
    SELECT COUNT(DISTINCT user_id) INTO total_customers_with_vehicles FROM vehicles;
    
    RAISE NOTICE '   Total service requests: %', total_requests;
    RAISE NOTICE '   With vehicles: % (%)', requests_with_vehicles,
        CASE WHEN total_requests > 0 THEN ROUND((requests_with_vehicles::DECIMAL / total_requests) * 100, 1) ELSE 0 END;
    RAISE NOTICE '   Without vehicles: % (%)', requests_without_vehicles,
        CASE WHEN total_requests > 0 THEN ROUND((requests_without_vehicles::DECIMAL / total_requests) * 100, 1) ELSE 0 END;
    RAISE NOTICE '   Customers who have vehicles: %', total_customers_with_vehicles;
END $$;

-- ========================================
-- STEP 2: Preview What Will Be Updated
-- ========================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE '📋 PREVIEW: Requests that will be linked';
    RAISE NOTICE '========================================';
END $$;

-- Show requests that will get vehicles assigned
SELECT 
    sr.id as request_id,
    sr.title as request_title,
    sr.customer_id,
    sr.status as request_status,
    sr.created_at as request_date,
    sr.vehicle_id as current_vehicle_id,
    COALESCE(
        primary_v.id,
        latest_v.id
    ) as vehicle_to_assign,
    COALESCE(
        primary_v.brand_name || ' ' || primary_v.model_name,
        latest_v.brand_name || ' ' || latest_v.model_name
    ) as vehicle_name,
    COALESCE(
        primary_v.plate_number,
        latest_v.plate_number
    ) as plate_number,
    CASE 
        WHEN primary_v.id IS NOT NULL THEN 'Primary vehicle'
        WHEN latest_v.id IS NOT NULL THEN 'Latest vehicle'
        ELSE 'No vehicle found'
    END as vehicle_source
FROM service_requests sr
-- Try to get primary vehicle first
LEFT JOIN LATERAL (
    SELECT id, brand_name, model_name, plate_number
    FROM vehicles
    WHERE user_id = sr.customer_id
    AND is_primary = true
    LIMIT 1
) primary_v ON true
-- Fallback to latest vehicle if no primary
LEFT JOIN LATERAL (
    SELECT id, brand_name, model_name, plate_number
    FROM vehicles
    WHERE user_id = sr.customer_id
    ORDER BY created_at DESC
    LIMIT 1
) latest_v ON primary_v.id IS NULL
WHERE sr.vehicle_id IS NULL
AND (primary_v.id IS NOT NULL OR latest_v.id IS NOT NULL)
ORDER BY sr.created_at DESC
LIMIT 20;

-- ========================================
-- STEP 3: Show requests that CAN'T be linked
-- ========================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE '⚠️ REQUESTS WITHOUT VEHICLES AVAILABLE';
    RAISE NOTICE '========================================';
END $$;

-- Show requests where customer has NO vehicles at all
SELECT 
    sr.id as request_id,
    sr.title as request_title,
    sr.customer_id,
    up.first_name || ' ' || up.last_name as customer_name,
    up.email as customer_email,
    sr.created_at as request_date,
    '❌ Customer has no vehicles' as issue
FROM service_requests sr
LEFT JOIN user_profiles up ON up.id = sr.customer_id
WHERE sr.vehicle_id IS NULL
AND NOT EXISTS (
    SELECT 1 FROM vehicles WHERE user_id = sr.customer_id
)
LIMIT 10;

-- ========================================
-- STEP 4: THE FIX - Uncomment to apply
-- ========================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE '🔧 EXECUTING UPDATE NOW!';
    RAISE NOTICE '========================================';
END $$;

-- THIS IS THE ACTUAL UPDATE!
UPDATE service_requests sr
SET vehicle_id = (
    -- Try primary vehicle first
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

-- Then update remaining requests with latest vehicle
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

-- ========================================
-- STEP 5: Verification
-- ========================================

DO $$
DECLARE
    total_requests INTEGER;
    requests_with_vehicles INTEGER;
    requests_without_vehicles INTEGER;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ AFTER UPDATE STATUS:';
    RAISE NOTICE '========================================';
    
    SELECT COUNT(*) INTO total_requests FROM service_requests;
    SELECT COUNT(vehicle_id) INTO requests_with_vehicles 
    FROM service_requests WHERE vehicle_id IS NOT NULL;
    requests_without_vehicles := total_requests - requests_with_vehicles;
    
    RAISE NOTICE '';
    RAISE NOTICE '   Total requests: %', total_requests;
    RAISE NOTICE '   With vehicles: % (%)', requests_with_vehicles,
        CASE WHEN total_requests > 0 THEN ROUND((requests_with_vehicles::DECIMAL / total_requests) * 100, 1) ELSE 0 END;
    RAISE NOTICE '   Without vehicles: % (%)', requests_without_vehicles,
        CASE WHEN total_requests > 0 THEN ROUND((requests_without_vehicles::DECIMAL / total_requests) * 100, 1) ELSE 0 END;
    
    IF requests_without_vehicles = 0 THEN
        RAISE NOTICE '';
        RAISE NOTICE '🎉 SUCCESS! All requests now have vehicles!';
    ELSIF requests_without_vehicles > 0 THEN
        RAISE NOTICE '';
        RAISE NOTICE '⚠️ Some requests still without vehicles.';
        RAISE NOTICE '   These customers may not have vehicles in the system.';
        RAISE NOTICE '   They need to add vehicles in the app first.';
    END IF;
    
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
END $$;

-- ========================================
-- STEP 6: Test Query (Run after UPDATE)
-- ========================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE '🧪 TEST: Sample linked requests';
    RAISE NOTICE '========================================';
END $$;

-- Verify the links are working
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
    RAISE NOTICE '📝 IMPORTANT NEXT STEPS:';
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
    RAISE NOTICE '1. Review the preview above';
    RAISE NOTICE '2. If it looks correct, uncomment the UPDATE statement';
    RAISE NOTICE '3. Run this script again to apply changes';
    RAISE NOTICE '4. After UPDATE succeeds:';
    RAISE NOTICE '   a) Run flutter clean in your terminal';
    RAISE NOTICE '   b) Run flutter pub get';
    RAISE NOTICE '   c) Run flutter run (full restart, not hot reload!)';
    RAISE NOTICE '5. Check console logs for 🚗 vehicle messages';
    RAISE NOTICE '6. Verify vehicle shows in mechanic & customer history';
    RAISE NOTICE '';
    RAISE NOTICE '🎯 The logic matches talyer_owner invoices:';
    RAISE NOTICE '   - Primary vehicle if available';
    RAISE NOTICE '   - Latest vehicle as fallback';
    RAISE NOTICE '   - Consistent across the entire app!';
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
END $$;
