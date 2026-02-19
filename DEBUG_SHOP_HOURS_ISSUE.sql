-- =====================================================
-- DEBUG: Why Closed Shops Still Show to Customers
-- =====================================================

-- 1. CHECK CURRENT SHOPS AND THEIR BUSINESS HOURS
SELECT 
    id,
    shop_name,
    owner_id,
    business_hours,
    is_active,
    created_at
FROM shops
ORDER BY shop_name;

-- 2. CHECK CURRENT DAY AND TIME
SELECT 
    NOW() as current_timestamp,
    TO_CHAR(NOW(), 'Day') as current_day_with_spaces,
    LOWER(TRIM(TO_CHAR(NOW(), 'Day'))) as formatted_day,
    NOW()::TIME as current_time;

-- 3. TEST is_shop_open FUNCTION WITH ACTUAL SHOP DATA
SELECT 
    s.id,
    s.shop_name,
    s.business_hours,
    LOWER(TRIM(TO_CHAR(NOW(), 'Day'))) as today,
    s.business_hours->LOWER(TRIM(TO_CHAR(NOW(), 'Day'))) as today_hours,
    (s.business_hours->LOWER(TRIM(TO_CHAR(NOW(), 'Day')))->>'open') as open_time,
    (s.business_hours->LOWER(TRIM(TO_CHAR(NOW(), 'Day')))->>'close') as close_time,
    is_shop_open(s.business_hours, NOW()) as is_currently_open,
    NOW()::TIME as current_time
FROM shops s
WHERE s.is_active = true
ORDER BY s.shop_name;

-- 4. TEST get_nearby_shops FUNCTION
-- Replace coordinates with actual customer location
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE '🧪 TESTING get_nearby_shops FUNCTION';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Current Time: %', NOW()::TIME;
    RAISE NOTICE 'Current Day: %', LOWER(TRIM(TO_CHAR(NOW(), 'Day')));
    RAISE NOTICE '';
END $$;

-- Show what get_nearby_shops returns
-- IMPORTANT: Replace with actual customer coordinates
SELECT * FROM get_nearby_shops(14.9321, 120.8807, 15.0);

-- 5. CHECK IF FUNCTION EXISTS AND ITS DEFINITION
SELECT 
    routine_name,
    routine_type,
    data_type as return_type
FROM information_schema.routines
WHERE routine_name IN ('is_shop_open', 'get_nearby_shops')
AND routine_schema = 'public';

-- 6. DETAILED HOUR-BY-HOUR TEST
DO $$
DECLARE
    shop_record RECORD;
    test_time TIME;
    is_open BOOLEAN;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE '⏰ HOUR-BY-HOUR SHOP STATUS TEST';
    RAISE NOTICE '========================================';
    
    FOR shop_record IN 
        SELECT id, shop_name, business_hours 
        FROM shops 
        WHERE is_active = true
    LOOP
        RAISE NOTICE '';
        RAISE NOTICE '🏪 Shop: %', shop_record.shop_name;
        RAISE NOTICE 'Business Hours: %', shop_record.business_hours;
        
        -- Test different times
        FOR i IN 0..23 LOOP
            test_time := (i || ':00:00')::TIME;
            is_open := is_shop_open(
                shop_record.business_hours, 
                (CURRENT_DATE + test_time)::TIMESTAMPTZ
            );
            
            RAISE NOTICE '  % - %', 
                TO_CHAR((CURRENT_DATE + test_time)::TIMESTAMPTZ, 'HH12:MI AM'),
                CASE WHEN is_open THEN '✅ OPEN' ELSE '❌ CLOSED' END;
        END LOOP;
    END LOOP;
END $$;

-- 7. CHECK IF business_hours FORMAT IS CORRECT
DO $$
DECLARE
    shop_record RECORD;
    day_keys TEXT[];
    day_key TEXT;
    day_hours JSONB;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE '🔍 BUSINESS HOURS FORMAT CHECK';
    RAISE NOTICE '========================================';
    
    FOR shop_record IN 
        SELECT id, shop_name, business_hours 
        FROM shops 
        WHERE is_active = true
    LOOP
        RAISE NOTICE '';
        RAISE NOTICE '🏪 Shop: %', shop_record.shop_name;
        
        -- Check each day
        day_keys := ARRAY['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
        
        FOREACH day_key IN ARRAY day_keys
        LOOP
            day_hours := shop_record.business_hours->day_key;
            
            IF day_hours IS NULL THEN
                RAISE NOTICE '  % - ⚠️  NOT DEFINED', UPPER(day_key);
            ELSE
                RAISE NOTICE '  % - Open: %, Close: %', 
                    UPPER(day_key),
                    day_hours->>'open',
                    day_hours->>'close';
            END IF;
        END LOOP;
    END LOOP;
END $$;

-- 8. SIMULATE CUSTOMER APP QUERY
DO $$
DECLARE
    nearby_shops_count INTEGER;
    open_shops_count INTEGER;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE '📱 CUSTOMER APP SIMULATION';
    RAISE NOTICE '========================================';
    
    -- Count total nearby shops (without time filter)
    SELECT COUNT(*) INTO nearby_shops_count
    FROM shops s
    INNER JOIN user_profiles up ON up.id = s.owner_id
    WHERE s.is_active = true
    AND up.user_type = 'talyer_owner';
    
    -- Count open shops (with time filter)
    SELECT COUNT(*) INTO open_shops_count
    FROM shops s
    INNER JOIN user_profiles up ON up.id = s.owner_id
    WHERE s.is_active = true
    AND up.user_type = 'talyer_owner'
    AND is_shop_open(s.business_hours, NOW()) = true;
    
    RAISE NOTICE 'Total Active Shops: %', nearby_shops_count;
    RAISE NOTICE 'Currently Open Shops: %', open_shops_count;
    RAISE NOTICE 'Closed Shops (Should be hidden): %', nearby_shops_count - open_shops_count;
    RAISE NOTICE '';
    
    IF nearby_shops_count = open_shops_count THEN
        RAISE NOTICE '⚠️  WARNING: All shops showing as OPEN';
        RAISE NOTICE 'This means the time filter might not be working!';
    ELSE
        RAISE NOTICE '✅ Time filter is working correctly';
    END IF;
END $$;

-- 9. CHECK FLUTTER APP RPC CALL
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE '📲 FLUTTER APP RPC CALL';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'The Flutter app calls:';
    RAISE NOTICE '  rpc(''get_nearby_shops'', params: {';
    RAISE NOTICE '    customer_lat: 14.9321,';
    RAISE NOTICE '    customer_lon: 120.8807,';
    RAISE NOTICE '    radius_km: 15.0';
    RAISE NOTICE '  })';
    RAISE NOTICE '';
    RAISE NOTICE '⚠️  If closed shops still show, check:';
    RAISE NOTICE '  1. Is Flutter app using latest RPC function?';
    RAISE NOTICE '  2. Is Flutter app caching old data?';
    RAISE NOTICE '  3. Are business_hours in correct format?';
END $$;
