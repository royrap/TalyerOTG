# QR Verification Troubleshooting Guide

## Current Issue: QR Verification Failed

### Most Likely Causes:

1. **Missing `job_completion_codes` table** - The QR system relies on this table
2. **Data mismatch** - Service request IDs or user IDs don't match
3. **Payment status issues** - QR generation requires completed payment
4. **Database permissions** - RLS policies might be blocking access

## Step-by-Step Fix:

### 1. Deploy Database Schema (CRITICAL)
First, run the `DATABASE_SCHEMA_VALIDATION.sql` script in your Supabase SQL Editor:
- This creates the missing `job_completion_codes` table
- Adds all required columns to existing tables
- Sets up proper RLS policies

### 2. Check QR Debug Screen
Access the QR Debug screen via:
- Talyer Owner Dashboard → ⋮ menu → "QR Debug"

### 3. Test QR Generation and Verification
In the debug screen:
1. Enter a test request ID (e.g., "test-123")
2. Click "Generate QR" 
3. Click "Test Verify"
4. Check the debug output

### 4. Common Issues and Solutions:

#### Issue: "job_completion_codes table NOT found"
**Solution:** Deploy the DATABASE_SCHEMA_VALIDATION.sql script

#### Issue: "Payment must be completed before generating QR code"
**Solution:** Ensure the invoice has a `paid_at` timestamp:
```sql
UPDATE invoices 
SET paid_at = now(), status = 'paid' 
WHERE request_id = 'YOUR_REQUEST_ID';
```

#### Issue: "QR code belongs to different request"
**Solution:** The QR was generated for a different service request

#### Issue: "QR code already used"
**Solution:** Generate a new QR code - each QR can only be used once

#### Issue: "QR code expired"
**Solution:** Generate a new QR code (current expiry is 24 hours)

### 5. Manual Database Checks:

Check if table exists:
```sql
SELECT table_name FROM information_schema.tables 
WHERE table_name = 'job_completion_codes';
```

Check QR codes:
```sql
SELECT * FROM job_completion_codes 
ORDER BY created_at DESC LIMIT 10;
```

Check service requests:
```sql
SELECT id, status, customer_id FROM service_requests 
ORDER BY created_at DESC LIMIT 10;
```

Check invoices:
```sql
SELECT request_id, status, paid_at FROM invoices 
ORDER BY created_at DESC LIMIT 10;
```

### 6. Generate Test Data:

If no real data exists, create test data:
```sql
-- Create test service request
INSERT INTO service_requests (id, customer_id, title, status, pickup_latitude, pickup_longitude)
VALUES ('test-123', auth.uid(), 'Test Service', 'in_progress', 14.5995, 120.9842);

-- Create test invoice
INSERT INTO invoices (request_id, customer_id, provider_id, subtotal, total_amount, provider_net_amount, status, paid_at)
VALUES ('test-123', auth.uid(), (SELECT id FROM service_providers WHERE user_id = auth.uid() LIMIT 1), 100, 100, 100, 'paid', now());
```

### 7. Emergency Fix:

If QR system still fails, use admin completion:
```dart
await QRCodeService.instance.adminCompleteJob('YOUR_REQUEST_ID', 'ADMIN_USER_ID');
```

## Verification Steps:

1. ✅ Deploy DATABASE_SCHEMA_VALIDATION.sql
2. ✅ Check QR Debug screen shows "table exists"
3. ✅ Generate test QR code successfully
4. ✅ Verify test QR code successfully
5. ✅ Check real service request has proper payment status

## Next Actions:

1. **IMMEDIATE**: Deploy the database schema
2. **TEST**: Use QR Debug screen to verify functionality
3. **VERIFY**: Test with real service request
4. **MONITOR**: Check debug logs for specific error messages

The root cause is most likely the missing `job_completion_codes` table. Once the database schema is deployed, the QR system should work properly.
