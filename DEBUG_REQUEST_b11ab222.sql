-- ====================================================================
-- DEBUG SPECIFIC REQUEST: b11ab222-4e02-4215-9144-01a3b105dd82
-- ====================================================================
-- Yung request ID sa screenshot mo
-- ====================================================================

-- 1. Check request details
SELECT 
    '=== REQUEST DETAILS ===' as section,
    id,
    customer_id,
    title,
    request_type,
    preferred_shop_id,
    shop_id,
    broadcast_status,
    notified_providers_count,
    status,
    created_at
FROM service_requests
WHERE id = 'b11ab222-4e02-4215-9144-01a3b105dd82'::uuid;

-- 2. Check if shop_id is set
SELECT 
    '=== SHOP CHECK ===' as section,
    CASE 
        WHEN preferred_shop_id IS NULL THEN '❌ NO SHOP ID - Broadcast mode activated'
        ELSE '✅ Has shop ID: ' || preferred_shop_id::text
    END as shop_status,
    broadcast_status,
    request_type
FROM service_requests
WHERE id = 'b11ab222-4e02-4215-9144-01a3b105dd82'::uuid;

-- 3. Check who received notification
SELECT 
    '=== NOTIFIED MECHANICS ===' as section,
    up.first_name || ' ' || up.last_name as mechanic_name,
    s.shop_name as from_shop,
    rb.notification_sent_at,
    rb.response_status
FROM request_broadcasts rb
JOIN user_profiles up ON up.id = rb.mechanic_id
LEFT JOIN shops s ON s.id = rb.shop_id
WHERE rb.request_id = 'b11ab222-4e02-4215-9144-01a3b105dd82'::uuid
ORDER BY rb.notification_sent_at;

-- 4. Check trigger logs (Supabase logs)
SELECT 
    '=== TRIGGER STATUS ===' as section,
    broadcast_status,
    notified_providers_count,
    broadcast_started_at,
    broadcast_expires_at,
    CASE 
        WHEN broadcast_status = 'no_mechanics_available' THEN '✅ CORRECT'
        WHEN broadcast_status = 'broadcasting' THEN '❌ WRONG - Should not broadcast'
        ELSE '⚠️ UNKNOWN STATUS'
    END as diagnosis
FROM service_requests
WHERE id = 'b11ab222-4e02-4215-9144-01a3b105dd82'::uuid;

-- ====================================================================
-- WHAT TO LOOK FOR:
-- ====================================================================
-- IF preferred_shop_id IS NULL:
--   → Problem: Flutter not passing shopId correctly
--   → Fix: Check vehicle_details_screen.dart line 882
--
-- IF preferred_shop_id IS NOT NULL AND broadcast_status = 'broadcasting':
--   → Problem: Trigger using old function
--   → Fix: Check if trigger is using broadcast_service_request_with_shop_filter
--
-- IF notified_providers_count > 0:
--   → Problem: Mechanics from other shops were notified
--   → Fix: Trigger not working correctly
-- ====================================================================

-- 5. Check which trigger function is being used
SELECT 
    trigger_name,
    action_statement,
    action_timing,
    event_manipulation
FROM information_schema.triggers
WHERE trigger_name = 'auto_broadcast_new_request';

-- 6. Check if our new function exists
SELECT 
    routine_name,
    routine_type
FROM information_schema.routines
WHERE routine_name = 'broadcast_service_request_with_shop_filter';
