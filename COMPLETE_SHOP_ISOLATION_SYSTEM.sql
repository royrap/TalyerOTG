-- =========================================================================
-- COMPLETE SHOP-BASED ISOLATION SYSTEM (Angkas-Style)
-- =========================================================================
-- Like Angkas: Customer selects Shop A → ONLY Shop A mechanics see and accept
-- Manual acceptance: First mechanic to click "Accept" wins
-- Decline behavior: Request stays visible to other mechanics
-- =========================================================================

-- =========================================================================
-- PART 1: ROW-LEVEL SECURITY (RLS) POLICIES
-- =========================================================================
-- Ensures database-level shop isolation

-- Enable RLS on service_requests
ALTER TABLE service_requests ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if any
DROP POLICY IF EXISTS shop_isolation_select_policy ON service_requests;
DROP POLICY IF EXISTS shop_isolation_update_policy ON service_requests;
DROP POLICY IF EXISTS customer_create_policy ON service_requests;
DROP POLICY IF EXISTS customer_view_own_requests ON service_requests;

-- ✅ POLICY 1: Mechanics can ONLY see requests from their own shop
CREATE POLICY shop_isolation_select_policy
ON service_requests
FOR SELECT
TO authenticated
USING (
    -- Customers can see their own requests
    (auth.uid() = customer_id)
    OR
    -- Mechanics can ONLY see requests where shop_id matches their shop
    (
        request_type = 'shop_based'
        AND EXISTS (
            SELECT 1 
            FROM mechanics m
            INNER JOIN shop_mechanics sm ON sm.mechanic_id = m.id
            WHERE m.user_id = auth.uid()
            AND sm.shop_id = service_requests.shop_id
            AND sm.is_active = true
        )
    )
    OR
    -- Broadcast requests visible to all mechanics
    (
        request_type IN ('broadcast', 'direct_mechanic')
        AND EXISTS (
            SELECT 1 FROM mechanics m
            WHERE m.user_id = auth.uid()
        )
    )
);

-- ✅ POLICY 2: Only mechanics from the SAME shop can update (accept) shop-based requests
CREATE POLICY shop_isolation_update_policy
ON service_requests
FOR UPDATE
TO authenticated
USING (
    -- Customers can update their own pending requests
    (auth.uid() = customer_id AND status IN ('pending', 'awaiting_payment'))
    OR
    -- Mechanics can ONLY update requests from their shop
    (
        request_type = 'shop_based'
        AND EXISTS (
            SELECT 1 
            FROM mechanics m
            INNER JOIN shop_mechanics sm ON sm.mechanic_id = m.id
            WHERE m.user_id = auth.uid()
            AND sm.shop_id = service_requests.shop_id
            AND sm.is_active = true
        )
    )
    OR
    -- Broadcast requests can be updated by any mechanic
    (
        request_type IN ('broadcast', 'direct_mechanic')
        AND EXISTS (
            SELECT 1 FROM mechanics m
            WHERE m.user_id = auth.uid()
        )
    )
)
WITH CHECK (
    -- Same conditions for the new values after update
    (auth.uid() = customer_id)
    OR
    EXISTS (
        SELECT 1 
        FROM mechanics m
        INNER JOIN shop_mechanics sm ON sm.mechanic_id = m.id
        WHERE m.user_id = auth.uid()
        AND sm.shop_id = service_requests.shop_id
        AND sm.is_active = true
    )
);

-- ✅ POLICY 3: Customers can create requests
CREATE POLICY customer_create_policy
ON service_requests
FOR INSERT
TO authenticated
WITH CHECK (
    auth.uid() = customer_id
);

-- =========================================================================
-- PART 2: ACCEPT REQUEST FUNCTION (with Shop Isolation)
-- =========================================================================

DROP FUNCTION IF EXISTS accept_shop_request(UUID, UUID);

CREATE OR REPLACE FUNCTION accept_shop_request(
    p_request_id UUID,
    p_mechanic_user_id UUID
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_mechanic_id UUID;
    v_mechanic_shop_id UUID;
    v_request_shop_id UUID;
    v_request_status TEXT;
    v_rows_updated INT;
    v_result JSON;
BEGIN
    RAISE NOTICE '🔧 Accept request started - Request: %, Mechanic User: %', p_request_id, p_mechanic_user_id;
    
    -- Step 1: Get mechanic ID and shop ID
    SELECT m.id, sm.shop_id
    INTO v_mechanic_id, v_mechanic_shop_id
    FROM mechanics m
    INNER JOIN shop_mechanics sm ON sm.mechanic_id = m.id
    WHERE m.user_id = p_mechanic_user_id
    AND sm.is_active = true
    LIMIT 1;
    
    IF v_mechanic_id IS NULL THEN
        RAISE EXCEPTION 'Mechanic not found or not assigned to any shop';
    END IF;
    
    IF v_mechanic_shop_id IS NULL THEN
        RAISE EXCEPTION 'Mechanic not assigned to any shop';
    END IF;
    
    RAISE NOTICE '✅ Mechanic found - ID: %, Shop: %', v_mechanic_id, v_mechanic_shop_id;
    
    -- Step 2: Get request details and validate shop
    SELECT shop_id, status
    INTO v_request_shop_id, v_request_status
    FROM service_requests
    WHERE id = p_request_id;
    
    IF v_request_shop_id IS NULL THEN
        RAISE EXCEPTION 'Service request not found';
    END IF;
    
    RAISE NOTICE 'ℹ️ Request Shop: %, Status: %', v_request_shop_id, v_request_status;
    
    -- Step 3: ✅ SHOP ISOLATION CHECK
    IF v_request_shop_id != v_mechanic_shop_id THEN
        RAISE EXCEPTION 'Shop isolation violation: Mechanic shop (%) does not match request shop (%)', 
            v_mechanic_shop_id, v_request_shop_id;
    END IF;
    
    RAISE NOTICE '✅ Shop validation passed';
    
    -- Step 4: Check if request is still available
    IF v_request_status NOT IN ('pending', 'ready_to_assign', 'awaiting_payment') THEN
        RAISE EXCEPTION 'Request no longer available (status: %)', v_request_status;
    END IF;
    
    -- Step 5: ✅ ATOMIC UPDATE with shop validation (prevent race condition)
    UPDATE service_requests
    SET 
        assigned_mechanic_id = p_mechanic_user_id,
        status = 'assigned',
        accepted_at = NOW(),
        updated_at = NOW()
    WHERE id = p_request_id
    AND shop_id = v_mechanic_shop_id  -- ✅ Double-check shop match
    AND status IN ('pending', 'ready_to_assign', 'awaiting_payment')
    AND (assigned_mechanic_id IS NULL OR assigned_mechanic_id = p_mechanic_user_id);
    
    GET DIAGNOSTICS v_rows_updated = ROW_COUNT;
    
    IF v_rows_updated = 0 THEN
        RAISE EXCEPTION 'Request was already accepted by another mechanic or shop validation failed';
    END IF;
    
    RAISE NOTICE '✅ Request accepted successfully';
    
    -- Return success response
    v_result := json_build_object(
        'success', true,
        'message', 'Request accepted successfully',
        'request_id', p_request_id,
        'mechanic_id', v_mechanic_id,
        'shop_id', v_mechanic_shop_id
    );
    
    RETURN v_result;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE '❌ Error in accept_shop_request: %', SQLERRM;
        RETURN json_build_object(
            'success', false,
            'error', SQLERRM
        );
END;
$$;

GRANT EXECUTE ON FUNCTION accept_shop_request(UUID, UUID) TO authenticated;

-- =========================================================================
-- PART 3: DECLINE REQUEST FUNCTION (Local filter only)
-- =========================================================================
-- Note: Decline doesn't update database - it's a local filter on client side
-- This function just validates the mechanic CAN see the request

DROP FUNCTION IF EXISTS can_decline_request(UUID, UUID);

CREATE OR REPLACE FUNCTION can_decline_request(
    p_request_id UUID,
    p_mechanic_user_id UUID
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_mechanic_shop_id UUID;
    v_request_shop_id UUID;
BEGIN
    -- Get mechanic's shop
    SELECT sm.shop_id
    INTO v_mechanic_shop_id
    FROM mechanics m
    INNER JOIN shop_mechanics sm ON sm.mechanic_id = m.id
    WHERE m.user_id = p_mechanic_user_id
    AND sm.is_active = true
    LIMIT 1;
    
    IF v_mechanic_shop_id IS NULL THEN
        RETURN false;
    END IF;
    
    -- Get request's shop
    SELECT shop_id
    INTO v_request_shop_id
    FROM service_requests
    WHERE id = p_request_id;
    
    IF v_request_shop_id IS NULL THEN
        RETURN false;
    END IF;
    
    -- Check if shops match
    RETURN v_mechanic_shop_id = v_request_shop_id;
END;
$$;

GRANT EXECUTE ON FUNCTION can_decline_request(UUID, UUID) TO authenticated;

-- =========================================================================
-- PART 4: HELPER FUNCTIONS
-- =========================================================================

-- Get mechanic's shop ID
DROP FUNCTION IF EXISTS get_mechanic_shop_id(UUID);

CREATE OR REPLACE FUNCTION get_mechanic_shop_id(p_mechanic_user_id UUID)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_shop_id UUID;
BEGIN
    SELECT sm.shop_id
    INTO v_shop_id
    FROM mechanics m
    INNER JOIN shop_mechanics sm ON sm.mechanic_id = m.id
    WHERE m.user_id = p_mechanic_user_id
    AND sm.is_active = true
    LIMIT 1;
    
    RETURN v_shop_id;
END;
$$;

GRANT EXECUTE ON FUNCTION get_mechanic_shop_id(UUID) TO authenticated;

-- Check if mechanic belongs to shop
DROP FUNCTION IF EXISTS mechanic_belongs_to_shop(UUID, UUID);

CREATE OR REPLACE FUNCTION mechanic_belongs_to_shop(
    p_mechanic_user_id UUID,
    p_shop_id UUID
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1
        FROM mechanics m
        INNER JOIN shop_mechanics sm ON sm.mechanic_id = m.id
        WHERE m.user_id = p_mechanic_user_id
        AND sm.shop_id = p_shop_id
        AND sm.is_active = true
    );
END;
$$;

GRANT EXECUTE ON FUNCTION mechanic_belongs_to_shop(UUID, UUID) TO authenticated;

-- =========================================================================
-- PART 5: INDEXES FOR PERFORMANCE
-- =========================================================================

CREATE INDEX IF NOT EXISTS idx_service_requests_shop_id_status 
ON service_requests(shop_id, status) 
WHERE request_type = 'shop_based';

CREATE INDEX IF NOT EXISTS idx_shop_mechanics_shop_mechanic 
ON shop_mechanics(shop_id, mechanic_id) 
WHERE is_active = true;

CREATE INDEX IF NOT EXISTS idx_mechanics_user_id 
ON mechanics(user_id);

-- =========================================================================
-- VERIFICATION QUERIES
-- =========================================================================

-- Check RLS is enabled
SELECT 
    schemaname, 
    tablename, 
    rowsecurity as rls_enabled
FROM pg_tables
WHERE tablename = 'service_requests';

-- Check policies exist
SELECT 
    policyname,
    cmd as operation,
    qual as using_expression
FROM pg_policies
WHERE tablename = 'service_requests'
ORDER BY policyname;

-- Test shop assignment
SELECT 
    m.id as mechanic_id,
    m.user_id,
    up.first_name || ' ' || up.last_name as mechanic_name,
    s.id as shop_id,
    s.shop_name,
    sm.is_active
FROM mechanics m
INNER JOIN user_profiles up ON m.user_id = up.id
LEFT JOIN shop_mechanics sm ON sm.mechanic_id = m.id
LEFT JOIN shops s ON s.id = sm.shop_id
ORDER BY s.shop_name, up.first_name;

-- =========================================================================
-- TESTING SCENARIOS
-- =========================================================================

/*
TEST 1: Check if mechanic can see shop-based request
-------------------------------------------------------
1. Login as Mechanic A (Shop A)
2. Customer creates request for Shop A
3. Mechanic A should see request ✅
4. Mechanic B (Shop B) should NOT see request ❌

TEST 2: Accept request (same shop)
-----------------------------------
SELECT accept_shop_request(
    'REQUEST_ID'::uuid,
    'MECHANIC_USER_ID'::uuid  -- Must be from same shop
);
-- Expected: {"success": true, ...}

TEST 3: Accept request (different shop) - SHOULD FAIL
-------------------------------------------------------
SELECT accept_shop_request(
    'REQUEST_ID'::uuid,  -- Shop A request
    'MECHANIC_USER_ID'::uuid  -- Shop B mechanic
);
-- Expected: ERROR: Shop isolation violation

TEST 4: Decline behavior
-------------------------
1. Mechanic clicks "Decline"
2. Request disappears from THAT mechanic's view (client-side filter)
3. Request stays in database with status 'ready_to_assign'
4. Other mechanics from same shop can still see it ✅

TEST 5: Race condition (two mechanics accept simultaneously)
-------------------------------------------------------------
-- Both mechanics click Accept at same time
-- ONLY ONE will succeed (atomic UPDATE with WHERE conditions)
-- Other will get: "Request was already accepted by another mechanic"
*/

-- =========================================================================
-- SUCCESS MESSAGE
-- =========================================================================

SELECT '✅ Shop isolation system complete!' as status;
SELECT '✅ RLS policies active' as rls_status;
SELECT '✅ Accept/Decline functions ready' as functions_status;
SELECT 'Run ASSIGN_MECHANIC_TO_MECHAIDSUPPLY.sql next' as next_step;

/*
DEPLOYMENT ORDER:
================
1. ✅ Run THIS FILE (COMPLETE_SHOP_ISOLATION_SYSTEM.sql)
2. ✅ Run ASSIGN_MECHANIC_TO_MECHAIDSUPPLY.sql
3. ✅ Run FIX_SHOP_ISOLATION_COMPLETE.sql (for get_nearby_requests function)
4. ✅ Restart Flutter app
5. ✅ Test shop-based request flow

EXPECTED BEHAVIOR:
==================
✅ Customer selects Shop A
✅ Request saved with shop_id = 'Shop A ID'
✅ Only Shop A mechanics see the request
✅ Shop B mechanics do NOT see the request
✅ Mechanic clicks Accept → Request assigned
✅ Other mechanics see request disappear instantly
✅ Mechanic clicks Decline → Request stays for others
✅ Race condition handled (only one mechanic wins)
*/
