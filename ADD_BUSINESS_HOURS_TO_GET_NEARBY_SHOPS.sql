-- =====================================================
-- ADD BUSINESS_HOURS TO get_nearby_shops FUNCTION
-- =====================================================
-- This updates the get_nearby_shops function to return
-- the business_hours JSONB field so the Flutter app
-- can display opening/closing times.
-- =====================================================

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
    is_open BOOLEAN,
    business_hours JSONB  -- ✅ ADDED: Return business hours
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
        is_shop_open(s.business_hours, NOW()) as is_open,
        s.business_hours  -- ✅ ADDED: Return business hours JSONB
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
        -- ✅ REMOVED: Database filter for open/closed
        -- Filtering now handled by Flutter app (_isShopCurrentlyOpen)
    ORDER BY distance_km ASC;
END;
$$ LANGUAGE plpgsql;

-- Grant permissions
GRANT EXECUTE ON FUNCTION get_nearby_shops(NUMERIC, NUMERIC, NUMERIC) TO authenticated;
GRANT EXECUTE ON FUNCTION get_nearby_shops(NUMERIC, NUMERIC, NUMERIC) TO anon;

-- =====================================================
-- VERIFICATION
-- =====================================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ UPDATED get_nearby_shops FUNCTION';
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
    RAISE NOTICE 'Changes:';
    RAISE NOTICE '  ✅ Added business_hours JSONB to return columns';
    RAISE NOTICE '  ✅ Function returns ALL shops (open and closed)';
    RAISE NOTICE '  ✅ Flutter app filters closed shops using _isShopCurrentlyOpen()';
    RAISE NOTICE '';
    RAISE NOTICE 'Filtering Strategy:';
    RAISE NOTICE '  • Database: Returns all shops with business_hours';
    RAISE NOTICE '  • Flutter: Filters out closed shops before display';
    RAISE NOTICE '  • Result: Only open shops visible to customer';
    RAISE NOTICE '';
    RAISE NOTICE 'Test query (returns ALL shops):';
    RAISE NOTICE '  SELECT * FROM get_nearby_shops(14.9321, 120.8807, 15.0);';
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
END $$;
