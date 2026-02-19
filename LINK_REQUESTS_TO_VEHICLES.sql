-- ========================================
-- 🔗 LINK SERVICE REQUESTS TO VEHICLES
-- ========================================
-- This script links existing service_requests to vehicles
-- Run this ONLY if service_requests have NULL vehicle_id

-- ⚠️ WARNING: Review the UPDATE queries before running!
-- ⚠️ This will modify existing data!

DO $$
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE '🔗 LINKING SERVICE REQUESTS TO VEHICLES';
    RAISE NOTICE '========================================';
END $$;

-- ========================================
-- OPTION 1: Link to customer's FIRST vehicle
-- ========================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE 'OPTION 1: Link each request to customers first vehicle';
    RAISE NOTICE 'Preview (will NOT update yet):';
END $$;

-- Preview what will be updated
SELECT 
    sr.id as request_id,
    sr.title as request_title,
    sr.customer_id,
    sr.vehicle_id as current_vehicle_id,
    v.id as new_vehicle_id,
    v.brand_name,
    v.model_name,
    v.plate_number
FROM service_requests sr
LEFT JOIN LATERAL (
    SELECT id, brand_name, model_name, plate_number
    FROM vehicles
    WHERE user_id = sr.customer_id
    ORDER BY created_at ASC
    LIMIT 1
) v ON true
WHERE sr.vehicle_id IS NULL
AND v.id IS NOT NULL
LIMIT 10;

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE 'To apply OPTION 1, uncomment and run the UPDATE below:';
END $$;

-- Uncomment the lines below to actually update:
/*
UPDATE service_requests sr
SET vehicle_id = (
    SELECT id 
    FROM vehicles 
    WHERE user_id = sr.customer_id 
    ORDER BY created_at ASC
    LIMIT 1
)
WHERE sr.vehicle_id IS NULL
AND EXISTS (
    SELECT 1 FROM vehicles WHERE user_id = sr.customer_id
);
*/

-- ========================================
-- OPTION 2: Link to customer's MOST RECENTLY USED vehicle
-- ========================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'OPTION 2: Link to customers most recently used vehicle';
    RAISE NOTICE 'Preview (will NOT update yet):';
END $$;

-- Preview
SELECT 
    sr.id as request_id,
    sr.title as request_title,
    sr.customer_id,
    sr.vehicle_id as current_vehicle_id,
    v.id as new_vehicle_id,
    v.brand_name,
    v.model_name,
    v.plate_number,
    v.created_at as vehicle_created
FROM service_requests sr
LEFT JOIN LATERAL (
    SELECT id, brand_name, model_name, plate_number, created_at
    FROM vehicles
    WHERE user_id = sr.customer_id
    ORDER BY created_at DESC
    LIMIT 1
) v ON true
WHERE sr.vehicle_id IS NULL
AND v.id IS NOT NULL
LIMIT 10;

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE 'To apply OPTION 2, uncomment and run the UPDATE below:';
END $$;

-- Uncomment the lines below to actually update:
/*
UPDATE service_requests sr
SET vehicle_id = (
    SELECT id 
    FROM vehicles 
    WHERE user_id = sr.customer_id 
    ORDER BY created_at DESC
    LIMIT 1
)
WHERE sr.vehicle_id IS NULL
AND EXISTS (
    SELECT 1 FROM vehicles WHERE user_id = sr.customer_id
);
*/

-- ========================================
-- OPTION 3: Link to customer's PRIMARY vehicle
-- ========================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'OPTION 3: Link to customers primary vehicle (is_primary = true)';
    RAISE NOTICE 'Preview (will NOT update yet):';
END $$;

-- Preview
SELECT 
    sr.id as request_id,
    sr.title as request_title,
    sr.customer_id,
    sr.vehicle_id as current_vehicle_id,
    v.id as new_vehicle_id,
    v.brand_name,
    v.model_name,
    v.plate_number
FROM service_requests sr
LEFT JOIN vehicles v ON v.user_id = sr.customer_id AND v.is_primary = true
WHERE sr.vehicle_id IS NULL
AND v.id IS NOT NULL
LIMIT 10;

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE 'To apply OPTION 3, uncomment and run the UPDATE below:';
END $$;

-- Uncomment the lines below to actually update:
/*
UPDATE service_requests sr
SET vehicle_id = (
    SELECT id 
    FROM vehicles 
    WHERE user_id = sr.customer_id 
    AND is_primary = true
    LIMIT 1
)
WHERE sr.vehicle_id IS NULL
AND EXISTS (
    SELECT 1 FROM vehicles WHERE user_id = sr.customer_id AND is_primary = true
);
*/

-- ========================================
-- VERIFICATION QUERY
-- ========================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'After running update, verify with this query:';
END $$;

SELECT 
    COUNT(*) as total_requests,
    COUNT(vehicle_id) as requests_with_vehicles,
    COUNT(*) - COUNT(vehicle_id) as requests_without_vehicles,
    CASE 
        WHEN COUNT(*) > 0 THEN ROUND((COUNT(vehicle_id)::DECIMAL / COUNT(*)) * 100, 1)
        ELSE 0
    END as percentage_with_vehicles
FROM service_requests;

-- ========================================
-- IMPORTANT NOTES
-- ========================================
DO $$
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE '⚠️ IMPORTANT NOTES';
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
    RAISE NOTICE '1. This script only PREVIEWS changes by default';
    RAISE NOTICE '   → Uncomment the UPDATE statements to apply';
    RAISE NOTICE '';
    RAISE NOTICE '2. Choose ONE option that fits your use case:';
    RAISE NOTICE '   → Option 1: First vehicle (oldest)';
    RAISE NOTICE '   → Option 2: Latest vehicle (newest)';
    RAISE NOTICE '   → Option 3: Default vehicle (if column exists)';
    RAISE NOTICE '';
    RAISE NOTICE '3. This only affects requests WITHOUT vehicle_id';
    RAISE NOTICE '   → Existing links are preserved';
    RAISE NOTICE '';
    RAISE NOTICE '4. After updating:';
    RAISE NOTICE '   → Run DIAGNOSE_VEHICLE_INFO_ISSUE.sql again';
    RAISE NOTICE '   → Restart Flutter app';
    RAISE NOTICE '   → Test vehicle display in job history';
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
    RAISE NOTICE '✅ Review complete! Uncomment UPDATE statements to apply.';
END $$;
