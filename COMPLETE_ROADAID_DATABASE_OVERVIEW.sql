-- COMPLETE ROADAID DATABASE OVERVIEW
-- Shows all 57 tables with their fields and data

-- 1. MAIN CORE TABLES
SELECT '=== CORE TABLES ===' as section;

-- User Profiles (49 fields)
SELECT 'USER_PROFILES - Key User Information' as table_info;
SELECT column_name, data_type, is_nullable
FROM information_schema.columns 
WHERE table_name = 'user_profiles' AND table_schema = 'public'
ORDER BY ordinal_position;

SELECT 'User Profiles Data Count:' as info, COUNT(*) as total_users FROM user_profiles;
SELECT role, COUNT(*) as count FROM user_profiles GROUP BY role ORDER BY count DESC;

-- Service Requests (87 fields - largest table!)
SELECT 'SERVICE_REQUESTS - Main Job Tracking (87 fields)' as table_info;
SELECT column_name, data_type, is_nullable
FROM information_schema.columns 
WHERE table_name = 'service_requests' AND table_schema = 'public'
ORDER BY ordinal_position;

SELECT 'Service Requests Data Count:' as info, COUNT(*) as total_requests FROM service_requests;
SELECT status, COUNT(*) as count FROM service_requests GROUP BY status ORDER BY count DESC;

-- Invoices (28 fields)
SELECT 'INVOICES - Payment Processing' as table_info;
SELECT column_name, data_type, is_nullable
FROM information_schema.columns 
WHERE table_name = 'invoices' AND table_schema = 'public'
ORDER BY ordinal_position;

SELECT 'Invoices Data Count:' as info, COUNT(*) as total_invoices FROM invoices;
SELECT status, COUNT(*) as count FROM invoices GROUP BY status ORDER BY count DESC;

-- 2. SHOP/MECHANIC TABLES
SELECT '=== SHOP & MECHANIC TABLES ===' as section;

-- Shops (23 fields)
SELECT 'SHOPS - Auto Repair Shops' as table_info;
SELECT column_name, data_type, is_nullable
FROM information_schema.columns 
WHERE table_name = 'shops' AND table_schema = 'public'
ORDER BY ordinal_position;

SELECT 'Shops Data Count:' as info, COUNT(*) as total_shops FROM shops;

-- Mechanics (17 fields)
SELECT 'MECHANICS - Individual Mechanics' as table_info;
SELECT column_name, data_type, is_nullable
FROM information_schema.columns 
WHERE table_name = 'mechanics' AND table_schema = 'public'
ORDER BY ordinal_position;

SELECT 'Mechanics Data Count:' as info, COUNT(*) as total_mechanics FROM mechanics;

-- Shop Services (32 fields)
SELECT 'SHOP_SERVICES - Services Offered by Shops' as table_info;
SELECT column_name, data_type, is_nullable
FROM information_schema.columns 
WHERE table_name = 'shop_services' AND table_schema = 'public'
ORDER BY ordinal_position;

SELECT 'Shop Services Data Count:' as info, COUNT(*) as total_shop_services FROM shop_services;

-- 3. VERIFICATION & SECURITY TABLES
SELECT '=== VERIFICATION & SECURITY ===' as section;

-- Business Permits (17 fields)
SELECT 'BUSINESS_PERMITS - Shop License Verification' as table_info;
SELECT column_name, data_type, is_nullable
FROM information_schema.columns 
WHERE table_name = 'business_permits' AND table_schema = 'public'
ORDER BY ordinal_position;

SELECT 'Business Permits Count:' as info, COUNT(*) as total_permits FROM business_permits;

-- Document Verifications (12 fields)
SELECT 'DOCUMENT_VERIFICATIONS - ID/License Checks' as table_info;
SELECT column_name, data_type, is_nullable
FROM information_schema.columns 
WHERE table_name = 'document_verifications' AND table_schema = 'public'
ORDER BY ordinal_position;

SELECT 'Document Verifications Count:' as info, COUNT(*) as total_doc_verifications FROM document_verifications;

-- 4. PAYMENT & TRANSACTION TABLES
SELECT '=== PAYMENT & TRANSACTIONS ===' as section;

-- Payments (17 fields)
SELECT 'PAYMENTS - Payment Processing' as table_info;
SELECT column_name, data_type, is_nullable
FROM information_schema.columns 
WHERE table_name = 'payments' AND table_schema = 'public'
ORDER BY ordinal_position;

SELECT 'Payments Count:' as info, COUNT(*) as total_payments FROM payments;

-- Payment Methods (10 fields)
SELECT 'PAYMENT_METHODS - Available Payment Options' as table_info;
SELECT column_name, data_type, is_nullable
FROM information_schema.columns 
WHERE table_name = 'payment_methods' AND table_schema = 'public'
ORDER BY ordinal_position;

SELECT 'Payment Methods Count:' as info, COUNT(*) as total_payment_methods FROM payment_methods;

-- Cash Payment Verifications (17 fields)
SELECT 'CASH_PAYMENT_VERIFICATIONS - Cash Transaction Tracking' as table_info;
SELECT column_name, data_type, is_nullable
FROM information_schema.columns 
WHERE table_name = 'cash_payment_verifications' AND table_schema = 'public'
ORDER BY ordinal_position;

SELECT 'Cash Payment Verifications Count:' as info, COUNT(*) as total_cash_verifications FROM cash_payment_verifications;

-- 5. NOTIFICATION & COMMUNICATION
SELECT '=== NOTIFICATIONS & COMMUNICATION ===' as section;

-- Notifications (9 fields)
SELECT 'NOTIFICATIONS - User Notifications' as table_info;
SELECT column_name, data_type, is_nullable
FROM information_schema.columns 
WHERE table_name = 'notifications' AND table_schema = 'public'
ORDER BY ordinal_position;

SELECT 'Notifications Count:' as info, COUNT(*) as total_notifications FROM notifications;

-- Messages (15 fields)
SELECT 'MESSAGES - Chat/Communication' as table_info;
SELECT column_name, data_type, is_nullable
FROM information_schema.columns 
WHERE table_name = 'messages' AND table_schema = 'public'
ORDER BY ordinal_position;

SELECT 'Messages Count:' as info, COUNT(*) as total_messages FROM messages;

-- Email Notifications (16 fields)
SELECT 'EMAIL_NOTIFICATIONS - Email System' as table_info;
SELECT column_name, data_type, is_nullable
FROM information_schema.columns 
WHERE table_name = 'email_notifications' AND table_schema = 'public'
ORDER BY ordinal_position;

SELECT 'Email Notifications Count:' as info, COUNT(*) as total_email_notifications FROM email_notifications;

-- 6. JOB COMPLETION & QR SYSTEM
SELECT '=== JOB COMPLETION & QR ===' as section;

-- Job Completion Codes (15 fields)
SELECT 'JOB_COMPLETION_CODES - QR Code System' as table_info;
SELECT column_name, data_type, is_nullable
FROM information_schema.columns 
WHERE table_name = 'job_completion_codes' AND table_schema = 'public'
ORDER BY ordinal_position;

SELECT 'Job Completion Codes Count:' as info, COUNT(*) as total_qr_codes FROM job_completion_codes;

-- Service Completions (13 fields)
SELECT 'SERVICE_COMPLETIONS - Completed Jobs' as table_info;
SELECT column_name, data_type, is_nullable
FROM information_schema.columns 
WHERE table_name = 'service_completions' AND table_schema = 'public'
ORDER BY ordinal_position;

SELECT 'Service Completions Count:' as info, COUNT(*) as total_completions FROM service_completions;

-- 7. HISTORY & TRACKING TABLES
SELECT '=== HISTORY & TRACKING ===' as section;

-- Customer Job History (17 fields)
SELECT 'CUSTOMER_JOB_HISTORY - Customer Service History' as table_info;
SELECT column_name, data_type, is_nullable
FROM information_schema.columns 
WHERE table_name = 'customer_job_history' AND table_schema = 'public'
ORDER BY ordinal_position;

SELECT 'Customer Job History Count:' as info, COUNT(*) as total_customer_history FROM customer_job_history;

-- Mechanic Job History (16 fields)
SELECT 'MECHANIC_JOB_HISTORY - Mechanic Service History' as table_info;
SELECT column_name, data_type, is_nullable
FROM information_schema.columns 
WHERE table_name = 'mechanic_job_history' AND table_schema = 'public'
ORDER BY ordinal_position;

SELECT 'Mechanic Job History Count:' as info, COUNT(*) as total_mechanic_history FROM mechanic_job_history;

-- Service History (14 fields)
SELECT 'SERVICE_HISTORY - General Service History' as table_info;
SELECT column_name, data_type, is_nullable
FROM information_schema.columns 
WHERE table_name = 'service_history' AND table_schema = 'public'
ORDER BY ordinal_position;

SELECT 'Service History Count:' as info, COUNT(*) as total_service_history FROM service_history;

-- 8. SUMMARY OF ALL 57 TABLES
SELECT '=== COMPLETE TABLE SUMMARY ===' as section;

SELECT 
    table_name,
    (SELECT COUNT(*) 
     FROM information_schema.columns 
     WHERE table_name = t.table_name AND table_schema = 'public'
    ) as field_count,
    CASE 
        WHEN table_name IN ('user_profiles', 'service_requests', 'invoices', 'shops', 'mechanics') THEN 'CORE'
        WHEN table_name LIKE '%verification%' OR table_name LIKE '%permit%' THEN 'VERIFICATION'
        WHEN table_name LIKE '%payment%' OR table_name LIKE '%invoice%' THEN 'PAYMENT'
        WHEN table_name LIKE '%notification%' OR table_name LIKE '%message%' THEN 'COMMUNICATION'
        WHEN table_name LIKE '%history%' OR table_name LIKE '%log%' THEN 'TRACKING'
        WHEN table_name LIKE '%completion%' OR table_name LIKE '%qr%' THEN 'COMPLETION'
        ELSE 'OTHER'
    END as category
FROM information_schema.tables t
WHERE t.table_schema = 'public' AND t.table_type = 'BASE TABLE'
ORDER BY 
    CASE 
        WHEN table_name IN ('user_profiles', 'service_requests', 'invoices') THEN 1
        WHEN table_name IN ('shops', 'mechanics', 'shop_services') THEN 2
        ELSE 3
    END,
    field_count DESC,
    table_name;