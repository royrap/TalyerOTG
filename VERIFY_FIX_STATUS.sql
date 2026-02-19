-- ====================================================================
-- QUICK FIX VERIFICATION
-- ====================================================================
-- I-run mo ito para i-check kung tama ang setup
-- ====================================================================

-- 1. ✅ Check if new functions exist
SELECT 
    '1. FUNCTIONS CHECK' as test,
    routine_name,
    CASE 
        WHEN routine_name IS NOT NULL THEN '✅ EXISTS'
        ELSE '❌ MISSING'
    END as status
FROM information_schema.routines
WHERE routine_name IN (
    'broadcast_service_request_with_shop_filter',
    'find_available_mechanics_in_shop',
    'check_shop_mechanic_availability'
)
ORDER BY routine_name;

-- Expected: 3 rows (all ✅ EXISTS)

-- 2. ✅ Check if trigger exists and uses correct function
SELECT 
    '2. TRIGGER CHECK' as test,
    trigger_name,
    action_statement,
    CASE 
        WHEN action_statement LIKE '%broadcast_service_request_with_shop_filter%' 
            THEN '✅ USING NEW FUNCTION'
        WHEN action_statement LIKE '%broadcast_service_request%' 
            THEN '⚠️ USING OLD FUNCTION (needs update)'
        ELSE '❌ UNKNOWN FUNCTION'
    END as status
FROM information_schema.triggers
WHERE trigger_name = 'auto_broadcast_new_request';

-- Expected: 1 row with '✅ USING NEW FUNCTION'

-- 3. ✅ Check "riza store" mechanic count
SELECT 
    '3. RIZA STORE CHECK' as test,
    s.shop_name,
    COUNT(sm.mechanic_id) as mechanic_count,
    CASE 
        WHEN COUNT(sm.mechanic_id) = 0 THEN '✅ CORRECT (0 mechanics)'
        ELSE '❌ WRONG (has mechanics)'
    END as status
FROM shops s
LEFT JOIN shop_mechanics sm ON sm.shop_id = s.id AND sm.is_active = true
WHERE s.shop_name ILIKE '%riza%'
GROUP BY s.id, s.shop_name;

-- Expected: 0 mechanics

-- 4. ✅ Check latest request
SELECT 
    '4. LATEST REQUEST' as test,
    CASE 
        WHEN preferred_shop_id IS NULL THEN '❌ NO SHOP ID (broadcast mode)'
        ELSE '✅ Has shop ID'
    END as shop_status,
    CASE 
        WHEN broadcast_status = 'no_mechanics_available' THEN '✅ CORRECT STATUS'
        WHEN broadcast_status = 'broadcasting' THEN '❌ WRONG (broadcasting)'
        ELSE '⚠️ STATUS: ' || COALESCE(broadcast_status, 'NULL')
    END as broadcast_status_check,
    CASE 
        WHEN notified_providers_count = 0 THEN '✅ NO MECHANICS NOTIFIED'
        ELSE '❌ ' || notified_providers_count::text || ' mechanics notified'
    END as notification_status
FROM service_requests
ORDER BY created_at DESC
LIMIT 1;

-- Expected for riza store:
-- shop_status: ✅ Has shop ID
-- broadcast_status_check: ✅ CORRECT STATUS
-- notification_status: ✅ NO MECHANICS NOTIFIED

-- ====================================================================
-- SUMMARY OF CHECKS
-- ====================================================================
/*
ALL CHECKS MUST PASS:

1. FUNCTIONS CHECK: 
   ✅ broadcast_service_request_with_shop_filter EXISTS
   ✅ find_available_mechanics_in_shop EXISTS
   ✅ check_shop_mechanic_availability EXISTS

2. TRIGGER CHECK:
   ✅ USING NEW FUNCTION

3. RIZA STORE CHECK:
   ✅ CORRECT (0 mechanics)

4. LATEST REQUEST:
   ✅ Has shop ID
   ✅ CORRECT STATUS
   ✅ NO MECHANICS NOTIFIED

IF ANY CHECK FAILS:
- Re-run FIX_SHOP_SPECIFIC_ROUTING.sql
- Make sure to copy ALL 506 lines
- Check for SQL errors during execution
*/
