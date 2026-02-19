-- =====================================================
-- CRITICAL DIAGNOSTIC TESTS
-- =====================================================
-- Run these one by one to find the issue

-- =====================================================
-- TEST 1: What does get_nearby_shops actually return?
-- =====================================================
SELECT 
    shop_id,
    shop_name,
    is_open,
    distance_km
FROM get_nearby_shops(14.9321, 120.8807, 15.0);

-- Expected: Only shops with is_open = true
-- If you see is_open = false, then the filter is NOT working!

-- =====================================================
-- TEST 2: Current time and shops status
-- =====================================================
SELECT 
    NOW() as current_timestamp,
    NOW()::TIME as current_time,
    LOWER(TRIM(TO_CHAR(NOW(), 'Day'))) as current_day;

-- Check what time it is NOW

-- =====================================================
-- TEST 3: Check each shop's status RIGHT NOW
-- =====================================================
SELECT 
    s.shop_name,
    s.business_hours->LOWER(TRIM(TO_CHAR(NOW(), 'Day'))) as today_hours,
    (s.business_hours->LOWER(TRIM(TO_CHAR(NOW(), 'Day')))->>'open') as open_time,
    (s.business_hours->LOWER(TRIM(TO_CHAR(NOW(), 'Day')))->>'close') as close_time,
    NOW()::TIME as current_time,
    is_shop_open(s.business_hours, NOW()) as is_open_now
FROM shops s
WHERE s.is_active = true
ORDER BY s.shop_name;

-- Check kung tama ba ang is_open_now
-- Kung mali, may problema sa is_shop_open() function

-- =====================================================
-- TEST 4: Check business_hours format
-- =====================================================
SELECT 
    shop_name,
    business_hours
FROM shops
WHERE is_active = true;

-- Verify kung tama ang format:
-- {"monday": {"open": "08:00", "close": "18:00"}}

-- =====================================================
-- TEST 5: Simulate different times
-- =====================================================
-- Test kung what time dapat open/closed ang shops
SELECT 
    shop_name,
    is_shop_open(business_hours, NOW()) as open_now,
    is_shop_open(business_hours, CURRENT_DATE + TIME '08:00:00') as open_8am,
    is_shop_open(business_hours, CURRENT_DATE + TIME '12:00:00') as open_noon,
    is_shop_open(business_hours, CURRENT_DATE + TIME '18:00:00') as open_6pm,
    is_shop_open(business_hours, CURRENT_DATE + TIME '22:00:00') as open_10pm
FROM shops
WHERE is_active = true;

-- Dapat makita mo kung kailan open/closed

-- =====================================================
-- TEST 6: Count open vs closed shops
-- =====================================================
SELECT 
    COUNT(*) as total_shops,
    COUNT(*) FILTER (WHERE is_shop_open(business_hours, NOW())) as open_now,
    COUNT(*) FILTER (WHERE NOT is_shop_open(business_hours, NOW())) as closed_now
FROM shops
WHERE is_active = true;

-- Kung lahat OPEN, may problema!
-- Kung may CLOSED, pero lumalabas pa rin sa customer, ibang issue yun
