-- Quick Database Check for RoadAid Main Tables
-- Copy and run this in Supabase SQL Editor

-- 1. Check main tables exist and their structure
SELECT 'TABLE STRUCTURE CHECK' as check_type;

-- Check user_profiles table
SELECT 'user_profiles' as table_name, column_name, data_type, is_nullable
FROM information_schema.columns 
WHERE table_name = 'user_profiles' AND table_schema = 'public'
ORDER BY ordinal_position;

-- Check service_requests table  
SELECT 'service_requests' as table_name, column_name, data_type, is_nullable
FROM information_schema.columns 
WHERE table_name = 'service_requests' AND table_schema = 'public'
ORDER BY ordinal_position;

-- Check invoices table
SELECT 'invoices' as table_name, column_name, data_type, is_nullable
FROM information_schema.columns 
WHERE table_name = 'invoices' AND table_schema = 'public'
ORDER BY ordinal_position;

-- Check job_completion_codes table
SELECT 'job_completion_codes' as table_name, column_name, data_type, is_nullable
FROM information_schema.columns 
WHERE table_name = 'job_completion_codes' AND table_schema = 'public'
ORDER BY ordinal_position;

-- 2. Check data counts
SELECT 'DATA COUNTS' as check_type;

SELECT 'user_profiles' as table_name, COUNT(*) as row_count FROM user_profiles
UNION ALL
SELECT 'service_requests' as table_name, COUNT(*) as row_count FROM service_requests
UNION ALL
SELECT 'invoices' as table_name, COUNT(*) as row_count FROM invoices
UNION ALL
SELECT 'job_completion_codes' as table_name, COUNT(*) as row_count FROM job_completion_codes
ORDER BY row_count DESC;

-- 3. Check for missing critical data
SELECT 'MISSING DATA CHECK' as check_type;

-- Users without essential info
SELECT 'Users missing phone' as issue, COUNT(*) as count 
FROM user_profiles WHERE phone_number IS NULL OR phone_number = ''
UNION ALL
SELECT 'Users missing name' as issue, COUNT(*) as count 
FROM user_profiles WHERE first_name IS NULL OR last_name IS NULL
UNION ALL
SELECT 'Service requests without customer' as issue, COUNT(*) as count 
FROM service_requests WHERE customer_id IS NULL
UNION ALL
SELECT 'Service requests without status' as issue, COUNT(*) as count 
FROM service_requests WHERE status IS NULL
UNION ALL
SELECT 'Invoices without amount' as issue, COUNT(*) as count 
FROM invoices WHERE total_amount IS NULL;

-- 4. Check service request statuses
SELECT 'SERVICE REQUEST STATUSES' as check_type;
SELECT status, COUNT(*) as count 
FROM service_requests 
GROUP BY status 
ORDER BY count DESC;

-- 5. Check invoice statuses
SELECT 'INVOICE STATUSES' as check_type;
SELECT status, COUNT(*) as count 
FROM invoices 
GROUP BY status 
ORDER BY count DESC;

-- 6. Check user roles
SELECT 'USER ROLES' as check_type;
SELECT role, COUNT(*) as count 
FROM user_profiles 
GROUP BY role 
ORDER BY count DESC;

-- 7. Recent activity check (fixed column names)
SELECT 'RECENT ACTIVITY' as check_type;

SELECT 'Recent service requests (last 7 days)' as activity, COUNT(*) as count
FROM service_requests 
WHERE created_at >= NOW() - INTERVAL '7 days'
UNION ALL
SELECT 'Recent invoices (last 7 days)' as activity, COUNT(*) as count
FROM invoices 
WHERE accepted_at >= NOW() - INTERVAL '7 days' OR issued_at >= NOW() - INTERVAL '7 days'
UNION ALL
SELECT 'Recent users (last 7 days)' as activity, COUNT(*) as count
FROM user_profiles 
WHERE created_at >= NOW() - INTERVAL '7 days';

-- 8. Check for active jobs
SELECT 'ACTIVE JOBS CHECK' as check_type;

SELECT 
    sr.id,
    sr.status,
    sr.title,
    up_customer.first_name || ' ' || up_customer.last_name as customer_name,
    up_mechanic.first_name || ' ' || up_mechanic.last_name as mechanic_name,
    sr.created_at
FROM service_requests sr
LEFT JOIN user_profiles up_customer ON sr.customer_id = up_customer.id
LEFT JOIN user_profiles up_mechanic ON sr.assigned_mechanic_id = up_mechanic.id
WHERE sr.status IN ('pending', 'confirmed', 'in_progress', 'arrived', 'invoice_sent', 'invoice_paid')
ORDER BY sr.created_at DESC
LIMIT 10;

-- 9. All tables summary
SELECT 'ALL TABLES SUMMARY' as check_type;

SELECT 
    tablename as table_name,
    (SELECT COUNT(*) FROM pg_class WHERE relname = tablename) as exists_check
FROM pg_tables 
WHERE schemaname = 'public'
ORDER BY tablename;