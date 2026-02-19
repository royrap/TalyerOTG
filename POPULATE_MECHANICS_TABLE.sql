-- ====================================================================
-- POPULATE MECHANICS TABLE FROM USER_PROFILES
-- ====================================================================
-- This script will:
-- 1. Check existing mechanics in user_profiles
-- 2. Create entries in mechanics table for each mechanic user
-- 3. Link them to shops via shop_mechanics if needed
-- ====================================================================

-- STEP 1: Check current mechanic users
SELECT 
    '🔍 CURRENT MECHANIC USERS IN USER_PROFILES' as info;

SELECT 
    id,
    email,
    first_name,
    last_name,
    user_type,
    status,
    created_at
FROM user_profiles
WHERE user_type = 'mechanic'
ORDER BY created_at DESC;

-- ====================================================================
-- STEP 2: Insert mechanics into mechanics table
-- ====================================================================

-- This will create a mechanic entry for EVERY user with user_type = 'mechanic'
-- Only inserts if they don't already exist in mechanics table
-- NOTE: Your mechanics table has different columns than expected

INSERT INTO mechanics (
    user_id,
    shop_id,
    specializations,
    certification_level,
    experience_years,
    hourly_rate,
    availability_status,
    current_location_lat,
    current_location_lng,
    tools_owned,
    vehicle_info,
    rating_average,
    total_jobs_completed,
    is_active,
    created_at,
    updated_at
)
SELECT 
    up.id as user_id,
    up.shop_id,  -- Use shop_id from user_profiles if exists
    ARRAY['general_repair']::TEXT[] as specializations,
    'certified' as certification_level,
    0 as experience_years,
    500.00 as hourly_rate,  -- Default rate
    'available' as availability_status,
    up.current_latitude as current_location_lat,
    up.current_longitude as current_location_lng,
    ARRAY[]::TEXT[] as tools_owned,
    '{}'::jsonb as vehicle_info,
    0.0 as rating_average,
    0 as total_jobs_completed,
    true as is_active,
    NOW() as created_at,
    NOW() as updated_at
FROM user_profiles up
WHERE up.user_type = 'mechanic'
AND NOT EXISTS (
    SELECT 1 FROM mechanics m WHERE m.user_id = up.id
);

-- Verify insertion
SELECT 
    '✅ MECHANICS INSERTED/UPDATED' as info;

SELECT 
    m.id as mechanic_id,
    m.user_id,
    up.email,
    up.first_name,
    up.last_name,
    m.availability_status,
    m.is_active,
    m.rating_average,
    m.total_jobs_completed,
    m.created_at
FROM mechanics m
INNER JOIN user_profiles up ON m.user_id = up.id
ORDER BY m.created_at DESC;

-- ====================================================================
-- STEP 3: Sync mechanics with service_providers table
-- ====================================================================
-- Your system uses service_providers table for some queries
-- Let's ensure mechanics exist there too

INSERT INTO service_providers (
    user_id,
    business_name,
    is_verified,
    is_available,
    status,
    rating,
    total_reviews,
    created_at,
    updated_at
)
SELECT 
    up.id as user_id,
    CONCAT(up.first_name, ' ', up.last_name, ' (Mechanic)') as business_name,
    true as is_verified,
    true as is_available,
    'offline' as status,
    0.0 as rating,
    0 as total_reviews,
    NOW() as created_at,
    NOW() as updated_at
FROM user_profiles up
WHERE up.user_type = 'mechanic'
AND NOT EXISTS (
    SELECT 1 FROM service_providers sp WHERE sp.user_id = up.id
)
ON CONFLICT (user_id) DO UPDATE
SET 
    is_verified = true,
    updated_at = NOW();

-- ====================================================================
-- STEP 4: Link mechanics to shops (if you have shop assignments)
-- ====================================================================

-- Check if shop_mechanics table has entries
SELECT 
    '🏪 CURRENT SHOP-MECHANIC ASSIGNMENTS' as info;

SELECT 
    sm.id,
    s.shop_name,
    CONCAT(up.first_name, ' ', up.last_name) as mechanic_name,
    sm.is_active,
    sm.created_at
FROM shop_mechanics sm
INNER JOIN shops s ON s.id = sm.shop_id
INNER JOIN user_profiles up ON up.id = sm.mechanic_id
ORDER BY s.shop_name, up.first_name;

-- ====================================================================
-- STEP 5: Ensure mechanic_availability_status entries exist
-- ====================================================================

INSERT INTO mechanic_availability_status (
    mechanic_id,
    shop_id,
    current_status,
    location_latitude,
    location_longitude,
    is_accepting_requests,
    last_status_update,
    created_at,
    updated_at
)
SELECT 
    up.id as mechanic_id,
    NULL as shop_id,  -- Will be updated when mechanic goes online
    'available' as current_status,
    NULL as location_latitude,
    NULL as location_longitude,
    true as is_accepting_requests,
    NOW() as last_status_update,
    NOW() as created_at,
    NOW() as updated_at
FROM user_profiles up
WHERE up.user_type = 'mechanic'
AND NOT EXISTS (
    SELECT 1 FROM mechanic_availability_status mas WHERE mas.mechanic_id = up.id
)
ON CONFLICT (mechanic_id) DO UPDATE
SET 
    current_status = 'available',
    is_accepting_requests = true,
    last_status_update = NOW(),
    updated_at = NOW();

-- ====================================================================
-- VERIFICATION QUERIES
-- ====================================================================

-- Check final state
SELECT 
    '📊 FINAL VERIFICATION - ALL MECHANICS' as info;

SELECT 
    up.id as user_id,
    up.email,
    CONCAT(up.first_name, ' ', up.last_name) as name,
    up.user_type,
    CASE WHEN m.id IS NOT NULL THEN '✅' ELSE '❌' END as in_mechanics_table,
    CASE WHEN sp.id IS NOT NULL THEN '✅' ELSE '❌' END as in_service_providers,
    CASE WHEN mas.id IS NOT NULL THEN '✅' ELSE '❌' END as has_availability_status,
    CASE WHEN sm.id IS NOT NULL THEN s.shop_name ELSE 'No shop' END as shop_assignment,
    m.availability_status as mechanic_status,
    mas.current_status as availability,
    mas.is_accepting_requests,
    m.is_active
FROM user_profiles up
LEFT JOIN mechanics m ON m.user_id = up.id
LEFT JOIN service_providers sp ON sp.user_id = up.id
LEFT JOIN mechanic_availability_status mas ON mas.mechanic_id = up.id
LEFT JOIN shop_mechanics sm ON sm.mechanic_id = up.id AND sm.is_active = true
LEFT JOIN shops s ON s.id = sm.shop_id
WHERE up.user_type = 'mechanic'
ORDER BY up.created_at DESC;

-- Count summary
SELECT 
    '📈 SUMMARY COUNTS' as info;

SELECT 
    (SELECT COUNT(*) FROM user_profiles WHERE user_type = 'mechanic') as total_mechanic_users,
    (SELECT COUNT(*) FROM mechanics) as total_in_mechanics_table,
    (SELECT COUNT(*) FROM service_providers sp INNER JOIN user_profiles up ON sp.user_id = up.id WHERE up.user_type = 'mechanic') as total_in_service_providers,
    (SELECT COUNT(*) FROM mechanic_availability_status) as total_with_availability_status,
    (SELECT COUNT(*) FROM shop_mechanics WHERE is_active = true) as total_shop_assignments;

-- ====================================================================
-- MANUAL INSERTION TEMPLATE (if needed)
-- ====================================================================
/*
-- If you need to manually add a specific mechanic, use this template:

INSERT INTO mechanics (
    user_id,
    shop_id,
    specializations,
    years_experience,
    is_available,
    is_verified,
    is_independent,
    status
) VALUES (
    'YOUR_USER_ID_HERE'::UUID,  -- From user_profiles.id
    NULL,  -- shop_id (or specific shop UUID)
    ARRAY['general_repair', 'engine_repair']::TEXT[],
    2,  -- years of experience
    true,  -- is_available
    true,  -- is_verified
    false,  -- is_independent (false if shop-based)
    'offline'  -- status
);

-- Then ensure availability status:
INSERT INTO mechanic_availability_status (mechanic_id, current_status, is_accepting_requests)
VALUES ('YOUR_USER_ID_HERE'::UUID, 'available', true)
ON CONFLICT (mechanic_id) DO UPDATE 
SET current_status = 'available', is_accepting_requests = true;

-- If assigning to a shop:
INSERT INTO shop_mechanics (shop_id, mechanic_id, is_active)
VALUES ('YOUR_SHOP_ID_HERE'::UUID, 'YOUR_USER_ID_HERE'::UUID, true);
*/

-- ====================================================================
-- TROUBLESHOOTING
-- ====================================================================
/*
IF YOU STILL SEE ERRORS AFTER RUNNING THIS:

1. Check if user_profiles has mechanics:
   SELECT COUNT(*) FROM user_profiles WHERE user_type = 'mechanic';
   
   If 0: You need to create mechanic users first in your app's registration

2. Check RLS policies:
   SELECT * FROM pg_policies WHERE tablename = 'mechanics';
   
   Make sure mechanics table has proper SELECT policies

3. Check if mechanics can see their own data:
   SET ROLE authenticated;
   SET request.jwt.claims.sub = 'YOUR_MECHANIC_USER_ID';
   SELECT * FROM mechanics WHERE user_id = 'YOUR_MECHANIC_USER_ID';
*/
