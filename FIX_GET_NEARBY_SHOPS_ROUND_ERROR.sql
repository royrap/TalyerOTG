-- =====================================================
-- FIX: ROUND() Function Error in get_nearby_shops
-- =====================================================
-- Error: function round(double precision, integer) does not exist
-- Solution: Cast ST_Distance result to NUMERIC before ROUND

-- Drop the existing function first
DROP FUNCTION IF EXISTS get_nearby_shops(NUMERIC, NUMERIC, NUMERIC);

-- Recreate with fixed ROUND() - cast to NUMERIC
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
        -- FIX: Cast to NUMERIC before ROUND
        ROUND(
            (ST_Distance(
                ST_SetSRID(ST_MakePoint(customer_lon, customer_lat), 4326)::geography,
                ST_SetSRID(ST_MakePoint(s.longitude, s.latitude), 4326)::geography
            ) / 1000.0)::NUMERIC, 2
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

-- Grant permissions
GRANT EXECUTE ON FUNCTION get_nearby_shops(NUMERIC, NUMERIC, NUMERIC) TO authenticated;
GRANT EXECUTE ON FUNCTION get_nearby_shops(NUMERIC, NUMERIC, NUMERIC) TO anon;

-- Test the fixed function
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ FIXED get_nearby_shops FUNCTION';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Fixed ROUND() error by casting to NUMERIC';
    RAISE NOTICE 'Test with: SELECT * FROM get_nearby_shops(14.9321, 120.8807, 15.0);';
    RAISE NOTICE '';
END $$;
