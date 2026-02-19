-- =====================================================
-- CHECK: Verify accept_request_fifo function version
-- =====================================================

-- Check the function definition
SELECT 
    p.proname as function_name,
    pg_get_functiondef(p.oid) as function_definition
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE p.proname = 'accept_request_fifo'
AND n.nspname = 'public';

-- This will show you the ENTIRE function code
-- Check if it has the new logic we added:
-- 1. Should have "request_type" variable
-- 2. Should check "v_request_type = 'broadcast'" (not "v_routing_type IS NULL")
-- 3. Should have shop isolation check for shop_based requests
