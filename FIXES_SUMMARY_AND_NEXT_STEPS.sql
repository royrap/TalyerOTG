-- =====================================================
-- SUMMARY: FIXES APPLIED AND NEXT STEPS
-- =====================================================

-- ✅ FIXES COMPLETED:
-- 1. Customer code: Changed 'preferred_shop_id' to 'shop_id' in service_request_service_enhanced.dart (line 90)
-- 2. Database: Updated existing request to populate shop_id
-- 3. Database function: Updated get_nearby_requests_for_mechanic() to use shop_id instead of preferred_shop_id

-- =====================================================
-- TEST: VERIFY SHOP-BASED REQUEST NOW WORKS
-- =====================================================

-- 1. Check the fixed request
SELECT 
    id,
    title,
    shop_id,
    request_type,
    status,
    created_at
FROM service_requests
WHERE id = '1de8e29c-b015-44b1-95f6-8e6c49195b90';

-- Expected: shop_id should be populated

-- 2. Test the fixed location function
SELECT 
    request_id,
    title,
    request_type,
    distance_km,
    is_eligible
FROM get_nearby_requests_for_mechanic(
    'da0aade5-1e11-4901-898c-3fd67379262f'::uuid,  -- Rafael
    14.9321157,
    120.8807151,
    50.0
);

-- Expected: Should see the shop-based request with is_eligible = true

-- =====================================================
-- SEPARATE ISSUE: BROADCAST REQUEST DUPLICATE KEY ERROR
-- =====================================================

-- This is a DIFFERENT problem from shop-based routing
-- Error: "duplicate key value violates unique constraint request_broadcasts_unique_notification"

-- Check what constraint is causing the problem
SELECT 
    conname as constraint_name,
    contype as constraint_type,
    pg_get_constraintdef(oid) as definition
FROM pg_constraint
WHERE conname LIKE '%broadcast%';

-- Check for duplicate broadcast entries
SELECT 
    request_id,
    provider_id,
    COUNT(*) as duplicate_count
FROM request_broadcasts
GROUP BY request_id, provider_id
HAVING COUNT(*) > 1;

-- Clean up any orphaned broadcast entries
DELETE FROM request_broadcasts
WHERE request_id NOT IN (
    SELECT id FROM service_requests
);

-- =====================================================
-- TO TEST SHOP-BASED REQUESTS (MAIN FIX):
-- =====================================================

-- OPTION 1: Test with existing fixed request
-- 1. Run TRIGGER_MECHANIC_NOTIFICATION.sql (from earlier)
-- 2. Refresh mechanic app
-- 3. Should see popup!

-- OPTION 2: Create fresh shop-based request
-- 1. FULLY RESTART customer app (q then flutter run)
-- 2. Browse shops → Select MechAid supply
-- 3. Select a service → Create request
-- 4. New request will use shop_id correctly
-- 5. Mechanics will see popup immediately!

-- =====================================================
-- PRIORITY:
-- =====================================================
-- 🔴 HIGH: Test shop-based request popup (MAIN ISSUE) - ALL FIXES APPLIED
-- 🟡 MEDIUM: Fix broadcast duplicate key error (SEPARATE ISSUE)
