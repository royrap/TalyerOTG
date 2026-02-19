-- =====================================================
-- TEST SHOP BUSINESS HOURS AND OPEN/CLOSED STATUS
-- =====================================================

-- 1. Show current time and day
SELECT 
    NOW() as current_timestamp,
    TO_CHAR(NOW(), 'Day') as current_day,
    NOW()::TIME as current_time,
    LOWER(TRIM(TO_CHAR(NOW(), 'Day'))) as formatted_day;

-- 2. Show all shops with their business hours
SELECT 
    s.shop_name,
    s.business_hours,
    s.business_hours->LOWER(TRIM(TO_CHAR(NOW(), 'Day'))) as today_hours,
    is_shop_open(s.business_hours, NOW()) as is_currently_open
FROM shops s
ORDER BY s.shop_name;

-- 3. Test get_nearby_shops (replace with actual coordinates)
-- This should ONLY return shops that are currently open
SELECT * FROM get_nearby_shops(14.9321, 120.8807, 15.0);

-- 4. Simulate checking at different times
-- Test what happens at midnight (closed)
SELECT 
    shop_name,
    business_hours->LOWER(TRIM(TO_CHAR(NOW(), 'Day'))) as today_hours,
    is_shop_open(business_hours, NOW()) as open_now,
    is_shop_open(business_hours, DATE_TRUNC('day', NOW()) + INTERVAL '00:00') as open_at_midnight,
    is_shop_open(business_hours, DATE_TRUNC('day', NOW()) + INTERVAL '09:00') as open_at_9am,
    is_shop_open(business_hours, DATE_TRUNC('day', NOW()) + INTERVAL '12:00') as open_at_noon,
    is_shop_open(business_hours, DATE_TRUNC('day', NOW()) + INTERVAL '18:00') as open_at_6pm,
    is_shop_open(business_hours, DATE_TRUNC('day', NOW()) + INTERVAL '22:00') as open_at_10pm
FROM shops
ORDER BY shop_name;

-- 5. Test with a shop that should be closed
-- Create a temporary test to simulate closed shop
DO $$
DECLARE
    test_business_hours JSONB;
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE '🧪 TESTING CLOSED SHOP SCENARIO';
    RAISE NOTICE '========================================';
    
    -- Test hours: 8:00 AM - 6:00 PM
    test_business_hours := jsonb_build_object(
        LOWER(TRIM(TO_CHAR(NOW(), 'Day'))),
        jsonb_build_object('open', '08:00', 'close', '18:00')
    );
    
    RAISE NOTICE 'Current Time: %', NOW()::TIME;
    RAISE NOTICE 'Test Shop Hours: 8:00 AM - 6:00 PM';
    RAISE NOTICE 'Should be open: %', is_shop_open(test_business_hours, NOW());
    
    -- Test at midnight (should be closed)
    RAISE NOTICE 'At midnight: %', is_shop_open(test_business_hours, DATE_TRUNC('day', NOW()) + INTERVAL '00:00');
    
    -- Test at 3 AM (should be closed)
    RAISE NOTICE 'At 3 AM: %', is_shop_open(test_business_hours, DATE_TRUNC('day', NOW()) + INTERVAL '03:00');
    
    -- Test at 9 AM (should be open)
    RAISE NOTICE 'At 9 AM: %', is_shop_open(test_business_hours, DATE_TRUNC('day', NOW()) + INTERVAL '09:00');
    
    -- Test at 10 PM (should be closed)
    RAISE NOTICE 'At 10 PM: %', is_shop_open(test_business_hours, DATE_TRUNC('day', NOW()) + INTERVAL '22:00');
    
    RAISE NOTICE '========================================';
END $$;
