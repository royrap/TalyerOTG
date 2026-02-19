-- ============================================================================
-- VERIFY DATABASE FUNCTION EXISTS
-- ============================================================================
-- Run this in Supabase SQL Editor to check if the function was created
-- ============================================================================

-- 1. Check if function exists
SELECT 
  proname AS function_name,
  pg_get_function_arguments(oid) AS parameters,
  pronargs AS number_of_args,
  proargtypes AS argument_types
FROM pg_proc 
WHERE proname = 'get_shop_mechanics_for_owner'
  AND pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public');

-- 2. If function exists, test it with your user ID
-- Replace 'YOUR-USER-ID' with actual ID: 19a8b4ca-f5f8-4b85-9147-5128d9651e04
SELECT * FROM public.get_shop_mechanics_for_owner('19a8b4ca-f5f8-4b85-9147-5128d9651e04');

-- 3. Check function permissions
SELECT 
  proname,
  proacl AS permissions
FROM pg_proc
WHERE proname = 'get_shop_mechanics_for_owner';

-- 4. Force PostgREST to reload schema cache
NOTIFY pgrst, 'reload schema';

-- ============================================================================
-- EXPECTED RESULTS
-- ============================================================================
-- Query 1: Should show function with parameters (owner_id_param UUID)
-- Query 2: Should return mechanics data (may be empty if no mechanics)
-- Query 3: Should show permissions including 'authenticated'
-- Query 4: Should show "NOTIFY" success message
-- ============================================================================
