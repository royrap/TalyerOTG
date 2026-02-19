-- ========================================
-- 🔓 ENABLE RLS ON ALL REQUIRED TABLES
-- ========================================
-- RLS might be DISABLED, let's enable it first
-- ========================================

-- Enable RLS on service_requests
ALTER TABLE service_requests ENABLE ROW LEVEL SECURITY;

-- Enable RLS on mechanic_job_history
ALTER TABLE mechanic_job_history ENABLE ROW LEVEL SECURITY;

-- Enable RLS on shops
ALTER TABLE shops ENABLE ROW LEVEL SECURITY;

-- Enable RLS on shop_mechanics
ALTER TABLE shop_mechanics ENABLE ROW LEVEL SECURITY;

-- Enable RLS on user_profiles (if not already)
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;

SELECT 
  '=== ✅ RLS ENABLED ON ALL TABLES ===' as section;

SELECT 
  tablename,
  rowsecurity as rls_now_enabled
FROM pg_tables
WHERE schemaname = 'public'
  AND tablename IN ('service_requests', 'mechanic_job_history', 'shops', 'shop_mechanics', 'user_profiles')
ORDER BY tablename;

DO $$
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ RLS ENABLED ON ALL TABLES';
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
    RAISE NOTICE 'Now run FIX_RLS_FOR_SHOP_OWNER.sql again!';
    RAISE NOTICE '========================================';
END $$;
