-- DISPLAY ALL TABLE CONTENTS - 57 TABLES
-- Shows actual data/content from each table
-- Run this in Supabase SQL Editor

SELECT '🔍 SHOWING ALL TABLE CONTENTS - ROADAID DATABASE' as display_title;
SELECT '📋 Sample data from all 57 tables' as display_subtitle;

-- === SECTION 1: CORE BUSINESS TABLES DATA ===
SELECT '=== 🎯 CORE BUSINESS TABLES DATA ===' as section_header;

-- USER_PROFILES - Show all users
SELECT '👤 USER_PROFILES - ALL USERS' as table_display;
SELECT 
    id,
    first_name,
    last_name,
    email,
    phone_number,
    role,
    user_type,
    profile_image_url,
    current_latitude,
    current_longitude,
    is_available,
    account_status,
    created_at,
    last_login_at
FROM user_profiles 
ORDER BY created_at DESC;

-- SERVICE_REQUESTS - Show all service requests
SELECT '🚗 SERVICE_REQUESTS - ALL SERVICE REQUESTS' as table_display;
SELECT 
    id,
    customer_id,
    title,
    description,
    status,
    pickup_latitude,
    pickup_longitude,
    pickup_address,
    estimated_price,
    final_price,
    assigned_mechanic_id,
    shop_id,
    vehicle_info,
    payment_status,
    is_emergency,
    created_at,
    updated_at
FROM service_requests 
ORDER BY created_at DESC;

-- SHOPS - Show all shops
SELECT '🏪 SHOPS - ALL SHOPS' as table_display;
SELECT 
    id,
    owner_id,
    shop_name,
    shop_address,
    shop_phone,
    shop_email,
    latitude,
    longitude,
    is_active,
    current_status,
    rating,
    total_reviews,
    total_services,
    total_earnings,
    created_at
FROM shops 
ORDER BY created_at DESC;

-- INVOICES - Show all invoices
SELECT '💰 INVOICES - ALL INVOICES' as table_display;
SELECT 
    id,
    request_id,
    customer_id,
    mechanic_id,
    invoice_number,
    subtotal,
    total_amount,
    platform_fee,
    status,
    payment_details,
    generated_at,
    sent_at,
    paid_at
FROM invoices 
ORDER BY generated_at DESC;

-- PAYMENTS - Show all payments
SELECT '💳 PAYMENTS - ALL PAYMENTS' as table_display;
SELECT 
    id,
    request_id,
    customer_id,
    provider_id,
    amount,
    platform_fee,
    payment_method,
    payment_gateway,
    transaction_id,
    status,
    processed_at,
    created_at
FROM payments 
ORDER BY created_at DESC;

-- === SECTION 2: JOB COMPLETION & QR SYSTEM ===
SELECT '=== ✅ JOB COMPLETION & QR SYSTEM ===' as section_header;

-- JOB_COMPLETION_CODES - Show all QR codes
SELECT '📱 JOB_COMPLETION_CODES - ALL QR CODES' as table_display;
SELECT 
    id,
    request_id,
    customer_id,
    completion_code,
    is_used,
    verification_status,
    used_at,
    expires_at,
    scan_latitude,
    scan_longitude,
    created_at
FROM job_completion_codes 
ORDER BY created_at DESC;

-- SERVICE_COMPLETIONS - Show all service completions
SELECT '✅ SERVICE_COMPLETIONS - ALL COMPLETIONS' as table_display;
SELECT 
    id,
    request_id,
    mechanic_id,
    customer_id,
    completion_code,
    qr_code_data,
    is_scanned,
    scanned_at,
    verification_status,
    created_at
FROM service_completions 
ORDER BY created_at DESC;

-- === SECTION 3: MECHANIC & SHOP MANAGEMENT ===
SELECT '=== 👨‍🔧 MECHANIC & SHOP MANAGEMENT ===' as section_header;

-- MECHANICS - Show all mechanics
SELECT '🔧 MECHANICS - ALL MECHANICS' as table_display;
SELECT 
    id,
    user_id,
    shop_id,
    specializations,
    certification_level,
    experience_years,
    hourly_rate,
    availability_status,
    current_location_lat,
    current_location_lng,
    rating_average,
    total_jobs_completed,
    is_active,
    created_at
FROM mechanics 
ORDER BY created_at DESC;

-- SHOP_SERVICES - Show all shop services
SELECT '🛠️ SHOP_SERVICES - ALL SERVICES' as table_display;
SELECT 
    id,
    shop_id,
    category_id,
    service_name,
    description,
    base_price,
    custom_price,
    estimated_duration,
    is_active,
    availability_status,
    created_at
FROM shop_services 
ORDER BY created_at DESC;

-- SHOP_MECHANICS - Show shop-mechanic relationships
SELECT '👥 SHOP_MECHANICS - SHOP-MECHANIC CONNECTIONS' as table_display;
SELECT 
    id,
    shop_id,
    mechanic_id,
    role,
    specialties,
    hourly_rate,
    is_active,
    is_available,
    joined_at
FROM shop_mechanics 
ORDER BY joined_at DESC;

-- === SECTION 4: VERIFICATION & SECURITY ===
SELECT '=== 🔐 VERIFICATION & SECURITY ===' as section_header;

-- BUSINESS_PERMITS - Show all business permits
SELECT '📄 BUSINESS_PERMITS - ALL PERMITS' as table_display;
SELECT 
    id,
    provider_id,
    business_permit_name,
    registered_address,
    nature_of_business,
    receipt_no,
    issued_on,
    permit_document_url,
    is_verified,
    verification_notes,
    created_at
FROM business_permits 
ORDER BY created_at DESC;

-- DOCUMENT_VERIFICATIONS - Show all document verifications
SELECT '📋 DOCUMENT_VERIFICATIONS - ALL VERIFICATIONS' as table_display;
SELECT 
    id,
    user_id,
    document_type,
    document_url,
    verification_status,
    verified_by,
    verified_at,
    rejection_reason,
    created_at
FROM document_verifications 
ORDER BY created_at DESC;

-- TALYER_OWNER_VERIFICATIONS - Show shop owner verifications
SELECT '🏢 TALYER_OWNER_VERIFICATIONS - SHOP OWNER VERIFICATIONS' as table_display;
SELECT 
    id,
    user_id,
    business_name,
    business_permit_url,
    valid_id_url,
    id_type,
    status,
    verification_score,
    created_at
FROM talyer_owner_verifications 
ORDER BY created_at DESC;

-- === SECTION 5: COMMUNICATION & NOTIFICATIONS ===
SELECT '=== 📢 COMMUNICATION & NOTIFICATIONS ===' as section_header;

-- NOTIFICATIONS - Show all notifications
SELECT '🔔 NOTIFICATIONS - ALL NOTIFICATIONS' as table_display;
SELECT 
    id,
    user_id,
    title,
    body,
    type,
    data,
    read,
    created_at
FROM notifications 
ORDER BY created_at DESC;

-- MESSAGES - Show all messages
SELECT '💬 MESSAGES - ALL MESSAGES' as table_display;
SELECT 
    id,
    request_id,
    sender_id,
    receiver_id,
    message,
    sent_at,
    is_read
FROM messages 
ORDER BY sent_at DESC;

-- EMAIL_NOTIFICATIONS - Show email notifications
SELECT '📧 EMAIL_NOTIFICATIONS - ALL EMAIL NOTIFICATIONS' as table_display;
SELECT 
    id,
    recipient_email,
    email_type,
    subject,
    delivery_status,
    sent_at,
    created_at
FROM email_notifications 
ORDER BY created_at DESC;

-- === SECTION 6: ROUTING & AVAILABILITY ===
SELECT '=== 📍 ROUTING & AVAILABILITY ===' as section_header;

-- REQUEST_BROADCASTS - Show request broadcasts
SELECT '📡 REQUEST_BROADCASTS - ALL BROADCASTS' as table_display;
SELECT 
    id,
    request_id,
    provider_id,
    provider_type,
    distance_km,
    response_status,
    notification_sent_at,
    responded_at,
    created_at
FROM request_broadcasts 
ORDER BY created_at DESC;

-- MECHANIC_AVAILABILITY_STATUS - Show mechanic availability
SELECT '⚡ MECHANIC_AVAILABILITY_STATUS - MECHANIC AVAILABILITY' as table_display;
SELECT 
    id,
    mechanic_id,
    shop_id,
    current_status,
    location_latitude,
    location_longitude,
    is_accepting_requests,
    last_status_update
FROM mechanic_availability_status 
ORDER BY last_status_update DESC;

-- PROVIDER_AVAILABILITY_CACHE - Show provider availability
SELECT '🏪 PROVIDER_AVAILABILITY_CACHE - PROVIDER AVAILABILITY' as table_display;
SELECT 
    id,
    provider_id,
    provider_type,
    is_available,
    availability_status,
    current_active_jobs,
    max_concurrent_jobs,
    last_activity_at
FROM provider_availability_cache 
ORDER BY last_activity_at DESC;

-- === SECTION 7: HISTORY & TRACKING ===
SELECT '=== 📋 HISTORY & TRACKING ===' as section_header;

-- CUSTOMER_JOB_HISTORY - Show customer job history
SELECT '📊 CUSTOMER_JOB_HISTORY - CUSTOMER HISTORY' as table_display;
SELECT 
    id,
    customer_id,
    service_request_id,
    mechanic_id,
    job_title,
    job_status,
    total_amount,
    rating,
    completed_at,
    created_at
FROM customer_job_history 
ORDER BY created_at DESC;

-- MECHANIC_JOB_HISTORY - Show mechanic job history
SELECT '🔧 MECHANIC_JOB_HISTORY - MECHANIC HISTORY' as table_display;
SELECT 
    id,
    mechanic_id,
    service_request_id,
    customer_id,
    job_title,
    job_status,
    total_amount,
    job_duration_minutes,
    completed_at,
    created_at
FROM mechanic_job_history 
ORDER BY created_at DESC;

-- REQUEST_STATUS_HISTORY - Show request status changes
SELECT '📈 REQUEST_STATUS_HISTORY - STATUS CHANGES' as table_display;
SELECT 
    id,
    request_id,
    status,
    notes,
    changed_by,
    created_at
FROM request_status_history 
ORDER BY created_at DESC;

-- AUDIT_LOGS - Show audit logs
SELECT '🔍 AUDIT_LOGS - SYSTEM AUDIT LOGS' as table_display;
SELECT 
    id,
    user_id,
    role,
    action,
    table_name,
    record_id,
    success,
    created_at
FROM audit_logs 
ORDER BY created_at DESC
LIMIT 50; -- Limit audit logs to prevent too much data

-- === SECTION 8: ADDITIONAL TABLES ===
SELECT '=== 🔧 ADDITIONAL TABLES ===' as section_header;

-- SERVICE_CATEGORIES - Show service categories
SELECT '📋 SERVICE_CATEGORIES - ALL CATEGORIES' as table_display;
SELECT 
    id,
    name,
    description,
    base_price,
    estimated_duration,
    is_active,
    category_type,
    created_at
FROM service_categories 
ORDER BY display_order, name;

-- VEHICLES - Show all vehicles
SELECT '🚗 VEHICLES - ALL VEHICLES' as table_display;
SELECT 
    id,
    user_id,
    brand_name,
    model_name,
    year,
    color,
    plate_number,
    vehicle_type,
    is_primary,
    created_at
FROM vehicles 
ORDER BY created_at DESC;

-- REVIEWS - Show all reviews
SELECT '⭐ REVIEWS - ALL REVIEWS' as table_display;
SELECT 
    id,
    request_id,
    customer_id,
    provider_id,
    rating,
    comment,
    response,
    is_verified,
    created_at
FROM reviews 
ORDER BY created_at DESC;

-- === SECTION 9: PAYMENT VERIFICATION ===
SELECT '=== 💰 PAYMENT VERIFICATION ===' as section_header;

-- CASH_PAYMENT_VERIFICATIONS - Show cash payment verifications
SELECT '💵 CASH_PAYMENT_VERIFICATIONS - CASH VERIFICATIONS' as table_display;
SELECT 
    id,
    invoice_id,
    customer_id,
    mechanic_id,
    cash_amount,
    receipt_photo_url,
    verification_status,
    verified_at,
    created_at
FROM cash_payment_verifications 
ORDER BY created_at DESC;

-- PAYMENT_RELEASES - Show payment releases
SELECT '💸 PAYMENT_RELEASES - PAYMENT RELEASES' as table_display;
SELECT 
    id,
    payment_id,
    provider_id,
    total_amount,
    platform_fee,
    provider_amount,
    release_status,
    approved_at,
    released_at,
    created_at
FROM payment_releases 
ORDER BY created_at DESC;

-- === SECTION 10: SYSTEM TABLES ===
SELECT '=== ⚙️ SYSTEM TABLES ===' as section_header;

-- APP_SETTINGS - Show app settings
SELECT '⚙️ APP_SETTINGS - APPLICATION SETTINGS' as table_display;
SELECT 
    id,
    key,
    value,
    description,
    is_public,
    category,
    created_at
FROM app_settings 
ORDER BY category, key;

-- DISTANCE_PRICING_CONFIG - Show pricing config
SELECT '💲 DISTANCE_PRICING_CONFIG - PRICING CONFIGURATION' as table_display;
SELECT 
    id,
    base_rate_per_km,
    minimum_service_fee,
    maximum_service_fee,
    emergency_multiplier,
    night_service_multiplier,
    is_active,
    effective_from
FROM distance_pricing_config 
ORDER BY effective_from DESC;

-- === SECTION 11: ALL REMAINING TABLES (EMPTY OR WITH MINIMAL DATA) ===
SELECT '=== 📊 ALL REMAINING TABLES STATUS ===' as section_header;

-- Show record counts for all remaining tables
SELECT 'TABLE RECORD COUNTS - ALL REMAINING TABLES' as summary_type;

SELECT 'ACCOUNT_SECURITY_LOGS' as table_name, COUNT(*) as records FROM account_security_logs
UNION ALL SELECT 'ADMIN_ACTIVITY_LOGS' as table_name, COUNT(*) as records FROM admin_activity_logs
UNION ALL SELECT 'APP_DOWNLOADS' as table_name, COUNT(*) as records FROM app_downloads
UNION ALL SELECT 'EMAIL_VERIFICATION_TOKENS' as table_name, COUNT(*) as records FROM email_verification_tokens
UNION ALL SELECT 'INSPECTION_REPORTS' as table_name, COUNT(*) as records FROM inspection_reports
UNION ALL SELECT 'MECHANIC_INVITATIONS' as table_name, COUNT(*) as records FROM mechanic_invitations
UNION ALL SELECT 'NOTIFICATION_DELIVERY_LOG' as table_name, COUNT(*) as records FROM notification_delivery_log
UNION ALL SELECT 'NOTIFICATION_TEMPLATES' as table_name, COUNT(*) as records FROM notification_templates
UNION ALL SELECT 'PASSWORD_RESET_TOKENS' as table_name, COUNT(*) as records FROM password_reset_tokens
UNION ALL SELECT 'PAYMENT_METHODS' as table_name, COUNT(*) as records FROM payment_methods
UNION ALL SELECT 'PAYMONGO_WEBHOOK_EVENTS' as table_name, COUNT(*) as records FROM paymongo_webhook_events
UNION ALL SELECT 'PROFILE_IMAGE_LOGS' as table_name, COUNT(*) as records FROM profile_image_logs
UNION ALL SELECT 'PROFILE_UPDATES' as table_name, COUNT(*) as records FROM profile_updates
UNION ALL SELECT 'PROGRESS_PHOTOS' as table_name, COUNT(*) as records FROM progress_photos
UNION ALL SELECT 'PROVIDER_SERVICES' as table_name, COUNT(*) as records FROM provider_services
UNION ALL SELECT 'REQUEST_ROUTING' as table_name, COUNT(*) as records FROM request_routing
UNION ALL SELECT 'SERVICE_AVAILABILITY_MATRIX' as table_name, COUNT(*) as records FROM service_availability_matrix
UNION ALL SELECT 'SERVICE_HISTORY' as table_name, COUNT(*) as records FROM service_history
UNION ALL SELECT 'SERVICE_PHASE_TRACKING' as table_name, COUNT(*) as records FROM service_phase_tracking
UNION ALL SELECT 'SERVICE_PROVIDERS' as table_name, COUNT(*) as records FROM service_providers
UNION ALL SELECT 'SHOP_NOTIFICATIONS' as table_name, COUNT(*) as records FROM shop_notifications
UNION ALL SELECT 'SHOP_SETTINGS' as table_name, COUNT(*) as records FROM shop_settings
UNION ALL SELECT 'SHOP_STATS_CACHE' as table_name, COUNT(*) as records FROM shop_stats_cache
UNION ALL SELECT 'SYSTEM_STATISTICS' as table_name, COUNT(*) as records FROM system_statistics
UNION ALL SELECT 'TALYER_CUSTOMER_CONNECTIONS' as table_name, COUNT(*) as records FROM talyer_customer_connections
UNION ALL SELECT 'TEMPORARY_PASSWORDS' as table_name, COUNT(*) as records FROM temporary_passwords
UNION ALL SELECT 'USER_LOCATIONS' as table_name, COUNT(*) as records FROM user_locations
UNION ALL SELECT 'USER_NOTIFICATION_PREFERENCES' as table_name, COUNT(*) as records FROM user_notification_preferences
UNION ALL SELECT 'DO_NOT_DISTURB_SETTINGS' as table_name, COUNT(*) as records FROM do_not_disturb_settings
ORDER BY records DESC;

SELECT '✅ ALL TABLE CONTENTS DISPLAYED' as completion_message;
SELECT '📋 Complete data view of all 57 RoadAid database tables' as final_summary;