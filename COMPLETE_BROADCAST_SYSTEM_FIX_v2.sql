-- COMPLETE BROADCAST SYSTEM FIX (Updated - No Duplicate Functions)
-- This script enables the broadcast request functionality for when customers 
-- don't select a specific shop and all nearby mechanics compete first-come-first-served

-- =====================================================
-- STEP 0: DROP EXISTING FUNCTIONS TO AVOID CONFLICTS
-- =====================================================

-- Drop ALL existing function variations if they exist
DROP FUNCTION IF EXISTS broadcast_service_request CASCADE;
DROP FUNCTION IF EXISTS accept_broadcast_request CASCADE;
DROP FUNCTION IF EXISTS accept_request_fifo CASCADE;
DROP FUNCTION IF EXISTS get_available_requests_for_mechanic CASCADE;
DROP FUNCTION IF EXISTS debug_request_acceptance CASCADE;
DROP FUNCTION IF EXISTS test_broadcast_system CASCADE;
DROP FUNCTION IF EXISTS trigger_broadcast_on_request_creation CASCADE;

-- Drop specific function signature variations that might exist
DROP FUNCTION IF EXISTS broadcast_service_request(uuid, double precision, double precision, double precision, text, boolean) CASCADE;
DROP FUNCTION IF EXISTS broadcast_service_request(text, double precision, double precision) CASCADE;
DROP FUNCTION IF EXISTS broadcast_service_request(text, double precision, double precision, double precision) CASCADE;
DROP FUNCTION IF EXISTS broadcast_service_request(text, double precision, double precision, double precision, text) CASCADE;

-- Drop accept_request_fifo variations
DROP FUNCTION IF EXISTS accept_request_fifo(text, text) CASCADE;
DROP FUNCTION IF EXISTS accept_request_fifo(uuid, uuid) CASCADE;
DROP FUNCTION IF EXISTS accept_request_fifo(text, uuid) CASCADE;
DROP FUNCTION IF EXISTS accept_request_fifo(uuid, text) CASCADE;

-- Drop other function variations
DROP FUNCTION IF EXISTS accept_broadcast_request(uuid, uuid, uuid) CASCADE;
DROP FUNCTION IF EXISTS get_available_requests_for_mechanic(uuid) CASCADE;
DROP FUNCTION IF EXISTS debug_request_acceptance(uuid, uuid) CASCADE;

-- =====================================================
-- STEP 1: CREATE BROADCAST-SPECIFIC FUNCTIONS
-- =====================================================

-- Function to broadcast a service request to all nearby mechanics
CREATE OR REPLACE FUNCTION broadcast_service_request(
    p_request_id text,
    p_customer_latitude double precision,
    p_customer_longitude double precision,
    p_radius_km double precision DEFAULT 10.0,
    p_service_type text DEFAULT NULL,
    p_is_emergency boolean DEFAULT false
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_mechanics_found integer := 0;
    v_routing_entries integer := 0;
    v_mechanic record;
    v_distance_km double precision;
    v_response_deadline timestamp;
BEGIN
    -- Set response deadline based on emergency status
    IF p_is_emergency THEN
        v_response_deadline := NOW() + INTERVAL '2 minutes';
    ELSE
        v_response_deadline := NOW() + INTERVAL '5 minutes';
    END IF;
    
    -- Log the broadcast attempt
    RAISE NOTICE 'Broadcasting request % to mechanics within % km of (%, %)', 
        p_request_id, p_radius_km, p_customer_latitude, p_customer_longitude;
    
    -- Find all available mechanics within radius
    FOR v_mechanic IN 
        SELECT 
            mas.mechanic_id,
            mas.location_latitude,
            mas.location_longitude,
            mas.current_status,
            mas.shop_id,
            up.first_name,
            up.last_name
        FROM mechanic_availability_status mas
        JOIN user_profiles up ON up.id = mas.mechanic_id
        WHERE mas.is_accepting_requests = true
        AND mas.current_status = 'available'
        AND mas.location_latitude IS NOT NULL
        AND mas.location_longitude IS NOT NULL
        AND mas.current_request_id IS NULL
    LOOP
        v_mechanics_found := v_mechanics_found + 1;
        
        -- Calculate distance using Haversine formula approximation
        v_distance_km := (
            6371 * acos(
                cos(radians(p_customer_latitude)) * 
                cos(radians(v_mechanic.location_latitude)) * 
                cos(radians(v_mechanic.location_longitude) - radians(p_customer_longitude)) + 
                sin(radians(p_customer_latitude)) * 
                sin(radians(v_mechanic.location_latitude))
            )
        );
        
        -- Include mechanic if within radius
        IF v_distance_km <= p_radius_km THEN
            -- Create routing entry
            INSERT INTO request_routing (
                request_id,
                eligible_mechanic_id,
                distance_km,
                created_at,
                is_notified,
                response_deadline,
                routing_type
            ) VALUES (
                p_request_id,
                v_mechanic.mechanic_id,
                v_distance_km,
                NOW(),
                false,
                v_response_deadline,
                'broadcast'
            );
            
            v_routing_entries := v_routing_entries + 1;
            
            RAISE NOTICE 'Added mechanic % (% %) at distance % km', 
                v_mechanic.mechanic_id, v_mechanic.first_name, v_mechanic.last_name, v_distance_km;
        END IF;
    END LOOP;
    
    -- Update service request with broadcast info
    UPDATE service_requests 
    SET 
        broadcast_radius_km = p_radius_km,
        mechanics_notified_count = v_routing_entries,
        broadcast_timestamp = NOW(),
        request_type = 'broadcast'
    WHERE id = p_request_id;
    
    RAISE NOTICE 'Broadcast complete: % mechanics found, % within radius', 
        v_mechanics_found, v_routing_entries;
    
    RETURN jsonb_build_object(
        'success', true,
        'mechanics_found', v_mechanics_found,
        'mechanics_notified', v_routing_entries,
        'radius_km', p_radius_km,
        'response_deadline', v_response_deadline
    );
    
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Error in broadcast_service_request: %', SQLERRM;
    RETURN jsonb_build_object(
        'success', false,
        'error', SQLERRM,
        'mechanics_found', v_mechanics_found,
        'mechanics_notified', v_routing_entries
    );
END;
$$;

-- Function to accept broadcast requests with race condition handling
CREATE OR REPLACE FUNCTION accept_broadcast_request(
    p_request_id text,
    p_provider_id text,
    p_mechanic_id text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_request_status text;
    v_assigned_mechanic text;
    v_routing_exists boolean := false;
    v_shop_id text;
BEGIN
    -- Check if request is still available
    SELECT status, assigned_mechanic_id 
    INTO v_request_status, v_assigned_mechanic
    FROM service_requests 
    WHERE id = p_request_id;
    
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Request not found');
    END IF;
    
    IF v_request_status != 'pending' THEN
        RETURN jsonb_build_object('success', false, 'error', 'Request no longer available');
    END IF;
    
    IF v_assigned_mechanic IS NOT NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Request already assigned');
    END IF;
    
    -- Check if mechanic has routing entry for this request
    SELECT EXISTS(
        SELECT 1 FROM request_routing 
        WHERE request_id = p_request_id 
        AND eligible_mechanic_id = p_mechanic_id
    ) INTO v_routing_exists;
    
    IF NOT v_routing_exists THEN
        RETURN jsonb_build_object('success', false, 'error', 'Mechanic not eligible for this request');
    END IF;
    
    -- Get mechanic's shop_id if any
    SELECT shop_id INTO v_shop_id
    FROM mechanic_availability_status
    WHERE mechanic_id = p_mechanic_id;
    
    -- Race condition safe assignment using UPDATE with WHERE conditions
    UPDATE service_requests 
    SET 
        assigned_mechanic_id = p_mechanic_id,
        assigned_shop_id = v_shop_id,
        status = 'assigned',
        assigned_at = NOW(),
        updated_at = NOW()
    WHERE id = p_request_id 
    AND status = 'pending' 
    AND assigned_mechanic_id IS NULL;
    
    -- Check if update was successful (means we won the race)
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Request was just assigned to another mechanic');
    END IF;
    
    -- Update mechanic availability
    UPDATE mechanic_availability_status 
    SET 
        current_status = 'busy',
        current_request_id = p_request_id,
        is_accepting_requests = false,
        last_status_update = NOW()
    WHERE mechanic_id = p_mechanic_id;
    
    -- Clean up routing table - remove all other routing entries for this request
    DELETE FROM request_routing 
    WHERE request_id = p_request_id;
    
    -- Insert notification for customer
    INSERT INTO notifications (user_id, title, body, type, data, created_at)
    SELECT 
        sr.customer_id,
        'Mechanic Assigned',
        'A mechanic has been assigned to your request and is on the way.',
        'mechanic_assigned',
        jsonb_build_object(
            'request_id', p_request_id,
            'mechanic_id', p_mechanic_id,
            'shop_id', v_shop_id
        ),
        NOW()
    FROM service_requests sr
    WHERE sr.id = p_request_id;
    
    RETURN jsonb_build_object(
        'success', true,
        'message', 'Request accepted successfully',
        'request_id', p_request_id,
        'mechanic_id', p_mechanic_id,
        'shop_id', v_shop_id
    );
    
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
        'success', false,
        'error', SQLERRM
    );
END;
$$;

-- =====================================================
-- STEP 2: UPDATE EXISTING FUNCTIONS FOR COMPATIBILITY
-- =====================================================

-- Enhanced accept_request_fifo function to handle both direct and broadcast requests
CREATE OR REPLACE FUNCTION accept_request_fifo(
    p_routing_id text,
    p_mechanic_user_id text
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_request_id text;
    v_request_status text;
    v_assigned_mechanic text;
    v_routing_type text;
    v_provider_id text;
    v_result jsonb;
BEGIN
    -- Get request details from routing
    SELECT request_id, routing_type
    INTO v_request_id, v_routing_type
    FROM request_routing 
    WHERE id = p_routing_id 
    AND eligible_mechanic_id = p_mechanic_user_id;
    
    IF NOT FOUND THEN
        RAISE NOTICE 'Routing entry not found for routing_id: %, mechanic: %', p_routing_id, p_mechanic_user_id;
        RETURN false;
    END IF;
    
    -- Check current request status
    SELECT status, assigned_mechanic_id 
    INTO v_request_status, v_assigned_mechanic
    FROM service_requests 
    WHERE id = v_request_id;
    
    IF v_request_status != 'pending' OR v_assigned_mechanic IS NOT NULL THEN
        RAISE NOTICE 'Request % no longer available (status: %, assigned: %)', 
            v_request_id, v_request_status, v_assigned_mechanic;
        RETURN false;
    END IF;
    
    -- Handle broadcast requests using the broadcast function
    IF v_routing_type = 'broadcast' OR v_routing_type IS NULL THEN
        -- For broadcast requests, use the broadcast acceptance function
        SELECT accept_broadcast_request(v_request_id, p_mechanic_user_id, p_mechanic_user_id) INTO v_result;
        
        IF v_result->>'success' = 'true' THEN
            RAISE NOTICE 'Broadcast request accepted successfully: %', v_request_id;
            RETURN true;
        ELSE
            RAISE NOTICE 'Broadcast request acceptance failed: %', v_result->>'error';
            RETURN false;
        END IF;
    END IF;
    
    -- Handle direct shop requests (original logic)
    -- Race condition safe assignment
    UPDATE service_requests 
    SET 
        assigned_mechanic_id = p_mechanic_user_id,
        status = 'assigned',
        assigned_at = NOW(),
        updated_at = NOW()
    WHERE id = v_request_id 
    AND status = 'pending' 
    AND assigned_mechanic_id IS NULL;
    
    IF NOT FOUND THEN
        RAISE NOTICE 'Request % was just assigned to another mechanic', v_request_id;
        RETURN false;
    END IF;
    
    -- Update mechanic availability
    UPDATE mechanic_availability_status 
    SET 
        current_status = 'busy',
        current_request_id = v_request_id,
        is_accepting_requests = false,
        last_status_update = NOW()
    WHERE mechanic_id = p_mechanic_user_id;
    
    -- Clean up routing table
    DELETE FROM request_routing 
    WHERE request_id = v_request_id;
    
    RAISE NOTICE 'Direct request accepted successfully: %', v_request_id;
    RETURN true;
    
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Error in accept_request_fifo: %', SQLERRM;
    RETURN false;
END;
$$;

-- =====================================================
-- STEP 3: ADD MISSING COLUMNS TO TABLES
-- =====================================================

-- Add broadcast-related columns to service_requests if they don't exist
DO $$
BEGIN
    -- Add broadcast_radius_km column
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'service_requests' 
        AND column_name = 'broadcast_radius_km'
    ) THEN
        ALTER TABLE service_requests ADD COLUMN broadcast_radius_km double precision;
        RAISE NOTICE 'Added broadcast_radius_km column to service_requests';
    END IF;
    
    -- Add mechanics_notified_count column
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'service_requests' 
        AND column_name = 'mechanics_notified_count'
    ) THEN
        ALTER TABLE service_requests ADD COLUMN mechanics_notified_count integer DEFAULT 0;
        RAISE NOTICE 'Added mechanics_notified_count column to service_requests';
    END IF;
    
    -- Add broadcast_timestamp column
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'service_requests' 
        AND column_name = 'broadcast_timestamp'
    ) THEN
        ALTER TABLE service_requests ADD COLUMN broadcast_timestamp timestamp;
        RAISE NOTICE 'Added broadcast_timestamp column to service_requests';
    END IF;
    
    -- Add request_type column
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'service_requests' 
        AND column_name = 'request_type'
    ) THEN
        ALTER TABLE service_requests ADD COLUMN request_type text DEFAULT 'direct_shop';
        RAISE NOTICE 'Added request_type column to service_requests';
    END IF;
    
    -- Add assigned_shop_id column
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'service_requests' 
        AND column_name = 'assigned_shop_id'
    ) THEN
        ALTER TABLE service_requests ADD COLUMN assigned_shop_id text;
        RAISE NOTICE 'Added assigned_shop_id column to service_requests';
    END IF;
END $$;

-- Add routing_type column to request_routing if it doesn't exist
DO $$
BEGIN
    -- Add distance_km column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'request_routing' 
        AND column_name = 'distance_km'
    ) THEN
        ALTER TABLE request_routing ADD COLUMN distance_km double precision;
        RAISE NOTICE 'Added distance_km column to request_routing';
    END IF;
    
    -- Add routing_type column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'request_routing' 
        AND column_name = 'routing_type'
    ) THEN
        ALTER TABLE request_routing ADD COLUMN routing_type text DEFAULT 'direct';
        RAISE NOTICE 'Added routing_type column to request_routing';
    END IF;
END $$;

-- =====================================================
-- STEP 4: CREATE TRIGGER FOR AUTOMATIC BROADCAST
-- =====================================================

-- Function to automatically broadcast requests when shop_id is null
CREATE OR REPLACE FUNCTION trigger_broadcast_on_request_creation()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_broadcast_result jsonb;
BEGIN
    -- Only broadcast if shop_id is null and status is pending
    IF NEW.shop_id IS NULL AND NEW.status = 'pending' THEN
        RAISE NOTICE 'Triggering automatic broadcast for request %', NEW.id;
        
        -- Trigger broadcast with 10km radius
        SELECT broadcast_service_request(
            NEW.id::text,
            NEW.pickup_latitude,
            NEW.pickup_longitude,
            10.0, -- 10km radius
            NEW.service_type,
            COALESCE(NEW.is_emergency, false)
        ) INTO v_broadcast_result;
        
        RAISE NOTICE 'Broadcast result: %', v_broadcast_result;
    END IF;
    
    RETURN NEW;
END;
$$;

-- Create trigger if it doesn't exist
DROP TRIGGER IF EXISTS auto_broadcast_service_request ON service_requests;
CREATE TRIGGER auto_broadcast_service_request
    AFTER INSERT ON service_requests
    FOR EACH ROW
    EXECUTE FUNCTION trigger_broadcast_on_request_creation();

-- Log trigger creation
DO $$
BEGIN
    RAISE NOTICE 'Created auto_broadcast_service_request trigger';
END $$;

-- =====================================================
-- STEP 5: HELPER FUNCTIONS
-- =====================================================

-- Function to get available requests for a mechanic (useful for debugging)
CREATE OR REPLACE FUNCTION get_available_requests_for_mechanic(
    p_mechanic_id text
)
RETURNS table(
    request_id text,
    title text,
    service_type text,
    distance_km double precision,
    customer_name text,
    pickup_address text,
    is_emergency boolean,
    created_at timestamp,
    response_deadline timestamp
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        rr.request_id,
        sr.title,
        sr.service_type,
        rr.distance_km,
        CONCAT(up.first_name, ' ', up.last_name) as customer_name,
        sr.pickup_address,
        COALESCE(sr.is_emergency, false) as is_emergency,
        sr.created_at,
        rr.response_deadline
    FROM request_routing rr
    JOIN service_requests sr ON sr.id = rr.request_id
    JOIN user_profiles up ON up.id = sr.customer_id
    WHERE rr.eligible_mechanic_id = p_mechanic_id
    AND sr.status = 'pending'
    AND sr.assigned_mechanic_id IS NULL
    ORDER BY sr.is_emergency DESC, rr.distance_km ASC;
END;
$$;

-- Debug function to check request acceptance eligibility
CREATE OR REPLACE FUNCTION debug_request_acceptance(
    p_request_id text,
    p_mechanic_id text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_request record;
    v_routing record;
    v_mechanic record;
    v_result jsonb := '{}';
BEGIN
    -- Get request details
    SELECT * INTO v_request
    FROM service_requests
    WHERE id = p_request_id;
    
    IF NOT FOUND THEN
        v_result := jsonb_build_object('error', 'Request not found');
    ELSE
        v_result := jsonb_build_object(
            'request_status', v_request.status,
            'assigned_mechanic', v_request.assigned_mechanic_id,
            'created_at', v_request.created_at
        );
    END IF;
    
    -- Get routing details
    SELECT * INTO v_routing
    FROM request_routing
    WHERE request_id = p_request_id
    AND eligible_mechanic_id = p_mechanic_id;
    
    IF FOUND THEN
        v_result := v_result || jsonb_build_object(
            'routing_exists', true,
            'routing_type', v_routing.routing_type,
            'is_notified', v_routing.is_notified,
            'response_deadline', v_routing.response_deadline
        );
    ELSE
        v_result := v_result || jsonb_build_object('routing_exists', false);
    END IF;
    
    -- Get mechanic details
    SELECT * INTO v_mechanic
    FROM mechanic_availability_status
    WHERE mechanic_id = p_mechanic_id;
    
    IF FOUND THEN
        v_result := v_result || jsonb_build_object(
            'mechanic_status', v_mechanic.current_status,
            'is_accepting_requests', v_mechanic.is_accepting_requests,
            'current_request_id', v_mechanic.current_request_id
        );
    ELSE
        v_result := v_result || jsonb_build_object('mechanic_found', false);
    END IF;
    
    RETURN v_result;
END;
$$;

-- =====================================================
-- STEP 6: SET PERMISSIONS
-- =====================================================

-- Grant execute permissions on functions
GRANT EXECUTE ON FUNCTION broadcast_service_request TO authenticated;
GRANT EXECUTE ON FUNCTION accept_broadcast_request TO authenticated;
GRANT EXECUTE ON FUNCTION accept_request_fifo TO authenticated;
GRANT EXECUTE ON FUNCTION get_available_requests_for_mechanic TO authenticated;
GRANT EXECUTE ON FUNCTION debug_request_acceptance TO authenticated;

-- =====================================================
-- STEP 7: TEST BROADCAST SYSTEM
-- =====================================================

-- Test function to verify broadcast system is working
CREATE OR REPLACE FUNCTION test_broadcast_system()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_test_request_id text;
    v_broadcast_result jsonb;
    v_routing_count integer;
BEGIN
    -- Create a test request
    INSERT INTO service_requests (
        id,
        customer_id,
        title,
        description,
        service_type,
        pickup_latitude,
        pickup_longitude,
        pickup_address,
        status,
        created_at
    ) VALUES (
        'test-broadcast-' || extract(epoch from now())::text,
        'test-customer-id',
        'Test Broadcast Request',
        'Testing broadcast functionality',
        'engine_trouble',
        14.5995,  -- Manila coordinates
        120.9842,
        'Manila, Philippines',
        'pending',
        NOW()
    ) RETURNING id INTO v_test_request_id;
    
    -- Trigger broadcast
    SELECT broadcast_service_request(
        v_test_request_id,
        14.5995,
        120.9842,
        10.0,
        'engine_trouble',
        false
    ) INTO v_broadcast_result;
    
    -- Count routing entries created
    SELECT COUNT(*) INTO v_routing_count
    FROM request_routing
    WHERE request_id = v_test_request_id;
    
    -- Clean up test data
    DELETE FROM request_routing WHERE request_id = v_test_request_id;
    DELETE FROM service_requests WHERE id = v_test_request_id;
    
    RETURN jsonb_build_object(
        'test_request_id', v_test_request_id,
        'broadcast_result', v_broadcast_result,
        'routing_entries_created', v_routing_count,
        'test_status', 'completed'
    );
END;
$$;

-- Grant permission to test function
GRANT EXECUTE ON FUNCTION test_broadcast_system TO authenticated;

-- =====================================================
-- COMPLETION MESSAGE
-- =====================================================

DO $$
BEGIN
    RAISE NOTICE '✅ BROADCAST REQUEST SYSTEM SETUP COMPLETE!';
    RAISE NOTICE '';
    RAISE NOTICE 'Features enabled:';
    RAISE NOTICE '- Automatic broadcast when customer creates request without shop_id';
    RAISE NOTICE '- Race condition safe request acceptance';
    RAISE NOTICE '- Distance-based mechanic selection (10km radius)';
    RAISE NOTICE '- Emergency request priority handling';
    RAISE NOTICE '- Compatibility with existing Flutter code';
    RAISE NOTICE '';
    RAISE NOTICE 'Key functions:';
    RAISE NOTICE '- broadcast_service_request(): Broadcasts request to nearby mechanics';
    RAISE NOTICE '- accept_broadcast_request(): Handles broadcast request acceptance';
    RAISE NOTICE '- accept_request_fifo(): Enhanced to work with both direct and broadcast';
    RAISE NOTICE '';
    RAISE NOTICE 'To test the system, run: SELECT test_broadcast_system();';
    RAISE NOTICE '';
    RAISE NOTICE 'The system will now automatically broadcast requests when';
    RAISE NOTICE 'customers create service requests without selecting a specific shop!';
END $$;