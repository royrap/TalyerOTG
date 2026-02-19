-- ============================================================================
-- MIGRATION: Provider to Mechanic Foreign Key Conversion
-- ============================================================================
-- Purpose: Change service_requests.provider_id to reference user_profiles (mechanics)
--          instead of service_providers table
-- Date: October 2, 2025
-- Impact: service_requests table foreign key constraint
-- ============================================================================

-- STEP 1: Backup current data
-- ============================================================================
CREATE TABLE IF NOT EXISTS service_requests_backup_20251002 AS 
SELECT * FROM service_requests;

-- STEP 2: Check current provider_id references
-- ============================================================================
-- This query shows how many service_requests currently use provider_id
SELECT 
    COUNT(*) as total_requests,
    COUNT(provider_id) as requests_with_provider,
    COUNT(assigned_mechanic_id) as requests_with_mechanic
FROM service_requests;

-- STEP 3: Drop the old foreign key constraint
-- ============================================================================
ALTER TABLE service_requests 
DROP CONSTRAINT IF EXISTS service_requests_provider_id_fkey;

-- STEP 4: Add new foreign key constraint pointing to user_profiles
-- ============================================================================
-- This makes provider_id reference mechanics in user_profiles table
ALTER TABLE service_requests 
ADD CONSTRAINT service_requests_provider_id_fkey 
FOREIGN KEY (provider_id) 
REFERENCES user_profiles(id) 
ON DELETE SET NULL;

-- STEP 5: Create index for performance
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_service_requests_provider_id 
ON service_requests(provider_id);

-- STEP 6: Verify the new constraint
-- ============================================================================
SELECT
    tc.table_name, 
    tc.constraint_name, 
    tc.constraint_type,
    kcu.column_name,
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name 
FROM information_schema.table_constraints AS tc 
JOIN information_schema.key_column_usage AS kcu
  ON tc.constraint_name = kcu.constraint_name
  AND tc.table_schema = kcu.table_schema
JOIN information_schema.constraint_column_usage AS ccu
  ON ccu.constraint_name = tc.constraint_name
  AND ccu.table_schema = tc.table_schema
WHERE tc.table_name = 'service_requests' 
  AND tc.constraint_name = 'service_requests_provider_id_fkey';

-- ============================================================================
-- DATA MIGRATION (Optional - if needed)
-- ============================================================================
-- If you have existing provider_id values that reference service_providers,
-- you may need to migrate them to the mechanic user_id

-- Example: Update provider_id to match the actual mechanic user_id
-- UPDATE service_requests sr
-- SET provider_id = sp.user_id
-- FROM service_providers sp
-- WHERE sr.provider_id = sp.id
-- AND sr.provider_id IS NOT NULL;

-- ============================================================================
-- VERIFICATION QUERIES
-- ============================================================================

-- Check all foreign keys on service_requests table
SELECT
    tc.constraint_name,
    kcu.column_name,
    ccu.table_name AS references_table,
    ccu.column_name AS references_column
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu 
    ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage ccu 
    ON ccu.constraint_name = tc.constraint_name
WHERE tc.table_name = 'service_requests'
    AND tc.constraint_type = 'FOREIGN KEY'
ORDER BY kcu.column_name;

-- Verify provider_id now points to user_profiles
SELECT 
    sr.id,
    sr.provider_id,
    up.email as mechanic_email,
    up.first_name,
    up.last_name,
    up.user_type
FROM service_requests sr
LEFT JOIN user_profiles up ON sr.provider_id = up.id
WHERE sr.provider_id IS NOT NULL
LIMIT 10;

-- ============================================================================
-- ROLLBACK SCRIPT (In case you need to revert)
-- ============================================================================
-- To rollback this migration, run:
-- 
-- ALTER TABLE service_requests DROP CONSTRAINT service_requests_provider_id_fkey;
-- ALTER TABLE service_requests ADD CONSTRAINT service_requests_provider_id_fkey 
--     FOREIGN KEY (provider_id) REFERENCES service_providers(id) ON DELETE SET NULL;
-- ============================================================================

-- SUCCESS MESSAGE
DO $$
BEGIN
    RAISE NOTICE '✅ Migration completed successfully!';
    RAISE NOTICE '   - Old constraint dropped: service_requests_provider_id_fkey → service_providers';
    RAISE NOTICE '   - New constraint added: service_requests_provider_id_fkey → user_profiles';
    RAISE NOTICE '   - provider_id now references mechanics in user_profiles table';
    RAISE NOTICE '   - Index created for performance optimization';
END $$;
