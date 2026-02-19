-- ====================================================================
-- QUICK FIX: POPULATE MECHANICS TABLE (SCHEMA-MATCHED VERSION)
-- ====================================================================
-- This is a streamlined version that matches your EXACT schema
-- Run this FIRST before the other fixes
-- ====================================================================

-- Check what mechanic users exist
SELECT 
    '🔍 Step 1: Checking mechanic users in user_profiles' as step;

SELECT 
    id,
    email,
    first_name || ' ' || last_name as full_name,
    user_type,
    status,
    shop_id
FROM user_profiles
WHERE user_type = 'mechanic'
ORDER BY created_at DESC;

-- ====================================================================
-- Insert into mechanics table
-- ====================================================================

SELECT 
    '📝 Step 2: Inserting mechanics into mechanics table' as step;

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
    up.id,
    up.shop_id,
    ARRAY['general_repair']::TEXT[],
    'certified',
    0,
    500.00,
    'available',
    up.current_latitude,
    up.current_longitude,
    ARRAY[]::TEXT[],
    '{}'::jsonb,
    0.0,
    0,
    true,
    NOW(),
    NOW()
FROM user_profiles up
WHERE up.user_type = 'mechanic'
AND NOT EXISTS (
    SELECT 1 FROM mechanics m WHERE m.user_id = up.id
);

-- Verify
SELECT 
    '✅ Step 3: Verifying mechanics table' as step;

SELECT 
    m.id,
    up.email,
    up.first_name || ' ' || up.last_name as name,
    m.availability_status,
    m.is_active,
    m.shop_id,
    m.created_at
FROM mechanics m
INNER JOIN user_profiles up ON m.user_id = up.id
ORDER BY m.created_at DESC;

-- ====================================================================
-- Sync with service_providers
-- ====================================================================

SELECT 
    '📝 Step 4: Syncing with service_providers' as step;

INSERT INTO service_providers (
    user_id,
    company_name,
    is_verified,
    is_available,
    status,
    rating,
    total_reviews,
    shop_id,
    created_at,
    updated_at
)
SELECT 
    up.id,
    up.first_name || ' ' || up.last_name || ' (Mechanic)',
    true,
    true,
    'offline',
    0.0,
    0,
    up.shop_id,
    NOW(),
    NOW()
FROM user_profiles up
WHERE up.user_type = 'mechanic'
AND NOT EXISTS (
    SELECT 1 FROM service_providers sp WHERE sp.user_id = up.id
)
ON CONFLICT (user_id) DO UPDATE
SET 
    is_verified = true,
    shop_id = EXCLUDED.shop_id,
    updated_at = NOW();

-- ====================================================================
-- Ensure mechanic_availability_status
-- ====================================================================

SELECT 
    '📝 Step 5: Creating availability status entries' as step;

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
    up.id,
    up.shop_id,
    'available',
    up.current_latitude,
    up.current_longitude,
    true,
    NOW(),
    NOW(),
    NOW()
FROM user_profiles up
WHERE up.user_type = 'mechanic'
AND NOT EXISTS (
    SELECT 1 FROM mechanic_availability_status mas WHERE mas.mechanic_id = up.id
)
ON CONFLICT (mechanic_id) DO UPDATE
SET 
    current_status = 'available',
    is_accepting_requests = true,
    shop_id = EXCLUDED.shop_id,
    last_status_update = NOW(),
    updated_at = NOW();

-- ====================================================================
-- FINAL VERIFICATION
-- ====================================================================

SELECT 
    '✅ FINAL VERIFICATION - ALL TABLES SYNCED' as step;

SELECT 
    up.id,
    up.email,
    up.first_name || ' ' || up.last_name as name,
    up.user_type,
    up.shop_id as user_profile_shop,
    CASE WHEN m.id IS NOT NULL THEN '✅' ELSE '❌' END as mechanics_table,
    CASE WHEN sp.id IS NOT NULL THEN '✅' ELSE '❌' END as service_providers_table,
    CASE WHEN mas.id IS NOT NULL THEN '✅' ELSE '❌' END as availability_status_table,
    m.availability_status,
    mas.current_status,
    mas.is_accepting_requests,
    s.shop_name
FROM user_profiles up
LEFT JOIN mechanics m ON m.user_id = up.id
LEFT JOIN service_providers sp ON sp.user_id = up.id
LEFT JOIN mechanic_availability_status mas ON mas.mechanic_id = up.id
LEFT JOIN shops s ON s.id = up.shop_id
WHERE up.user_type = 'mechanic'
ORDER BY up.created_at DESC;

-- Summary counts
SELECT 
    '📊 SUMMARY' as step;

SELECT 
    (SELECT COUNT(*) FROM user_profiles WHERE user_type = 'mechanic') as total_mechanic_users,
    (SELECT COUNT(*) FROM mechanics) as in_mechanics_table,
    (SELECT COUNT(*) FROM service_providers sp 
     INNER JOIN user_profiles up ON sp.user_id = up.id 
     WHERE up.user_type = 'mechanic') as in_service_providers,
    (SELECT COUNT(*) FROM mechanic_availability_status) as has_availability_status,
    (SELECT COUNT(*) FROM shop_mechanics WHERE is_active = true) as shop_assignments;

-- ====================================================================
-- SUCCESS MESSAGE
-- ====================================================================
SELECT 
    '🎉 MECHANICS TABLE POPULATED!' as result,
    'Now run: FIX_NUMERIC_OVERFLOW_AND_FK_ERRORS.sql' as next_step,
    'Then restart app: flutter run' as final_step;
