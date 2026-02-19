-- CORE BUSINESS TABLES DATA
-- Run each query separately in Supabase

-- === USER PROFILES ===
SELECT 'USER_PROFILES:' as info, COUNT(*) as total_records FROM user_profiles;
SELECT * FROM user_profiles LIMIT 50;

-- === SERVICE REQUESTS ===
SELECT 'SERVICE_REQUESTS:' as info, COUNT(*) as total_records FROM service_requests;
SELECT * FROM service_requests LIMIT 50;

-- === SHOPS ===
SELECT 'SHOPS:' as info, COUNT(*) as total_records FROM shops;
SELECT * FROM shops LIMIT 50;

-- === INVOICES ===
SELECT 'INVOICES:' as info, COUNT(*) as total_records FROM invoices;
SELECT * FROM invoices LIMIT 50;

-- === PAYMENTS ===
SELECT 'PAYMENTS:' as info, COUNT(*) as total_records FROM payments;
SELECT * FROM payments LIMIT 50;

-- === MECHANICS ===
SELECT 'MECHANICS:' as info, COUNT(*) as total_records FROM mechanics;
SELECT * FROM mechanics LIMIT 50;

-- === VEHICLES ===
SELECT 'VEHICLES:' as info, COUNT(*) as total_records FROM vehicles;
SELECT * FROM vehicles LIMIT 50;

-- === SERVICE PROVIDERS ===
SELECT 'SERVICE_PROVIDERS:' as info, COUNT(*) as total_records FROM service_providers;
SELECT * FROM service_providers LIMIT 50;

-- === SERVICE CATEGORIES ===
SELECT 'SERVICE_CATEGORIES:' as info, COUNT(*) as total_records FROM service_categories;
SELECT * FROM service_categories LIMIT 50;

-- === SHOP SERVICES ===
SELECT 'SHOP_SERVICES:' as info, COUNT(*) as total_records FROM shop_services;
SELECT * FROM shop_services LIMIT 50;