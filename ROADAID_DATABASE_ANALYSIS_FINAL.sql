-- ROADAID DATABASE COMPREHENSIVE ANALYSIS
-- Fixed all column name issues and syntax errors
-- Ready to run in Supabase SQL Editor

-- === 1. DATABASE OVERVIEW ===
SELECT '=== ROADAID DATABASE OVERVIEW ===' as analysis_section;

-- Total tables and field counts
SELECT 
    COUNT(*) as total_tables,
    SUM((SELECT COUNT(*) FROM information_schema.columns WHERE table_name = t.table_name AND table_schema = 'public')) as total_fields
FROM information_schema.tables t
WHERE t.table_schema = 'public' AND t.table_type = 'BASE TABLE';

-- === 2. CORE BUSINESS TABLES DATA ANALYSIS ===
SELECT '=== CORE BUSINESS DATA ANALYSIS ===' as analysis_section;

-- Users Analysis
SELECT 'USER PROFILES ANALYSIS' as section;
SELECT 
    role as user_role,
    COUNT(*) as user_count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM user_profiles), 2) as percentage
FROM user_profiles 
GROUP BY role 
ORDER BY user_count DESC;

-- Service Requests Analysis
SELECT 'SERVICE REQUESTS ANALYSIS' as section;
SELECT 
    status as request_status,
    COUNT(*) as request_count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM service_requests), 2) as percentage
FROM service_requests 
GROUP BY status 
ORDER BY request_count DESC;

-- Active Jobs by Status
SELECT 'ACTIVE JOBS BREAKDOWN' as section;
SELECT 
    status,
    COUNT(*) as count,
    AVG(EXTRACT(EPOCH FROM (now() - created_at))/3600)::integer as avg_hours_old
FROM service_requests 
WHERE status IN ('pending', 'accepted', 'assigned', 'mechanic_assigned', 'in_progress', 'inspection_started', 'inspection_completed', 'invoice_sent', 'invoice_paid')
GROUP BY status
ORDER BY 
    CASE status
        WHEN 'pending' THEN 1
        WHEN 'accepted' THEN 2
        WHEN 'assigned' THEN 3
        WHEN 'mechanic_assigned' THEN 4
        WHEN 'in_progress' THEN 5
        WHEN 'inspection_started' THEN 6
        WHEN 'inspection_completed' THEN 7
        WHEN 'invoice_sent' THEN 8
        WHEN 'invoice_paid' THEN 9
    END;

-- === 3. PAYMENT & INVOICE ANALYSIS ===
SELECT '=== PAYMENT & INVOICE ANALYSIS ===' as analysis_section;

-- Invoice Status
SELECT 'INVOICE STATUS BREAKDOWN' as section;
SELECT 
    status as invoice_status,
    COUNT(*) as count,
    COALESCE(SUM(total_amount), 0) as total_value
FROM invoices 
GROUP BY status 
ORDER BY count DESC;

-- Payment Status
SELECT 'PAYMENT STATUS BREAKDOWN' as section;
SELECT 
    status as payment_status,
    COUNT(*) as count,
    COALESCE(SUM(amount), 0) as total_amount
FROM payments 
GROUP BY status 
ORDER BY count DESC;

-- === 4. SHOP & MECHANIC ANALYSIS ===
SELECT '=== SHOP & MECHANIC ANALYSIS ===' as analysis_section;

-- Shop Status
SELECT 'SHOPS OVERVIEW' as section;
SELECT 
    COUNT(*) as total_shops,
    COUNT(*) FILTER (WHERE is_active = true) as active_shops,
    COUNT(*) FILTER (WHERE current_status = 'open') as currently_open
FROM shops;

-- Mechanics Overview
SELECT 'MECHANICS OVERVIEW' as section;
SELECT 
    COUNT(*) as total_mechanics,
    COUNT(*) FILTER (WHERE is_active = true) as active_mechanics,
    COUNT(*) FILTER (WHERE availability_status = 'available') as available_mechanics
FROM mechanics;

-- === 5. VERIFICATION & SECURITY ===
SELECT '=== VERIFICATION & SECURITY ===' as analysis_section;

-- Business Permits
SELECT 'BUSINESS PERMIT VERIFICATION' as section;
SELECT 
    is_verified,
    COUNT(*) as permit_count
FROM business_permits 
GROUP BY is_verified;

-- Document Verifications
SELECT 'DOCUMENT VERIFICATION STATUS' as section;
SELECT 
    verification_status,
    COUNT(*) as document_count
FROM document_verifications 
GROUP BY verification_status
ORDER BY document_count DESC;

-- === 6. COMMUNICATION & NOTIFICATIONS ===
SELECT '=== COMMUNICATION ANALYSIS ===' as analysis_section;

-- Notifications
SELECT 'NOTIFICATIONS OVERVIEW' as section;
SELECT 
    type as notification_type,
    COUNT(*) as notification_count,
    COUNT(*) FILTER (WHERE read = false) as unread_count
FROM notifications 
GROUP BY type 
ORDER BY notification_count DESC 
LIMIT 10;

-- Messages
SELECT 'MESSAGES OVERVIEW' as section;
SELECT 
    COUNT(*) as total_messages,
    COUNT(*) FILTER (WHERE is_read = false) as unread_messages,
    COUNT(DISTINCT sender_id) as unique_senders
FROM messages;

-- === 7. JOB COMPLETION & QR SYSTEM ===
SELECT '=== JOB COMPLETION & QR SYSTEM ===' as analysis_section;

-- QR Codes
SELECT 'QR CODE SYSTEM STATUS' as section;
SELECT 
    verification_status,
    COUNT(*) as qr_count,
    COUNT(*) FILTER (WHERE is_used = true) as used_count
FROM job_completion_codes 
GROUP BY verification_status;

-- Service Completions
SELECT 'SERVICE COMPLETION STATUS' as section;
SELECT 
    verification_status,
    COUNT(*) as completion_count,
    COUNT(*) FILTER (WHERE is_scanned = true) as scanned_count
FROM service_completions 
GROUP BY verification_status;

-- === 8. RECENT ACTIVITY (Last 7 Days) ===
SELECT '=== RECENT ACTIVITY (LAST 7 DAYS) ===' as analysis_section;

SELECT 
    'New service requests' as activity_type,
    COUNT(*) as count
FROM service_requests 
WHERE created_at >= NOW() - INTERVAL '7 days'
UNION ALL
SELECT 
    'New users' as activity_type,
    COUNT(*) as count
FROM user_profiles 
WHERE created_at >= NOW() - INTERVAL '7 days'
UNION ALL
SELECT 
    'Invoices issued' as activity_type,
    COUNT(*) as count
FROM invoices 
WHERE issued_at >= NOW() - INTERVAL '7 days'
UNION ALL
SELECT 
    'Payments processed' as activity_type,
    COUNT(*) as count
FROM payments 
WHERE created_at >= NOW() - INTERVAL '7 days'
ORDER BY count DESC;

-- === 9. DATA QUALITY CHECKS ===
SELECT '=== DATA QUALITY ANALYSIS ===' as analysis_section;

-- Check for missing critical data
SELECT 'MISSING DATA CHECK' as section;
SELECT 
    'Users without phone' as issue,
    COUNT(*) as count 
FROM user_profiles 
WHERE phone_number IS NULL OR phone_number = ''
UNION ALL
SELECT 
    'Service requests without customer' as issue,
    COUNT(*) as count 
FROM service_requests 
WHERE customer_id IS NULL
UNION ALL
SELECT 
    'Invoices without amount' as issue,
    COUNT(*) as count 
FROM invoices 
WHERE total_amount IS NULL OR total_amount = 0
UNION ALL
SELECT 
    'Shops without location' as issue,
    COUNT(*) as count 
FROM shops 
WHERE latitude IS NULL OR longitude IS NULL
ORDER BY count DESC;

-- === 10. BUSINESS METRICS ===
SELECT '=== KEY BUSINESS METRICS ===' as analysis_section;

-- Revenue Analysis
SELECT 'REVENUE METRICS' as section;
SELECT 
    COUNT(*) as total_paid_invoices,
    COALESCE(SUM(total_amount), 0) as total_revenue,
    COALESCE(AVG(total_amount), 0) as average_invoice_value,
    COALESCE(SUM(platform_fee), 0) as total_platform_fees
FROM invoices 
WHERE status = 'paid';

-- Job Completion Rate
SELECT 'JOB COMPLETION METRICS' as section;
SELECT 
    COUNT(*) as total_requests,
    COUNT(*) FILTER (WHERE status = 'completed') as completed_requests,
    ROUND(COUNT(*) FILTER (WHERE status = 'completed') * 100.0 / NULLIF(COUNT(*), 0), 2) as completion_rate_percentage
FROM service_requests;

-- === 11. TOP PERFORMERS ===
SELECT '=== TOP PERFORMERS ===' as analysis_section;

-- Top Shops by Revenue
SELECT 'TOP SHOPS BY COMPLETED JOBS' as section;
SELECT 
    s.shop_name,
    COUNT(sr.id) as completed_jobs,
    COALESCE(SUM(i.total_amount), 0) as total_revenue
FROM shops s
LEFT JOIN service_requests sr ON s.id = sr.shop_id AND sr.status = 'completed'
LEFT JOIN invoices i ON sr.id = i.request_id AND i.status = 'paid'
GROUP BY s.id, s.shop_name
HAVING COUNT(sr.id) > 0
ORDER BY completed_jobs DESC, total_revenue DESC
LIMIT 10;

-- Top Mechanics by Jobs
SELECT 'TOP MECHANICS BY COMPLETED JOBS' as section;
SELECT 
    up.first_name || ' ' || up.last_name as mechanic_name,
    COUNT(sr.id) as completed_jobs,
    AVG(COALESCE(up.rating, 0)) as average_rating
FROM user_profiles up
LEFT JOIN service_requests sr ON up.id = sr.assigned_mechanic_id AND sr.status = 'completed'
WHERE up.role = 'mechanic'
GROUP BY up.id, up.first_name, up.last_name
HAVING COUNT(sr.id) > 0
ORDER BY completed_jobs DESC
LIMIT 10;

-- === 12. FINAL SUMMARY ===
SELECT '=== DATABASE HEALTH SUMMARY ===' as analysis_section;

-- Overall system status
SELECT 
    'Database Health Score' as metric,
    CASE 
        WHEN (SELECT COUNT(*) FROM user_profiles WHERE role = 'customer') > 10 
         AND (SELECT COUNT(*) FROM shops WHERE is_active = true) > 5
         AND (SELECT COUNT(*) FROM service_requests WHERE status = 'completed') > 20
        THEN 'HEALTHY - System has good user base and activity'
        WHEN (SELECT COUNT(*) FROM user_profiles) > 5
         AND (SELECT COUNT(*) FROM service_requests) > 10
        THEN 'DEVELOPING - System is growing'
        ELSE 'EARLY STAGE - System is just starting'
    END as status;

SELECT 'ANALYSIS COMPLETE - RoadAid Database Overview Generated' as final_message;