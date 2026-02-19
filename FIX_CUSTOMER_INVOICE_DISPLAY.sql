-- ========================================
-- 🔧 FIX CUSTOMER INVOICE DISPLAY
-- ========================================
-- Issue: Customers cannot see their invoices due to RLS blocking INNER JOINs
-- Solution: Add permissive allow_all policies for invoice-related queries

-- 1. Check current RLS status on invoices table
SELECT tablename, rowsecurity 
FROM pg_tables 
WHERE schemaname = 'public' 
  AND tablename IN ('invoices', 'service_requests', 'service_providers');

-- 2. Add permissive policy for customers to view their own invoices
DROP POLICY IF EXISTS invoices_customer_view ON invoices;
CREATE POLICY invoices_customer_view ON invoices
  FOR SELECT
  USING (
    customer_id = auth.uid() OR
    talyer_owner_id = auth.uid() OR
    mechanic_id = auth.uid()
  );

-- 3. Add permissive policy for service_requests related to invoices
DROP POLICY IF EXISTS service_requests_invoice_view ON service_requests;
CREATE POLICY service_requests_invoice_view ON service_requests
  FOR SELECT
  USING (
    customer_id = auth.uid() OR
    provider_id IN (SELECT id FROM service_providers WHERE user_id = auth.uid()) OR
    assigned_mechanic_id = auth.uid() OR
    shop_id IN (SELECT id FROM shops WHERE owner_id = auth.uid())
  );

-- 4. Add permissive policy for service_providers related to invoices
DROP POLICY IF EXISTS service_providers_invoice_view ON service_providers;
CREATE POLICY service_providers_invoice_view ON service_providers
  FOR SELECT
  USING (
    user_id = auth.uid() OR
    talyer_owner_id = auth.uid() OR
    id IN (
      SELECT provider_id 
      FROM service_requests 
      WHERE customer_id = auth.uid()
    )
  );

-- 5. Test query to verify customer can see invoices
-- Replace with actual customer ID
DO $$
DECLARE
    v_customer_id uuid := '1779a3d6-7308-45ec-aeae-cc3909d6cc03';
    invoice_count integer;
BEGIN
    -- Test direct invoice query
    SELECT COUNT(*) INTO invoice_count
    FROM invoices
    WHERE customer_id = v_customer_id;
    
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ CUSTOMER INVOICE FIX VERIFICATION';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Customer ID: %', v_customer_id;
    RAISE NOTICE 'Total invoices (direct query): %', invoice_count;
    
    -- Test complex join query (like app does)
    SELECT COUNT(*) INTO invoice_count
    FROM invoices i
    INNER JOIN service_requests sr ON sr.id = i.request_id
    INNER JOIN service_providers sp ON sp.id = i.provider_id
    WHERE i.customer_id = v_customer_id;
    
    RAISE NOTICE 'Total invoices (with JOINs): %', invoice_count;
    RAISE NOTICE '';
    
    IF invoice_count > 0 THEN
        RAISE NOTICE '✅ SUCCESS: Customer can view invoices!';
    ELSE
        RAISE NOTICE '⚠️  No invoices found for this customer';
    END IF;
    RAISE NOTICE '========================================';
END $$;

-- 6. Show sample invoice data
SELECT 
    i.id,
    i.invoice_number,
    i.status,
    i.total_amount,
    i.generated_at,
    sr.title as service_title,
    sr.status as request_status
FROM invoices i
INNER JOIN service_requests sr ON sr.id = i.request_id
WHERE i.customer_id = '1779a3d6-7308-45ec-aeae-cc3909d6cc03'
ORDER BY i.generated_at DESC
LIMIT 5;

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE '📋 WHAT WAS FIXED:';
    RAISE NOTICE '1. Added invoices_customer_view policy';
    RAISE NOTICE '2. Added service_requests_invoice_view policy';
    RAISE NOTICE '3. Added service_providers_invoice_view policy';
    RAISE NOTICE '';
    RAISE NOTICE '🔄 NEXT STEPS:';
    RAISE NOTICE '1. Hot restart Flutter app';
    RAISE NOTICE '2. Navigate to customer Invoices tab';
    RAISE NOTICE '3. Verify invoices appear correctly';
    RAISE NOTICE '========================================';
END $$;
