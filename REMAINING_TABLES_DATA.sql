-- REMAINING TABLES DATA
-- Run each query separately in Supabase

-- === APP SETTINGS ===
SELECT 'APP_SETTINGS:' as info, COUNT(*) as total_records FROM app_settings;
SELECT * FROM app_settings LIMIT 50;

-- === REVIEWS ===
SELECT 'REVIEWS:' as info, COUNT(*) as total_records FROM reviews;
SELECT * FROM reviews LIMIT 50;

-- === USER LOCATIONS ===
SELECT 'USER_LOCATIONS:' as info, COUNT(*) as total_records FROM user_locations;
SELECT * FROM user_locations LIMIT 50;

-- === PROVIDER SERVICES ===
SELECT 'PROVIDER_SERVICES:' as info, COUNT(*) as total_records FROM provider_services;
SELECT * FROM provider_services LIMIT 50;

-- === SERVICE AVAILABILITY MATRIX ===
SELECT 'SERVICE_AVAILABILITY_MATRIX:' as info, COUNT(*) as total_records FROM service_availability_matrix;
SELECT * FROM service_availability_matrix LIMIT 50;

-- === SERVICE HISTORY ===
SELECT 'SERVICE_HISTORY:' as info, COUNT(*) as total_records FROM service_history;
SELECT * FROM service_history LIMIT 50;

-- === SERVICE PHASE TRACKING ===
SELECT 'SERVICE_PHASE_TRACKING:' as info, COUNT(*) as total_records FROM service_phase_tracking;
SELECT * FROM service_phase_tracking LIMIT 50;

-- === NOTIFICATION TEMPLATES ===
SELECT 'NOTIFICATION_TEMPLATES:' as info, COUNT(*) as total_records FROM notification_templates;
SELECT * FROM notification_templates LIMIT 50;

-- === USER NOTIFICATION PREFERENCES ===
SELECT 'USER_NOTIFICATION_PREFERENCES:' as info, COUNT(*) as total_records FROM user_notification_preferences;
SELECT * FROM user_notification_preferences LIMIT 50;

-- === DO NOT DISTURB SETTINGS ===
SELECT 'DO_NOT_DISTURB_SETTINGS:' as info, COUNT(*) as total_records FROM do_not_disturb_settings;
SELECT * FROM do_not_disturb_settings LIMIT 50;

-- === DISTANCE PRICING CONFIG ===
SELECT 'DISTANCE_PRICING_CONFIG:' as info, COUNT(*) as total_records FROM distance_pricing_config;
SELECT * FROM distance_pricing_config LIMIT 50;

-- === SHOP NOTIFICATIONS ===
SELECT 'SHOP_NOTIFICATIONS:' as info, COUNT(*) as total_records FROM shop_notifications;
SELECT * FROM shop_notifications LIMIT 50;

-- === SHOP SETTINGS ===
SELECT 'SHOP_SETTINGS:' as info, COUNT(*) as total_records FROM shop_settings;
SELECT * FROM shop_settings LIMIT 50;

-- === SHOP STATS CACHE ===
SELECT 'SHOP_STATS_CACHE:' as info, COUNT(*) as total_records FROM shop_stats_cache;
SELECT * FROM shop_stats_cache LIMIT 50;

-- === REQUEST ROUTING ===
SELECT 'REQUEST_ROUTING:' as info, COUNT(*) as total_records FROM request_routing;
SELECT * FROM request_routing LIMIT 50;

-- === TALYER CUSTOMER CONNECTIONS ===
SELECT 'TALYER_CUSTOMER_CONNECTIONS:' as info, COUNT(*) as total_records FROM talyer_customer_connections;
SELECT * FROM talyer_customer_connections LIMIT 50;

-- === INSPECTION REPORTS ===
SELECT 'INSPECTION_REPORTS:' as info, COUNT(*) as total_records FROM inspection_reports;
SELECT * FROM inspection_reports LIMIT 50;

-- === PROGRESS PHOTOS ===
SELECT 'PROGRESS_PHOTOS:' as info, COUNT(*) as total_records FROM progress_photos;
SELECT * FROM progress_photos LIMIT 50;

-- === SYSTEM STATISTICS ===
SELECT 'SYSTEM_STATISTICS:' as info, COUNT(*) as total_records FROM system_statistics;
SELECT * FROM system_statistics LIMIT 50;

-- === ADMIN ACTIVITY LOGS ===
SELECT 'ADMIN_ACTIVITY_LOGS:' as info, COUNT(*) as total_records FROM admin_activity_logs;
SELECT * FROM admin_activity_logs LIMIT 50;

-- === PROFILE IMAGE LOGS ===
SELECT 'PROFILE_IMAGE_LOGS:' as info, COUNT(*) as total_records FROM profile_image_logs;
SELECT * FROM profile_image_logs LIMIT 50;

-- === PROFILE UPDATES ===
SELECT 'PROFILE_UPDATES:' as info, COUNT(*) as total_records FROM profile_updates;
SELECT * FROM profile_updates LIMIT 50;

-- === NOTIFICATION DELIVERY LOG ===
SELECT 'NOTIFICATION_DELIVERY_LOG:' as info, COUNT(*) as total_records FROM notification_delivery_log;
SELECT * FROM notification_delivery_log LIMIT 50;

-- === PROVIDER AVAILABILITY CACHE ===
SELECT 'PROVIDER_AVAILABILITY_CACHE:' as info, COUNT(*) as total_records FROM provider_availability_cache;
SELECT * FROM provider_availability_cache LIMIT 50;