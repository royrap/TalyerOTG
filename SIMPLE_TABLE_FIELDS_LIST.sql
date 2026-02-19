-- Simple Table and Field List
-- Copy this into Supabase SQL Editor to see all tables and fields

-- List all tables
SELECT 'TABLES IN DATABASE:' as info;
SELECT tablename as table_name
FROM pg_tables 
WHERE schemaname = 'public'
ORDER BY tablename;

-- Show fields for each main table
SELECT '--- USER_PROFILES TABLE ---' as info;
SELECT column_name, data_type, is_nullable
FROM information_schema.columns 
WHERE table_name = 'user_profiles' AND table_schema = 'public'
ORDER BY ordinal_position;

SELECT '--- SERVICE_REQUESTS TABLE ---' as info;
SELECT column_name, data_type, is_nullable
FROM information_schema.columns 
WHERE table_name = 'service_requests' AND table_schema = 'public'
ORDER BY ordinal_position;

SELECT '--- INVOICES TABLE ---' as info;
SELECT column_name, data_type, is_nullable
FROM information_schema.columns 
WHERE table_name = 'invoices' AND table_schema = 'public'
ORDER BY ordinal_position;

SELECT '--- JOB_COMPLETION_CODES TABLE ---' as info;
SELECT column_name, data_type, is_nullable
FROM information_schema.columns 
WHERE table_name = 'job_completion_codes' AND table_schema = 'public'
ORDER BY ordinal_position;

-- Show all tables and their field counts
SELECT 'TABLE SUMMARY:' as info;
SELECT 
    t.table_name,
    COUNT(c.column_name) as field_count
FROM information_schema.tables t
LEFT JOIN information_schema.columns c ON t.table_name = c.table_name
WHERE t.table_schema = 'public' AND t.table_type = 'BASE TABLE'
GROUP BY t.table_name
ORDER BY t.table_name;