-- ========================================
-- 🔍 DIAGNOSE CUSTOMER INVOICE RLS ISSUE
-- ========================================

-- 1. Check RLS policies on invoices table
SELECT 
    policyname,
    cmd as command,
    qual as using_expression
FROM pg_policies
WHERE tablename = 'invoices'
ORDER BY policyname;

-- 2. Check if customer can query their own invoices
-- Replace with actual customer ID
DO $$
DECLARE
    v_customer_id uuid := '1779a3d6-7308-45ec-aeae-cc3909d6cc03';  -- Replace with actual
    invoice_count integer;
BEGIN
    -- Count invoices for customer
    SELECT COUNT(*) INTO invoice_count
    FROM invoices
    WHERE customer_id = v_customer_id;
    
    RAISE NOTICE '========================================';
    RAISE NOTICE '📊 CUSTOMER INVOICE DIAGNOSTIC';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Customer ID: %', v_customer_id;
    RAISE NOTICE 'Total invoices: %', invoice_count;
    RAISE NOTICE '';
END $$;

-- 3. Check service_requests policies (invoices join with service_requests)
SELECT 
    policyname,
    cmd as command
FROM pg_policies
WHERE tablename = 'service_requests'
  AND policyname LIKE '%allow%'
ORDER BY policyname;

-- 4. Check service_providers policies (invoices join with service_providers)
SELECT 
    policyname,
    cmd as command
FROM pg_policies
WHERE tablename = 'service_providers'
  AND policyname LIKE '%allow%'
ORDER BY policyname;

-- 5. Test a sample query similar to what the app does
SELECT 
    i.id,
    i.status,
    i.total_amount,
    sr.service_type,
    sr.pickup_address
FROM invoices i
INNER JOIN service_requests sr ON sr.id = i.request_id
INNER JOIN service_providers sp ON sp.id = i.provider_id
WHERE i.customer_id = '1779a3d6-7308-45ec-aeae-cc3909d6cc03'  -- Replace
LIMIT 5;

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE '⚠️  COMMON ISSUES:';
    RAISE NOTICE '1. Infinite recursion in service_requests policies';
    RAISE NOTICE '2. RLS blocking service_providers join';
    RAISE NOTICE '3. Missing _allow_all policies';
    RAISE NOTICE '';
    RAISE NOTICE 'Check if *_allow_all policies exist and are PERMISSIVE!';
    RAISE NOTICE '========================================';
END $$;
