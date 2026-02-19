-- COMPREHENSIVE CHECK FOR ALL EMPTY/NULL FIELDS ACROSS ALL TABLES
-- This script checks for missing data in all major tables

-- =============================================================================
-- 1. USER PROFILES - Check for incomplete profiles
-- =============================================================================
SELECT 
  'USER_PROFILES_MISSING_DATA' as table_check,
  COUNT(*) as total_users,
  COUNT(CASE WHEN profile_image_url IS NULL THEN 1 END) as missing_profile_image,
  COUNT(CASE WHEN current_latitude IS NULL THEN 1 END) as missing_location,
  COUNT(CASE WHEN email_verified_at IS NULL THEN 1 END) as unverified_emails,
  COUNT(CASE WHEN business_permit_url IS NULL AND user_type = 'talyer_owner' THEN 1 END) as missing_business_permits,
  COUNT(CASE WHEN drivers_license_url IS NULL AND user_type = 'mechanic' THEN 1 END) as missing_licenses,
  COUNT(CASE WHEN rating = 0.0 THEN 1 END) as no_ratings,
  COUNT(CASE WHEN first_login_completed = false THEN 1 END) as incomplete_first_login
FROM user_profiles;

-- =============================================================================
-- 2. SERVICE REQUESTS - Check for incomplete requests
-- =============================================================================
SELECT 
  'SERVICE_REQUESTS_MISSING_DATA' as table_check,
  COUNT(*) as total_requests,
  COUNT(CASE WHEN provider_id IS NULL THEN 1 END) as no_provider,
  COUNT(CASE WHEN assigned_mechanic_id IS NULL THEN 1 END) as no_mechanic,
  COUNT(CASE WHEN final_price IS NULL THEN 1 END) as no_final_price,
  COUNT(CASE WHEN pickup_address IS NULL THEN 1 END) as no_pickup_address,
  COUNT(CASE WHEN vehicle_info IS NULL THEN 1 END) as no_vehicle_info,
  COUNT(CASE WHEN qr_code_data IS NULL AND status = 'invoice_paid' THEN 1 END) as missing_qr_codes,
  COUNT(CASE WHEN inspection_report IS NULL AND status IN ('inspection_completed', 'invoice_sent') THEN 1 END) as missing_inspection_reports
FROM service_requests;

-- =============================================================================
-- 3. SERVICE PROVIDERS - Check for incomplete providers
-- =============================================================================
SELECT 
  'SERVICE_PROVIDERS_MISSING_DATA' as table_check,
  COUNT(*) as total_providers,
  COUNT(CASE WHEN company_name IS NULL THEN 1 END) as no_company_name,
  COUNT(CASE WHEN license_number IS NULL THEN 1 END) as no_license,
  COUNT(CASE WHEN current_latitude IS NULL THEN 1 END) as no_location,
  COUNT(CASE WHEN rating = 0.0 THEN 1 END) as no_ratings,
  COUNT(CASE WHEN is_verified = false THEN 1 END) as unverified
FROM service_providers;

-- =============================================================================
-- 4. SHOPS - Check for incomplete shop data
-- =============================================================================
SELECT 
  'SHOPS_MISSING_DATA' as table_check,
  COUNT(*) as total_shops,
  COUNT(CASE WHEN shop_address IS NULL THEN 1 END) as no_address,
  COUNT(CASE WHEN shop_phone IS NULL THEN 1 END) as no_phone,
  COUNT(CASE WHEN latitude IS NULL THEN 1 END) as no_coordinates,
  COUNT(CASE WHEN rating = 0.0 THEN 1 END) as no_ratings,
  COUNT(CASE WHEN total_services = 0 THEN 1 END) as no_services
FROM shops;

-- =============================================================================
-- 5. INVOICES - Check for incomplete invoices
-- =============================================================================
SELECT 
  'INVOICES_MISSING_DATA' as table_check,
  COUNT(*) as total_invoices,
  COUNT(CASE WHEN sent_at IS NULL AND status != 'generated' THEN 1 END) as missing_sent_date,
  COUNT(CASE WHEN paid_at IS NULL AND status = 'paid' THEN 1 END) as missing_paid_date,
  COUNT(CASE WHEN payment_details = '{}' THEN 1 END) as empty_payment_details,
  COUNT(CASE WHEN service_details = '{}' THEN 1 END) as empty_service_details,
  COUNT(CASE WHEN selected_payment_method IS NULL AND status = 'paid' THEN 1 END) as missing_payment_method
FROM invoices;

-- =============================================================================
-- 6. JOB COMPLETION CODES - Check for QR code issues
-- =============================================================================
SELECT 
  'JOB_COMPLETION_CODES_MISSING_DATA' as table_check,
  COUNT(*) as total_codes,
  COUNT(CASE WHEN is_used = false AND expires_at < NOW() THEN 1 END) as expired_unused,
  COUNT(CASE WHEN used_at IS NULL AND is_used = true THEN 1 END) as marked_used_no_date,
  COUNT(CASE WHEN used_by_provider_id IS NULL AND is_used = true THEN 1 END) as used_no_provider,
  COUNT(CASE WHEN scan_latitude IS NULL AND is_used = true THEN 1 END) as used_no_location
FROM job_completion_codes;

-- =============================================================================
-- 7. PAYMENTS - Check for payment issues
-- =============================================================================
SELECT 
  'PAYMENTS_MISSING_DATA' as table_check,
  COUNT(*) as total_payments,
  COUNT(CASE WHEN payment_method IS NULL THEN 1 END) as no_payment_method,
  COUNT(CASE WHEN transaction_id IS NULL AND status = 'completed' THEN 1 END) as completed_no_transaction_id,
  COUNT(CASE WHEN processed_at IS NULL AND status = 'completed' THEN 1 END) as completed_no_processed_date,
  COUNT(CASE WHEN payment_details IS NULL THEN 1 END) as no_payment_details
FROM payments;

-- =============================================================================
-- 8. MECHANIC/CUSTOMER JOB HISTORY - Check for missing history
-- =============================================================================
SELECT 
  'JOB_HISTORY_MISSING_DATA' as table_check,
  'mechanic' as history_type,
  COUNT(*) as total_records,
  COUNT(CASE WHEN completed_at IS NULL AND job_status = 'completed' THEN 1 END) as completed_no_date,
  COUNT(CASE WHEN total_amount IS NULL THEN 1 END) as no_amount,
  COUNT(CASE WHEN rating IS NULL AND job_status = 'completed' THEN 1 END) as completed_no_rating
FROM mechanic_job_history
UNION ALL
SELECT 
  'JOB_HISTORY_MISSING_DATA' as table_check,
  'customer' as history_type,
  COUNT(*) as total_records,
  COUNT(CASE WHEN completed_at IS NULL AND job_status = 'completed' THEN 1 END) as completed_no_date,
  COUNT(CASE WHEN total_amount IS NULL THEN 1 END) as no_amount,
  COUNT(CASE WHEN rating IS NULL AND job_status = 'completed' THEN 1 END) as completed_no_rating
FROM customer_job_history;

-- =============================================================================
-- 9. VEHICLES - Check for incomplete vehicle data
-- =============================================================================
SELECT 
  'VEHICLES_MISSING_DATA' as table_check,
  COUNT(*) as total_vehicles,
  COUNT(CASE WHEN color IS NULL THEN 1 END) as no_color,
  COUNT(CASE WHEN plate_number IS NULL THEN 1 END) as no_plate_number,
  COUNT(CASE WHEN is_primary = true THEN 1 END) as primary_vehicles,
  COUNT(DISTINCT user_id) as users_with_vehicles
FROM vehicles;

-- =============================================================================
-- 10. NOTIFICATIONS - Check for notification issues
-- =============================================================================
SELECT 
  'NOTIFICATIONS_MISSING_DATA' as table_check,
  COUNT(*) as total_notifications,
  COUNT(CASE WHEN data IS NULL THEN 1 END) as no_data,
  COUNT(CASE WHEN read = false THEN 1 END) as unread_notifications,
  COUNT(CASE WHEN created_at > NOW() - INTERVAL '7 days' THEN 1 END) as recent_notifications
FROM notifications;

-- =============================================================================
-- 11. BUSINESS PERMITS - Check for verification data
-- =============================================================================
SELECT 
  'BUSINESS_PERMITS_MISSING_DATA' as table_check,
  COUNT(*) as total_permits,
  COUNT(CASE WHEN permit_document_url IS NULL THEN 1 END) as no_document,
  COUNT(CASE WHEN is_verified = false THEN 1 END) as unverified,
  COUNT(CASE WHEN verification_notes IS NULL AND is_verified = false THEN 1 END) as unverified_no_notes,
  COUNT(CASE WHEN extraction_confidence_score = 0.0 THEN 1 END) as no_extraction_score
FROM business_permits;

-- =============================================================================
-- 12. PROGRESS PHOTOS - Check for service documentation
-- =============================================================================
SELECT 
  'PROGRESS_PHOTOS_MISSING_DATA' as table_check,
  COUNT(*) as total_photos,
  COUNT(CASE WHEN description = '' THEN 1 END) as no_description,
  COUNT(CASE WHEN metadata = '{}' THEN 1 END) as no_metadata,
  COUNT(DISTINCT service_request_id) as requests_with_photos
FROM progress_photos;

-- =============================================================================
-- SUMMARY: Most Critical Missing Data
-- =============================================================================
SELECT 
  'CRITICAL_MISSING_DATA_SUMMARY' as summary_type,
  'High Priority Issues to Fix' as description
UNION ALL
SELECT 'QR_CODES', CONCAT(COUNT(*), ' service requests with status invoice_paid but no QR code')
FROM service_requests 
WHERE status = 'invoice_paid' AND qr_code_data IS NULL
UNION ALL
SELECT 'UNVERIFIED_PROVIDERS', CONCAT(COUNT(*), ' service providers not verified')
FROM service_providers 
WHERE is_verified = false
UNION ALL
SELECT 'INCOMPLETE_PROFILES', CONCAT(COUNT(*), ' user profiles missing profile images')
FROM user_profiles 
WHERE profile_image_url IS NULL
UNION ALL
SELECT 'MISSING_LOCATIONS', CONCAT(COUNT(*), ' service providers without location data')
FROM service_providers 
WHERE current_latitude IS NULL
UNION ALL
SELECT 'INCOMPLETE_INVOICES', CONCAT(COUNT(*), ' invoices with empty service details')
FROM invoices 
WHERE service_details = '{}';