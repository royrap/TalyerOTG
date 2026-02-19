-- ========================================
-- 🔍 DIAGNOSE CUSTOMER INVOICE APP QUERY
-- ========================================
-- Test the exact query the app is using

-- 1. Test the app's exact query structure
DO $$
DECLARE
    v_customer_id uuid := '1779a3d6-7308-45ec-aeae-cc3909d6cc03';
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE '🔍 TESTING APP QUERY STRUCTURE';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Customer ID: %', v_customer_id;
    RAISE NOTICE '';
END $$;

-- 2. Test simple invoice query (should work)
SELECT 
    id,
    invoice_number,
    status,
    total_amount
FROM invoices
WHERE customer_id = '1779a3d6-7308-45ec-aeae-cc3909d6cc03';

-- 3. Test with service_requests join (may fail)
SELECT 
    i.id,
    i.invoice_number,
    i.status,
    i.total_amount,
    sr.service_type,
    sr.pickup_address
FROM invoices i
INNER JOIN service_requests sr ON sr.id = i.request_id
WHERE i.customer_id = '1779a3d6-7308-45ec-aeae-cc3909d6cc03';

-- 4. Test with service_providers join (app's query)
SELECT 
    i.id,
    i.invoice_number,
    i.status,
    i.total_amount,
    sr.service_type,
    sr.pickup_address,
    sp.id as provider_id,
    up.first_name,
    up.last_name,
    up.phone_number
FROM invoices i
INNER JOIN service_requests sr ON sr.id = i.request_id
INNER JOIN service_providers sp ON sp.id = i.provider_id
INNER JOIN user_profiles up ON up.id = sp.user_id
WHERE i.customer_id = '1779a3d6-7308-45ec-aeae-cc3909d6cc03';

-- 5. Check if provider_id exists in invoices
SELECT 
    i.id,
    i.invoice_number,
    i.request_id,
    i.provider_id,
    i.customer_id,
    i.talyer_owner_id,
    i.mechanic_id
FROM invoices i
WHERE i.customer_id = '1779a3d6-7308-45ec-aeae-cc3909d6cc03';

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE '💡 ANALYSIS:';
    RAISE NOTICE 'If query 2 works but 3 or 4 fails:';
    RAISE NOTICE '  → RLS policy blocking service_requests or service_providers';
    RAISE NOTICE 'If query 5 shows NULL provider_id:';
    RAISE NOTICE '  → Invoice missing provider_id (JOIN fails)';
    RAISE NOTICE '========================================';
END $$;
