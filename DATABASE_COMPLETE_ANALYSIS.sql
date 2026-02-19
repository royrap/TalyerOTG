-- Complete Database Analysis Script
-- Run this in your Supabase SQL Editor to get a full overview of all tables and fields

-- 1. List all tables in the database
SELECT 
    schemaname,
    tablename,
    tableowner
FROM pg_tables 
WHERE schemaname = 'public'
ORDER BY tablename;

-- 2. Get detailed column information for each table
SELECT 
    t.table_name,
    t.column_name,
    t.data_type,
    t.is_nullable,
    t.column_default,
    t.character_maximum_length,
    CASE 
        WHEN pk.column_name IS NOT NULL THEN 'PRIMARY KEY'
        WHEN fk.column_name IS NOT NULL THEN 'FOREIGN KEY'
        ELSE ''
    END as key_type,
    t.ordinal_position
FROM information_schema.columns t
LEFT JOIN (
    SELECT ku.table_name, ku.column_name
    FROM information_schema.table_constraints tc
    JOIN information_schema.key_column_usage ku
        ON tc.constraint_name = ku.constraint_name
    WHERE tc.constraint_type = 'PRIMARY KEY'
) pk ON t.table_name = pk.table_name AND t.column_name = pk.column_name
LEFT JOIN (
    SELECT ku.table_name, ku.column_name
    FROM information_schema.table_constraints tc
    JOIN information_schema.key_column_usage ku
        ON tc.constraint_name = ku.constraint_name
    WHERE tc.constraint_type = 'FOREIGN KEY'
) fk ON t.table_name = fk.table_name AND t.column_name = fk.column_name
WHERE t.table_schema = 'public'
ORDER BY t.table_name, t.ordinal_position;

-- 3. Check row counts for each table
SELECT 
    schemaname,
    tablename,
    n_tup_ins as total_inserts,
    n_tup_upd as total_updates,
    n_tup_del as total_deletes,
    n_live_tup as current_rows,
    n_dead_tup as dead_rows
FROM pg_stat_user_tables
WHERE schemaname = 'public'
ORDER BY current_rows DESC;

-- 4. Check for empty tables
SELECT 
    table_name,
    (xpath('/row/c/text()', query_to_xml(format('select count(*) as c from %I.%I', table_schema, table_name), false, true, '')))[1]::text::int AS row_count
FROM information_schema.tables 
WHERE table_schema = 'public' 
    AND table_type = 'BASE TABLE'
ORDER BY row_count;

-- 5. Check for tables with null or missing important fields
-- Users table analysis
SELECT 'user_profiles' as table_name, 
       COUNT(*) as total_rows,
       COUNT(first_name) as has_first_name,
       COUNT(last_name) as has_last_name,
       COUNT(phone_number) as has_phone,
       COUNT(email) as has_email,
       COUNT(*) - COUNT(first_name) as missing_first_name,
       COUNT(*) - COUNT(last_name) as missing_last_name,
       COUNT(*) - COUNT(phone_number) as missing_phone,
       COUNT(*) - COUNT(email) as missing_email
FROM user_profiles;

-- Service requests analysis
SELECT 'service_requests' as table_name,
       COUNT(*) as total_rows,
       COUNT(customer_id) as has_customer_id,
       COUNT(assigned_mechanic_id) as has_mechanic_id,
       COUNT(status) as has_status,
       COUNT(issue_title) as has_issue_title,
       COUNT(location) as has_location,
       COUNT(*) - COUNT(customer_id) as missing_customer_id,
       COUNT(*) - COUNT(assigned_mechanic_id) as missing_mechanic_id,
       COUNT(*) - COUNT(status) as missing_status,
       COUNT(*) - COUNT(issue_title) as missing_issue_title,
       COUNT(*) - COUNT(location) as missing_location
FROM service_requests;

-- Invoices analysis
SELECT 'invoices' as table_name,
       COUNT(*) as total_rows,
       COUNT(request_id) as has_request_id,
       COUNT(mechanic_id) as has_mechanic_id,
       COUNT(customer_id) as has_customer_id,
       COUNT(total_amount) as has_total_amount,
       COUNT(status) as has_status,
       COUNT(*) - COUNT(request_id) as missing_request_id,
       COUNT(*) - COUNT(mechanic_id) as missing_mechanic_id,
       COUNT(*) - COUNT(customer_id) as missing_customer_id,
       COUNT(*) - COUNT(total_amount) as missing_total_amount,
       COUNT(*) - COUNT(status) as missing_status
FROM invoices;

-- 6. Check foreign key relationships
SELECT
    tc.table_name, 
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
WHERE tc.constraint_type = 'FOREIGN KEY' 
    AND tc.table_schema = 'public'
ORDER BY tc.table_name, kcu.column_name;

-- 7. Check indexes
SELECT 
    schemaname,
    tablename,
    indexname,
    indexdef
FROM pg_indexes 
WHERE schemaname = 'public'
ORDER BY tablename, indexname;

-- 8. Check table sizes
SELECT 
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size,
    pg_total_relation_size(schemaname||'.'||tablename) AS size_bytes
FROM pg_tables 
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;

-- 9. Check for recent activity (last 24 hours)
SELECT 
    schemaname,
    tablename,
    n_tup_ins as inserts_since_last_stats,
    n_tup_upd as updates_since_last_stats,
    n_tup_del as deletes_since_last_stats,
    last_vacuum,
    last_autovacuum,
    last_analyze,
    last_autoanalyze
FROM pg_stat_user_tables
WHERE schemaname = 'public'
ORDER BY (n_tup_ins + n_tup_upd + n_tup_del) DESC;

-- 10. Summary report
SELECT 
    'SUMMARY REPORT' as report_type,
    COUNT(*) as total_tables
FROM information_schema.tables 
WHERE table_schema = 'public' AND table_type = 'BASE TABLE';