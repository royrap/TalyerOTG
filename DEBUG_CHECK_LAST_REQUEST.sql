-- ====================================================================
-- DEBUG: CHECK LAST SERVICE REQUEST
-- ====================================================================
-- Check kung ano ang nangyari sa last request na ni-create
-- ====================================================================

-- 1. Get the last service request (most recent)
SELECT 
    id,
    customer_id,
    title,
    description,
    request_type,
    preferred_shop_id,
    shop_id,
    broadcast_status,
    notified_providers_count,
    status,
    created_at,
    broadcast_started_at
FROM service_requests
ORDER BY created_at DESC
LIMIT 1;

-- 2. Check kung may shop_id ba talaga
SELECT 
    'Request Details' as info,
    CASE 
        WHEN preferred_shop_id IS NULL THEN '❌ NO preferred_shop_id (broadcast mode)'
        ELSE '✅ Has preferred_shop_id: ' || preferred_shop_id::text
    END as shop_status,
    broadcast_status,
    notified_providers_count,
    request_type
FROM service_requests
ORDER BY created_at DESC
LIMIT 1;

-- 3. Check kung sino ang naka-receive ng notification
SELECT 
    'Notified Mechanics' as info,
    rb.mechanic_id,
    up.first_name || ' ' || up.last_name as mechanic_name,
    rb.shop_id,
    s.shop_name,
    rb.notification_sent_at,
    rb.response_status
FROM request_broadcasts rb
LEFT JOIN user_profiles up ON up.id = rb.mechanic_id
LEFT JOIN shops s ON s.id = rb.shop_id
WHERE rb.request_id = (
    SELECT id FROM service_requests ORDER BY created_at DESC LIMIT 1
)
ORDER BY rb.notification_sent_at DESC;

-- 4. Check the trigger result (may nag-trigger ba?)
SELECT 
    'Trigger Check' as info,
    id as request_id,
    broadcast_status,
    CASE 
        WHEN broadcast_status = 'no_mechanics_available' THEN '✅ CORRECT: No mechanics error'
        WHEN broadcast_status = 'broadcasting' THEN '❌ WRONG: Broadcasting to mechanics'
        WHEN broadcast_status IS NULL THEN '⚠️ WARNING: No broadcast status (trigger not fired?)'
        ELSE '❓ UNKNOWN: ' || broadcast_status
    END as result,
    notified_providers_count
FROM service_requests
ORDER BY created_at DESC
LIMIT 1;

-- 5. Get the shop details (kung may shop)
SELECT 
    'Shop Details' as info,
    sr.preferred_shop_id,
    s.shop_name,
    COUNT(sm.mechanic_id) as total_mechanics_in_shop
FROM service_requests sr
LEFT JOIN shops s ON s.id = sr.preferred_shop_id
LEFT JOIN shop_mechanics sm ON sm.shop_id = sr.preferred_shop_id AND sm.is_active = true
WHERE sr.id = (SELECT id FROM service_requests ORDER BY created_at DESC LIMIT 1)
GROUP BY sr.preferred_shop_id, s.shop_name;

-- ====================================================================
-- EXPECTED RESULTS FOR "riza store" (0 mechanics):
-- ====================================================================
-- preferred_shop_id: NOT NULL (UUID of riza store)
-- broadcast_status: 'no_mechanics_available'
-- notified_providers_count: 0
-- request_type: 'shop_based'
-- Notified Mechanics: 0 rows (empty result)
-- ====================================================================

-- ====================================================================
-- IF YOU SEE THIS - SOMETHING IS WRONG:
-- ====================================================================
-- ❌ preferred_shop_id: NULL (means not setting shop ID)
-- ❌ broadcast_status: 'broadcasting' (should be 'no_mechanics_available')
-- ❌ notified_providers_count: > 0 (should be 0)
-- ❌ request_type: 'broadcast' (should be 'shop_based')
-- ❌ Notified Mechanics: Shows mechanics from other shops
-- ====================================================================
