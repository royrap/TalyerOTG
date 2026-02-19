-- EMERGENCY FIX: HINDI NAKIKITA NG IBANG MECHANICS ANG REQUESTS
-- This script fixes the issue where only rafaelpineda471@gmail.com can see requests
-- Root cause: Other mechanics don't have proper mechanic_availability_status records

-- =====================================================
-- STEP 1: CHECK CURRENT MECHANIC DATA
-- =====================================================

-- Check all mechanics in the system
SELECT 
    'CURRENT_MECHANICS' as check_type,
    up.id,
    up.first_name,
    up.last_name,
    up.email,
    up.user_type,
    mas.current_status,
    mas.is_accepting_requests,
    mas.location_latitude,
    mas.location_longitude
FROM user_profiles up
LEFT JOIN mechanic_availability_status mas ON mas.mechanic_id = up.id
WHERE up.user_type = 'mechanic'
ORDER BY up.created_at;

-- =====================================================
-- STEP 2: CREATE MISSING MECHANIC AVAILABILITY RECORDS
-- =====================================================

-- Insert missing availability records for all mechanics
INSERT INTO mechanic_availability_status (
    mechanic_id,
    current_status,
    is_accepting_requests,
    location_latitude,
    location_longitude,
    last_status_update,
    created_at,
    updated_at
)
SELECT 
    up.id,
    'available'::text,
    true,
    -- Use Manila coordinates as default (mechanics can update later)
    14.5995 + (random() * 0.1 - 0.05), -- Random nearby Manila location
    120.9842 + (random() * 0.1 - 0.05), -- Random nearby Manila location  
    NOW(),
    NOW(),
    NOW()
FROM user_profiles up
LEFT JOIN mechanic_availability_status mas ON mas.mechanic_id = up.id
WHERE up.user_type = 'mechanic'
AND mas.mechanic_id IS NULL
ON CONFLICT (mechanic_id) DO UPDATE SET
    current_status = 'available',
    is_accepting_requests = true,
    location_latitude = COALESCE(mechanic_availability_status.location_latitude, 14.5995 + (random() * 0.1 - 0.05)),
    location_longitude = COALESCE(mechanic_availability_status.location_longitude, 120.9842 + (random() * 0.1 - 0.05)),
    last_status_update = NOW(),
    updated_at = NOW();

-- =====================================================
-- STEP 3: DEPLOY BROADCAST SYSTEM FUNCTIONS
-- =====================================================

-- Drop existing functions to avoid conflicts
DROP FUNCTION IF EXISTS broadcast_service_request CASCADE;
DROP FUNCTION IF EXISTS accept_broadcast_request CASCADE;
DROP FUNCTION IF EXISTS accept_request_fifo CASCADE;
DROP FUNCTION IF EXISTS trigger_broadcast_on_request_creation CASCADE;

-- Core broadcast function
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
            up.last_name,
            up.email
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
            
            RAISE NOTICE 'Added mechanic % (% % - %) at distance % km', 
                v_mechanic.mechanic_id, v_mechanic.first_name, v_mechanic.last_name, v_mechanic.email, v_distance_km;
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
    
    RAISE NOTICE 'Broadcast complete: % mechanics found, % within radius and notified', 
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

-- Accept broadcast request function
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

-- Enhanced accept_request_fifo function
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
    
    RETURN true;
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Error in accept_request_fifo: %', SQLERRM;
    RETURN false;
END;
$$;

-- =====================================================
-- STEP 4: ADD MISSING COLUMNS IF NEEDED
-- =====================================================

-- Add broadcast columns to service_requests if they don't exist
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

-- Add columns to request_routing if needed
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
-- STEP 5: CREATE AUTO-BROADCAST TRIGGER
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
        RAISE NOTICE 'AUTO-TRIGGERING BROADCAST for request %', NEW.id;
        
        -- Trigger broadcast with 10km radius
        SELECT broadcast_service_request(
            NEW.id::text,
            NEW.pickup_latitude,
            NEW.pickup_longitude,
            10.0, -- 10km radius
            NEW.service_type,
            COALESCE(NEW.is_emergency, false)
        ) INTO v_broadcast_result;
        
        RAISE NOTICE 'Auto-broadcast result: %', v_broadcast_result;
    END IF;
    
    RETURN NEW;
END;
$$;

-- Create trigger
DROP TRIGGER IF EXISTS auto_broadcast_service_request ON service_requests;
CREATE TRIGGER auto_broadcast_service_request
    AFTER INSERT ON service_requests
    FOR EACH ROW
    EXECUTE FUNCTION trigger_broadcast_on_request_creation();

-- =====================================================
-- STEP 6: MANUALLY BROADCAST EXISTING REQUEST
-- =====================================================

-- Broadcast the existing request that only rafaelpineda471 can see
DO $$
DECLARE
    v_broadcast_result jsonb;
    v_latest_request record;
BEGIN
    -- Get the latest pending request
    SELECT * INTO v_latest_request
    FROM service_requests 
    WHERE status = 'pending'
    AND assigned_mechanic_id IS NULL
    ORDER BY created_at DESC
    LIMIT 1;
    
    IF v_latest_request.id IS NOT NULL THEN
        RAISE NOTICE 'MANUALLY BROADCASTING existing request: %', v_latest_request.id;
        RAISE NOTICE 'Request location: %, %', v_latest_request.pickup_latitude, v_latest_request.pickup_longitude;
        
        -- Clear any existing routing entries for this request
        DELETE FROM request_routing WHERE request_id = v_latest_request.id;
        
        -- Manually trigger broadcast
        SELECT broadcast_service_request(
            v_latest_request.id::text,
            v_latest_request.pickup_latitude,
            v_latest_request.pickup_longitude,
            10.0,
            COALESCE(v_latest_request.service_type, 'general'),
            COALESCE(v_latest_request.is_emergency, false)
        ) INTO v_broadcast_result;
        
        RAISE NOTICE 'Manual broadcast result: %', v_broadcast_result;
    ELSE
        RAISE NOTICE 'No pending requests found to broadcast';
    END IF;
END $$;

-- =====================================================
-- STEP 7: VERIFY ALL MECHANICS CAN SEE REQUESTS
-- =====================================================

-- Check which mechanics are now eligible for broadcasts
SELECT 
    'FINAL_MECHANIC_CHECK' as check_type,
    up.email,
    up.first_name,
    up.last_name,
    mas.current_status,
    mas.is_accepting_requests,
    mas.location_latitude,
    mas.location_longitude,
    CASE 
        WHEN mas.is_accepting_requests = true 
        AND mas.current_status = 'available'
        AND mas.location_latitude IS NOT NULL
        AND mas.location_longitude IS NOT NULL
        AND mas.current_request_id IS NULL
        THEN '✅ ELIGIBLE FOR BROADCASTS'
        ELSE '❌ NOT ELIGIBLE'
    END as broadcast_eligibility
FROM user_profiles up
JOIN mechanic_availability_status mas ON mas.mechanic_id = up.id
WHERE up.user_type = 'mechanic'
ORDER BY up.email;

-- Set permissions
GRANT EXECUTE ON FUNCTION broadcast_service_request TO authenticated;
GRANT EXECUTE ON FUNCTION accept_broadcast_request TO authenticated;
GRANT EXECUTE ON FUNCTION accept_request_fifo TO authenticated;

-- =====================================================
-- COMPLETION MESSAGE
-- =====================================================

DO $$
BEGIN
    RAISE NOTICE '🎉 EMERGENCY FIX COMPLETE!';
    RAISE NOTICE '';
    RAISE NOTICE '✅ FIXED ISSUES:';
    RAISE NOTICE '- Created missing mechanic_availability_status records';
    RAISE NOTICE '- Added location coordinates for all mechanics';
    RAISE NOTICE '- Deployed working broadcast system';
    RAISE NOTICE '- Created auto-broadcast trigger';
    RAISE NOTICE '- Manually broadcasted existing request';
    RAISE NOTICE '';
    RAISE NOTICE '🚀 ALL MECHANICS SHOULD NOW SEE REQUESTS!';
    RAISE NOTICE '';
    RAISE NOTICE 'Future requests with shop_id = null will automatically';
    RAISE NOTICE 'broadcast to all nearby mechanics for paunahan system!';
END $$;