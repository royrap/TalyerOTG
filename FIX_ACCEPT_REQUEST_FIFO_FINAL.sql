-- =====================================================
-- FIX: accept_request_fifo - Proper handling of UPDATE result
-- =====================================================
-- The issue: UPDATE might succeed but IF NOT FOUND incorrectly triggers
-- Solution: Use GET DIAGNOSTICS to check rows affected
-- =====================================================

DROP FUNCTION IF EXISTS accept_request_fifo(text, text);

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
    v_rows_updated int;
BEGIN
    RAISE NOTICE '🔧 Starting accept_request_fifo for routing: %, mechanic: %', p_routing_id, p_mechanic_user_id;
    
    -- Get request details from routing
    SELECT request_id, routing_type
    INTO v_request_id, v_routing_type
    FROM request_routing 
    WHERE id = p_routing_id::uuid
    AND eligible_mechanic_id = p_mechanic_user_id::uuid;
    
    IF NOT FOUND THEN
        RAISE NOTICE '❌ Routing entry not found for routing_id: %, mechanic: %', p_routing_id, p_mechanic_user_id;
        RETURN false;
    END IF;
    
    RAISE NOTICE '✅ Routing found - request_id: %, routing_type: %', v_request_id, v_routing_type;
    
    -- Get request type and shop_id from service_requests
    SELECT status, assigned_mechanic_id, request_type, shop_id
    INTO v_request_status, v_assigned_mechanic, v_request_type, v_shop_id
    FROM service_requests 
    WHERE id = v_request_id::uuid;
    
    IF NOT FOUND THEN
        RAISE NOTICE '❌ Service request % not found', v_request_id;
        RETURN false;
    END IF;
    
    RAISE NOTICE '✅ Request found - status: %, type: %, shop_id: %', v_request_status, v_request_type, v_shop_id;
    
    IF v_request_status != 'pending' OR v_assigned_mechanic IS NOT NULL THEN
        RAISE NOTICE '❌ Request % no longer available (status: %, assigned: %)', 
            v_request_id, v_request_status, v_assigned_mechanic;
        RETURN false;
    END IF;
    
    -- Get mechanic's shop_id
    SELECT shop_id INTO v_mechanic_shop_id
    FROM mechanic_availability_status
    WHERE mechanic_id = p_mechanic_user_id::uuid;
    
    RAISE NOTICE '✅ Mechanic shop: %', v_mechanic_shop_id;
    
    -- Handle broadcast requests
    IF v_request_type = 'broadcast' OR v_routing_type = 'broadcast' THEN
        RAISE NOTICE '📢 Handling as broadcast request';
        DECLARE
            v_result jsonb;
        BEGIN
            -- For broadcast requests, use the broadcast acceptance function
            SELECT accept_broadcast_request(
                v_request_id::uuid, 
                p_mechanic_user_id::uuid, 
                p_mechanic_user_id::uuid
            ) INTO v_result;
            
            IF v_result->>'success' = 'true' THEN
                RAISE NOTICE '✅ Broadcast request accepted successfully: %', v_request_id;
                RETURN true;
            ELSE
                RAISE NOTICE '❌ Broadcast request acceptance failed: %', v_result->>'error';
                RETURN false;
            END IF;
        END;
    END IF;
    
    -- Handle shop-based requests - verify mechanic belongs to the shop
    IF v_request_type = 'shop_based' AND v_shop_id IS NOT NULL THEN
        RAISE NOTICE '🏪 Validating shop isolation for shop-based request';
        IF v_mechanic_shop_id IS NULL OR v_mechanic_shop_id != v_shop_id THEN
            RAISE NOTICE '❌ Shop isolation violation: Mechanic shop % does not match request shop %', 
                v_mechanic_shop_id, v_shop_id;
            RETURN false;
        END IF;
        RAISE NOTICE '✅ Shop validation passed';
    END IF;
    
    -- Race condition safe assignment for shop-based and location-based requests
    RAISE NOTICE '🔄 Attempting to assign request...';
    UPDATE service_requests 
    SET 
        assigned_mechanic_id = p_mechanic_user_id::uuid,
        status = 'assigned',
        assigned_at = NOW(),
        updated_at = NOW()
    WHERE id = v_request_id::uuid
    AND status = 'pending' 
    AND assigned_mechanic_id IS NULL;
    
    -- Check how many rows were updated
    GET DIAGNOSTICS v_rows_updated = ROW_COUNT;
    RAISE NOTICE '🔧 Rows updated: %', v_rows_updated;
    
    IF v_rows_updated = 0 THEN
        RAISE NOTICE '❌ Request % was just assigned to another mechanic (or status changed)', v_request_id;
        RETURN false;
    END IF;
    
    RAISE NOTICE '✅ Request assigned successfully';
    
    -- Update mechanic availability
    UPDATE mechanic_availability_status 
    SET 
        current_status = 'busy',
        current_request_id = v_request_id::uuid,
        is_accepting_requests = false,
        last_status_update = NOW()
    WHERE mechanic_id = p_mechanic_user_id::uuid;
    
    RAISE NOTICE '✅ Mechanic availability updated';
    
    -- Clean up routing table
    DELETE FROM request_routing 
    WHERE request_id = v_request_id::uuid;
    
    RAISE NOTICE '✅ Routing entries cleaned up';
    RAISE NOTICE '🎉 Request accepted successfully: % (type: %)', v_request_id, v_request_type;
    RETURN true;
    
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE '💥 Error in accept_request_fifo: %', SQLERRM;
    RETURN false;
END;
$$;

COMMENT ON FUNCTION accept_request_fifo IS 
'Accept a service request with proper shop isolation and race condition handling. 
Handles broadcast, shop-based, and location-based requests correctly.
Now with detailed logging and proper UUID type casting.';

-- Verify it was created
SELECT 'Function updated with enhanced logging' as status;
