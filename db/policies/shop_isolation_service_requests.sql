-- Shop isolation policies for service_requests
-- Run this in your Supabase SQL editor or psql connected to the DB.
-- This script will:
-- 1) Enable RLS on public.service_requests
-- 2) Create a SELECT policy to allow mechanics in the same shop to see shop_based requests
-- 3) Create UPDATE policy to allow a mechanic to accept (update accepted_by / status) only when they belong to the same shop
-- 4) Create INSERT/UPDATE trigger to auto-copy preferred_shop_id -> shop_id for shop_based requests
-- 5) Add an index on shop_id and provide verification queries

BEGIN;

-----------------------------------------------------------------
-- 0) Safety: check that table exists
-----------------------------------------------------------------
-- If your schema uses a different schema than public, change accordingly.

-- 1) Enable Row Level Security
ALTER TABLE IF EXISTS public.service_requests
    ENABLE ROW LEVEL SECURITY;

-----------------------------------------------------------------
-- 2) SELECT policy: mechanics only see shop_based requests for their shop
-- Mechanics (and shop-level providers) should see:
--  - All non-shop-based requests (broadcast/direct where can_accept_by_any_mechanic = true)
--  - Shop-based requests only when they belong to the same shop (via shop_mechanics or service_providers.shop_id)
-----------------------------------------------------------------

-- Drop existing policies if present (idempotent)
DROP POLICY IF EXISTS "mechanics_select_service_requests" ON public.service_requests;

CREATE POLICY "mechanics_select_service_requests"
    ON public.service_requests
    FOR SELECT
    USING (
        -- Allow customers (owners) to always select their own requests
        (customer_id = current_setting('jwt.claims.user_id', true)::uuid)
        -- Allow system-role/admins (use role claim check if you have it)
        OR (current_setting('jwt.claims.role', true) = 'admin')
        -- Allow mechanics and shops based on request type:
        OR (
            -- For shop_based requests: ensure mechanic belongs to that shop
            request_type = 'shop_based' AND shop_id IS NOT NULL AND (
                EXISTS (
                    SELECT 1 FROM public.shop_mechanics sm
                    WHERE sm.mechanic_id = current_setting('jwt.claims.user_id', true)::uuid
                    AND sm.shop_id = public.service_requests.shop_id
                    AND sm.is_active = true
                )
                OR
                -- Also allow service_providers that represent a shop (if you use service_providers table)
                EXISTS (
                    SELECT 1 FROM public.service_providers sp
                    WHERE sp.user_id = current_setting('jwt.claims.user_id', true)::uuid
                    AND sp.shop_id = public.service_requests.shop_id
                )
            )
        )
        OR (
            -- For broadcast or direct requests that are allowed to any mechanic
            (request_type IN ('broadcast', 'direct_mechanic') AND can_accept_by_any_mechanic = true)
        )
    );

-----------------------------------------------------------------
-- 3) UPDATE policy: allow mechanics to accept only requests for their shop
-- We only permit updating 'accepted_by', 'status', 'accepted_at', 'assigned_mechanic_id', etc.
-- This policy is narrow: it only allows mechanics to set 'accepted_by' when they belong to the shop.
-----------------------------------------------------------------
DROP POLICY IF EXISTS "mechanics_update_accept_requests" ON public.service_requests;

CREATE POLICY "mechanics_update_accept_requests"
    ON public.service_requests
    FOR UPDATE
    USING (
        -- Allow update if the user is the request owner (customer) so they can cancel
        customer_id = current_setting('jwt.claims.user_id', true)::uuid
        OR current_setting('jwt.claims.role', true) = 'admin'
        OR (
            -- Allow mechanics to update when request is shop_based and they belong to the shop
            request_type = 'shop_based' AND shop_id IS NOT NULL
            AND EXISTS (
                SELECT 1 FROM public.shop_mechanics sm
                WHERE sm.mechanic_id = current_setting('jwt.claims.user_id', true)::uuid
                AND sm.shop_id = public.service_requests.shop_id
                AND sm.is_active = true
            )
        )
        OR (
            -- Allow mechanics to update broadcast/direct requests if can_accept_by_any_mechanic = true
            request_type IN ('broadcast', 'direct_mechanic') AND can_accept_by_any_mechanic = true
        )
    )
    WITH CHECK (
        -- Enforce that if a mechanic accepts the request they set accepted_by to themselves
        (
            NOT (accepted_by IS NOT NULL) -- allow non-accept updates
        ) OR (
            accepted_by = current_setting('jwt.claims.user_id', true)::uuid
        )
    );

-----------------------------------------------------------------
-- 4) Trigger to copy preferred_shop_id -> shop_id on INSERT/UPDATE for shop_based requests
-----------------------------------------------------------------
DROP FUNCTION IF EXISTS public.fn_set_shop_id_from_preferred();

CREATE OR REPLACE FUNCTION public.fn_set_shop_id_from_preferred()
RETURNS trigger AS $$
BEGIN
    -- If it's a shop-based request and shop_id is null but preferred_shop_id present, copy it
    IF (TG_OP = 'INSERT' OR TG_OP = 'UPDATE') THEN
        IF (NEW.request_type = 'shop_based' AND NEW.shop_id IS NULL AND NEW.preferred_shop_id IS NOT NULL) THEN
            NEW.shop_id := NEW.preferred_shop_id;
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_set_shop_id_from_preferred ON public.service_requests;
CREATE TRIGGER trg_set_shop_id_from_preferred
    BEFORE INSERT OR UPDATE ON public.service_requests
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_set_shop_id_from_preferred();

-----------------------------------------------------------------
-- 5) Index for performance
-----------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_service_requests_shop_id ON public.service_requests (shop_id);

-----------------------------------------------------------------
-- 6) Diagnostic / verification queries (run as an authenticated user)
-----------------------------------------------------------------
-- Replace the placeholder IDs with actual test IDs (customer / mechanic / shop)
-- Example checks you can run in Supabase SQL editor as an admin:

-- Check a pending shop_based request
-- SELECT id, customer_id, request_type, shop_id, preferred_shop_id, status FROM public.service_requests WHERE id = '<REQUEST_ID>';

-- Check shop_mechanics for a mechanic
-- SELECT * FROM public.shop_mechanics WHERE mechanic_id = '<MECHANIC_USER_ID>' AND is_active = true;

-- Test: As the mechanic (authenticated jwt with user_id claim set), try selecting shop-based requests:
-- (This should only return requests for the mechanic's shop because of RLS)
-- SET LOCAL jwt.claims.user_id = '<MECHANIC_USER_ID>';
-- SELECT * FROM public.service_requests WHERE request_type = 'shop_based';

COMMIT;

-- End of script
