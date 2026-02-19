-- ==========================================
-- CHECK USER_PROFILES EMAIL UPDATE POLICIES
-- Para ma-verify kung pwede mag-update ng email ang users
-- ==========================================

-- Query 1: Show all user_profiles policies in detail
SELECT 
    policyname AS policy_name,
    cmd AS command,
    CASE 
        WHEN permissive = 'PERMISSIVE' THEN '✓ Permissive'
        ELSE '✗ Restrictive'
    END AS policy_type,
    roles AS applied_to_roles,
    qual AS using_condition,
    with_check AS with_check_condition
FROM pg_policies
WHERE schemaname = 'public'
    AND tablename = 'user_profiles'
ORDER BY cmd, policyname;

-- ==========================================
-- Query 2: Check specifically UPDATE policies for user_profiles
-- ==========================================
SELECT 
    policyname AS policy_name,
    roles AS applied_to_roles,
    qual AS using_condition,
    with_check AS with_check_condition,
    CASE 
        WHEN qual LIKE '%email%' OR with_check LIKE '%email%' THEN '⚠️ May email restriction'
        ELSE '✓ No email restriction'
    END AS email_restriction_status
FROM pg_policies
WHERE schemaname = 'public'
    AND tablename = 'user_profiles'
    AND (cmd = 'UPDATE' OR cmd = 'ALL')
ORDER BY policyname;

-- ==========================================
-- Query 3: Check if email column is restricted
-- ==========================================
-- This checks if there's any policy that blocks email updates
SELECT 
    policyname AS policy_name,
    cmd AS command,
    CASE 
        WHEN with_check LIKE '%email%' THEN 'WITH CHECK may email restriction'
        WHEN qual LIKE '%email%' THEN 'USING may email restriction'
        ELSE 'Walang email restriction'
    END AS restriction_type,
    COALESCE(with_check, qual) AS policy_expression
FROM pg_policies
WHERE schemaname = 'public'
    AND tablename = 'user_profiles'
    AND (with_check LIKE '%email%' OR qual LIKE '%email%')
ORDER BY policyname;

-- ==========================================
-- Query 4: Test if authenticated users can update email
-- ==========================================
-- This simulates if current policies allow email updates
SELECT 
    policyname AS policy_name,
    CASE 
        WHEN cmd = 'UPDATE' AND 'authenticated' = ANY(roles) THEN '✓ Authenticated can UPDATE'
        WHEN cmd = 'ALL' AND 'authenticated' = ANY(roles) THEN '✓ Authenticated has ALL access'
        WHEN cmd = 'UPDATE' AND 'public' = ANY(roles) THEN '✓ Public can UPDATE'
        WHEN cmd = 'ALL' AND 'public' = ANY(roles) THEN '✓ Public has ALL access'
        ELSE '✗ No update access'
    END AS update_access,
    roles AS applied_to_roles,
    CASE 
        WHEN qual LIKE '%id = auth.uid()%' OR qual LIKE '%id = (SELECT auth.uid())%' THEN '✓ Users can update own profile'
        WHEN qual IS NULL THEN '⚠️ No restriction (anyone can update)'
        ELSE '✗ Other restriction: ' || LEFT(qual, 50)
    END AS access_control
FROM pg_policies
WHERE schemaname = 'public'
    AND tablename = 'user_profiles'
    AND (cmd = 'UPDATE' OR cmd = 'ALL')
ORDER BY policyname;

-- ==========================================
-- Query 5: RECOMMENDATION - Suggested policy for email updates
-- ==========================================
/*
SABI MO HINDI PWEDE MAG-UPDATE NG EMAIL?

Tingnan mo kung meron nang ganitong policy:

CREATE POLICY "Users can update own profile"
ON public.user_profiles
FOR UPDATE
TO authenticated
USING (id = auth.uid())
WITH CHECK (id = auth.uid());

Kung gusto mong ALLOW ang email update for authenticated users:
1. Siguruhin na walang restriction sa email column
2. Siguraduhin na may policy na:
   - FOR UPDATE
   - TO authenticated
   - USING (id = auth.uid())
   - WITH CHECK (id = auth.uid())

OPTIONAL: Kung gusto mo ng extra validation sa email changes:

CREATE POLICY "Email changes require verification"
ON public.user_profiles
FOR UPDATE
TO authenticated
USING (id = auth.uid())
WITH CHECK (
  id = auth.uid() AND
  (
    email = OLD.email OR  -- Email hindi nagbago
    email_verified_at IS NULL  -- OR email change pending verification
  )
);

PERO SA CURRENT SETUP mo, dapat pwede na mag-update ng email
kung may policy na "Users can update own profile" o similar.
*/

-- ==========================================
-- Query 6: Check table columns to verify email column exists
-- ==========================================
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'public'
    AND table_name = 'user_profiles'
    AND column_name IN ('email', 'temp_email', 'email_change_token', 'email_change_expires_at')
ORDER BY column_name;

-- ==========================================
-- Query 7: Summary - Can users update email?
-- ==========================================
SELECT 
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM pg_policies
            WHERE schemaname = 'public'
                AND tablename = 'user_profiles'
                AND (cmd = 'UPDATE' OR cmd = 'ALL')
                AND (
                    'authenticated' = ANY(roles) OR
                    'public' = ANY(roles)
                )
                AND (
                    qual LIKE '%auth.uid()%' OR
                    qual IS NULL
                )
                AND (
                    with_check NOT LIKE '%email%' OR
                    with_check IS NULL
                )
        ) THEN '✅ YES - Users can update their email'
        ELSE '❌ NO - Email updates may be blocked'
    END AS can_users_update_email,
    (
        SELECT COUNT(*)
        FROM pg_policies
        WHERE schemaname = 'public'
            AND tablename = 'user_profiles'
            AND (cmd = 'UPDATE' OR cmd = 'ALL')
    ) AS total_update_policies,
    (
        SELECT COUNT(*)
        FROM pg_policies
        WHERE schemaname = 'public'
            AND tablename = 'user_profiles'
            AND (cmd = 'UPDATE' OR cmd = 'ALL')
            AND (with_check LIKE '%email%' OR qual LIKE '%email%')
    ) AS policies_with_email_restriction;
