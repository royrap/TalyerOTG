-- =====================================================
-- TEST SHOP OPEN/CLOSE FILTERING
-- =====================================================
-- This script tests whether shops are properly filtered
-- based on their business hours and current time.
-- =====================================================

-- Show current time and day
SELECT 
    NOW() as current_timestamp,
    NOW()::TIME as current_time,
    LOWER(TRIM(TO_CHAR(NOW(), 'Day'))) as current_day,
    TO_CHAR(NOW(), 'HH24:MI') as current_time_24h;

-- Check all shops and their business hours
SELECT 
    s.id,
    s.shop_name,
    s.business_hours,
    s.business_hours->LOWER(TRIM(TO_CHAR(NOW(), 'Day'))) as today_hours,
    is_shop_open(s.business_hours, NOW()) as is_currently_open,
    s.is_active,
    up.is_available as owner_available
FROM shops s
INNER JOIN user_profiles up ON up.id = s.owner_id
WHERE s.is_active = true
ORDER BY s.shop_name;

-- Test the get_nearby_shops function (should only return OPEN shops)
SELECT 
    shop_name,
    business_hours,
    is_open,
    distance_km,
    owner_name
FROM get_nearby_shops(14.9321, 120.8807, 15.0);

-- Verify: Count total shops vs open shops
SELECT 
    COUNT(*) as total_active_shops,
    SUM(CASE WHEN is_shop_open(s.business_hours, NOW()) THEN 1 ELSE 0 END) as currently_open_shops,
    SUM(CASE WHEN NOT is_shop_open(s.business_hours, NOW()) THEN 1 ELSE 0 END) as currently_closed_shops
FROM shops s
WHERE s.is_active = true;

-- Show which shops should be hidden right now
SELECT 
    s.shop_name,
    s.business_hours->LOWER(TRIM(TO_CHAR(NOW(), 'Day'))) as today_hours,
    is_shop_open(s.business_hours, NOW()) as is_open,
    CASE 
        WHEN is_shop_open(s.business_hours, NOW()) THEN '✅ VISIBLE'
        ELSE '❌ HIDDEN (CLOSED)'
    END as display_status
FROM shops s
WHERE s.is_active = true
ORDER BY is_shop_open(s.business_hours, NOW()) DESC, s.shop_name;
