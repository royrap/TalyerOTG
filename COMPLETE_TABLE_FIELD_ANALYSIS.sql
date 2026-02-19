-- COMPREHENSIVE TABLE AND FIELD ANALYSIS FOR ALL TABLES
-- This script checks every table and every field for completeness

-- =============================================================================
-- 1. USER_PROFILES TABLE - Complete field analysis
-- =============================================================================
SELECT 'USER_PROFILES' as table_name, 'Field Analysis' as check_type;

SELECT 
    'user_profiles' as table_name,
    COUNT(*) as total_records,
    COUNT(id) as id_filled,
    COUNT(email) as email_filled,
    COUNT(first_name) as first_name_filled,
    COUNT(last_name) as last_name_filled,
    COUNT(profile_image_url) as profile_image_filled,
    COUNT(user_type) as user_type_filled,
    COUNT(current_latitude) as latitude_filled,
    COUNT(current_longitude) as longitude_filled,
    COUNT(email_verified_at) as email_verified_filled,
    COUNT(business_permit_url) as business_permit_filled,
    COUNT(drivers_license_url) as drivers_license_filled,
    COUNT(CASE WHEN rating > 0 THEN 1 END) as has_rating,
    COUNT(CASE WHEN first_login_completed = true THEN 1 END) as completed_first_login,
    COUNT(last_login_at) as has_last_login,
    COUNT(created_at) as created_at_filled,
    COUNT(updated_at) as updated_at_filled,
    COUNT(phone_number) as phone_number_filled,
    COUNT(CASE WHEN can_login = true THEN 1 END) as can_login_count
FROM user_profiles;

-- =============================================================================
-- 2. SERVICE_PROVIDERS TABLE - Complete field analysis
-- =============================================================================
SELECT 'SERVICE_PROVIDERS' as table_name, 'Field Analysis' as check_type;

SELECT 
    'service_providers' as table_name,
    COUNT(*) as total_records,
    COUNT(id) as id_filled,
    COUNT(user_id) as user_id_filled,
    COUNT(company_name) as company_name_filled,
    COUNT(license_number) as license_number_filled,
    COUNT(current_latitude) as latitude_filled,
    COUNT(current_longitude) as longitude_filled,
    COUNT(CASE WHEN rating > 0 THEN 1 END) as has_rating,
    COUNT(CASE WHEN is_verified = true THEN 1 END) as verified_count,
    COUNT(CASE WHEN is_available = true THEN 1 END) as available_count,
    COUNT(created_at) as created_at_filled,
    COUNT(updated_at) as updated_at_filled
FROM service_providers;

-- =============================================================================
-- 3. SERVICE_REQUESTS TABLE - Complete field analysis
-- =============================================================================
SELECT 'SERVICE_REQUESTS' as table_name, 'Field Analysis' as check_type;

SELECT 
    'service_requests' as table_name,
    COUNT(*) as total_records,
    COUNT(id) as id_filled,
    COUNT(customer_id) as customer_id_filled,
    COUNT(provider_id) as provider_id_filled,
    COUNT(assigned_mechanic_id) as mechanic_id_filled,
    COUNT(service_type) as service_type_filled,
    COUNT(description) as description_filled,
    COUNT(pickup_address) as pickup_address_filled,
    COUNT(pickup_latitude) as pickup_latitude_filled,
    COUNT(pickup_longitude) as pickup_longitude_filled,
    COUNT(status) as status_filled,
    COUNT(final_price) as final_price_filled,
    COUNT(qr_code_data) as qr_code_filled,
    COUNT(vehicle_info) as vehicle_info_filled,
    COUNT(inspection_report) as inspection_report_filled,
    COUNT(created_at) as created_at_filled,
    COUNT(updated_at) as updated_at_filled,
    COUNT(title) as title_filled,
    COUNT(category_id) as category_id_filled
FROM service_requests;

-- =============================================================================
-- 4. SHOPS TABLE - Complete field analysis
-- =============================================================================
SELECT 'SHOPS' as table_name, 'Field Analysis' as check_type;

SELECT 
    'shops' as table_name,
    COUNT(*) as total_records,
    COUNT(id) as id_filled,
    COUNT(provider_id) as provider_id_filled,
    COUNT(shop_name) as shop_name_filled,
    COUNT(shop_address) as shop_address_filled,
    COUNT(shop_phone) as shop_phone_filled,
    COUNT(latitude) as latitude_filled,
    COUNT(longitude) as longitude_filled,
    COUNT(CASE WHEN rating > 0 THEN 1 END) as has_rating,
    COUNT(CASE WHEN total_services > 0 THEN 1 END) as has_services,
    COUNT(CASE WHEN is_active = true THEN 1 END) as active_count,
    COUNT(created_at) as created_at_filled,
    COUNT(updated_at) as updated_at_filled
FROM shops;

-- =============================================================================
-- 5. INVOICES TABLE - Complete field analysis
-- =============================================================================
SELECT 'INVOICES' as table_name, 'Field Analysis' as check_type;

SELECT 
    'invoices' as table_name,
    COUNT(*) as total_records,
    COUNT(id) as id_filled,
    COUNT(request_id) as request_id_filled,
    COUNT(invoice_number) as invoice_number_filled,
    COUNT(total_amount) as total_amount_filled,
    COUNT(status) as status_filled,
    COUNT(sent_at) as sent_at_filled,
    COUNT(paid_at) as paid_at_filled,
    COUNT(payment_details) as payment_details_filled,
    COUNT(service_details) as service_details_filled,
    COUNT(selected_payment_method) as payment_method_filled,
    COUNT(created_at) as created_at_filled,
    COUNT(updated_at) as updated_at_filled,
    COUNT(customer_id) as customer_id_filled,
    COUNT(talyer_owner_id) as talyer_owner_id_filled
FROM invoices;

-- =============================================================================
-- 6. JOB_COMPLETION_CODES TABLE - Complete field analysis
-- =============================================================================
SELECT 'JOB_COMPLETION_CODES' as table_name, 'Field Analysis' as check_type;

SELECT 
    'job_completion_codes' as table_name,
    COUNT(*) as total_records,
    COUNT(id) as id_filled,
    COUNT(request_id) as service_request_id_filled,
    COUNT(completion_code) as completion_code_filled,
    COUNT(customer_id) as customer_id_filled,
    COUNT(expires_at) as expires_at_filled,
    COUNT(CASE WHEN is_used = true THEN 1 END) as used_count,
    COUNT(used_at) as used_at_filled,
    COUNT(used_by_provider_id) as used_by_provider_filled,
    COUNT(scan_latitude) as scan_latitude_filled,
    COUNT(scan_longitude) as scan_longitude_filled,
    COUNT(created_at) as created_at_filled,
    COUNT(CASE WHEN verification_status = 'verified' THEN 1 END) as verified_count
FROM job_completion_codes;

-- =============================================================================
-- 7. PAYMENTS TABLE - Complete field analysis
-- =============================================================================
SELECT 'PAYMENTS' as table_name, 'Field Analysis' as check_type;

SELECT 
    'payments' as table_name,
    COUNT(*) as total_records,
    COUNT(id) as id_filled,
    COUNT(request_id) as request_id_filled,
    COUNT(amount) as amount_filled,
    COUNT(payment_method) as payment_method_filled,
    COUNT(transaction_id) as transaction_id_filled,
    COUNT(status) as status_filled,
    COUNT(processed_at) as processed_at_filled,
    COUNT(payment_details) as payment_details_filled,
    COUNT(created_at) as created_at_filled,
    COUNT(customer_id) as customer_id_filled,
    COUNT(provider_id) as provider_id_filled
FROM payments;

-- =============================================================================
-- 8. MECHANIC_JOB_HISTORY TABLE - Complete field analysis
-- =============================================================================
SELECT 'MECHANIC_JOB_HISTORY' as table_name, 'Field Analysis' as check_type;

SELECT 
    'mechanic_job_history' as table_name,
    COUNT(*) as total_records,
    COUNT(id) as id_filled,
    COUNT(mechanic_id) as mechanic_id_filled,
    COUNT(service_request_id) as service_request_id_filled,
    COUNT(job_status) as job_status_filled,
    COUNT(total_amount) as total_amount_filled,
    COUNT(rating) as rating_filled,
    COUNT(completed_at) as completed_at_filled,
    COUNT(created_at) as created_at_filled
FROM mechanic_job_history;

-- =============================================================================
-- 9. CUSTOMER_JOB_HISTORY TABLE - Complete field analysis
-- =============================================================================
SELECT 'CUSTOMER_JOB_HISTORY' as table_name, 'Field Analysis' as check_type;

SELECT 
    'customer_job_history' as table_name,
    COUNT(*) as total_records,
    COUNT(id) as id_filled,
    COUNT(customer_id) as customer_id_filled,
    COUNT(service_request_id) as service_request_id_filled,
    COUNT(job_status) as job_status_filled,
    COUNT(total_amount) as total_amount_filled,
    COUNT(rating) as rating_filled,
    COUNT(completed_at) as completed_at_filled,
    COUNT(created_at) as created_at_filled
FROM customer_job_history;

-- =============================================================================
-- 10. VEHICLES TABLE - Complete field analysis
-- =============================================================================
SELECT 'VEHICLES' as table_name, 'Field Analysis' as check_type;

SELECT 
    'vehicles' as table_name,
    COUNT(*) as total_records,
    COUNT(id) as id_filled,
    COUNT(user_id) as user_id_filled,
    COUNT(brand_name) as brand_filled,
    COUNT(model_name) as model_filled,
    COUNT(year) as year_filled,
    COUNT(color) as color_filled,
    COUNT(plate_number) as plate_number_filled,
    COUNT(CASE WHEN is_primary = true THEN 1 END) as primary_count,
    COUNT(created_at) as created_at_filled,
    COUNT(updated_at) as updated_at_filled,
    COUNT(vehicle_type) as vehicle_type_filled
FROM vehicles;

-- =============================================================================
-- 11. NOTIFICATIONS TABLE - Complete field analysis
-- =============================================================================
SELECT 'NOTIFICATIONS' as table_name, 'Field Analysis' as check_type;

SELECT 
    'notifications' as table_name,
    COUNT(*) as total_records,
    COUNT(id) as id_filled,
    COUNT(user_id) as user_id_filled,
    COUNT(title) as title_filled,
    COUNT(message) as message_filled,
    COUNT(type) as type_filled,
    COUNT(data) as data_filled,
    COUNT(CASE WHEN read = true THEN 1 END) as read_count,
    COUNT(CASE WHEN read = false THEN 1 END) as unread_count,
    COUNT(created_at) as created_at_filled
FROM notifications;

-- =============================================================================
-- 12. BUSINESS_PERMITS TABLE - Complete field analysis
-- =============================================================================
SELECT 'BUSINESS_PERMITS' as table_name, 'Field Analysis' as check_type;

SELECT 
    'business_permits' as table_name,
    COUNT(*) as total_records,
    COUNT(id) as id_filled,
    COUNT(provider_id) as provider_id_filled,
    COUNT(business_permit_name) as permit_name_filled,
    COUNT(permit_document_url) as document_url_filled,
    COUNT(CASE WHEN is_verified = true THEN 1 END) as verified_count,
    COUNT(verification_notes) as verification_notes_filled,
    COUNT(CASE WHEN extraction_confidence_score > 0 THEN 1 END) as has_confidence_score,
    COUNT(verified_at) as verified_at_filled,
    COUNT(created_at) as created_at_filled,
    COUNT(updated_at) as updated_at_filled,
    COUNT(receipt_no) as receipt_no_filled,
    COUNT(registered_address) as registered_address_filled
FROM business_permits;

-- =============================================================================
-- 13. PROGRESS_PHOTOS TABLE - Complete field analysis
-- =============================================================================
SELECT 'PROGRESS_PHOTOS' as table_name, 'Field Analysis' as check_type;

SELECT 
    'progress_photos' as table_name,
    COUNT(*) as total_records,
    COUNT(id) as id_filled,
    COUNT(service_request_id) as service_request_id_filled,
    COUNT(image_url) as photo_url_filled,
    COUNT(description) as description_filled,
    COUNT(mechanic_id) as uploaded_by_filled,
    COUNT(metadata) as metadata_filled,
    COUNT(timestamp) as created_at_filled,
    COUNT(service_phase) as service_phase_filled
FROM progress_photos;

-- =============================================================================
-- 14. REVIEWS TABLE - Complete field analysis (if exists)
-- =============================================================================
SELECT 'REVIEWS' as table_name, 'Field Analysis' as check_type;

SELECT 
    'reviews' as table_name,
    COUNT(*) as total_records,
    COUNT(id) as id_filled,
    COUNT(request_id) as service_request_id_filled,
    COUNT(customer_id) as reviewer_id_filled,
    COUNT(provider_id) as reviewee_id_filled,
    COUNT(rating) as rating_filled,
    COUNT(comment) as comment_filled,
    COUNT(created_at) as created_at_filled,
    COUNT(CASE WHEN is_verified = true THEN 1 END) as verified_count
FROM reviews;

-- =============================================================================
-- SUMMARY: FIELD COMPLETENESS ANALYSIS
-- =============================================================================
SELECT 'FIELD_COMPLETENESS_SUMMARY' as analysis_type, 'Overall Database Health' as description;

-- Critical fields that should never be NULL
SELECT 
    'CRITICAL_NULL_FIELDS' as issue_type,
    'Fields that should never be empty' as description
UNION ALL
SELECT 'USER_PROFILES', CONCAT(COUNT(*), ' users without email') 
FROM user_profiles WHERE email IS NULL
UNION ALL
SELECT 'USER_PROFILES', CONCAT(COUNT(*), ' users without names') 
FROM user_profiles WHERE first_name IS NULL OR last_name IS NULL
UNION ALL
SELECT 'SERVICE_REQUESTS', CONCAT(COUNT(*), ' requests without customer_id') 
FROM service_requests WHERE customer_id IS NULL
UNION ALL
SELECT 'SERVICE_REQUESTS', CONCAT(COUNT(*), ' requests without service_type') 
FROM service_requests WHERE service_type IS NULL
UNION ALL
SELECT 'INVOICES', CONCAT(COUNT(*), ' invoices without amounts') 
FROM invoices WHERE total_amount IS NULL
UNION ALL
SELECT 'PAYMENTS', CONCAT(COUNT(*), ' payments without amounts') 
FROM payments WHERE amount IS NULL;

-- Optional fields analysis
SELECT 
    'OPTIONAL_FIELDS_STATUS' as field_category,
    'Fields that can be empty but affect functionality' as description
UNION ALL
SELECT 'PROFILE_IMAGES', CONCAT(COUNT(*), ' users without profile images')
FROM user_profiles WHERE profile_image_url IS NULL
UNION ALL
SELECT 'USER_LOCATIONS', CONCAT(COUNT(*), ' users without location data')
FROM user_profiles WHERE current_latitude IS NULL
UNION ALL
SELECT 'VEHICLE_INFO', CONCAT(COUNT(*), ' service requests without vehicle info')
FROM service_requests WHERE vehicle_info IS NULL
UNION ALL
SELECT 'QR_CODES', CONCAT(COUNT(*), ' paid invoices without QR codes')
FROM service_requests WHERE status = 'invoice_paid' AND qr_code_data IS NULL
UNION ALL
SELECT 'RATINGS', CONCAT(COUNT(*), ' service providers without ratings')
FROM service_providers WHERE rating = 0.0
UNION ALL
SELECT 'SHOP_ADDRESSES', CONCAT(COUNT(*), ' shops without addresses')
FROM shops WHERE shop_address IS NULL;

-- Data integrity checks
SELECT 
    'DATA_INTEGRITY_CHECKS' as check_category,
    'Relationships and constraints validation' as description
UNION ALL
SELECT 'ORPHANED_REQUESTS', CONCAT(COUNT(*), ' service requests with invalid customer_id')
FROM service_requests sr
LEFT JOIN user_profiles up ON sr.customer_id = up.id
WHERE up.id IS NULL
UNION ALL
SELECT 'ORPHANED_INVOICES', CONCAT(COUNT(*), ' invoices with invalid service_request_id')
FROM invoices i
LEFT JOIN service_requests sr ON i.service_request_id = sr.id
WHERE sr.id IS NULL
UNION ALL
SELECT 'ORPHANED_QR_CODES', CONCAT(COUNT(*), ' QR codes with invalid service_request_id')
FROM job_completion_codes jcc
LEFT JOIN service_requests sr ON jcc.service_request_id = sr.id
WHERE sr.id IS NULL;