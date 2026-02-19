-- Migration: Backfill service_requests.shop_id from preferred_shop_id, add FK if missing, drop broad ALL policy, and verification queries
-- Run this in Supabase SQL editor as an admin.

BEGIN;

-- 1) Backfill existing rows: copy preferred_shop_id -> shop_id for shop_based requests where shop_id is null
UPDATE public.service_requests
SET shop_id = preferred_shop_id
WHERE shop_id IS NULL
  AND preferred_shop_id IS NOT NULL
  AND request_type = 'shop_based';

-- 2) Add FK constraint if not present (safe check)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints tc
    WHERE tc.constraint_name = 'service_requests_shop_id_fkey' AND tc.table_schema = 'public'
  ) THEN
    ALTER TABLE public.service_requests
      ADD CONSTRAINT service_requests_shop_id_fkey FOREIGN KEY (shop_id) REFERENCES public.shops(id);
  END IF;
END;
$$ LANGUAGE plpgsql;

-- 3) Ensure there is an index on shop_id for performance
CREATE INDEX IF NOT EXISTS idx_service_requests_shop_id ON public.service_requests (shop_id);

-- 4) Remove overly-broad RLS policy (if present) that grants ALL to authenticated users
-- Many times a policy named like 'service_request_access' with command=ALL for role=authenticated will bypass intended restrictions.
DROP POLICY IF EXISTS service_request_access ON public.service_requests;

-- 5) (Optional) Re-enable/confirm RLS is enabled
ALTER TABLE IF EXISTS public.service_requests ENABLE ROW LEVEL SECURITY;

COMMIT;

-- ==============================================
-- Verification queries (run as admin; replace IDs)
-- ==============================================

-- Inspect the problematic request
SELECT id, request_type, shop_id, preferred_shop_id, status, broadcast_status, is_broadcast_request
FROM public.service_requests
WHERE id = '7ba7a353-0f51-4759-ab1b-39d1c1727007';

-- Inspect routing/broadcast records for the request
SELECT * FROM public.request_routing WHERE request_id = '7ba7a353-0f51-4759-ab1b-39d1c1727007';
SELECT * FROM public.request_broadcasts WHERE request_id = '7ba7a353-0f51-4759-ab1b-39d1c1727007';

-- Check shop_mechanics membership for the mechanic
SELECT * FROM public.shop_mechanics WHERE mechanic_id = 'e4cbf14b-5729-45ef-a124-1f2e05acad8c';

-- See what shop_id the mechanic belongs to (if using service_providers or mechanics table)
SELECT sp.id, sp.user_id, sp.shop_id FROM public.service_providers sp WHERE sp.user_id = 'e4cbf14b-5729-45ef-a124-1f2e05acad8c';
SELECT m.id, m.user_id, m.shop_id FROM public.mechanics m WHERE m.user_id = 'e4cbf14b-5729-45ef-a124-1f2e05acad8c';

-- Quick query: pending shop_based requests for the mechanic's shop
-- Replace <MECHANIC_SHOP_ID> with the shop_id you found for the mechanic
-- SELECT * FROM public.service_requests WHERE request_type = 'shop_based' AND shop_id = '<MECHANIC_SHOP_ID>' AND status = 'pending';

-- Check policies defined on the table (Supabase/Postgres helper view)
-- Note: if this view is not available in your Postgres, use the Supabase dashboard Policies UI
SELECT * FROM pg_policies WHERE schemaname = 'public' AND tablename = 'service_requests';

-- End of migration
