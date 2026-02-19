-- ============================================================
-- VERIFY SIMPLIFIED PAYMENT FLOW SETUP
-- ============================================================
-- This script verifies that all database components are ready
-- for the simplified payment flow (Online + Cash with camera)
-- ============================================================

-- 1. Check if cash_payment_verifications table exists
SELECT 
    'cash_payment_verifications' as table_name,
    EXISTS (
        SELECT FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'cash_payment_verifications'
    ) as table_exists;

-- 2. Check cash_payment_verifications table structure
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'cash_payment_verifications'
ORDER BY ordinal_position;

-- 3. Verify invoices table has payment_status column
SELECT 
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_name = 'invoices' 
AND column_name = 'payment_status';

-- 4. Check current cash payment verification records
SELECT 
    COUNT(*) as total_cash_verifications,
    COUNT(CASE WHEN status = 'pending_verification' THEN 1 END) as pending_count,
    COUNT(CASE WHEN status = 'verified' THEN 1 END) as verified_count,
    COUNT(CASE WHEN status = 'rejected' THEN 1 END) as rejected_count
FROM cash_payment_verifications;

-- 5. Check invoices with cash payment status
SELECT 
    payment_status,
    COUNT(*) as count
FROM invoices
WHERE payment_status IN ('pending_cash_verification', 'cash_verified', 'cash_rejected')
GROUP BY payment_status;

-- 6. Check storage buckets (if you have access)
-- Note: This may not work depending on your RLS policies
SELECT 
    id,
    name,
    public
FROM storage.buckets
WHERE name = 'payment_verifications';

-- 7. Check RLS policies on cash_payment_verifications
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual
FROM pg_policies
WHERE tablename = 'cash_payment_verifications';

-- 8. Check storage policies for payment_verifications bucket
SELECT 
    name as policy_name,
    operation,
    definition
FROM storage.policies
WHERE bucket_id = 'payment_verifications'
ORDER BY name;

-- 9. Sample query to see recent cash payment verifications
SELECT 
    cpv.id,
    cpv.invoice_id,
    cpv.customer_id,
    cpv.amount,
    cpv.status,
    cpv.cash_photo_url,
    cpv.created_at,
    i.total as invoice_total,
    i.payment_status as invoice_payment_status
FROM cash_payment_verifications cpv
LEFT JOIN invoices i ON i.id = cpv.invoice_id
ORDER BY cpv.created_at DESC
LIMIT 10;

-- 10. Check if any invoices are ready for cash payment
SELECT 
    i.id,
    i.request_id,
    i.customer_id,
    i.total,
    i.payment_status,
    i.status as invoice_status,
    sr.status as request_status
FROM invoices i
LEFT JOIN service_requests sr ON sr.id = i.request_id
WHERE i.payment_status IN ('pending', 'unpaid')
AND i.status = 'accepted'
ORDER BY i.created_at DESC
LIMIT 5;

-- ============================================================
-- MANUAL TESTING SCRIPT
-- ============================================================
-- Use this to manually insert a test cash payment verification

-- EXAMPLE: Insert test cash payment verification
-- Uncomment and replace with actual values to test:

/*
INSERT INTO cash_payment_verifications (
    invoice_id,
    request_id,
    customer_id,
    cash_photo_url,
    amount,
    status,
    created_at
) VALUES (
    'your-invoice-id-here',
    'your-request-id-here',
    'your-customer-id-here',
    'https://your-supabase-url.com/storage/v1/object/public/payment_verifications/cash_payments/test_photo.jpg',
    1500.00,
    'pending_verification',
    NOW()
) RETURNING *;
*/

-- EXAMPLE: Update invoice to pending_cash_verification
-- Uncomment and replace with actual invoice_id:

/*
UPDATE invoices
SET 
    payment_status = 'pending_cash_verification',
    updated_at = NOW()
WHERE id = 'your-invoice-id-here'
RETURNING *;
*/

-- ============================================================
-- CLEANUP SCRIPT (USE WITH CAUTION)
-- ============================================================
-- Use this to clean up test data if needed

-- EXAMPLE: Delete test cash payment verifications
-- Uncomment to use:

/*
DELETE FROM cash_payment_verifications
WHERE created_at > NOW() - INTERVAL '1 hour'
AND status = 'pending_verification';
*/

-- EXAMPLE: Reset invoice payment status
-- Uncomment and replace with actual invoice_id:

/*
UPDATE invoices
SET 
    payment_status = 'pending',
    updated_at = NOW()
WHERE id = 'your-invoice-id-here';
*/

-- ============================================================
-- EXPECTED RESULTS CHECKLIST
-- ============================================================

/*
✅ Query 1: table_exists should be TRUE
✅ Query 2: Should show columns:
   - id (uuid)
   - invoice_id (uuid)
   - payment_id (uuid)
   - request_id (uuid)
   - customer_id (uuid)
   - mechanic_id (uuid)
   - receipt_photo_url (text)
   - cash_photo_url (text)
   - amount (numeric)
   - status (text)
   - verified_at (timestamp)
   - verified_by (uuid)
   - notes (text)
   - created_at (timestamp)
   - updated_at (timestamp)

✅ Query 3: Should show payment_status column exists in invoices table

✅ Query 4: Should show counts of cash verifications by status

✅ Query 5: Should show count of invoices with cash payment statuses

✅ Query 6: Should show payment_verifications bucket (public=true)

✅ Query 7: Should show RLS policies for cash_payment_verifications

✅ Query 8: Should show storage policies for uploads and selects

✅ Query 9: Should show recent cash payment verification records

✅ Query 10: Should show invoices ready for payment
*/

-- ============================================================
-- END OF VERIFICATION SCRIPT
-- ============================================================
