-- QUICK DATA CHECK - See which tables have data
-- Run this first to see which tables actually have records

SELECT 'TABLE DATA INVENTORY - WHICH TABLES HAVE DATA' as inventory_title;

-- Check all tables for data
SELECT 'user_profiles' as table_name, COUNT(*) as record_count FROM user_profiles
UNION ALL
SELECT 'service_requests' as table_name, COUNT(*) as record_count FROM service_requests
UNION ALL
SELECT 'shops' as table_name, COUNT(*) as record_count FROM shops
UNION ALL
SELECT 'invoices' as table_name, COUNT(*) as record_count FROM invoices
UNION ALL
SELECT 'payments' as table_name, COUNT(*) as record_count FROM payments
UNION ALL
SELECT 'job_completion_codes' as table_name, COUNT(*) as record_count FROM job_completion_codes
UNION ALL
SELECT 'service_completions' as table_name, COUNT(*) as record_count FROM service_completions
UNION ALL
SELECT 'mechanics' as table_name, COUNT(*) as record_count FROM mechanics
UNION ALL
SELECT 'shop_services' as table_name, COUNT(*) as record_count FROM shop_services
UNION ALL
SELECT 'shop_mechanics' as table_name, COUNT(*) as record_count FROM shop_mechanics
UNION ALL
SELECT 'business_permits' as table_name, COUNT(*) as record_count FROM business_permits
UNION ALL
SELECT 'document_verifications' as table_name, COUNT(*) as record_count FROM document_verifications
UNION ALL
SELECT 'talyer_owner_verifications' as table_name, COUNT(*) as record_count FROM talyer_owner_verifications
UNION ALL
SELECT 'notifications' as table_name, COUNT(*) as record_count FROM notifications
UNION ALL
SELECT 'messages' as table_name, COUNT(*) as record_count FROM messages
UNION ALL
SELECT 'email_notifications' as table_name, COUNT(*) as record_count FROM email_notifications
UNION ALL
SELECT 'request_broadcasts' as table_name, COUNT(*) as record_count FROM request_broadcasts
UNION ALL
SELECT 'mechanic_availability_status' as table_name, COUNT(*) as record_count FROM mechanic_availability_status
UNION ALL
SELECT 'provider_availability_cache' as table_name, COUNT(*) as record_count FROM provider_availability_cache
UNION ALL
SELECT 'customer_job_history' as table_name, COUNT(*) as record_count FROM customer_job_history
UNION ALL
SELECT 'mechanic_job_history' as table_name, COUNT(*) as record_count FROM mechanic_job_history
UNION ALL
SELECT 'request_status_history' as table_name, COUNT(*) as record_count FROM request_status_history
UNION ALL
SELECT 'audit_logs' as table_name, COUNT(*) as record_count FROM audit_logs
UNION ALL
SELECT 'service_categories' as table_name, COUNT(*) as record_count FROM service_categories
UNION ALL
SELECT 'vehicles' as table_name, COUNT(*) as record_count FROM vehicles
UNION ALL
SELECT 'reviews' as table_name, COUNT(*) as record_count FROM reviews
UNION ALL
SELECT 'cash_payment_verifications' as table_name, COUNT(*) as record_count FROM cash_payment_verifications
UNION ALL
SELECT 'payment_releases' as table_name, COUNT(*) as record_count FROM payment_releases
UNION ALL
SELECT 'app_settings' as table_name, COUNT(*) as record_count FROM app_settings
UNION ALL
SELECT 'distance_pricing_config' as table_name, COUNT(*) as record_count FROM distance_pricing_config
UNION ALL
SELECT 'account_security_logs' as table_name, COUNT(*) as record_count FROM account_security_logs
UNION ALL
SELECT 'admin_activity_logs' as table_name, COUNT(*) as record_count FROM admin_activity_logs
UNION ALL
SELECT 'app_downloads' as table_name, COUNT(*) as record_count FROM app_downloads
UNION ALL
SELECT 'email_verification_tokens' as table_name, COUNT(*) as record_count FROM email_verification_tokens
UNION ALL
SELECT 'inspection_reports' as table_name, COUNT(*) as record_count FROM inspection_reports
UNION ALL
SELECT 'mechanic_invitations' as table_name, COUNT(*) as record_count FROM mechanic_invitations
UNION ALL
SELECT 'notification_delivery_log' as table_name, COUNT(*) as record_count FROM notification_delivery_log
UNION ALL
SELECT 'notification_templates' as table_name, COUNT(*) as record_count FROM notification_templates
UNION ALL
SELECT 'password_reset_tokens' as table_name, COUNT(*) as record_count FROM password_reset_tokens
UNION ALL
SELECT 'payment_methods' as table_name, COUNT(*) as record_count FROM payment_methods
UNION ALL
SELECT 'paymongo_webhook_events' as table_name, COUNT(*) as record_count FROM paymongo_webhook_events
UNION ALL
SELECT 'profile_image_logs' as table_name, COUNT(*) as record_count FROM profile_image_logs
UNION ALL
SELECT 'profile_updates' as table_name, COUNT(*) as record_count FROM profile_updates
UNION ALL
SELECT 'progress_photos' as table_name, COUNT(*) as record_count FROM progress_photos
UNION ALL
SELECT 'provider_services' as table_name, COUNT(*) as record_count FROM provider_services
UNION ALL
SELECT 'request_routing' as table_name, COUNT(*) as record_count FROM request_routing
UNION ALL
SELECT 'service_availability_matrix' as table_name, COUNT(*) as record_count FROM service_availability_matrix
UNION ALL
SELECT 'service_history' as table_name, COUNT(*) as record_count FROM service_history
UNION ALL
SELECT 'service_phase_tracking' as table_name, COUNT(*) as record_count FROM service_phase_tracking
UNION ALL
SELECT 'service_providers' as table_name, COUNT(*) as record_count FROM service_providers
UNION ALL
SELECT 'shop_notifications' as table_name, COUNT(*) as record_count FROM shop_notifications
UNION ALL
SELECT 'shop_settings' as table_name, COUNT(*) as record_count FROM shop_settings
UNION ALL
SELECT 'shop_stats_cache' as table_name, COUNT(*) as record_count FROM shop_stats_cache
UNION ALL
SELECT 'system_statistics' as table_name, COUNT(*) as record_count FROM system_statistics
UNION ALL
SELECT 'talyer_customer_connections' as table_name, COUNT(*) as record_count FROM talyer_customer_connections
UNION ALL
SELECT 'temporary_passwords' as table_name, COUNT(*) as record_count FROM temporary_passwords
UNION ALL
SELECT 'user_locations' as table_name, COUNT(*) as record_count FROM user_locations
UNION ALL
SELECT 'user_notification_preferences' as table_name, COUNT(*) as record_count FROM user_notification_preferences
UNION ALL
SELECT 'do_not_disturb_settings' as table_name, COUNT(*) as record_count FROM do_not_disturb_settings
ORDER BY record_count DESC;

-- Show which tables have the most data
SELECT 'TABLES WITH MOST DATA' as summary_section;
SELECT 'Tables with more than 0 records will show here' as note;