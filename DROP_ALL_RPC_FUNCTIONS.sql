-- ========================================
-- 🗑️ DROP ALL RPC FUNCTIONS (REVERT TO ORIGINAL)
-- ========================================

-- Drop all RPC functions we created
DROP FUNCTION IF EXISTS get_talyer_owner_dashboard_stats();
DROP FUNCTION IF EXISTS get_shop_mechanics_for_owner();
DROP FUNCTION IF EXISTS get_mechanic_job_history();
DROP FUNCTION IF EXISTS get_today_jobs_for_shop();
DROP FUNCTION IF EXISTS get_recent_jobs_for_shop();
DROP FUNCTION IF EXISTS get_all_mechanics_simple();
DROP FUNCTION IF EXISTS get_mechanic_names_only();

-- Drop the extra columns we added
ALTER TABLE mechanic_availability_status 
DROP COLUMN IF EXISTS last_active_at;

-- ========================================
-- SUCCESS MESSAGE
-- ========================================
DO $$
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ ALL RPC FUNCTIONS DROPPED!';
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
    RAISE NOTICE 'Dropped functions:';
    RAISE NOTICE '  - get_talyer_owner_dashboard_stats()';
    RAISE NOTICE '  - get_shop_mechanics_for_owner()';
    RAISE NOTICE '  - get_mechanic_job_history()';
    RAISE NOTICE '  - get_today_jobs_for_shop()';
    RAISE NOTICE '  - get_recent_jobs_for_shop()';
    RAISE NOTICE '  - get_all_mechanics_simple()';
    RAISE NOTICE '  - get_mechanic_names_only()';
    RAISE NOTICE '';
    RAISE NOTICE 'Removed columns:';
    RAISE NOTICE '  - mechanic_availability_status.last_active_at';
    RAISE NOTICE '';
    RAISE NOTICE 'System reverted to original state!';
    RAISE NOTICE '========================================';
END $$;
