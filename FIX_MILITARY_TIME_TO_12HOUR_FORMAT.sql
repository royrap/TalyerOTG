-- =====================================================
-- FIX: Convert Military Time to 12-Hour Format
-- =====================================================
-- This converts business hours from 24-hour (18:00) to 12-hour (6:00 PM)

-- =====================================================
-- OPTION 1: PostgreSQL Function to Convert Time Format
-- =====================================================

CREATE OR REPLACE FUNCTION format_time_12hour(military_time TEXT)
RETURNS TEXT AS $$
DECLARE
    hour INTEGER;
    minute TEXT;
    am_pm TEXT;
    formatted_hour TEXT;
BEGIN
    -- Handle null or invalid input
    IF military_time IS NULL OR military_time = 'closed' THEN
        RETURN 'Closed';
    END IF;
    
    -- Extract hour and minute
    hour := SPLIT_PART(military_time, ':', 1)::INTEGER;
    minute := SPLIT_PART(military_time, ':', 2);
    
    -- Determine AM/PM
    IF hour >= 12 THEN
        am_pm := 'PM';
        IF hour > 12 THEN
            hour := hour - 12;
        END IF;
    ELSE
        am_pm := 'AM';
        IF hour = 0 THEN
            hour := 12;
        END IF;
    END IF;
    
    formatted_hour := hour::TEXT;
    
    -- Return formatted time
    RETURN formatted_hour || ':' || minute || ' ' || am_pm;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- =====================================================
-- OPTION 2: Function to Get Formatted Business Hours
-- =====================================================

CREATE OR REPLACE FUNCTION get_formatted_business_hours(shop_business_hours JSONB)
RETURNS JSONB AS $$
DECLARE
    result JSONB := '{}'::JSONB;
    day_keys TEXT[] := ARRAY['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
    day_key TEXT;
    day_hours JSONB;
    open_time TEXT;
    close_time TEXT;
    formatted_open TEXT;
    formatted_close TEXT;
BEGIN
    FOREACH day_key IN ARRAY day_keys
    LOOP
        day_hours := shop_business_hours->day_key;
        
        IF day_hours IS NOT NULL THEN
            open_time := day_hours->>'open';
            close_time := day_hours->>'close';
            
            -- Format times
            formatted_open := format_time_12hour(open_time);
            formatted_close := format_time_12hour(close_time);
            
            -- Add to result
            result := result || jsonb_build_object(
                day_key, 
                jsonb_build_object(
                    'open', formatted_open,
                    'close', formatted_close,
                    'raw_open', open_time,
                    'raw_close', close_time
                )
            );
        ELSE
            result := result || jsonb_build_object(
                day_key,
                jsonb_build_object('open', 'Closed', 'close', 'Closed')
            );
        END IF;
    END LOOP;
    
    RETURN result;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- =====================================================
-- OPTION 3: Update get_nearby_shops to Return Formatted Hours
-- =====================================================

CREATE OR REPLACE FUNCTION get_nearby_shops_with_formatted_hours(
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
    is_open BOOLEAN,
    business_hours JSONB,
    formatted_hours JSONB
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
        -- FIX: Cast to NUMERIC before ROUND
        ROUND(
            (ST_Distance(
                ST_SetSRID(ST_MakePoint(customer_lon, customer_lat), 4326)::geography,
                ST_SetSRID(ST_MakePoint(s.longitude, s.latitude), 4326)::geography
            ) / 1000.0)::NUMERIC, 2
        ) as distance_km,
        is_shop_open(s.business_hours, NOW()) as is_open,
        s.business_hours,
        get_formatted_business_hours(s.business_hours) as formatted_hours
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
        AND is_shop_open(s.business_hours, NOW()) = true
    ORDER BY distance_km ASC;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- TEST THE CONVERSION
-- =====================================================

DO $$
DECLARE
    test_hours JSONB;
    formatted JSONB;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE '🧪 TESTING TIME FORMAT CONVERSION';
    RAISE NOTICE '========================================';
    
    -- Test military time conversion
    RAISE NOTICE '';
    RAISE NOTICE '24-Hour Format → 12-Hour Format:';
    RAISE NOTICE '  08:00 → %', format_time_12hour('08:00');
    RAISE NOTICE '  12:00 → %', format_time_12hour('12:00');
    RAISE NOTICE '  13:00 → %', format_time_12hour('13:00');
    RAISE NOTICE '  18:00 → %', format_time_12hour('18:00');
    RAISE NOTICE '  22:00 → %', format_time_12hour('22:00');
    RAISE NOTICE '  closed → %', format_time_12hour('closed');
    
    -- Test full business hours conversion
    RAISE NOTICE '';
    RAISE NOTICE 'Full Business Hours Conversion:';
    test_hours := '{
        "monday": {"open": "08:00", "close": "18:00"},
        "tuesday": {"open": "08:00", "close": "18:00"},
        "wednesday": {"open": "08:00", "close": "18:00"},
        "thursday": {"open": "08:00", "close": "18:00"},
        "friday": {"open": "08:00", "close": "18:00"},
        "saturday": {"open": "09:00", "close": "17:00"},
        "sunday": {"open": null, "close": null}
    }'::JSONB;
    
    formatted := get_formatted_business_hours(test_hours);
    
    RAISE NOTICE 'Original: %', test_hours;
    RAISE NOTICE '';
    RAISE NOTICE 'Formatted: %', formatted;
END $$;

-- =====================================================
-- GRANT PERMISSIONS
-- =====================================================

GRANT EXECUTE ON FUNCTION format_time_12hour(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION format_time_12hour(TEXT) TO anon;

GRANT EXECUTE ON FUNCTION get_formatted_business_hours(JSONB) TO authenticated;
GRANT EXECUTE ON FUNCTION get_formatted_business_hours(JSONB) TO anon;

GRANT EXECUTE ON FUNCTION get_nearby_shops_with_formatted_hours(NUMERIC, NUMERIC, NUMERIC) TO authenticated;
GRANT EXECUTE ON FUNCTION get_nearby_shops_with_formatted_hours(NUMERIC, NUMERIC, NUMERIC) TO anon;

-- =====================================================
-- USAGE EXAMPLES
-- =====================================================

-- Example 1: Convert single time
-- SELECT format_time_12hour('18:00'); -- Returns: '6:00 PM'

-- Example 2: Get formatted business hours for a shop
-- SELECT 
--     shop_name,
--     get_formatted_business_hours(business_hours) as formatted_hours
-- FROM shops
-- WHERE id = 'your-shop-id';

-- Example 3: Use new function in Flutter app
-- final response = await SupabaseService.client
--     .rpc('get_nearby_shops_with_formatted_hours', params: {
--       'customer_lat': currentLocation.latitude,
--       'customer_lon': currentLocation.longitude,
--       'radius_km': 15.0,
--     });
-- 
-- // Access formatted hours
-- final formattedHours = response[0]['formatted_hours'];
-- final mondayOpen = formattedHours['monday']['open']; // "8:00 AM"
-- final mondayClose = formattedHours['monday']['close']; // "6:00 PM"

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ TIME FORMAT CONVERSION COMPLETE!';
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
    RAISE NOTICE 'Created Functions:';
    RAISE NOTICE '  1. format_time_12hour(TEXT)';
    RAISE NOTICE '     - Converts "18:00" → "6:00 PM"';
    RAISE NOTICE '';
    RAISE NOTICE '  2. get_formatted_business_hours(JSONB)';
    RAISE NOTICE '     - Converts all hours in business_hours JSONB';
    RAISE NOTICE '';
    RAISE NOTICE '  3. get_nearby_shops_with_formatted_hours()';
    RAISE NOTICE '     - Returns shops with formatted hours';
    RAISE NOTICE '';
    RAISE NOTICE 'Next Steps:';
    RAISE NOTICE '  1. Test with: SELECT format_time_12hour(''18:00'')';
    RAISE NOTICE '  2. Update Flutter app to use new RPC';
    RAISE NOTICE '  3. Display formatted_hours in UI';
END $$;
