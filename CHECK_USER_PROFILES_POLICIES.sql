-- ========================================
-- 🔍 CHECK ALL RLS POLICIES ON user_profiles
-- ========================================

-- List all policies on user_profiles table
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd as command,
    qual as using_expression,
    with_check as with_check_expression
FROM pg_policies
WHERE tablename = 'user_profiles'
ORDER BY policyname;

-- ========================================
-- 🔍 CHECK SPECIFIC POLICY DETAILS
-- ========================================

-- Get the exact SQL definition of each policy
SELECT 
    polname as policy_name,
    polcmd as command,
    polpermissive as is_permissive,
    polroles::regrole[] as roles,
    pg_get_expr(polqual, polrelid) as using_clause,
    pg_get_expr(polwithcheck, polrelid) as with_check_clause
FROM pg_policy
WHERE polrelid = 'user_profiles'::regclass
ORDER BY polname;

-- ========================================
-- 🔍 CHECK IF RLS IS ENABLED
-- ========================================

SELECT 
    schemaname,
    tablename,
    rowsecurity as rls_enabled
FROM pg_tables
WHERE tablename = 'user_profiles';

-- ========================================
-- 📊 SUMMARY
-- ========================================

DO $$
DECLARE
    policy_count INTEGER;
    rls_enabled BOOLEAN;
BEGIN
    -- Count policies
    SELECT COUNT(*) INTO policy_count
    FROM pg_policies
    WHERE tablename = 'user_profiles';
    
    -- Check RLS status
    SELECT rowsecurity INTO rls_enabled
    FROM pg_tables
    WHERE tablename = 'user_profiles';
    
    RAISE NOTICE '========================================';
    RAISE NOTICE '📊 USER_PROFILES RLS SUMMARY';
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
    RAISE NOTICE 'RLS Enabled: %', CASE WHEN rls_enabled THEN 'YES' ELSE 'NO' END;
    RAISE NOTICE 'Total Policies: %', policy_count;
    RAISE NOTICE '';
    
    IF policy_count = 0 THEN
        RAISE NOTICE '⚠️  WARNING: No policies found!';
        RAISE NOTICE 'Users may not be able to access any data.';
    ELSIF policy_count > 5 THEN
        RAISE NOTICE '⚠️  WARNING: Many policies detected!';
        RAISE NOTICE 'May cause performance issues or conflicts.';
    ELSE
        RAISE NOTICE '✅ Policy count looks reasonable.';
    END IF;
    
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
END $$;
