-- =====================================================
-- FIX: UPDATE LOCATION FUNCTION TO USE SHOP_ID
-- =====================================================
-- The get_nearby_requests_for_mechanic function is checking preferred_shop_id
-- but we fixed the code to use shop_id. This is why mechanics can't see shop requests!

-- STEP 1: Drop the old function first
DROP FUNCTION IF EXISTS get_nearby_requests_for_mechanic(UUID, NUMERIC, NUMERIC, NUMERIC);

-- STEP 2: Create the corrected function
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
            sr.shop_id,  -- ✅ CHANGED: Use shop_id instead of preferred_shop_id
            sr.can_accept_by_any_mechanic,
            up.first_name as customer_first_name,
            up.last_name as customer_last_name,
            up.phone_number as customer_phone,
            up.profile_image_url as customer_profile_image,
            -- Calculate distance using Haversine formula
            (
                6371 * acos(
                    cos(radians(p_mechanic_lat)) * 
                    cos(radians(sr.pickup_latitude)) * 
                    cos(radians(sr.pickup_longitude) - radians(p_mechanic_lng)) + 
                    sin(radians(p_mechanic_lat)) * 
                    sin(radians(sr.pickup_latitude))
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
                -- For shop-based requests
                WHEN dc.request_type = 'shop_based' AND dc.shop_id IS NOT NULL THEN  -- ✅ CHANGED: Use shop_id
                    EXISTS (
                        SELECT 1 FROM shop_mechanics sm
                        INNER JOIN mechanic_availability_status mas ON sm.mechanic_id = mas.mechanic_id
                        WHERE sm.mechanic_id = p_mechanic_id
                        AND sm.shop_id = dc.shop_id  -- ✅ CHANGED: Use shop_id
                        AND sm.is_active = true
                        AND mas.current_status = 'available'
                        AND mas.is_accepting_requests = true
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
$$ LANGUAGE plpgsql STABLE;

-- Grant execution permissions
GRANT EXECUTE ON FUNCTION get_nearby_requests_for_mechanic(UUID, NUMERIC, NUMERIC, NUMERIC) TO authenticated;

-- =====================================================
-- TEST THE FIX
-- =====================================================

-- Test with mechanic IDs to verify shop-based filtering
SELECT 
    request_id,
    title,
    request_type,
    distance_km,
    is_eligible
FROM get_nearby_requests_for_mechanic(
    'e4cbf14b-5729-45ef-a124-1f2e05acad8c'::uuid,  -- Yuji mechanic
    14.9321542,
    120.8807335,
    50.0
);

-- Expected: Should now see shop-based requests for shops the mechanic belongs to!

-- =====================================================
-- VERIFICATION QUERIES
-- =====================================================

-- Check mechanic's shop assignment
SELECT 
    m.mechanic_id, 
    m.shop_id, 
    s.shop_name,
    m.is_active
FROM shop_mechanics m
JOIN shops s ON m.shop_id = s.id
WHERE m.mechanic_id = 'e4cbf14b-5729-45ef-a124-1f2e05acad8c'
AND m.is_active = true;

-- Check pending shop-based requests
SELECT 
    id,
    title,
    request_type,
    shop_id,
    status
FROM service_requests
WHERE status = 'pending'
AND request_type = 'shop_based'
AND shop_id IS NOT NULL;

-- =====================================================
-- SUCCESS INDICATORS
-- =====================================================
-- ✅ Function drops and recreates successfully
-- ✅ Test query returns shop-based requests for assigned mechanics
-- ✅ Mechanics NOT assigned to a shop don't see shop-based requests
-- ✅ Broadcast/direct requests still work for all mechanics
-- =====================================================
