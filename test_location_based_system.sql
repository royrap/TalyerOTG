-- Test script to verify location-based request system
-- This script will check if mechanics can receive location-based requests

-- 1. Check if mechanics have availability status records
SELECT 
    up.id,
    up.first_name,
    up.last_name,
    up.user_type,
    mas.current_status,
    mas.is_accepting_requests,
    mas.created_at as availability_created
FROM user_profiles up
LEFT JOIN mechanic_availability_status mas ON mas.mechanic_id = up.id
WHERE up.user_type = 'mechanic'
ORDER BY up.created_at;

-- 2. Create availability status for mechanics who don't have it
INSERT INTO mechanic_availability_status (
    mechanic_id,
    current_status,
    is_accepting_requests,
    last_status_update,
    created_at,
    updated_at
)
SELECT 
    up.id,
    'available',
    true,
    NOW(),
    NOW(),
    NOW()
FROM user_profiles up
WHERE up.user_type = 'mechanic'
AND NOT EXISTS (
    SELECT 1 FROM mechanic_availability_status mas 
    WHERE mas.mechanic_id = up.id
);

-- 3. Check if there are any pending service requests with location data
SELECT 
    sr.id,
    sr.title,
    sr.pickup_latitude,
    sr.pickup_longitude,
    sr.pickup_address,
    sr.status,
    sr.request_type,
    sr.created_at,
    up.first_name as customer_name
FROM service_requests sr
JOIN user_profiles up ON sr.customer_id = up.id
WHERE sr.status IN ('pending', 'awaiting_payment', 'ready_to_assign')
AND sr.pickup_latitude IS NOT NULL
AND sr.pickup_longitude IS NOT NULL
ORDER BY sr.created_at DESC;

-- 4. Check database functions exist
SELECT 
    proname as function_name,
    'Function exists' as status
FROM pg_proc 
WHERE proname IN ('get_nearby_requests_for_mechanic', 'accept_nearby_request');

-- 4b. If functions don't exist, this will show manual distance calculation
-- This simulates the get_nearby_requests_for_mechanic function
WITH test_mechanic AS (
    SELECT id FROM user_profiles WHERE user_type = 'mechanic' LIMIT 1
),
test_location AS (
    SELECT 14.5995 as mechanic_lat, 120.9842 as mechanic_lng, 50.0 as max_distance_km
),
distance_calc AS (
    SELECT 
        sr.id as request_id,
        sr.customer_id,
        sr.title,
        sr.description,
        sr.pickup_latitude,
        sr.pickup_longitude,
        sr.pickup_address,
        sr.service_type,
        sr.priority,
        sr.status,
        sr.created_at,
        sr.estimated_price,
        sr.request_type,
        up.first_name as customer_first_name,
        up.last_name as customer_last_name,
        up.phone_number as customer_phone,
        up.profile_image_url as customer_profile_image,
        -- Calculate distance using Haversine formula
        (
            6371 * acos(
                cos(radians(tl.mechanic_lat)) * 
                cos(radians(sr.pickup_latitude)) * 
                cos(radians(sr.pickup_longitude) - radians(tl.mechanic_lng)) + 
                sin(radians(tl.mechanic_lat)) * 
                sin(radians(sr.pickup_latitude))
            )
        ) AS distance_km
    FROM service_requests sr
    INNER JOIN user_profiles up ON sr.customer_id = up.id
    CROSS JOIN test_location tl
    WHERE 
        sr.status IN ('pending', 'awaiting_payment', 'ready_to_assign')
        AND sr.pickup_latitude IS NOT NULL 
        AND sr.pickup_longitude IS NOT NULL
        AND sr.assigned_mechanic_id IS NULL
        AND sr.accepted_by IS NULL
)
SELECT 
    dc.*,
    ROUND(dc.distance_km::numeric, 2) as distance_km_rounded,
    CASE 
        WHEN dc.distance_km < 1 THEN CONCAT(ROUND((dc.distance_km * 1000)::numeric), 'm away')
        WHEN dc.distance_km < 10 THEN CONCAT(ROUND(dc.distance_km::numeric, 1), 'km away')
        ELSE CONCAT(ROUND(dc.distance_km::numeric), 'km away')
    END as distance_text,
    -- Estimate arrival time (assume 30 km/h average speed + 5 minutes prep)
    ROUND((dc.distance_km / 30.0 * 60) + 5) AS estimated_arrival_minutes
FROM distance_calc dc
WHERE dc.distance_km <= 50.0  -- 50km radius
ORDER BY dc.distance_km ASC;

-- 5. Create a test service request near Manila for testing
INSERT INTO service_requests (
    customer_id,
    title,
    description,
    pickup_latitude,
    pickup_longitude,
    pickup_address,
    service_type,
    status,
    request_type,
    can_accept_by_any_mechanic,
    created_at
) VALUES (
    (SELECT id FROM user_profiles WHERE user_type = 'customer' LIMIT 1),
    'Test Service Request - Location Based',
    'This is a test request to verify location-based system works',
    14.5995,  -- Manila latitude
    120.9842, -- Manila longitude
    'Manila City Hall, Manila, Philippines',
    'Emergency Repair',
    'pending',
    'broadcast',
    true,
    NOW()
) 
ON CONFLICT DO NOTHING;

-- 6. Verify the test data was created
SELECT 
    'Total Mechanics' as metric,
    COUNT(*) as count
FROM user_profiles 
WHERE user_type = 'mechanic'

UNION ALL

SELECT 
    'Mechanics with Availability Status' as metric,
    COUNT(*) as count
FROM mechanic_availability_status mas
JOIN user_profiles up ON mas.mechanic_id = up.id
WHERE up.user_type = 'mechanic'

UNION ALL

SELECT 
    'Available Mechanics' as metric,
    COUNT(*) as count
FROM mechanic_availability_status mas
JOIN user_profiles up ON mas.mechanic_id = up.id
WHERE up.user_type = 'mechanic'
AND mas.current_status = 'available'
AND mas.is_accepting_requests = true

UNION ALL

SELECT 
    'Pending Requests with Location' as metric,
    COUNT(*) as count
FROM service_requests 
WHERE status = 'pending'
AND pickup_latitude IS NOT NULL
AND pickup_longitude IS NOT NULL;