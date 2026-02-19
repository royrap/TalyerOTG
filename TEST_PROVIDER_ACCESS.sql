-- ========================================
-- 🔍 TEST SPECIFIC PROVIDER ACCESS
-- ========================================
-- Check if customer can access the provider through RLS

-- Test if customer can see this specific provider
SELECT 
    sp.id,
    sp.user_id,
    sp.company_name,
    sp.status
FROM service_providers sp
WHERE sp.id = 'e3bb7f57-45fc-40f4-883c-4705874f84c3';

-- Test if customer can see the mechanic's user profile
SELECT 
    up.id,
    up.first_name,
    up.last_name,
    up.phone_number
FROM user_profiles up
WHERE up.id = 'da0aade5-1e11-4901-898c-3fd67379262f';

-- Test the full query chain (what app does)
SELECT 
    i.id,
    i.invoice_number,
    i.status,
    i.total_amount,
    sr.service_type,
    sr.pickup_address,
    sp.id as provider_id,
    up.first_name,
    up.last_name
FROM invoices i
INNER JOIN service_requests sr ON sr.id = i.request_id
INNER JOIN service_providers sp ON sp.id = i.provider_id
INNER JOIN user_profiles up ON up.id = sp.user_id
WHERE i.customer_id = '1779a3d6-7308-45ec-aeae-cc3909d6cc03';

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE '🔍 DIAGNOSIS:';
    RAISE NOTICE 'If first query returns 0 rows:';
    RAISE NOTICE '  → service_providers RLS blocking access';
    RAISE NOTICE '  → Need to add policy for customers to view their service providers';
    RAISE NOTICE '';
    RAISE NOTICE 'If second query returns 0 rows:';
    RAISE NOTICE '  → user_profiles RLS blocking mechanic profile';
    RAISE NOTICE '  → Should work with existing mechanics_and_customers_view_each_other policy';
    RAISE NOTICE '';
    RAISE NOTICE 'If third query returns 0 rows but first two work:';
    RAISE NOTICE '  → Check service_requests RLS policy';
    RAISE NOTICE '========================================';
END $$;
