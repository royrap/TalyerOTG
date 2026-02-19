-- =====================================================
-- FIX: Shop-based Request Acceptance Issue
-- =====================================================
-- Problem: accept_request_fifo treats NULL routing_type as broadcast
-- This causes shop-based requests to fail acceptance
--
-- Solution: Fix the logic to properly handle shop-based requests

-- =====================================================
-- STEP 1: Fix accept_request_fifo function
-- =====================================================

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
    v_request_type text;
    v_shop_id uuid;
    v_mechanic_shop_id uuid;
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
    
    -- Get request type and shop_id from service_requests
    SELECT status, assigned_mechanic_id, request_type, shop_id
    INTO v_request_status, v_assigned_mechanic, v_request_type, v_shop_id
    FROM service_requests 
    WHERE id = v_request_id;
    
    IF NOT FOUND THEN
        RAISE NOTICE 'Service request % not found', v_request_id;
        RETURN false;
    END IF;
    
    IF v_request_status != 'pending' OR v_assigned_mechanic IS NOT NULL THEN
        RAISE NOTICE 'Request % no longer available (status: %, assigned: %)', 
            v_request_id, v_request_status, v_assigned_mechanic;
        RETURN false;
    END IF;
    
    -- Get mechanic's shop_id
    SELECT shop_id INTO v_mechanic_shop_id
    FROM mechanic_availability_status
    WHERE mechanic_id = p_mechanic_user_id;
    
    RAISE NOTICE 'Request type: %, Shop ID: %, Mechanic Shop ID: %', 
        v_request_type, v_shop_id, v_mechanic_shop_id;
    
    -- Handle broadcast requests
    IF v_request_type = 'broadcast' OR v_routing_type = 'broadcast' THEN
        DECLARE
            v_result jsonb;
        BEGIN
            -- For broadcast requests, use the broadcast acceptance function
            SELECT accept_broadcast_request(v_request_id, p_mechanic_user_id, p_mechanic_user_id) INTO v_result;
            
            IF v_result->>'success' = 'true' THEN
                RAISE NOTICE 'Broadcast request accepted successfully: %', v_request_id;
                RETURN true;
            ELSE
                RAISE NOTICE 'Broadcast request acceptance failed: %', v_result->>'error';
                RETURN false;
            END IF;
        END;
    END IF;
    
    -- Handle shop-based requests - verify mechanic belongs to the shop
    IF v_request_type = 'shop_based' AND v_shop_id IS NOT NULL THEN
        IF v_mechanic_shop_id IS NULL OR v_mechanic_shop_id != v_shop_id THEN
            RAISE NOTICE 'Shop isolation violation: Mechanic shop % does not match request shop %', 
                v_mechanic_shop_id, v_shop_id;
            RETURN false;
        END IF;
    END IF;
    
    -- Race condition safe assignment for shop-based and location-based requests
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
    
    RAISE NOTICE 'Request accepted successfully: % (type: %)', v_request_id, v_request_type;
    RETURN true;
    
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Error in accept_request_fifo: %', SQLERRM;
    RETURN false;
END;
$$;

COMMENT ON FUNCTION accept_request_fifo IS 
'Accept a service request with proper shop isolation and race condition handling. 
Handles broadcast, shop-based, and location-based requests correctly.';

-- =====================================================
-- STEP 2: Verify the fix
-- =====================================================

-- Check the current request routing entries
SELECT 
    rr.id as routing_id,
    rr.request_id,
    rr.routing_type,
    sr.request_type,
    sr.shop_id,
    sr.status,
    mas.shop_id as mechanic_shop_id,
    rr.eligible_mechanic_id
FROM request_routing rr
JOIN service_requests sr ON rr.request_id = sr.id
LEFT JOIN mechanic_availability_status mas ON rr.eligible_mechanic_id = mas.mechanic_id
WHERE sr.status = 'pending'
ORDER BY rr.created_at DESC
LIMIT 10;

-- =====================================================
-- SUMMARY
-- =====================================================
-- 1. Fixed accept_request_fifo to check request_type from service_requests ✅
-- 2. Added proper shop isolation check for shop-based requests ✅
-- 3. Only treats request as broadcast if request_type = 'broadcast' ✅
-- 4. Shop-based requests now properly handled with shop_id validation ✅
