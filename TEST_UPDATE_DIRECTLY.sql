-- =====================================================
-- SIMPLE TEST: Check if UPDATE would work
-- =====================================================

-- Test if we can UPDATE the service_requests table directly
DO $$
DECLARE
    v_request_id text := 'b9e0d0a6-1345-4abe-8ec6-c72cc231d4b5';
    v_mechanic_id text := 'e4cbf14b-5729-45ef-a124-1f2e05acad8c';
    v_rows_updated int;
BEGIN
    RAISE NOTICE 'Testing UPDATE on service_requests...';
    RAISE NOTICE 'Request ID: %', v_request_id;
    RAISE NOTICE 'Mechanic ID: %', v_mechanic_id;
    
    -- Try the UPDATE
    UPDATE service_requests 
    SET 
        assigned_mechanic_id = v_mechanic_id,
        status = 'assigned',
        assigned_at = NOW(),
        updated_at = NOW()
    WHERE id = v_request_id 
    AND status = 'pending' 
    AND assigned_mechanic_id IS NULL;
    
    GET DIAGNOSTICS v_rows_updated = ROW_COUNT;
    
    RAISE NOTICE 'Rows updated: %', v_rows_updated;
    
    IF v_rows_updated = 0 THEN
        RAISE NOTICE '❌ UPDATE FAILED - No rows were updated!';
        RAISE NOTICE 'Possible reasons:';
        RAISE NOTICE '1. Request is not in pending status';
        RAISE NOTICE '2. Request already has an assigned mechanic';
        RAISE NOTICE '3. Request ID does not exist';
        RAISE NOTICE '4. RLS policy is blocking the update';
    ELSE
        RAISE NOTICE '✅ UPDATE SUCCESSFUL - % rows updated', v_rows_updated;
    END IF;
    
    -- Rollback so we don't actually assign the request
    RAISE EXCEPTION 'Rolling back test...';
END $$;

-- Check the current RLS policies on service_requests
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies
WHERE tablename = 'service_requests'
AND cmd = 'UPDATE';
