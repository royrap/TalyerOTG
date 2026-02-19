-- =====================================================
-- VERIFY EARNINGS COLUMNS IN YOUR CURRENT DATABASE
-- =====================================================
-- This checks if earnings columns already exist
-- =====================================================

-- Check mechanic_job_history columns
SELECT 'mechanic_job_history columns:' as info;
SELECT column_name, data_type, column_default
FROM information_schema.columns
WHERE table_name = 'mechanic_job_history'
AND table_schema = 'public'
ORDER BY ordinal_position;

-- Check service_requests columns
SELECT 'service_requests columns related to earnings:' as info;
SELECT column_name, data_type, column_default
FROM information_schema.columns
WHERE table_name = 'service_requests'
AND table_schema = 'public'
AND (column_name LIKE '%earnings%' OR column_name LIKE '%fee%')
ORDER BY ordinal_position;

-- Check invoices columns
SELECT 'invoices columns related to earnings:' as info;
SELECT column_name, data_type, column_default
FROM information_schema.columns
WHERE table_name = 'invoices'
AND table_schema = 'public'
AND (column_name LIKE '%earnings%' OR column_name LIKE '%fee%' OR column_name LIKE '%amount%')
ORDER BY ordinal_position;
