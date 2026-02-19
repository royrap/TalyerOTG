-- Debug script to investigate PostgrestException: multiple rows returned
-- This script identifies data integrity issues causing the 894 rows error

-- 1. Check for duplicate service_providers entries for same user_id
SELECT 
    user_id, 
    COUNT(*) as duplicate_count,
    array_agg(id) as provider_ids,
    array_agg(company_name) as company_names
FROM service_providers 
GROUP BY user_id 
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC;

-- 2. Check total rows in service_providers (should explain the 894 rows)
SELECT 
    COUNT(*) as total_service_providers,
    COUNT(DISTINCT user_id) as unique_users,
    COUNT(*) - COUNT(DISTINCT user_id) as duplicate_entries
FROM service_providers;

-- 3. Check if there are NULL user_ids causing issues
SELECT 
    COUNT(*) as null_user_ids
FROM service_providers 
WHERE user_id IS NULL;

-- 4. Check for missing user_profiles relationships
SELECT 
    sp.user_id,
    sp.company_name,
    CASE WHEN up.id IS NULL THEN 'MISSING_PROFILE' ELSE 'HAS_PROFILE' END as profile_status
FROM service_providers sp
LEFT JOIN user_profiles up ON sp.user_id = up.id
WHERE up.id IS NULL;

-- 5. Sample the data structure to understand the issue
SELECT 
    sp.user_id,
    sp.company_name,
    sp.current_latitude,
    sp.current_longitude,
    up.first_name,
    up.last_name
FROM service_providers sp
LEFT JOIN user_profiles up ON sp.user_id = up.id
LIMIT 10;

-- IMMEDIATE FIX: Clean up duplicate service_providers
-- (This will be applied after investigation)
/*
DELETE FROM service_providers 
WHERE id NOT IN (
    SELECT MIN(id) 
    FROM service_providers 
    GROUP BY user_id
);
*/

-- Add constraint to prevent future duplicates
/*
ALTER TABLE service_providers 
ADD CONSTRAINT unique_user_id_per_provider 
UNIQUE (user_id);
*/