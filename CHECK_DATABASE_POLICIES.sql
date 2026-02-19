-- ============================================================================
-- 🔒 ROADAID DATABASE - COMPLETE POLICY VIEWER
-- ============================================================================
-- DESCRIPTION: View all Row Level Security (RLS) policies in your database
-- DATE: October 3, 2025
-- PURPOSE: Check security policies, permissions, and access controls
-- ============================================================================

-- ============================================================================
-- PART 1: VIEW ALL RLS POLICIES
-- ============================================================================

SELECT 
    schemaname AS schema,
    tablename AS table_name,
    policyname AS policy_name,
    permissive AS is_permissive,
    roles AS applies_to_roles,
    cmd AS command_type,
    qual AS using_expression,
    with_check AS with_check_expression
FROM pg_policies
WHERE schemaname = 'public'
ORDER BY tablename, policyname;

-- ============================================================================
-- PART 2: CHECK WHICH TABLES HAVE RLS ENABLED
-- ============================================================================

SELECT 
    schemaname AS schema,
    tablename AS table_name,
    rowsecurity AS rls_enabled
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY tablename;

-- ============================================================================
-- PART 3: DETAILED POLICY INFORMATION
-- ============================================================================

SELECT 
    n.nspname AS schema_name,
    c.relname AS table_name,
    pol.polname AS policy_name,
    CASE pol.polcmd
        WHEN 'r' THEN 'SELECT'
        WHEN 'a' THEN 'INSERT'
        WHEN 'w' THEN 'UPDATE'
        WHEN 'd' THEN 'DELETE'
        WHEN '*' THEN 'ALL'
    END AS command,
    CASE pol.polpermissive
        WHEN true THEN 'PERMISSIVE'
        WHEN false THEN 'RESTRICTIVE'
    END AS policy_type,
    pg_get_expr(pol.polqual, pol.polrelid) AS using_expression,
    pg_get_expr(pol.polwithcheck, pol.polrelid) AS with_check_expression,
    ARRAY(
        SELECT rolname 
        FROM pg_roles 
        WHERE oid = ANY(pol.polroles)
    ) AS applies_to_roles
FROM pg_policy pol
JOIN pg_class c ON c.oid = pol.polrelid
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
ORDER BY c.relname, pol.polname;

-- ============================================================================
-- PART 4: TABLES WITHOUT RLS POLICIES (Security Gap Check)
-- ============================================================================

SELECT 
    t.schemaname AS schema,
    t.tablename AS table_name,
    'NO RLS ENABLED' AS security_status,
    'POTENTIAL SECURITY RISK' AS warning
FROM pg_tables t
WHERE t.schemaname = 'public'
AND t.rowsecurity = false
AND t.tablename NOT LIKE '%_backup%'
ORDER BY t.tablename;

-- ============================================================================
-- PART 5: TABLES WITH RLS BUT NO POLICIES (Locked Tables)
-- ============================================================================

SELECT 
    t.schemaname AS schema,
    t.tablename AS table_name,
    'RLS ENABLED BUT NO POLICIES' AS security_status,
    'TABLE IS LOCKED - NO ONE CAN ACCESS' AS warning
FROM pg_tables t
WHERE t.schemaname = 'public'
AND t.rowsecurity = true
AND NOT EXISTS (
    SELECT 1 FROM pg_policies p 
    WHERE p.schemaname = t.schemaname 
    AND p.tablename = t.tablename
)
ORDER BY t.tablename;

-- ============================================================================
-- PART 6: COUNT POLICIES PER TABLE
-- ============================================================================

SELECT 
    tablename AS table_name,
    COUNT(*) AS total_policies,
    COUNT(CASE WHEN cmd = 'SELECT' THEN 1 END) AS select_policies,
    COUNT(CASE WHEN cmd = 'INSERT' THEN 1 END) AS insert_policies,
    COUNT(CASE WHEN cmd = 'UPDATE' THEN 1 END) AS update_policies,
    COUNT(CASE WHEN cmd = 'DELETE' THEN 1 END) AS delete_policies,
    COUNT(CASE WHEN cmd = 'ALL' THEN 1 END) AS all_command_policies
FROM pg_policies
WHERE schemaname = 'public'
GROUP BY tablename
ORDER BY total_policies DESC, tablename;

-- ============================================================================
-- PART 7: POLICY SUMMARY BY COMMAND TYPE
-- ============================================================================

SELECT 
    cmd AS command_type,
    COUNT(*) AS policy_count,
    ARRAY_AGG(DISTINCT tablename ORDER BY tablename) AS tables
FROM pg_policies
WHERE schemaname = 'public'
GROUP BY cmd
ORDER BY policy_count DESC;

-- ============================================================================
-- PART 8: CHECK AUTH.UID() USAGE IN POLICIES
-- ============================================================================

SELECT 
    tablename AS table_name,
    policyname AS policy_name,
    cmd AS command,
    CASE 
        WHEN qual LIKE '%auth.uid()%' THEN 'YES'
        ELSE 'NO'
    END AS uses_auth_uid,
    qual AS policy_expression
FROM pg_policies
WHERE schemaname = 'public'
ORDER BY tablename, policyname;

-- ============================================================================
-- PART 9: FIND POLICIES THAT ALLOW PUBLIC ACCESS
-- ============================================================================

SELECT 
    tablename AS table_name,
    policyname AS policy_name,
    cmd AS command,
    roles AS applies_to,
    qual AS using_condition,
    'PUBLIC ACCESS - EVERYONE CAN ACCESS' AS warning
FROM pg_policies
WHERE schemaname = 'public'
AND (
    'public' = ANY(roles)
    OR qual IS NULL
    OR qual = 'true'
)
ORDER BY tablename;

-- ============================================================================
-- PART 10: SECURITY RECOMMENDATIONS
-- ============================================================================

WITH table_security AS (
    SELECT 
        t.tablename,
        t.rowsecurity AS has_rls,
        COUNT(p.policyname) AS policy_count
    FROM pg_tables t
    LEFT JOIN pg_policies p ON p.tablename = t.tablename AND p.schemaname = t.schemaname
    WHERE t.schemaname = 'public'
    AND t.tablename NOT LIKE '%_backup%'
    GROUP BY t.tablename, t.rowsecurity
)
SELECT 
    tablename AS table_name,
    CASE 
        WHEN NOT has_rls THEN '❌ CRITICAL: Enable RLS'
        WHEN has_rls AND policy_count = 0 THEN '⚠️  WARNING: Add policies (table is locked)'
        WHEN has_rls AND policy_count < 2 THEN '⚡ SUGGESTION: Add more policies for complete coverage'
        ELSE '✅ GOOD: Has RLS and policies'
    END AS security_status,
    policy_count AS current_policies,
    CASE 
        WHEN NOT has_rls THEN 'Run: ALTER TABLE ' || tablename || ' ENABLE ROW LEVEL SECURITY;'
        WHEN has_rls AND policy_count = 0 THEN 'Create policies using CREATE POLICY command'
        ELSE 'Security looks good'
    END AS recommendation
FROM table_security
ORDER BY 
    CASE 
        WHEN NOT has_rls THEN 1
        WHEN has_rls AND policy_count = 0 THEN 2
        WHEN has_rls AND policy_count < 2 THEN 3
        ELSE 4
    END,
    tablename;

-- ============================================================================
-- PART 11: QUICK SECURITY SCORE
-- ============================================================================

WITH security_stats AS (
    SELECT 
        COUNT(*) AS total_tables,
        COUNT(CASE WHEN rowsecurity = true THEN 1 END) AS tables_with_rls,
        COUNT(CASE WHEN rowsecurity = false THEN 1 END) AS tables_without_rls
    FROM pg_tables
    WHERE schemaname = 'public'
    AND tablename NOT LIKE '%_backup%'
),
policy_stats AS (
    SELECT COUNT(DISTINCT tablename) AS tables_with_policies
    FROM pg_policies
    WHERE schemaname = 'public'
)
SELECT 
    s.total_tables,
    s.tables_with_rls,
    s.tables_without_rls,
    p.tables_with_policies,
    s.tables_with_rls - p.tables_with_policies AS locked_tables,
    ROUND((s.tables_with_rls::NUMERIC / s.total_tables * 100), 2) AS rls_coverage_percent,
    ROUND((p.tables_with_policies::NUMERIC / s.total_tables * 100), 2) AS policy_coverage_percent,
    CASE 
        WHEN s.tables_with_rls = s.total_tables AND p.tables_with_policies = s.total_tables THEN '🎉 EXCELLENT'
        WHEN s.tables_with_rls >= s.total_tables * 0.8 THEN '✅ GOOD'
        WHEN s.tables_with_rls >= s.total_tables * 0.5 THEN '⚠️  NEEDS IMPROVEMENT'
        ELSE '❌ CRITICAL - SECURITY RISK'
    END AS overall_security_rating
FROM security_stats s, policy_stats p;

-- ============================================================================
-- PART 12: EXPORT CURRENT POLICIES AS CREATE POLICY STATEMENTS
-- ============================================================================

SELECT 
    'CREATE POLICY "' || policyname || '" ON public.' || tablename ||
    ' FOR ' || 
    CASE cmd
        WHEN 'r' THEN 'SELECT'
        WHEN 'a' THEN 'INSERT'
        WHEN 'w' THEN 'UPDATE'
        WHEN 'd' THEN 'DELETE'
        WHEN '*' THEN 'ALL'
    END ||
    ' USING (' || COALESCE(qual, 'true') || ')' ||
    CASE 
        WHEN with_check IS NOT NULL THEN ' WITH CHECK (' || with_check || ')'
        ELSE ''
    END || ';' AS create_policy_statement
FROM pg_policies
WHERE schemaname = 'public'
ORDER BY tablename, policyname;

-- ============================================================================
-- 🎯 QUICK REFERENCE GUIDE
-- ============================================================================

/*
WHAT IS RLS (Row Level Security)?
==================================
RLS controls which rows users can see and modify in tables.

POLICY TYPES:
=============
1. PERMISSIVE (default) - Grants access if ANY policy allows it
2. RESTRICTIVE - User must pass ALL policies to access

POLICY COMMANDS:
================
- SELECT: Controls who can view rows
- INSERT: Controls who can add new rows
- UPDATE: Controls who can modify rows
- DELETE: Controls who can remove rows
- ALL: Applies to all operations

COMMON PATTERNS:
================
1. Users see their own data:
   USING (auth.uid() = user_id)

2. Public read, private write:
   SELECT: USING (true)
   INSERT/UPDATE/DELETE: USING (auth.uid() = user_id)

3. Admin access:
   USING (
       EXISTS (
           SELECT 1 FROM admin_users 
           WHERE user_id = auth.uid() AND is_active = true
       )
   )

HOW TO ENABLE RLS:
==================
ALTER TABLE table_name ENABLE ROW LEVEL SECURITY;

HOW TO CREATE POLICY:
=====================
CREATE POLICY "policy_name" ON table_name
    FOR SELECT
    USING (auth.uid() = user_id);

HOW TO DROP POLICY:
===================
DROP POLICY IF EXISTS "policy_name" ON table_name;

HOW TO DISABLE RLS:
===================
ALTER TABLE table_name DISABLE ROW LEVEL SECURITY;
(Not recommended for production!)
*/

-- ============================================================================
-- END OF POLICY VIEWER
-- ============================================================================

DO $$
BEGIN
    RAISE NOTICE '✅ Policy analysis complete!';
    RAISE NOTICE '📊 Check the results above for:';
    RAISE NOTICE '   1. All RLS policies';
    RAISE NOTICE '   2. Tables with/without RLS';
    RAISE NOTICE '   3. Security gaps and recommendations';
    RAISE NOTICE '   4. Overall security score';
END $$;
