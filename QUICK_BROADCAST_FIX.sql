-- ====================================================================
-- QUICK FIX FOR BROADCAST SYSTEM
-- ====================================================================
-- This creates the necessary functions to make the broadcast system work
-- with your current Flutter implementation

-- ====================================================================
-- 1. CREATE ACCEPT_BROADCAST_REQUEST FUNCTION
-- ====================================================================

CREATE OR REPLACE FUNCTION accept_broadcast_request(
    p_request_id uuid,
    p_provider_id uuid,
    p_mechanic_id uuid DEFAULT NULL
)
RETURNS jsonb AS $$
DECLARE
    v_current_status text;
    v_result jsonb;
    v_request_exists boolean;
BEGIN
    -- Check if request exists and is still pending
    SELECT EXISTS(
        SELECT 1 FROM public.service_requests 
        WHERE id = p_request_id 
        AND status = 'pending'
        AND assigned_mechanic_id IS NULL
    ) INTO v_request_exists;
    
    IF NOT v_request_exists THEN
        RETURN jsonb_build_object(
            'success', false, 
            'error', 'Request is no longer available or already assigned'
        );
    END IF;
    
    -- Begin transaction to ensure atomicity
    BEGIN
        -- Update the service request atomically
        UPDATE public.service_requests 
        SET 
            provider_id = p_provider_id,
            assigned_mechanic_id = COALESCE(p_mechanic_id, p_provider_id),
            status = 'accepted',
            accepted_at = now(),
            accepted_by = COALESCE(p_mechanic_id, p_provider_id)
        WHERE id = p_request_id 
        AND status = 'pending'
        AND assigned_mechanic_id IS NULL;
        
        -- Check if update was successful (no race condition)
        GET DIAGNOSTICS v_current_status = ROW_COUNT;
        IF v_current_status = 0 THEN
            RETURN jsonb_build_object(
                'success', false, 
                'error', 'Request was already accepted by another provider'
            );
        END IF;
        
        -- Update mechanic availability if applicable
        IF p_mechanic_id IS NOT NULL THEN
            UPDATE public.mechanic_availability_status
            SET 
                current_status = 'in_service',
                current_request_id = p_request_id,
                is_accepting_requests = false,
                last_status_update = now()
            WHERE mechanic_id = p_mechanic_id;
        END IF;
        
        v_result := jsonb_build_object(
            'success', true,
            'request_id', p_request_id,
            'provider_id', p_provider_id,
            'accepted_at', now()
        );
        
        RETURN v_result;
        
    EXCEPTION WHEN OTHERS THEN
        -- Rollback happens automatically
        RETURN jsonb_build_object(
            'success', false, 
            'error', 'Failed to accept request: ' || SQLERRM
        );
    END;
END;
$$ LANGUAGE plpgsql;

-- ====================================================================
-- 2. CREATE BROADCAST_SERVICE_REQUEST FUNCTION
-- ====================================================================

CREATE OR REPLACE FUNCTION broadcast_service_request(
    p_request_id uuid,
    p_max_radius_km numeric DEFAULT 25.0,
    p_response_timeout_minutes integer DEFAULT 30
)
RETURNS jsonb AS $$
DECLARE
    v_request_data record;
    v_notified_count integer := 0;
    v_result jsonb;
    v_mechanic record;
BEGIN
    -- Get request details
    SELECT customer_id, pickup_latitude, pickup_longitude, category_id, title, description
    INTO v_request_data
    FROM public.service_requests 
    WHERE id = p_request_id;
    
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Request not found');
    END IF;
    
    -- Update request to broadcast mode
    UPDATE public.service_requests 
    SET 
        request_type = 'broadcast',
        status = 'pending'
    WHERE id = p_request_id;
    
    -- Find available mechanics within radius and create routing entries
    FOR v_mechanic IN 
        SELECT 
            mas.mechanic_id,
            up.first_name || ' ' || up.last_name as mechanic_name,
            mas.location_latitude,
            mas.location_longitude,
            -- Calculate distance using Haversine formula
            (6371 * acos(
                cos(radians(v_request_data.pickup_latitude)) * 
                cos(radians(mas.location_latitude)) * 
                cos(radians(mas.location_longitude) - radians(v_request_data.pickup_longitude)) + 
                sin(radians(v_request_data.pickup_latitude)) * 
                sin(radians(mas.location_latitude))
            )) as distance_km
        FROM public.mechanic_availability_status mas
        JOIN public.user_profiles up ON up.id = mas.mechanic_id
        WHERE 
            mas.current_status = 'available'
            AND mas.is_accepting_requests = true
            AND mas.location_latitude IS NOT NULL 
            AND mas.location_longitude IS NOT NULL
            AND mas.current_request_id IS NULL
            -- Distance filter
            AND (6371 * acos(
                cos(radians(v_request_data.pickup_latitude)) * 
                cos(radians(mas.location_latitude)) * 
                cos(radians(mas.location_longitude) - radians(v_request_data.pickup_longitude)) + 
                sin(radians(v_request_data.pickup_latitude)) * 
                sin(radians(mas.location_latitude))
            )) <= p_max_radius_km
        ORDER BY distance_km ASC
        LIMIT 20
    LOOP
        -- Insert routing entry for each eligible mechanic
        INSERT INTO public.request_routing (
            request_id,
            eligible_mechanic_id,
            routing_type,
            is_notified,
            notified_at,
            response_deadline
        ) VALUES (
            p_request_id,
            v_mechanic.mechanic_id,
            'any_available',
            false,
            now(),
            now() + (p_response_timeout_minutes || ' minutes')::interval
        );
        
        v_notified_count := v_notified_count + 1;
    END LOOP;
    
    v_result := jsonb_build_object(
        'success', true,
        'request_id', p_request_id,
        'notified_mechanics', v_notified_count,
        'broadcast_radius_km', p_max_radius_km,
        'expires_at', (now() + (p_response_timeout_minutes || ' minutes')::interval)
    );
    
    RETURN v_result;
END;
$$ LANGUAGE plpgsql;

-- ====================================================================
-- 3. UPDATE ACCEPT_REQUEST_FIFO TO HANDLE BROADCAST REQUESTS
-- ====================================================================

CREATE OR REPLACE FUNCTION accept_request_fifo(
    p_routing_id uuid,
    p_mechanic_user_id uuid
)
RETURNS boolean AS $$
DECLARE
    v_routing_data record;
    v_request_status text;
    v_assigned_mechanic_id uuid;
BEGIN
    -- Get routing data
    SELECT request_id, eligible_mechanic_id 
    INTO v_routing_data
    FROM public.request_routing 
    WHERE id = p_routing_id;
    
    IF NOT FOUND THEN
        RETURN false;
    END IF;
    
    -- Verify mechanic eligibility
    IF v_routing_data.eligible_mechanic_id != p_mechanic_user_id THEN
        RETURN false;
    END IF;
    
    -- Check request status
    SELECT status, assigned_mechanic_id 
    INTO v_request_status, v_assigned_mechanic_id
    FROM public.service_requests 
    WHERE id = v_routing_data.request_id;
    
    -- If already assigned to someone else, return false
    IF v_assigned_mechanic_id IS NOT NULL AND v_assigned_mechanic_id != p_mechanic_user_id THEN
        RETURN false;
    END IF;
    
    -- If not pending, check if it's already assigned to this mechanic
    IF v_request_status != 'pending' THEN
        IF v_assigned_mechanic_id = p_mechanic_user_id THEN
            RETURN true; -- Already assigned to this mechanic
        ELSE
            RETURN false;
        END IF;
    END IF;
    
    -- Try to atomically assign the request
    UPDATE public.service_requests 
    SET 
        assigned_mechanic_id = p_mechanic_user_id,
        status = 'accepted',
        accepted_at = now(),
        accepted_by = p_mechanic_user_id
    WHERE 
        id = v_routing_data.request_id 
        AND status = 'pending'
        AND assigned_mechanic_id IS NULL;
    
    -- Check if we successfully updated
    IF FOUND THEN
        -- Mark routing as notified (accepted)
        UPDATE public.request_routing 
        SET is_notified = true 
        WHERE id = p_routing_id;
        
        -- Update mechanic availability
        UPDATE public.mechanic_availability_status
        SET 
            current_status = 'in_service',
            current_request_id = v_routing_data.request_id,
            is_accepting_requests = false,
            last_status_update = now()
        WHERE mechanic_id = p_mechanic_user_id;
        
        RETURN true;
    ELSE
        RETURN false;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- ====================================================================
-- 4. CREATE FUNCTION TO FIND AVAILABLE REQUESTS FOR MECHANIC
-- ====================================================================

CREATE OR REPLACE FUNCTION get_available_requests_for_mechanic(
    p_mechanic_id uuid
)
RETURNS TABLE(
    routing_id uuid,
    request_id uuid,
    customer_name text,
    service_type text,
    service_title text,
    pickup_address text,
    distance_km numeric,
    estimated_price numeric,
    priority text,
    created_at timestamp with time zone,
    expires_at timestamp with time zone
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        rr.id as routing_id,
        sr.id as request_id,
        (up.first_name || ' ' || up.last_name) as customer_name,
        sr.service_type,
        sr.title as service_title,
        sr.pickup_address,
        sr.distance_km,
        sr.estimated_price,
        sr.priority,
        sr.created_at,
        rr.response_deadline as expires_at
    FROM public.request_routing rr
    JOIN public.service_requests sr ON sr.id = rr.request_id
    JOIN public.user_profiles up ON up.id = sr.customer_id
    WHERE 
        rr.eligible_mechanic_id = p_mechanic_id
        AND sr.status = 'pending'
        AND sr.assigned_mechanic_id IS NULL
        AND rr.response_deadline > now()
        AND rr.is_notified = false
    ORDER BY 
        sr.priority DESC,
        sr.created_at ASC;
END;
$$ LANGUAGE plpgsql;

-- ====================================================================
-- 5. CREATE A TEST BROADCAST REQUEST
-- ====================================================================

-- Example usage to test the system:
/*
-- First, make sure you have an active service request
-- Then call:
SELECT broadcast_service_request(
    'your-request-id-here',  -- Replace with actual request ID
    15.0,                    -- 15km radius
    30                       -- 30 minutes timeout
);

-- Mechanics can accept using:
SELECT accept_request_fifo(
    'routing-id-here',       -- Replace with routing ID from request_routing table
    'mechanic-user-id-here'  -- Replace with mechanic's user ID
);
*/

-- ====================================================================
-- 6. CREATE DEBUG FUNCTION TO TROUBLESHOOT ACCEPTANCE ISSUES
-- ====================================================================

CREATE OR REPLACE FUNCTION debug_request_acceptance(
    p_request_id uuid,
    p_mechanic_id uuid
)
RETURNS jsonb AS $$
DECLARE
    v_request record;
    v_routing record;
    v_mechanic record;
    v_result jsonb;
BEGIN
    -- Get request details
    SELECT * INTO v_request
    FROM public.service_requests 
    WHERE id = p_request_id;
    
    -- Get routing details
    SELECT * INTO v_routing
    FROM public.request_routing 
    WHERE request_id = p_request_id 
    AND eligible_mechanic_id = p_mechanic_id
    LIMIT 1;
    
    -- Get mechanic availability
    SELECT * INTO v_mechanic
    FROM public.mechanic_availability_status 
    WHERE mechanic_id = p_mechanic_id;
    
    v_result := jsonb_build_object(
        'request_found', (v_request.id IS NOT NULL),
        'request_status', v_request.status,
        'request_assigned_to', v_request.assigned_mechanic_id,
        'routing_found', (v_routing.id IS NOT NULL),
        'routing_notified', v_routing.is_notified,
        'mechanic_status', v_mechanic.current_status,
        'mechanic_accepting', v_mechanic.is_accepting_requests,
        'mechanic_current_request', v_mechanic.current_request_id
    );
    
    RETURN v_result;
END;
$$ LANGUAGE plpgsql;
