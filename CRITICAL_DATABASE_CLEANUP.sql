-- CRITICAL: Clean up duplicate service_providers causing PostgrestException
-- This script fixes the "multiple rows returned" error affecting getMechanicLocationForRequest

-- Step 1: Backup affected data before cleanup
CREATE TABLE IF NOT EXISTS service_providers_backup AS
SELECT * FROM service_providers;

-- Step 2: Identify and display duplicate entries
DO $$
DECLARE
    duplicate_count integer;
    total_count integer;
    unique_count integer;
BEGIN
    SELECT COUNT(*) INTO total_count FROM service_providers;
    SELECT COUNT(DISTINCT user_id) INTO unique_count FROM service_providers;
    duplicate_count := total_count - unique_count;
    
    RAISE NOTICE '📊 Service Providers Analysis:';
    RAISE NOTICE '  Total entries: %', total_count;
    RAISE NOTICE '  Unique users: %', unique_count;
    RAISE NOTICE '  Duplicates: %', duplicate_count;
    
    IF duplicate_count > 0 THEN
        RAISE NOTICE '🚨 Found % duplicate entries that need cleanup', duplicate_count;
    ELSE
        RAISE NOTICE '✅ No duplicates found';
    END IF;
END
$$;

-- Step 3: Show specific duplicate entries for review
SELECT 
    user_id, 
    COUNT(*) as duplicate_count,
    array_agg(id ORDER BY created_at DESC) as provider_ids,
    array_agg(company_name) as company_names
FROM service_providers 
GROUP BY user_id 
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC;

-- Step 4: Clean up duplicates (keeps most recent entry per user_id)
DELETE FROM service_providers 
WHERE id NOT IN (
    SELECT DISTINCT ON (user_id) id
    FROM service_providers 
    ORDER BY user_id, created_at DESC
);

-- Step 5: Add constraint to prevent future duplicates
ALTER TABLE service_providers 
DROP CONSTRAINT IF EXISTS unique_user_id_per_provider;

ALTER TABLE service_providers 
ADD CONSTRAINT unique_user_id_per_provider 
UNIQUE (user_id);

-- Step 6: Verify cleanup success
DO $$
DECLARE
    remaining_duplicates integer;
    total_after integer;
BEGIN
    SELECT COUNT(*) INTO total_after FROM service_providers;
    
    SELECT COUNT(*) INTO remaining_duplicates 
    FROM (
        SELECT user_id, COUNT(*) 
        FROM service_providers 
        GROUP BY user_id 
        HAVING COUNT(*) > 1
    ) duplicates;
    
    RAISE NOTICE '🔍 Post-cleanup verification:';
    RAISE NOTICE '  Total entries after cleanup: %', total_after;
    RAISE NOTICE '  Remaining duplicates: %', remaining_duplicates;
    
    IF remaining_duplicates = 0 THEN
        RAISE NOTICE '✅ Cleanup successful - no duplicates remain';
        RAISE NOTICE '✅ getMechanicLocationForRequest should now work properly';
    ELSE
        RAISE NOTICE '❌ Cleanup incomplete - % duplicates still exist', remaining_duplicates;
    END IF;
END
$$;

-- Step 7: Test the fixed query (simulates the application query)
DO $$
DECLARE
    test_user_id text;
    result_count integer;
BEGIN
    -- Get a sample user_id to test with
    SELECT user_id INTO test_user_id 
    FROM service_providers 
    LIMIT 1;
    
    IF test_user_id IS NOT NULL THEN
        -- Count how many rows would be returned
        SELECT COUNT(*) INTO result_count
        FROM service_providers sp
        LEFT JOIN user_profiles up ON sp.user_id = up.id
        WHERE sp.user_id = test_user_id;
        
        RAISE NOTICE '🧪 Test Query Results:';
        RAISE NOTICE '  Test user_id: %', test_user_id;
        RAISE NOTICE '  Rows returned: %', result_count;
        
        IF result_count = 1 THEN
            RAISE NOTICE '✅ Query returns single row as expected';
        ELSE
            RAISE NOTICE '❌ Query still returns % rows - issue not resolved', result_count;
        END IF;
    END IF;
END
$$;

RAISE NOTICE '🎯 Database integrity restored!';
RAISE NOTICE '📱 The app should now work without PostgrestException errors';
RAISE NOTICE '💡 Constraint added prevents future duplicates';