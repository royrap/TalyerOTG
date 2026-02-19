-- ====================================================================
-- FIX NUMERIC OVERFLOW AND FOREIGN KEY RELATIONSHIP ERRORS
-- ====================================================================
-- This fixes:
-- 1. PostgrestException(message: input is out of range, code: 22003)
--    Caused by: Haversine formula acos() receiving values outside [-1, 1]
-- 2. Foreign key relationship error between shop_mechanics and mechanic_availability_status
-- ====================================================================

-- DROP THE OLD VERSION FIRST
DROP FUNCTION IF EXISTS get_nearby_requests_for_mechanic(UUID, NUMERIC, NUMERIC, NUMERIC);

-- CREATE FIXED VERSION with safe Haversine calculation
CREATE OR REPLACE FUNCTION get_nearby_requests_for_mechanic(
    p_mechanic_id UUID,
    p_mechanic_lat NUMERIC,
    p_mechanic_lng NUMERIC,
    p_max_distance_km NUMERIC DEFAULT 50.0
)
RETURNS TABLE (
    request_id UUID,
    customer_id UUID,
    title VARCHAR,
    description TEXT,
    pickup_latitude NUMERIC,
    pickup_longitude NUMERIC,
    pickup_address TEXT,
    service_type VARCHAR,
    priority VARCHAR,
    status VARCHAR,
    created_at TIMESTAMPTZ,
    estimated_price NUMERIC,
    request_type TEXT,
    distance_km NUMERIC,
    estimated_arrival_minutes INTEGER,
    urgency_level TEXT,
    customer_first_name VARCHAR,
    customer_last_name VARCHAR,
    customer_phone VARCHAR,
    customer_profile_image TEXT,
    is_eligible BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    WITH distance_calc AS (
        SELECT 
            sr.id,
            sr.customer_id,
            sr.title,
            sr.description,
            sr.pickup_latitude,
            sr.pickup_longitude,
            sr.pickup_address,
            sr.service_type,
            sr.priority,
            sr.status,
            sr.created_at,
            sr.estimated_price,
            sr.request_type,
            sr.preferred_shop_id,
            sr.can_accept_by_any_mechanic,
            up.first_name as customer_first_name,
            up.last_name as customer_last_name,
            up.phone_number as customer_phone,
            up.profile_image_url as customer_profile_image,
            -- SAFE Haversine formula with LEAST/GREATEST to prevent acos domain errors
            -- This prevents "input is out of range" error (code 22003)
            (
                6371 * acos(
                    LEAST(1.0, GREATEST(-1.0,
                        cos(radians(p_mechanic_lat)) * 
                        cos(radians(sr.pickup_latitude)) * 
                        cos(radians(sr.pickup_longitude) - radians(p_mechanic_lng)) + 
                        sin(radians(p_mechanic_lat)) * 
                        sin(radians(sr.pickup_latitude))
                    ))
                )
            ) AS distance_km,
            -- Calculate urgency based on how long the request has been pending
            CASE 
                WHEN EXTRACT(HOUR FROM (NOW() - sr.created_at)) >= 2 THEN 'high'
                WHEN EXTRACT(HOUR FROM (NOW() - sr.created_at)) >= 1 THEN 'medium'
                ELSE 'normal'
            END AS urgency_level
        FROM service_requests sr
        INNER JOIN user_profiles up ON sr.customer_id = up.id
        WHERE 
            sr.status IN ('pending', 'awaiting_payment', 'ready_to_assign')
            AND sr.pickup_latitude IS NOT NULL 
            AND sr.pickup_longitude IS NOT NULL
            AND sr.assigned_mechanic_id IS NULL
            AND sr.accepted_by IS NULL
    ),
    filtered_requests AS (
        SELECT 
            dc.*,
            -- Estimate arrival time based on distance (assume 30 km/h average speed + 5 minutes prep)
            ROUND((dc.distance_km / 30.0 * 60) + 5)::INTEGER AS estimated_arrival_minutes,
            -- Check eligibility based on request type and mechanic association
            CASE 
                -- For broadcast/direct mechanic requests
                WHEN dc.request_type IN ('broadcast', 'direct_mechanic') AND dc.can_accept_by_any_mechanic = true THEN
                    EXISTS (
                        SELECT 1 FROM mechanic_availability_status mas
                        WHERE mas.mechanic_id = p_mechanic_id
                        AND mas.current_status = 'available'
                        AND mas.is_accepting_requests = true
                    )
                -- For shop-based requests - FIXED: Use separate subqueries instead of JOIN
                -- This fixes the "Could not find a relationship between shop_mechanics and mechanic_availability_status" error
                WHEN dc.request_type = 'shop_based' AND dc.preferred_shop_id IS NOT NULL THEN
                    (
                        -- Check if mechanic works at the shop
                        EXISTS (
                            SELECT 1 FROM shop_mechanics sm
                            WHERE sm.mechanic_id = p_mechanic_id
                            AND sm.shop_id = dc.preferred_shop_id
                            AND sm.is_active = true
                        )
                        AND
                        -- Check if mechanic is available (separate query - no FK relationship)
                        EXISTS (
                            SELECT 1 FROM mechanic_availability_status mas
                            WHERE mas.mechanic_id = p_mechanic_id
                            AND mas.current_status = 'available'
                            AND mas.is_accepting_requests = true
                        )
                    )
                ELSE false
            END AS is_eligible
        FROM distance_calc dc
        WHERE dc.distance_km <= p_max_distance_km
    )
    SELECT 
        fr.id::UUID as request_id,
        fr.customer_id::UUID,
        fr.title::VARCHAR,
        fr.description::TEXT,
        fr.pickup_latitude::NUMERIC,
        fr.pickup_longitude::NUMERIC,
        fr.pickup_address::TEXT,
        fr.service_type::VARCHAR,
        fr.priority::VARCHAR,
        fr.status::VARCHAR,
        fr.created_at::TIMESTAMPTZ,
        fr.estimated_price::NUMERIC,
        fr.request_type::TEXT,
        fr.distance_km::NUMERIC,
        fr.estimated_arrival_minutes::INTEGER,
        fr.urgency_level::TEXT,
        fr.customer_first_name::VARCHAR,
        fr.customer_last_name::VARCHAR,
        fr.customer_phone::VARCHAR,
        fr.customer_profile_image::TEXT,
        fr.is_eligible::BOOLEAN
    FROM filtered_requests fr
    WHERE fr.is_eligible = true
    ORDER BY 
        -- Sort by urgency first, then by distance
        CASE fr.urgency_level 
            WHEN 'high' THEN 1
            WHEN 'medium' THEN 2
            ELSE 3
        END,
        fr.distance_km ASC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION get_nearby_requests_for_mechanic(UUID, NUMERIC, NUMERIC, NUMERIC) TO authenticated;

-- ====================================================================
-- VERIFICATION QUERIES
-- ====================================================================

-- Verify the function was created successfully
SELECT 
    proname as function_name,
    'Function created successfully!' as status
FROM pg_proc 
WHERE proname = 'get_nearby_requests_for_mechanic';

-- ====================================================================
-- TEST QUERY (OPTIONAL - Comment out if you want to skip testing)
-- ====================================================================
/*
-- Uncomment and replace YOUR_MECHANIC_ID to test:

SELECT * FROM get_nearby_requests_for_mechanic(
    'YOUR_MECHANIC_ID'::UUID,  -- Replace with actual mechanic ID from user_profiles
    14.5995::NUMERIC,           -- Manila latitude
    120.9842::NUMERIC,          -- Manila longitude
    50.0::NUMERIC               -- 50km radius
);

-- To get a real mechanic ID, run this first:
SELECT id, email, first_name, last_name 
FROM user_profiles 
WHERE user_type = 'mechanic' 
LIMIT 1;
*/

-- ====================================================================
-- DEPLOYMENT NOTES
-- ====================================================================
/*
WHAT WAS FIXED:

1. ✅ NUMERIC OVERFLOW FIX (Error code 22003):
   - Added LEAST(1.0, GREATEST(-1.0, ...)) wrapper around acos() argument
   - Prevents acos() from receiving values outside valid domain [-1, 1]
   - This was caused by floating-point precision errors in Haversine formula

2. ✅ FOREIGN KEY RELATIONSHIP FIX (PGRST200):
   - Removed INNER JOIN between shop_mechanics and mechanic_availability_status
   - Used separate EXISTS subqueries instead
   - No FK relationship exists between these tables (both reference mechanics differently)
   - shop_mechanics.mechanic_id -> user_profiles.id
   - mechanic_availability_status.mechanic_id -> user_profiles.id
   - There's NO direct FK from shop_mechanics to mechanic_availability_status

3. ✅ IMPACT:
   - Mechanics will now see nearby location-based requests without errors
   - Shop-based request eligibility checks will work correctly
   - No more "input is out of range" errors during distance calculations
   - No more "Could not find a relationship" PostgREST errors

TO DEPLOY:
1. Run this entire SQL file in your Supabase SQL Editor
2. Restart your Flutter app: flutter run
3. Test with a mechanic account by logging in
4. Verify no errors in terminal logs
5. Check that location-based requests appear correctly

TESTING:
- Create a new service request as customer
- Login as mechanic
- Check "Nearby Requests" tab
- Should see requests within 50km without any PostgreSQL errors
*/
