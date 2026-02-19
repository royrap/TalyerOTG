-- SELECT ALL DATA FROM ALL 57 TABLES
-- Shows complete data from every table
-- Copy and run this in Supabase SQL Editor

-- === CORE BUSINESS TABLES ===
SELECT 'USER_PROFILES TABLE' as table_header;
SELECT * FROM user_profiles;

SELECT 'SERVICE_REQUESTS TABLE' as table_header;
SELECT * FROM service_requests;

SELECT 'SHOPS TABLE' as table_header;
SELECT * FROM shops;

SELECT 'INVOICES TABLE' as table_header;
SELECT * FROM invoices;

SELECT 'PAYMENTS TABLE' as table_header;
SELECT * FROM payments;

-- === JOB COMPLETION & QR SYSTEM ===
SELECT 'JOB_COMPLETION_CODES TABLE' as table_header;
SELECT * FROM job_completion_codes;

SELECT 'SERVICE_COMPLETIONS TABLE' as table_header;
SELECT * FROM service_completions;

-- === MECHANIC & SHOP MANAGEMENT ===
SELECT 'MECHANICS TABLE' as table_header;
SELECT * FROM mechanics;

SELECT 'SHOP_SERVICES TABLE' as table_header;
SELECT * FROM shop_services;

SELECT 'SHOP_MECHANICS TABLE' as table_header;
SELECT * FROM shop_mechanics;

-- === VERIFICATION & SECURITY ===
SELECT 'BUSINESS_PERMITS TABLE' as table_header;
SELECT * FROM business_permits;

SELECT 'DOCUMENT_VERIFICATIONS TABLE' as table_header;
SELECT * FROM document_verifications;

SELECT 'TALYER_OWNER_VERIFICATIONS TABLE' as table_header;
SELECT * FROM talyer_owner_verifications;

-- === COMMUNICATION & NOTIFICATIONS ===
SELECT 'NOTIFICATIONS TABLE' as table_header;
SELECT * FROM notifications;

SELECT 'MESSAGES TABLE' as table_header;
SELECT * FROM messages;

SELECT 'EMAIL_NOTIFICATIONS TABLE' as table_header;
SELECT * FROM email_notifications;

-- === ROUTING & AVAILABILITY ===
SELECT 'REQUEST_BROADCASTS TABLE' as table_header;
SELECT * FROM request_broadcasts;

SELECT 'MECHANIC_AVAILABILITY_STATUS TABLE' as table_header;
SELECT * FROM mechanic_availability_status;

SELECT 'PROVIDER_AVAILABILITY_CACHE TABLE' as table_header;
SELECT * FROM provider_availability_cache;

-- === HISTORY & TRACKING ===
SELECT 'CUSTOMER_JOB_HISTORY TABLE' as table_header;
SELECT * FROM customer_job_history;

SELECT 'MECHANIC_JOB_HISTORY TABLE' as table_header;
SELECT * FROM mechanic_job_history;

SELECT 'REQUEST_STATUS_HISTORY TABLE' as table_header;
SELECT * FROM request_status_history;

SELECT 'AUDIT_LOGS TABLE' as table_header;
SELECT * FROM audit_logs;

-- === SERVICE MANAGEMENT ===
SELECT 'SERVICE_CATEGORIES TABLE' as table_header;
SELECT * FROM service_categories;

SELECT 'SERVICE_PROVIDERS TABLE' as table_header;
SELECT * FROM service_providers;

SELECT 'PROVIDER_SERVICES TABLE' as table_header;
SELECT * FROM provider_services;

SELECT 'SERVICE_AVAILABILITY_MATRIX TABLE' as table_header;
SELECT * FROM service_availability_matrix;

SELECT 'SERVICE_HISTORY TABLE' as table_header;
SELECT * FROM service_history;

SELECT 'SERVICE_PHASE_TRACKING TABLE' as table_header;
SELECT * FROM service_phase_tracking;

-- === CUSTOMER & VEHICLE DATA ===
SELECT 'VEHICLES TABLE' as table_header;
SELECT * FROM vehicles;

SELECT 'REVIEWS TABLE' as table_header;
SELECT * FROM reviews;

SELECT 'USER_LOCATIONS TABLE' as table_header;
SELECT * FROM user_locations;

-- === PAYMENT VERIFICATION ===
SELECT 'CASH_PAYMENT_VERIFICATIONS TABLE' as table_header;
SELECT * FROM cash_payment_verifications;

SELECT 'PAYMENT_RELEASES TABLE' as table_header;
SELECT * FROM payment_releases;

SELECT 'PAYMENT_METHODS TABLE' as table_header;
SELECT * FROM payment_methods;

SELECT 'PAYMONGO_WEBHOOK_EVENTS TABLE' as table_header;
SELECT * FROM paymongo_webhook_events;

-- === SYSTEM CONFIGURATION ===
SELECT 'APP_SETTINGS TABLE' as table_header;
SELECT * FROM app_settings;

SELECT 'DISTANCE_PRICING_CONFIG TABLE' as table_header;
SELECT * FROM distance_pricing_config;

SELECT 'NOTIFICATION_TEMPLATES TABLE' as table_header;
SELECT * FROM notification_templates;

SELECT 'USER_NOTIFICATION_PREFERENCES TABLE' as table_header;
SELECT * FROM user_notification_preferences;

SELECT 'DO_NOT_DISTURB_SETTINGS TABLE' as table_header;
SELECT * FROM do_not_disturb_settings;

-- === SECURITY & LOGGING ===
SELECT 'ACCOUNT_SECURITY_LOGS TABLE' as table_header;
SELECT * FROM account_security_logs;

SELECT 'ADMIN_ACTIVITY_LOGS TABLE' as table_header;
SELECT * FROM admin_activity_logs;

SELECT 'PROFILE_IMAGE_LOGS TABLE' as table_header;
SELECT * FROM profile_image_logs;

SELECT 'PROFILE_UPDATES TABLE' as table_header;
SELECT * FROM profile_updates;

SELECT 'NOTIFICATION_DELIVERY_LOG TABLE' as table_header;
SELECT * FROM notification_delivery_log;

-- === AUTHENTICATION & TOKENS ===
SELECT 'EMAIL_VERIFICATION_TOKENS TABLE' as table_header;
SELECT * FROM email_verification_tokens;

SELECT 'PASSWORD_RESET_TOKENS TABLE' as table_header;
SELECT * FROM password_reset_tokens;

SELECT 'TEMPORARY_PASSWORDS TABLE' as table_header;
SELECT * FROM temporary_passwords;

-- === INVITATIONS & DOWNLOADS ===
SELECT 'MECHANIC_INVITATIONS TABLE' as table_header;
SELECT * FROM mechanic_invitations;

SELECT 'APP_DOWNLOADS TABLE' as table_header;
SELECT * FROM app_downloads;

-- === SHOP MANAGEMENT EXTENDED ===
SELECT 'SHOP_NOTIFICATIONS TABLE' as table_header;
SELECT * FROM shop_notifications;

SELECT 'SHOP_SETTINGS TABLE' as table_header;
SELECT * FROM shop_settings;

SELECT 'SHOP_STATS_CACHE TABLE' as table_header;
SELECT * FROM shop_stats_cache;

-- === ROUTING & REQUEST MANAGEMENT ===
SELECT 'REQUEST_ROUTING TABLE' as table_header;
SELECT * FROM request_routing;

SELECT 'TALYER_CUSTOMER_CONNECTIONS TABLE' as table_header;
SELECT * FROM talyer_customer_connections;

-- === INSPECTION & PROGRESS ===
SELECT 'INSPECTION_REPORTS TABLE' as table_header;
SELECT * FROM inspection_reports;

SELECT 'PROGRESS_PHOTOS TABLE' as table_header;
SELECT * FROM progress_photos;

-- === SYSTEM STATISTICS ===
SELECT 'SYSTEM_STATISTICS TABLE' as table_header;
SELECT * FROM system_statistics;

-- === COMPLETION MESSAGE ===
SELECT 'ALL 57 TABLES DISPLAYED' as completion_status;
SELECT 'Complete data from all RoadAid database tables shown above' as final_message;