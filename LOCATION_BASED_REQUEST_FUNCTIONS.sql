-- Function to get nearby service requests for a mechanic based on pickup location
-- This function calculates distance using the Haversine formula and filters by eligibility

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
                WHEN dc.request_type = 'shop_based' AND dc.preferred_shop_id IS NOT NULL THEN
                    EXISTS (
                        SELECT 1 FROM shop_mechanics sm
                        INNER JOIN mechanic_availability_status mas ON sm.mechanic_id = mas.mechanic_id
                        WHERE sm.mechanic_id = p_mechanic_id
                        AND sm.shop_id = dc.preferred_shop_id
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
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION get_nearby_requests_for_mechanic(UUID, NUMERIC, NUMERIC, NUMERIC) TO authenticated;

-- Function to accept a nearby request with location validation
CREATE OR REPLACE FUNCTION accept_nearby_request(
    p_mechanic_id UUID,
    p_request_id UUID,
    p_mechanic_lat NUMERIC,
    p_mechanic_lng NUMERIC
)
RETURNS TABLE (
    success BOOLEAN,
    message TEXT,
    distance_km NUMERIC
) AS $$
DECLARE
    v_request_record RECORD;
    v_calculated_distance NUMERIC;
    v_is_eligible BOOLEAN;
    v_arrival_minutes INTEGER;
BEGIN
    -- Get request details
    SELECT sr.*, 
           sr.pickup_latitude, 
           sr.pickup_longitude,
           sr.status,
           sr.request_type,
           sr.preferred_shop_id,
           sr.can_accept_by_any_mechanic,
           sr.assigned_mechanic_id,
           sr.accepted_by
    INTO v_request_record
    FROM service_requests sr
    WHERE sr.id = p_request_id;
    
    -- Check if request exists
    IF NOT FOUND THEN
        RETURN QUERY SELECT false, 'Request not found'::TEXT, 0::NUMERIC;
        RETURN;
    END IF;
    
    -- Check if request is still available
    IF v_request_record.status != 'pending' OR 
       v_request_record.assigned_mechanic_id IS NOT NULL OR 
       v_request_record.accepted_by IS NOT NULL THEN
        RETURN QUERY SELECT false, 'Request is no longer available'::TEXT, 0::NUMERIC;
        RETURN;
    END IF;
    
    -- Calculate distance to pickup location
    v_calculated_distance := (
        6371 * acos(
            cos(radians(p_mechanic_lat)) * 
            cos(radians(v_request_record.pickup_latitude)) * 
            cos(radians(v_request_record.pickup_longitude) - radians(p_mechanic_lng)) + 
            sin(radians(p_mechanic_lat)) * 
            sin(radians(v_request_record.pickup_latitude))
        )
    );
    
    -- Check eligibility based on request type
    IF v_request_record.request_type IN ('broadcast', 'direct_mechanic') AND v_request_record.can_accept_by_any_mechanic = true THEN
        -- Check if mechanic is available for general requests
        SELECT EXISTS (
            SELECT 1 FROM mechanic_availability_status mas
            WHERE mas.mechanic_id = p_mechanic_id
            AND mas.current_status = 'available'
            AND mas.is_accepting_requests = true
        ) INTO v_is_eligible;
    ELSIF v_request_record.request_type = 'shop_based' AND v_request_record.preferred_shop_id IS NOT NULL THEN
        -- Check if mechanic works at the preferred shop
        SELECT EXISTS (
            SELECT 1 FROM shop_mechanics sm
            INNER JOIN mechanic_availability_status mas ON sm.mechanic_id = mas.mechanic_id
            WHERE sm.mechanic_id = p_mechanic_id
            AND sm.shop_id = v_request_record.preferred_shop_id
            AND sm.is_active = true
            AND mas.current_status = 'available'
            AND mas.is_accepting_requests = true
        ) INTO v_is_eligible;
    ELSE
        v_is_eligible := false;
    END IF;
    
    -- Check eligibility
    IF NOT v_is_eligible THEN
        RETURN QUERY SELECT false, 'Mechanic not eligible for this request'::TEXT, v_calculated_distance;
        RETURN;
    END IF;
    
    -- Calculate estimated arrival time
    v_arrival_minutes := ROUND((v_calculated_distance / 30.0 * 60) + 5)::INTEGER;
    
    -- Accept the request
    UPDATE service_requests 
    SET 
        status = 'accepted',
        accepted_by = p_mechanic_id,
        assigned_mechanic_id = p_mechanic_id,
        accepted_at = NOW(),
        distance_to_customer = v_calculated_distance,
        estimated_arrival_minutes = v_arrival_minutes
    WHERE id = p_request_id;
    
    -- Update mechanic availability
    UPDATE mechanic_availability_status 
    SET 
        current_status = 'on_job',
        is_accepting_requests = false,
        last_active_at = NOW()
    WHERE mechanic_id = p_mechanic_id;
    
    -- Log the acceptance in request status history
    INSERT INTO request_status_history (
        request_id,
        status,
        notes,
        changed_by,
        created_at
    ) VALUES (
        p_request_id,
        'accepted',
        FORMAT('Request accepted by mechanic. Distance: %s km, ETA: %s minutes', 
               ROUND(v_calculated_distance, 1), v_arrival_minutes),
        p_mechanic_id,
        NOW()
    );
    
    RETURN QUERY SELECT true, 'Request accepted successfully'::TEXT, v_calculated_distance;
    
EXCEPTION WHEN OTHERS THEN
    -- Rollback any changes and return error
    RETURN QUERY SELECT false, SQLERRM::TEXT, 0::NUMERIC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION accept_nearby_request(UUID, UUID, NUMERIC, NUMERIC) TO authenticated;

-- Create index for better performance on location-based queries
CREATE INDEX IF NOT EXISTS idx_service_requests_location_status 
ON service_requests(pickup_latitude, pickup_longitude, status) 
WHERE status IN ('pending', 'awaiting_payment', 'ready_to_assign');

-- Create index for request eligibility checks
CREATE INDEX IF NOT EXISTS idx_service_requests_eligibility 
ON service_requests(request_type, preferred_shop_id, can_accept_by_any_mechanic, status, assigned_mechanic_id, accepted_by);

-- Create composite index for mechanic availability checks
CREATE INDEX IF NOT EXISTS idx_mechanic_availability_active 
ON mechanic_availability_status(mechanic_id, current_status, is_accepting_requests) 
WHERE current_status = 'available' AND is_accepting_requests = true;