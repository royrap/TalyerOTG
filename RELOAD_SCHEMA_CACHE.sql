-- ============================================================================
-- FORCE POSTGREST SCHEMA CACHE RELOAD
-- ============================================================================
-- Run this immediately after creating database functions to make them
-- available to the Supabase API (PostgREST)
-- ============================================================================

-- Force PostgREST to reload its schema cache
NOTIFY pgrst, 'reload schema';

-- Verify the function exists
SELECT 
  proname AS function_name,
  pg_get_function_arguments(oid) AS parameters,
  pronargs AS arg_count
FROM pg_proc 
WHERE proname = 'get_shop_mechanics_for_owner'
  AND pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public');

-- Test the function with your actual owner ID
SELECT * FROM public.get_shop_mechanics_for_owner('19a8b4ca-f5f8-4b85-9147-5128d9651e04');

-- ============================================================================
-- EXPECTED RESULTS
-- ============================================================================
-- Query 1: Should show "reload schema" notification sent
-- Query 2: Should show the function with 1 parameter (owner_id_param uuid)
-- Query 3: Should return 2 mechanics (Rafaels pineda and yujiro fuma)
-- ============================================================================

-- If Query 3 returns mechanics data, the function is working!
-- If it still gives "function not found", wait 30 seconds and try again,
-- or restart your Flutter app after running this script.
