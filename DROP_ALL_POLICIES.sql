-- =====================================================
-- DROP ALL RLS POLICIES - COMPREHENSIVE CLEANUP
-- =====================================================
-- This will remove ALL Row Level Security policies from all tables
-- to ensure nothing is blocking the triggers and queries

-- =====================================================
-- DISABLE RLS ON ALL CRITICAL TABLES
-- =====================================================

ALTER TABLE service_requests DISABLE ROW LEVEL SECURITY;
ALTER TABLE request_routing DISABLE ROW LEVEL SECURITY;
ALTER TABLE request_broadcasts DISABLE ROW LEVEL SECURITY;
ALTER TABLE notifications DISABLE ROW LEVEL SECURITY;
ALTER TABLE user_profiles DISABLE ROW LEVEL SECURITY;
ALTER TABLE shop_mechanics DISABLE ROW LEVEL SECURITY;
ALTER TABLE mechanic_availability_status DISABLE ROW LEVEL SECURITY;
ALTER TABLE shops DISABLE ROW LEVEL SECURITY;
ALTER TABLE service_providers DISABLE ROW LEVEL SECURITY;

-- =====================================================
-- DROP ALL POLICIES FROM service_requests
-- =====================================================

DROP POLICY IF EXISTS "Allow authenticated users to insert requests" ON service_requests;
DROP POLICY IF EXISTS "Allow users to view their own requests" ON service_requests;
DROP POLICY IF EXISTS "Allow mechanics to view assigned requests" ON service_requests;
DROP POLICY IF EXISTS "Allow mechanics to update assigned requests" ON service_requests;
DROP POLICY IF EXISTS "Allow customers to view their requests" ON service_requests;
DROP POLICY IF EXISTS "Allow customers to create requests" ON service_requests;
DROP POLICY IF EXISTS "Allow customers to update their requests" ON service_requests;
DROP POLICY IF EXISTS "Allow service providers to view requests" ON service_requests;
DROP POLICY IF EXISTS "Allow service providers to update requests" ON service_requests;
DROP POLICY IF EXISTS "service_requests_select_policy" ON service_requests;
DROP POLICY IF EXISTS "service_requests_insert_policy" ON service_requests;
DROP POLICY IF EXISTS "service_requests_update_policy" ON service_requests;
DROP POLICY IF EXISTS "service_requests_delete_policy" ON service_requests;

-- =====================================================
-- DROP ALL POLICIES FROM request_routing
-- =====================================================

DROP POLICY IF EXISTS "Allow system to insert routing" ON request_routing;
DROP POLICY IF EXISTS "Allow mechanics to view their routing" ON request_routing;
DROP POLICY IF EXISTS "Allow system to update routing" ON request_routing;
DROP POLICY IF EXISTS "request_routing_select_policy" ON request_routing;
DROP POLICY IF EXISTS "request_routing_insert_policy" ON request_routing;
DROP POLICY IF EXISTS "request_routing_update_policy" ON request_routing;
DROP POLICY IF EXISTS "request_routing_delete_policy" ON request_routing;

-- =====================================================
-- DROP ALL POLICIES FROM request_broadcasts
-- =====================================================

DROP POLICY IF EXISTS "Allow system to insert broadcasts" ON request_broadcasts;
DROP POLICY IF EXISTS "Allow mechanics to view broadcasts" ON request_broadcasts;
DROP POLICY IF EXISTS "Allow system to update broadcasts" ON request_broadcasts;
DROP POLICY IF EXISTS "request_broadcasts_select_policy" ON request_broadcasts;
DROP POLICY IF EXISTS "request_broadcasts_insert_policy" ON request_broadcasts;
DROP POLICY IF EXISTS "request_broadcasts_update_policy" ON request_broadcasts;
DROP POLICY IF EXISTS "request_broadcasts_delete_policy" ON request_broadcasts;

-- =====================================================
-- DROP ALL POLICIES FROM notifications
-- =====================================================

DROP POLICY IF EXISTS "Allow users to view their notifications" ON notifications;
DROP POLICY IF EXISTS "Allow system to create notifications" ON notifications;
DROP POLICY IF EXISTS "Allow users to update their notifications" ON notifications;
DROP POLICY IF EXISTS "notifications_select_policy" ON notifications;
DROP POLICY IF EXISTS "notifications_insert_policy" ON notifications;
DROP POLICY IF EXISTS "notifications_update_policy" ON notifications;
DROP POLICY IF EXISTS "notifications_delete_policy" ON notifications;

-- =====================================================
-- DROP ALL POLICIES FROM user_profiles
-- =====================================================

DROP POLICY IF EXISTS "Allow users to view profiles" ON user_profiles;
DROP POLICY IF EXISTS "Allow users to update own profile" ON user_profiles;
DROP POLICY IF EXISTS "user_profiles_select_policy" ON user_profiles;
DROP POLICY IF EXISTS "user_profiles_insert_policy" ON user_profiles;
DROP POLICY IF EXISTS "user_profiles_update_policy" ON user_profiles;
DROP POLICY IF EXISTS "user_profiles_delete_policy" ON user_profiles;

-- =====================================================
-- DROP ALL POLICIES FROM shop_mechanics
-- =====================================================

DROP POLICY IF EXISTS "Allow shop owners to manage mechanics" ON shop_mechanics;
DROP POLICY IF EXISTS "Allow mechanics to view their shops" ON shop_mechanics;
DROP POLICY IF EXISTS "shop_mechanics_select_policy" ON shop_mechanics;
DROP POLICY IF EXISTS "shop_mechanics_insert_policy" ON shop_mechanics;
DROP POLICY IF EXISTS "shop_mechanics_update_policy" ON shop_mechanics;
DROP POLICY IF EXISTS "shop_mechanics_delete_policy" ON shop_mechanics;

-- =====================================================
-- DROP ALL POLICIES FROM mechanic_availability_status
-- =====================================================

DROP POLICY IF EXISTS "Allow mechanics to manage availability" ON mechanic_availability_status;
DROP POLICY IF EXISTS "Allow system to update availability" ON mechanic_availability_status;
DROP POLICY IF EXISTS "mechanic_availability_status_select_policy" ON mechanic_availability_status;
DROP POLICY IF EXISTS "mechanic_availability_status_insert_policy" ON mechanic_availability_status;
DROP POLICY IF EXISTS "mechanic_availability_status_update_policy" ON mechanic_availability_status;
DROP POLICY IF EXISTS "mechanic_availability_status_delete_policy" ON mechanic_availability_status;

-- =====================================================
-- DROP ALL POLICIES FROM shops
-- =====================================================

DROP POLICY IF EXISTS "Allow shop owners to manage shops" ON shops;
DROP POLICY IF EXISTS "Allow public to view shops" ON shops;
DROP POLICY IF EXISTS "shops_select_policy" ON shops;
DROP POLICY IF EXISTS "shops_insert_policy" ON shops;
DROP POLICY IF EXISTS "shops_update_policy" ON shops;
DROP POLICY IF EXISTS "shops_delete_policy" ON shops;

-- =====================================================
-- DROP ALL POLICIES FROM service_providers
-- =====================================================

DROP POLICY IF EXISTS "Allow providers to manage profile" ON service_providers;
DROP POLICY IF EXISTS "Allow public to view providers" ON service_providers;
DROP POLICY IF EXISTS "service_providers_select_policy" ON service_providers;
DROP POLICY IF EXISTS "service_providers_insert_policy" ON service_providers;
DROP POLICY IF EXISTS "service_providers_update_policy" ON service_providers;
DROP POLICY IF EXISTS "service_providers_delete_policy" ON service_providers;

-- =====================================================
-- VERIFY ALL POLICIES DROPPED
-- =====================================================

SELECT 
    schemaname,
    tablename,
    policyname,
    cmd,
    qual
FROM pg_policies
WHERE schemaname = 'public'
AND tablename IN (
    'service_requests',
    'request_routing',
    'request_broadcasts',
    'notifications',
    'user_profiles',
    'shop_mechanics',
    'mechanic_availability_status',
    'shops',
    'service_providers'
)
ORDER BY tablename, policyname;

-- Expected: Should return 0 rows (all policies dropped)

-- =====================================================
-- VERIFY RLS DISABLED
-- =====================================================

SELECT 
    tablename,
    rowsecurity as rls_enabled
FROM pg_tables
WHERE schemaname = 'public'
AND tablename IN (
    'service_requests',
    'request_routing',
    'request_broadcasts',
    'notifications',
    'user_profiles',
    'shop_mechanics',
    'mechanic_availability_status',
    'shops',
    'service_providers'
)
ORDER BY tablename;

-- Expected: All should show rls_enabled = false

-- =====================================================
-- SUCCESS MESSAGE
-- =====================================================

DO $$ 
BEGIN
    RAISE NOTICE '✅ All RLS policies dropped successfully!';
    RAISE NOTICE '✅ RLS disabled on all critical tables!';
    RAISE NOTICE '🎯 System is now ready for testing!';
END $$;
