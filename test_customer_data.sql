-- Debug script to check customer data availability
-- This will help us understand why customer history is empty

-- Check if we have any service_requests with customer_id
SELECT 
    'Total service_requests' as description,
    COUNT(*) as count
FROM service_requests
UNION ALL

-- Check service_requests with customer_id
SELECT 
    'service_requests with customer_id' as description,
    COUNT(*) as count
FROM service_requests 
WHERE customer_id IS NOT NULL
UNION ALL

-- Check customer_job_history table
SELECT 
    'customer_job_history records' as description,
    COUNT(*) as count
FROM customer_job_history
UNION ALL

-- Sample of service_requests data (latest 3)
-- This will show us the actual data structure
SELECT 
    id,
    customer_id,
    title,
    description,
    status,
    created_at
FROM service_requests 
WHERE customer_id IS NOT NULL 
ORDER BY created_at DESC 
LIMIT 3;