-- =====================================================
-- HIDE CLOSED SHOPS FROM CUSTOMERS
-- =====================================================
-- This ensures customers can only see shops that are currently open
-- based on their business hours settings

-- =====================================================
-- 1. CREATE FUNCTION TO CHECK IF SHOP IS OPEN
-- =====================================================

CREATE OR REPLACE FUNCTION is_shop_open(
    shop_business_hours JSONB,
    check_time TIMESTAMPTZ DEFAULT NOW()
)
RETURNS BOOLEAN AS $$
DECLARE
    day_of_week TEXT;
    time_of_day TIME;
    day_hours JSONB;
    open_time TEXT;
    close_time TEXT;
BEGIN
    -- Get current day of week (lowercase)
    day_of_week := LOWER(TO_CHAR(check_time, 'Day'));
    day_of_week := TRIM(day_of_week); -- Remove trailing spaces
    
    -- Get current time
    time_of_day := check_time::TIME;
    
    -- Return false if business_hours is null
    IF shop_business_hours IS NULL THEN
        RETURN FALSE;
    END IF;
    
    -- Get hours for current day
    day_hours := shop_business_hours->day_of_week;
    
    -- Return false if no hours defined for this day
    IF day_hours IS NULL THEN
        RETURN FALSE;
    END IF;
    
    -- Extract open and close times
    open_time := day_hours->>'open';
    close_time := day_hours->>'close';
    
    -- Return false if either time is null or shop is marked as closed
    IF open_time IS NULL OR close_time IS NULL THEN
        RETURN FALSE;
    END IF;
    
    -- Return false if explicitly marked as closed
    IF open_time = 'closed' OR close_time = 'closed' THEN
        RETURN FALSE;
    END IF;
    
    -- Check if current time is within business hours
    RETURN time_of_day >= open_time::TIME 
       AND time_of_day <= close_time::TIME;
       
EXCEPTION
    WHEN OTHERS THEN
        -- If any error occurs, consider shop closed for safety
        RETURN FALSE;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- =====================================================
-- 2. UPDATE get_nearby_shops FUNCTION
-- =====================================================

-- Drop existing function first (if it exists with different return type)
DROP FUNCTION IF EXISTS get_nearby_shops(NUMERIC, NUMERIC, NUMERIC);

CREATE OR REPLACE FUNCTION get_nearby_shops(
    customer_lat NUMERIC,
    customer_lon NUMERIC,
    radius_km NUMERIC DEFAULT 15.0
)
RETURNS TABLE (
    shop_id UUID,
    shop_name VARCHAR,
    shop_address TEXT,
    shop_latitude NUMERIC,
    shop_longitude NUMERIC,
    owner_name TEXT,
    owner_phone VARCHAR,
    is_available BOOLEAN,
    distance_km NUMERIC,
    is_open BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        s.id,
        s.shop_name,
        s.shop_address,
        s.latitude,
        s.longitude,
        CONCAT(up.first_name, ' ', up.last_name) as owner_name,
        up.phone_number,
        COALESCE(up.is_available, false) as is_available,
        ROUND(
            ST_Distance(
                ST_SetSRID(ST_MakePoint(customer_lon, customer_lat), 4326)::geography,
                ST_SetSRID(ST_MakePoint(s.longitude, s.latitude), 4326)::geography
            ) / 1000.0, 2
        ) as distance_km,
        is_shop_open(s.business_hours, NOW()) as is_open
    FROM shops s
    INNER JOIN user_profiles up ON up.id = s.owner_id
    WHERE 
        s.is_active = true
        AND up.user_type = 'talyer_owner'
        AND s.latitude IS NOT NULL
        AND s.longitude IS NOT NULL
        AND ST_DWithin(
            ST_SetSRID(ST_MakePoint(customer_lon, customer_lat), 4326)::geography,
            ST_SetSRID(ST_MakePoint(s.longitude, s.latitude), 4326)::geography,
            radius_km * 1000
        )
        -- IMPORTANT: Only show shops that are currently open
        AND is_shop_open(s.business_hours, NOW()) = true
    ORDER BY distance_km ASC;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 3. CREATE VIEW FOR OPEN SHOPS
-- =====================================================

CREATE OR REPLACE VIEW open_shops_view AS
SELECT 
    s.id,
    s.shop_name,
    s.shop_address,
    s.latitude,
    s.longitude,
    s.owner_id,
    s.business_hours,
    s.is_active,
    s.created_at,
    s.updated_at,
    is_shop_open(s.business_hours, NOW()) as is_currently_open,
    CONCAT(up.first_name, ' ', up.last_name) as owner_name,
    up.phone_number as owner_phone,
    up.is_available as owner_available
FROM shops s
INNER JOIN user_profiles up ON up.id = s.owner_id
WHERE 
    s.is_active = true
    AND up.user_type = 'talyer_owner'
    AND is_shop_open(s.business_hours, NOW()) = true;

-- =====================================================
-- 4. TEST THE FUNCTION
-- =====================================================

-- Test with sample business hours
DO $$
DECLARE
    test_hours JSONB;
    is_open BOOLEAN;
    day_of_week TEXT;
    time_of_day TIME;
BEGIN
    -- Get current day and time
    day_of_week := LOWER(TRIM(TO_CHAR(NOW(), 'Day')));
    time_of_day := NOW()::TIME;
    
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE '🧪 TESTING SHOP OPEN/CLOSED LOGIC';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Current Day: %', day_of_week;
    RAISE NOTICE 'Current Time: %', time_of_day;
    RAISE NOTICE '';
    
    -- Test Case 1: Shop is open (8am-6pm)
    test_hours := '{"monday": {"open": "08:00", "close": "18:00"}}'::JSONB;
    is_open := is_shop_open(test_hours, NOW());
    RAISE NOTICE 'Test 1 - Regular Hours (8am-6pm): %', 
        CASE WHEN is_open THEN '✅ OPEN' ELSE '❌ CLOSED' END;
    
    -- Test Case 2: Shop is closed (null hours)
    test_hours := '{"monday": {"open": null, "close": null}}'::JSONB;
    is_open := is_shop_open(test_hours, NOW());
    RAISE NOTICE 'Test 2 - Null Hours: %', 
        CASE WHEN is_open THEN '✅ OPEN' ELSE '❌ CLOSED (Expected)' END;
    
    -- Test Case 3: Shop explicitly closed
    test_hours := '{"monday": {"open": "closed", "close": "closed"}}'::JSONB;
    is_open := is_shop_open(test_hours, NOW());
    RAISE NOTICE 'Test 3 - Explicitly Closed: %', 
        CASE WHEN is_open THEN '✅ OPEN' ELSE '❌ CLOSED (Expected)' END;
    
    -- Test Case 4: 24/7 shop
    test_hours := '{"monday": {"open": "00:00", "close": "23:59"}}'::JSONB;
    is_open := is_shop_open(test_hours, NOW());
    RAISE NOTICE 'Test 4 - 24/7 Hours: %', 
        CASE WHEN is_open THEN '✅ OPEN (Expected)' ELSE '❌ CLOSED' END;
    
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
END $$;

-- =====================================================
-- 5. CHECK ACTUAL SHOPS STATUS
-- =====================================================

-- Show all shops with their current open/closed status
SELECT 
    s.id,
    s.shop_name,
    CONCAT(up.first_name, ' ', up.last_name) as owner_name,
    TO_CHAR(NOW(), 'Day') as current_day,
    NOW()::TIME as current_time,
    s.business_hours->LOWER(TRIM(TO_CHAR(NOW(), 'Day'))) as today_hours,
    is_shop_open(s.business_hours, NOW()) as is_currently_open,
    s.is_active as shop_is_active
FROM shops s
INNER JOIN user_profiles up ON up.id = s.owner_id
WHERE up.user_type = 'talyer_owner'
ORDER BY s.shop_name;

-- =====================================================
-- 6. COUNT OPEN VS CLOSED SHOPS
-- =====================================================

SELECT 
    COUNT(*) as total_shops,
    COUNT(*) FILTER (WHERE is_shop_open(business_hours, NOW())) as currently_open,
    COUNT(*) FILTER (WHERE NOT is_shop_open(business_hours, NOW())) as currently_closed,
    COUNT(*) FILTER (WHERE is_active = true) as active_shops,
    COUNT(*) FILTER (WHERE is_active = false) as inactive_shops
FROM shops s
INNER JOIN user_profiles up ON up.id = s.owner_id
WHERE up.user_type = 'talyer_owner';

-- =====================================================
-- 7. GRANT PERMISSIONS
-- =====================================================

-- Grant execute permission on the function
GRANT EXECUTE ON FUNCTION is_shop_open(JSONB, TIMESTAMPTZ) TO authenticated;
GRANT EXECUTE ON FUNCTION is_shop_open(JSONB, TIMESTAMPTZ) TO anon;

GRANT EXECUTE ON FUNCTION get_nearby_shops(NUMERIC, NUMERIC, NUMERIC) TO authenticated;
GRANT EXECUTE ON FUNCTION get_nearby_shops(NUMERIC, NUMERIC, NUMERIC) TO anon;

-- Grant select on the view
GRANT SELECT ON open_shops_view TO authenticated;

-- =====================================================
-- 8. SUCCESS CONFIRMATION
-- =====================================================

DO $$ 
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ HIDE CLOSED SHOPS - SETUP COMPLETE!';
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
    RAISE NOTICE 'What was implemented:';
    RAISE NOTICE '  ✅ is_shop_open() function - Checks if shop is open';
    RAISE NOTICE '  ✅ Updated get_nearby_shops() - Filters closed shops';
    RAISE NOTICE '  ✅ open_shops_view - View of currently open shops';
    RAISE NOTICE '  ✅ Permissions granted to authenticated users';
    RAISE NOTICE '';
    RAISE NOTICE 'How it works:';
    RAISE NOTICE '  1. Checks current day of week';
    RAISE NOTICE '  2. Checks current time';
    RAISE NOTICE '  3. Compares against business_hours JSONB';
    RAISE NOTICE '  4. Returns true only if shop is open NOW';
    RAISE NOTICE '';
    RAISE NOTICE 'Customer experience:';
    RAISE NOTICE '  ✅ Only see shops that are currently open';
    RAISE NOTICE '  ✅ Closed shops are hidden automatically';
    RAISE NOTICE '  ✅ Updates in real-time based on business hours';
    RAISE NOTICE '';
    RAISE NOTICE 'Next steps:';
    RAISE NOTICE '  1. Update Flutter app to use new get_nearby_shops()';
    RAISE NOTICE '  2. Test with different times of day';
    RAISE NOTICE '  3. Verify shop owners can update business hours';
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
END $$;

-- =====================================================
-- 9. EXAMPLE QUERIES FOR TESTING
-- =====================================================

-- Test get_nearby_shops with your location
-- EXAMPLE: Replace with actual coordinates
-- SELECT * FROM get_nearby_shops(14.9321, 120.8807, 15.0);

-- Check which shops are open right now
-- SELECT * FROM open_shops_view;

-- Manual check for a specific shop
-- SELECT 
--     shop_name,
--     business_hours,
--     is_shop_open(business_hours, NOW()) as is_open_now
-- FROM shops 
-- WHERE id = 'your-shop-id';
