-- ====================================================================
-- REMOVE SHOP ISOLATION VALIDATION (DIRECT MECHANIC ACCEPTANCE)
-- ====================================================================
-- This removes the shop isolation check that blocks mechanics from
-- accepting requests when they're not pre-assigned to shops.
-- 
-- NEW FLOW:
-- 1. Customer selects a shop
-- 2. ANY mechanic can see the request (no pre-assignment needed)
-- 3. First mechanic to accept gets the job
-- 4. NO shop_mechanics validation required
-- ====================================================================

-- Option 1: DROP the validation function entirely (RECOMMENDED)
-- This removes all shop isolation checks

DROP FUNCTION IF EXISTS public.validate_mechanic_shop_for_request(uuid, uuid);

-- ====================================================================
-- Update accept_request_fifo to REMOVE validation call
-- ====================================================================

CREATE OR REPLACE FUNCTION public.accept_request_fifo(
    p_routing_id text,
    p_mechanic_user_id text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_request_id uuid;
    v_mechanic_uuid uuid;
    v_request_record record;
    v_result jsonb;
BEGIN
    -- Convert string IDs to UUIDs
    v_mechanic_uuid := p_mechanic_user_id::uuid;
    
    -- If routing_id provided, get request_id from routing
    IF p_routing_id IS NOT NULL AND p_routing_id != '' AND p_routing_id != 'null' THEN
        SELECT request_id INTO v_request_id
        FROM public.request_routing
        WHERE id::text = p_routing_id;
    END IF;

    -- ❌ REMOVED: Shop validation check
    -- No longer checking shop_mechanics table
    -- Any mechanic can accept any request

    -- Get the request details
    SELECT * INTO v_request_record
    FROM public.service_requests
    WHERE id = v_request_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Request not found: %', v_request_id USING ERRCODE = 'P0001';
    END IF;

    -- Check if already accepted
    IF v_request_record.status NOT IN ('pending', 'awaiting_payment', 'ready_to_assign') THEN
        RAISE EXCEPTION 'Request already accepted or completed' USING ERRCODE = 'P0001';
    END IF;

    -- Accept the request
    UPDATE public.service_requests
    SET 
        status = 'assigned',
        assigned_mechanic_id = v_mechanic_uuid,
        accepted_by = v_mechanic_uuid,
        accepted_at = NOW(),
        updated_at = NOW()
    WHERE id = v_request_id;

    -- Remove routing entries for this request
    DELETE FROM public.request_routing WHERE request_id = v_request_id;

    -- Update broadcast status
    UPDATE public.request_broadcasts
    SET 
        response_status = 'accepted',
        responded_at = NOW()
    WHERE request_id = v_request_id
      AND mechanic_id = v_mechanic_uuid;

    v_result := jsonb_build_object(
        'success', true,
        'request_id', v_request_id,
        'mechanic_id', v_mechanic_uuid,
        'message', 'Request accepted successfully'
    );

    RETURN v_result;

EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION '%', SQLERRM USING ERRCODE = SQLSTATE;
END;
$$;

GRANT EXECUTE ON FUNCTION public.accept_request_fifo(text, text) TO authenticated;

-- ====================================================================
-- VERIFICATION
-- ====================================================================

SELECT '✅ Shop isolation validation REMOVED' as status;
SELECT '✅ Any mechanic can now accept requests' as flow;
SELECT '✅ No shop_mechanics check required' as validation;

-- Check that validation function is dropped
SELECT 
    CASE 
        WHEN COUNT(*) = 0 THEN '✅ Validation function removed'
        ELSE '❌ Validation function still exists'
    END as validation_status
FROM pg_proc
WHERE proname = 'validate_mechanic_shop_for_request';

-- Check that accept_request_fifo is updated
SELECT 
    CASE 
        WHEN pg_get_functiondef(oid) NOT LIKE '%validate_mechanic_shop_for_request%' THEN '✅ Accept function updated (no validation)'
        ELSE '❌ Accept function still has validation'
    END as accept_function_status
FROM pg_proc
WHERE proname = 'accept_request_fifo';

-- ====================================================================
-- TESTING
-- ====================================================================
/*
TO TEST:
1. Create a service request as customer with a shop selected
2. Login as ANY mechanic (doesn't need to be assigned to that shop)
3. Try to accept the request
4. Should succeed without "Shop isolation violation" error

EXPECTED BEHAVIOR:
- ✅ Any mechanic can see requests
- ✅ Any mechanic can accept requests
- ✅ First to accept wins
- ✅ No shop pre-assignment needed
*/

-- ====================================================================
-- DEPLOYMENT NOTES
-- ====================================================================
/*
WHAT CHANGED:

1. ✅ REMOVED shop isolation validation
   - Dropped validate_mechanic_shop_for_request function
   - Removed validation call from accept_request_fifo
   
2. ✅ NEW FLOW:
   - Customer selects shop
   - Request visible to all mechanics
   - Any mechanic can accept (first come, first served)
   - No shop_mechanics table check
   
3. ✅ IMPACT:
   - Mechanics no longer blocked by "not assigned to shop" error
   - Faster acceptance flow
   - No need for shop owner to pre-assign mechanics
   
TO DEPLOY:
1. Run this SQL file in Supabase SQL Editor
2. Restart Flutter app: flutter run
3. Test: Any mechanic should be able to accept any request
4. No more "Shop isolation violation" errors
*/
