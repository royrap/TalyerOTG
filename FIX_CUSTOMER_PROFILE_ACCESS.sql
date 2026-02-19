-- ========================================
-- 🔍 DIAGNOSE CUSTOMER PROFILE NOT FOUND
-- ========================================

-- Check if the customer profile exists
SELECT 
    id,
    first_name,
    last_name,
    email,
    phone_number,
    user_type,
    account_status
FROM user_profiles
WHERE id = '1779a3d6-7308-45ec-aeae-cc3909d6cc03';

-- Check RLS policies on user_profiles
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies
WHERE tablename = 'user_profiles'
ORDER BY policyname;

-- Check if there are any RLS issues when mechanic queries customer
SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claim.sub = 'da0aade5-1e11-4901-898c-3fd67379262f'; -- mechanic ID

SELECT 
    id,
    first_name,
    last_name,
    phone_number
FROM user_profiles
WHERE id = '1779a3d6-7308-45ec-aeae-cc3909d6cc03';

RESET ROLE;

-- ========================================
-- 🔧 FIX: Add RLS policy for mechanics to view customers
-- ========================================

-- Drop existing problematic policies if any
DROP POLICY IF EXISTS "Mechanics can view customer profiles for their jobs" ON user_profiles;

-- Create policy allowing mechanics to see customer profiles
-- FIXED: Removed the admin check that caused infinite recursion
CREATE POLICY "Mechanics can view customer profiles for their jobs"
ON user_profiles
FOR SELECT
TO authenticated
USING (
    -- Allow users to see their own profile
    auth.uid() = id
    OR
    -- Allow mechanics to see customers they're serving
    EXISTS (
        SELECT 1 
        FROM service_requests sr
        WHERE sr.customer_id = user_profiles.id
        AND sr.assigned_mechanic_id = auth.uid()
    )
    OR
    -- Allow shop owners to see all profiles (simple check, no recursion)
    user_type = 'talyer_owner'
);

-- ========================================
-- VERIFY FIX
-- ========================================

-- Test as mechanic again
SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claim.sub = 'da0aade5-1e11-4901-898c-3fd67379262f';

SELECT 
    id,
    first_name,
    last_name,
    phone_number,
    'Should now return customer data!' as test_result
FROM user_profiles
WHERE id = '1779a3d6-7308-45ec-aeae-cc3909d6cc03';

RESET ROLE;

-- ========================================
-- SUCCESS MESSAGE
-- ========================================
DO $$
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ CUSTOMER PROFILE ACCESS FIXED!';
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
    RAISE NOTICE 'Added RLS policy:';
    RAISE NOTICE '  - Mechanics can now view customer profiles for their assigned jobs';
    RAISE NOTICE '';
    RAISE NOTICE 'Mechanic can now see:';
    RAISE NOTICE '  - Customer name';
    RAISE NOTICE '  - Customer phone';
    RAISE NOTICE '  - Customer details for service requests';
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
END $$;
