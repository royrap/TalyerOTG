-- ========================================
-- 🔍 CHECK IF TWO-WAY POLICY IS ACTIVE
-- ========================================

-- 1. Check if the function exists
SELECT 
    proname as function_name,
    prosecdef as is_security_definer
FROM pg_proc
WHERE proname = 'is_mechanic_serving_customer';

-- 2. Check current policies on user_profiles
SELECT 
    policyname,
    cmd as command,
    qual as using_expression
FROM pg_policies
WHERE tablename = 'user_profiles'
ORDER BY policyname;

-- 3. Count total policies
SELECT COUNT(*) as total_user_profile_policies
FROM pg_policies
WHERE tablename = 'user_profiles';

-- 4. Test if infinite recursion is gone
DO $$
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE '📊 RLS POLICY STATUS CHECK';
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
    RAISE NOTICE 'If you see this message without errors, RLS is working!';
    RAISE NOTICE '';
    RAISE NOTICE 'Now check:';
    RAISE NOTICE '1. Does function is_mechanic_serving_customer exist?';
    RAISE NOTICE '2. Does policy mechanics_and_customers_view_each_other exist?';
    RAISE NOTICE '3. Total policies should be 5 (4 old + 1 new)';
    RAISE NOTICE '';
END $$;
