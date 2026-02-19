-- ==========================================
-- COMPREHENSIVE RLS POLICY VIEWER
-- Shows all Row Level Security policies for all tables
-- ==========================================

-- Query 1: Get all policies with details
SELECT 
    schemaname AS schema_name,
    tablename AS table_name,
    policyname AS policy_name,
    permissive AS is_permissive,
    roles AS applied_to_roles,
    cmd AS command_type,
    qual AS using_expression,
    with_check AS with_check_expression
FROM pg_policies
WHERE schemaname = 'public'
ORDER BY tablename, policyname;

-- ==========================================
-- Query 2: Count policies per table
-- ==========================================
SELECT 
    tablename AS table_name,
    COUNT(*) AS policy_count,
    COUNT(CASE WHEN cmd = 'SELECT' THEN 1 END) AS select_policies,
    COUNT(CASE WHEN cmd = 'INSERT' THEN 1 END) AS insert_policies,
    COUNT(CASE WHEN cmd = 'UPDATE' THEN 1 END) AS update_policies,
    COUNT(CASE WHEN cmd = 'DELETE' THEN 1 END) AS delete_policies,
    COUNT(CASE WHEN cmd = 'ALL' THEN 1 END) AS all_command_policies
FROM pg_policies
WHERE schemaname = 'public'
GROUP BY tablename
ORDER BY policy_count DESC, tablename;

-- ==========================================
-- Query 3: Tables WITHOUT RLS policies
-- ==========================================
SELECT 
    t.tablename AS table_name
FROM pg_tables t
LEFT JOIN pg_policies p ON t.tablename = p.tablename AND t.schemaname = p.schemaname
WHERE t.schemaname = 'public'
    AND p.policyname IS NULL
    AND t.tablename NOT LIKE 'pg_%'
    AND t.tablename NOT IN ('spatial_ref_sys', 'service_providers_backup')
ORDER BY t.tablename;

-- ==========================================
-- Query 4: RLS Status for all tables
-- ==========================================
SELECT 
    schemaname AS schema_name,
    tablename AS table_name,
    rowsecurity AS rls_enabled,
    CASE 
        WHEN rowsecurity THEN 'ENABLED'
        ELSE 'DISABLED'
    END AS rls_status
FROM pg_tables
WHERE schemaname = 'public'
    AND tablename NOT LIKE 'pg_%'
    AND tablename NOT IN ('spatial_ref_sys', 'service_providers_backup')
ORDER BY rowsecurity DESC, tablename;

-- ==========================================
-- Query 5: Detailed policy information by table
-- ==========================================
SELECT 
    tablename AS table_name,
    policyname AS policy_name,
    cmd AS command,
    CASE 
        WHEN permissive = 'PERMISSIVE' THEN '✓ Permissive'
        ELSE '✗ Restrictive'
    END AS policy_type,
    CASE 
        WHEN roles = '{public}' THEN 'Everyone (public)'
        ELSE array_to_string(roles, ', ')
    END AS roles,
    CASE 
        WHEN qual IS NULL THEN 'No restriction'
        ELSE qual
    END AS using_condition,
    CASE 
        WHEN with_check IS NULL THEN 'No check'
        ELSE with_check
    END AS with_check_condition
FROM pg_policies
WHERE schemaname = 'public'
ORDER BY tablename, policyname;

-- ==========================================
-- Query 6: Policies by role
-- ==========================================
SELECT 
    unnest(roles) AS role_name,
    COUNT(*) AS policy_count,
    array_agg(DISTINCT tablename ORDER BY tablename) AS tables
FROM pg_policies
WHERE schemaname = 'public'
GROUP BY unnest(roles)
ORDER BY policy_count DESC;

-- ==========================================
-- Query 7: Complex policies (with expressions)
-- ==========================================
SELECT 
    tablename AS table_name,
    policyname AS policy_name,
    cmd AS command,
    qual AS using_expression,
    with_check AS with_check_expression
FROM pg_policies
WHERE schemaname = 'public'
    AND (qual IS NOT NULL OR with_check IS NOT NULL)
ORDER BY tablename, policyname;

-- ==========================================
-- Query 8: Security summary report
-- ==========================================
SELECT 
    COUNT(DISTINCT t.tablename) AS total_tables,
    COUNT(DISTINCT CASE WHEN t.rowsecurity THEN t.tablename END) AS tables_with_rls_enabled,
    COUNT(DISTINCT CASE WHEN NOT t.rowsecurity THEN t.tablename END) AS tables_with_rls_disabled,
    COUNT(p.policyname) AS total_policies,
    COUNT(DISTINCT p.tablename) AS tables_with_policies,
    COUNT(DISTINCT t.tablename) - COUNT(DISTINCT p.tablename) AS tables_without_policies
FROM pg_tables t
LEFT JOIN pg_policies p ON t.tablename = p.tablename AND t.schemaname = p.schemaname
WHERE t.schemaname = 'public'
    AND t.tablename NOT LIKE 'pg_%'
    AND t.tablename NOT IN ('spatial_ref_sys', 'service_providers_backup');

-- ==========================================
-- Query 9: Policies grouped by command type
-- ==========================================
SELECT 
    cmd AS command_type,
    COUNT(*) AS policy_count,
    COUNT(DISTINCT tablename) AS affected_tables,
    array_agg(DISTINCT tablename ORDER BY tablename) AS tables
FROM pg_policies
WHERE schemaname = 'public'
GROUP BY cmd
ORDER BY policy_count DESC;

-- ==========================================
-- Query 10: Find specific table policies
-- ==========================================
-- Example: Find all policies for user_profiles table
-- Uncomment and modify the table name to search:
/*
SELECT 
    policyname AS policy_name,
    cmd AS command,
    permissive AS type,
    roles,
    qual AS using_condition,
    with_check AS check_condition
FROM pg_policies
WHERE schemaname = 'public'
    AND tablename = 'user_profiles'
ORDER BY policyname;
*/

-- ==========================================
-- Query 11: Check for auth.users references in policies
-- ==========================================
SELECT 
    tablename AS table_name,
    policyname AS policy_name,
    qual AS policy_expression
FROM pg_policies
WHERE schemaname = 'public'
    AND (qual LIKE '%auth.uid()%' OR qual LIKE '%auth.jwt()%')
ORDER BY tablename, policyname;

-- ==========================================
-- Query 12: Export policy creation statements
-- ==========================================
SELECT 
    'CREATE POLICY "' || policyname || '" ON public.' || tablename ||
    E'\n  AS ' || CASE WHEN permissive = 'PERMISSIVE' THEN 'PERMISSIVE' ELSE 'RESTRICTIVE' END ||
    E'\n  FOR ' || cmd ||
    E'\n  TO ' || array_to_string(roles, ', ') ||
    CASE WHEN qual IS NOT NULL THEN E'\n  USING (' || qual || ')' ELSE '' END ||
    CASE WHEN with_check IS NOT NULL THEN E'\n  WITH CHECK (' || with_check || ')' ELSE '' END ||
    ';' AS policy_create_statement
FROM pg_policies
WHERE schemaname = 'public'
ORDER BY tablename, policyname;

-- ==========================================
-- Query 13: Tables by security level
-- ==========================================
WITH policy_counts AS (
    SELECT 
        t.tablename,
        t.rowsecurity,
        COUNT(p.policyname) AS policy_count
    FROM pg_tables t
    LEFT JOIN pg_policies p ON t.tablename = p.tablename AND t.schemaname = p.schemaname
    WHERE t.schemaname = 'public'
        AND t.tablename NOT LIKE 'pg_%'
        AND t.tablename NOT IN ('spatial_ref_sys', 'service_providers_backup')
    GROUP BY t.tablename, t.rowsecurity
)
SELECT 
    tablename AS table_name,
    CASE 
        WHEN rowsecurity AND policy_count > 0 THEN '🔒 Secured (RLS + Policies)'
        WHEN rowsecurity AND policy_count = 0 THEN '⚠️ RLS Enabled but No Policies'
        WHEN NOT rowsecurity AND policy_count > 0 THEN '⚠️ Has Policies but RLS Disabled'
        ELSE '🔓 Unsecured (No RLS)'
    END AS security_status,
    policy_count AS number_of_policies
FROM policy_counts
ORDER BY 
    CASE 
        WHEN rowsecurity AND policy_count > 0 THEN 1
        WHEN rowsecurity AND policy_count = 0 THEN 2
        WHEN NOT rowsecurity AND policy_count > 0 THEN 3
        ELSE 4
    END,
    tablename;

-- ==========================================
-- Query 14: Check if RLS is bypassed for specific roles
-- ==========================================
SELECT 
    t.tablename AS table_name,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM pg_policies p 
            WHERE p.tablename = t.tablename 
                AND p.schemaname = 'public'
                AND 'service_role' = ANY(p.roles)
        ) THEN 'Has service_role policy'
        ELSE 'No service_role policy'
    END AS service_role_status,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM pg_policies p 
            WHERE p.tablename = t.tablename 
                AND p.schemaname = 'public'
                AND 'authenticated' = ANY(p.roles)
        ) THEN 'Has authenticated policy'
        ELSE 'No authenticated policy'
    END AS authenticated_status,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM pg_policies p 
            WHERE p.tablename = t.tablename 
                AND p.schemaname = 'public'
                AND 'anon' = ANY(p.roles)
        ) THEN 'Has anon policy'
        ELSE 'No anon policy'
    END AS anon_status
FROM pg_tables t
WHERE t.schemaname = 'public'
    AND t.tablename NOT LIKE 'pg_%'
    AND t.tablename NOT IN ('spatial_ref_sys', 'service_providers_backup')
ORDER BY t.tablename;

-- ==========================================
-- Query 15: List all your application tables
-- ==========================================
SELECT 
    tablename AS table_name,
    schemaname AS schema_name
FROM pg_tables
WHERE schemaname = 'public'
    AND tablename IN (
        'account_security_logs',
        'admin_activity_logs',
        'app_downloads',
        'app_settings',
        'audit_logs',
        'business_permits',
        'cash_payment_verifications',
        'customer_job_history',
        'distance_pricing_config',
        'do_not_disturb_settings',
        'document_verifications',
        'email_notifications',
        'email_verification_tokens',
        'inspection_reports',
        'invoices',
        'job_completion_codes',
        'mechanic_availability_status',
        'mechanic_invitations',
        'mechanic_job_history',
        'mechanics',
        'messages',
        'notification_delivery_log',
        'notification_templates',
        'notifications',
        'password_reset_tokens',
        'payment_methods',
        'payment_releases',
        'payments',
        'paymongo_webhook_events',
        'profile_image_logs',
        'profile_updates',
        'progress_photos',
        'provider_availability_cache',
        'provider_services',
        'request_broadcasts',
        'request_routing',
        'request_status_history',
        'reviews',
        'service_availability_matrix',
        'service_categories',
        'service_completions',
        'service_history',
        'service_phase_tracking',
        'service_providers',
        'service_requests',
        'shop_mechanics',
        'shop_notifications',
        'shop_services',
        'shop_settings',
        'shop_stats_cache',
        'shops',
        'system_statistics',
        'talyer_customer_connections',
        'talyer_owner_verifications',
        'temporary_passwords',
        'user_locations',
        'user_notification_preferences',
        'user_profiles',
        'vehicles'
    )
ORDER BY tablename;
