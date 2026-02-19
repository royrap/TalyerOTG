-- TOP 10 MOST IMPORTANT TABLES - Quick Overview
-- Based on your 57 tables, focusing on the core functionality

-- 1. SERVICE_REQUESTS (87 fields - your biggest table!)
SELECT '🚗 SERVICE_REQUESTS (87 fields) - Main job tracking' as table_info;
SELECT 'Total service requests:' as info, COUNT(*) as count FROM service_requests;
SELECT 'Status breakdown:' as info;
SELECT status, COUNT(*) as count FROM service_requests GROUP BY status ORDER BY count DESC;

-- 2. USER_PROFILES (49 fields - all users)
SELECT '👤 USER_PROFILES (49 fields) - All users' as table_info;
SELECT 'Total users:' as info, COUNT(*) as count FROM user_profiles;
SELECT 'User roles:' as info;
SELECT role, COUNT(*) as count FROM user_profiles GROUP BY role ORDER BY count DESC;

-- 3. INVOICES (28 fields - payment processing)
SELECT '💰 INVOICES (28 fields) - Payment processing' as table_info;
SELECT 'Total invoices:' as info, COUNT(*) as count FROM invoices;
SELECT 'Invoice status:' as info;
SELECT status, COUNT(*) as count FROM invoices GROUP BY status ORDER BY count DESC;

-- 4. SHOP_SERVICES (32 fields - services offered)
SELECT '🔧 SHOP_SERVICES (32 fields) - Services offered' as table_info;
SELECT 'Total shop services:' as info, COUNT(*) as count FROM shop_services;

-- 5. SHOPS (23 fields - auto repair shops)
SELECT '🏪 SHOPS (23 fields) - Auto repair shops' as table_info;
SELECT 'Total shops:' as info, COUNT(*) as count FROM shops;

-- 6. MECHANICS (17 fields - individual mechanics)
SELECT '👨‍🔧 MECHANICS (17 fields) - Individual mechanics' as table_info;
SELECT 'Total mechanics:' as info, COUNT(*) as count FROM mechanics;

-- 7. BUSINESS_PERMITS (17 fields - shop verification)
SELECT '📄 BUSINESS_PERMITS (17 fields) - Shop verification' as table_info;
SELECT 'Total permits:' as info, COUNT(*) as count FROM business_permits;

-- 8. PAYMENTS (17 fields - payment transactions)
SELECT '💳 PAYMENTS (17 fields) - Payment transactions' as table_info;
SELECT 'Total payments:' as info, COUNT(*) as count FROM payments;

-- 9. JOB_COMPLETION_CODES (15 fields - QR system)
SELECT '📱 JOB_COMPLETION_CODES (15 fields) - QR system' as table_info;
SELECT 'Total QR codes:' as info, COUNT(*) as count FROM job_completion_codes;

-- 10. NOTIFICATIONS (9 fields - user notifications)
SELECT '🔔 NOTIFICATIONS (9 fields) - User notifications' as table_info;
SELECT 'Total notifications:' as info, COUNT(*) as count FROM notifications;

-- ACTIVE JOBS CHECK
SELECT '🔥 ACTIVE JOBS - Currently in progress' as info;
SELECT 
    status,
    COUNT(*) as count
FROM service_requests 
WHERE status IN ('pending', 'confirmed', 'in_progress', 'arrived', 'invoice_sent', 'invoice_paid')
GROUP BY status
ORDER BY 
    CASE status
        WHEN 'pending' THEN 1
        WHEN 'confirmed' THEN 2
        WHEN 'in_progress' THEN 3
        WHEN 'arrived' THEN 4
        WHEN 'invoice_sent' THEN 5
        WHEN 'invoice_paid' THEN 6
    END;

-- SUMMARY BY CATEGORY
SELECT '📊 TABLES BY CATEGORY' as summary;
SELECT 
    CASE 
        WHEN table_name IN ('user_profiles', 'service_requests', 'invoices', 'shops', 'mechanics', 'shop_services') THEN '🎯 CORE BUSINESS'
        WHEN table_name LIKE '%verification%' OR table_name LIKE '%permit%' OR table_name LIKE '%document%' THEN '✅ VERIFICATION'
        WHEN table_name LIKE '%payment%' OR table_name LIKE '%cash%' OR table_name LIKE 'invoices' THEN '💰 PAYMENT'
        WHEN table_name LIKE '%notification%' OR table_name LIKE '%message%' OR table_name LIKE '%email%' THEN '📢 COMMUNICATION'
        WHEN table_name LIKE '%history%' OR table_name LIKE '%log%' OR table_name LIKE '%audit%' THEN '📋 TRACKING & LOGS'
        WHEN table_name LIKE '%completion%' OR table_name LIKE 'job_completion_codes' THEN '✅ JOB COMPLETION'
        WHEN table_name LIKE '%availability%' OR table_name LIKE '%routing%' OR table_name LIKE '%broadcast%' THEN '📍 ROUTING & AVAILABILITY'
        ELSE '🔧 OTHER FEATURES'
    END as category,
    COUNT(*) as table_count,
    SUM((SELECT COUNT(*) FROM information_schema.columns WHERE table_name = t.table_name AND table_schema = 'public')) as total_fields
FROM information_schema.tables t
WHERE t.table_schema = 'public' AND t.table_type = 'BASE TABLE'
GROUP BY 
    CASE 
        WHEN table_name IN ('user_profiles', 'service_requests', 'invoices', 'shops', 'mechanics', 'shop_services') THEN '🎯 CORE BUSINESS'
        WHEN table_name LIKE '%verification%' OR table_name LIKE '%permit%' OR table_name LIKE '%document%' THEN '✅ VERIFICATION'
        WHEN table_name LIKE '%payment%' OR table_name LIKE '%cash%' OR table_name LIKE 'invoices' THEN '💰 PAYMENT'
        WHEN table_name LIKE '%notification%' OR table_name LIKE '%message%' OR table_name LIKE '%email%' THEN '📢 COMMUNICATION'
        WHEN table_name LIKE '%history%' OR table_name LIKE '%log%' OR table_name LIKE '%audit%' THEN '📋 TRACKING & LOGS'
        WHEN table_name LIKE '%completion%' OR table_name LIKE 'job_completion_codes' THEN '✅ JOB COMPLETION'
        WHEN table_name LIKE '%availability%' OR table_name LIKE '%routing%' OR table_name LIKE '%broadcast%' THEN '📍 ROUTING & AVAILABILITY'
        ELSE '🔧 OTHER FEATURES'
    END
ORDER BY table_count DESC;