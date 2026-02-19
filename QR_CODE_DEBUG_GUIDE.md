# QR CODE DEBUGGING GUIDE

## 🔍 Issue Analysis
Your QR codes are always showing "invalid or expired" when scanned. Here's what I've done to help debug this:

## ✅ Changes Made

### 1. Enhanced QR Code Service (`lib/services/qr_code_service.dart`)
- **Added detailed logging** in the `verifyAndProcessQRScan` method
- **Extended QR expiration** from 2 hours to 24 hours for testing
- **Added debug functions**:
  - `debugGetAllQRCodes()` - Shows all QR codes in database
  - `debugCheckTableExists()` - Verifies table exists

### 2. Created QR Debug Screen (`lib/screens/qr_debug_screen.dart`)
- **Database status checker** - Verifies if `job_completion_codes` table exists
- **QR generation tester** - Generate test QR codes
- **QR verification tester** - Test verification logic
- **QR codes list** - View all QR codes with status

### 3. Added Debug Access
- **Added to Talyer Owner menu** - Go to ⋮ menu → "QR Debug"

## 🚀 How to Debug

### Step 1: Access QR Debug Screen
1. Run your Flutter app
2. Login as a Talyer Owner
3. Tap the ⋮ (three dots) menu in the top right
4. Select "QR Debug"

### Step 2: Check Database Status
The debug screen will show:
- ✅ Green check = `job_completion_codes` table exists
- ❌ Red X = Table missing or no access

### Step 3: Test QR Generation
1. Enter any test Request ID (e.g., "test-123")
2. Tap "Generate QR"
3. Check if a QR code is generated

### Step 4: Test QR Verification
1. After generating a QR, tap "Test Verify"
2. Check if verification works

### Step 5: View Detailed Logs
Check your debug console for detailed logs that show:
- What QR codes exist in the database
- Why verification is failing (expired, used, wrong request ID, etc.)

## 🔧 Possible Issues & Solutions

### Issue 1: Table Doesn't Exist
**Symptoms:** Red X in database status
**Solution:** Run the database schema script
```sql
-- Run this in your Supabase SQL editor:
-- File: DATABASE_SCHEMA_VALIDATION.sql
```

### Issue 2: QR Codes Not Being Generated
**Symptoms:** Empty QR codes list
**Solution:** Check these requirements:
- User must be logged in
- Service request must have paid invoice
- Payment status must be completed

### Issue 3: Request ID Mismatch
**Symptoms:** QR exists but verification fails
**Solution:** Ensure the request ID used for generation matches verification

### Issue 4: QR Code Expired
**Symptoms:** QR codes show as "EXPIRED"
**Solution:** Generate new QR codes (now extended to 24 hours)

### Issue 5: Permission Issues
**Symptoms:** Database access errors
**Solution:** Check Row Level Security policies in Supabase

## 📊 Enhanced Logging

The updated QR service now logs:
```
🔍 Verifying QR code: ABC123-4567 for request: req-123
🔍 User ID: user-456
🔍 Service provider ID: provider-789
🔍 Recent QR codes in database:
   Code: ABC123-4567, Request: req-123, Used: false, Expires: 2025-08-13T...
🔍 Found QR record: {completion_code: ABC123-4567, ...}
🔍 QR expires at: 2025-08-13T10:30:00.000Z
🔍 Current time: 2025-08-12T14:25:00.000Z
🔍 Is expired: false
🔍 Is used: false
🔍 QR request ID: req-123
🔍 Expected request ID: req-123
🔍 Request IDs match: true
```

## 🎯 Next Steps

1. **Run the debug screen** and check the database status
2. **Test QR generation** with a simple test ID
3. **Check the console logs** for detailed error information
4. **Report findings** - Tell me what the debug screen shows:
   - Does the table exist?
   - Are QR codes being generated?
   - What error messages appear in the logs?

## 🆘 If Nothing Works

If the debug screen shows the table doesn't exist:
1. **Run database schema script** - `DATABASE_SCHEMA_VALIDATION.sql` in Supabase
2. **Check Supabase permissions** - Ensure your user has access
3. **Try manual QR creation** - Use Supabase SQL editor to insert test data

## 📞 Quick Test Commands

You can also test manually in Supabase SQL editor:

```sql
-- Check if table exists
SELECT * FROM job_completion_codes LIMIT 5;

-- Create a test QR code
INSERT INTO job_completion_codes (
  request_id, customer_id, completion_code, expires_at
) VALUES (
  'test-request-123',
  (SELECT id FROM user_profiles WHERE user_type = 'customer' LIMIT 1),
  'TEST123-4567',
  NOW() + INTERVAL '24 hours'
);

-- Check created QR code
SELECT * FROM job_completion_codes WHERE completion_code = 'TEST123-4567';
```

---

**The debug screen will tell us exactly what's wrong with your QR code system!** 🔧
