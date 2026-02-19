# 🗄️ Supabase Storage Bucket Setup for Cash Payment Verification

## Step-by-Step Setup Guide

### 1. Create Storage Bucket

1. Go to your Supabase Dashboard
2. Navigate to **Storage** (left sidebar)
3. Click **"New Bucket"**
4. Use these settings:
   - **Name**: `payment-verifications`
   - **Public bucket**: ✅ Enable (para ma-access ang images via URL)
   - **File size limit**: 5 MB (recommended)
   - **Allowed MIME types**: `image/jpeg, image/png, image/jpg`

### 2. Create Folder Structure

Supabase will automatically create folders when files are uploaded, but here's the structure:

```
payment-verifications/
├── cash-payments/
│   └── {customer_id}/
│       └── cash_payment_*.jpg
└── receipts/
    └── {customer_id}/
        └── receipt_*.jpg
```

### 3. Set Bucket Policies (RLS - Row Level Security)

Go to **Storage** → **Policies** → Click on `payment-verifications` bucket

#### Policy 1: Allow Authenticated Users to Upload
```sql
-- Policy Name: "Authenticated users can upload"
-- Allowed operation: INSERT
-- Policy definition:

CREATE POLICY "Authenticated users can upload"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'payment-verifications' AND
  (storage.foldername(name))[1] IN ('cash-payments', 'receipts')
);
```

#### Policy 2: Allow Public Read Access
```sql
-- Policy Name: "Public read access"
-- Allowed operation: SELECT
-- Policy definition:

CREATE POLICY "Public read access"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'payment-verifications');
```

#### Policy 3: Allow Users to Update Own Files
```sql
-- Policy Name: "Users can update own files"
-- Allowed operation: UPDATE
-- Policy definition:

CREATE POLICY "Users can update own files"
ON storage.objects FOR UPDATE
TO authenticated
USING (bucket_id = 'payment-verifications');
```

#### Policy 4: Allow Talyer Owner to Delete
```sql
-- Policy Name: "Talyer owners can delete"
-- Allowed operation: DELETE
-- Policy definition:

CREATE POLICY "Talyer owners can delete"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'payment-verifications' AND
  auth.uid() IN (
    SELECT id FROM user_profiles WHERE user_type = 'talyer_owner'
  )
);
```

### 4. Verify Bucket Configuration

Check these settings in Supabase Dashboard:

✅ **Bucket created**: `payment-verifications`
✅ **Public**: Enabled
✅ **Policies**: 4 policies active (upload, read, update, delete)
✅ **File size limit**: 5 MB
✅ **MIME types**: image/jpeg, image/png, image/jpg

### 5. Test Upload (Optional)

You can test by manually uploading a file:

1. Go to **Storage** → `payment-verifications`
2. Click **Upload File**
3. Create folder: `cash-payments/test`
4. Upload a test image
5. Get public URL and verify it works

### 6. Alternative: Simpler Public Bucket (If RLS is complicated)

If you want to simplify (less secure pero easier):

```sql
-- Remove all policies and just allow public access

-- For INSERT (upload)
CREATE POLICY "Anyone can upload"
ON storage.objects FOR INSERT
WITH CHECK (bucket_id = 'payment-verifications');

-- For SELECT (read)
CREATE POLICY "Anyone can read"
ON storage.objects FOR SELECT
USING (bucket_id = 'payment-verifications');
```

⚠️ **Warning**: This allows anyone to upload/read. Use only for development/testing.

### 7. Production-Ready Setup (Recommended)

For production, use stricter policies:

```sql
-- Only allow specific users to upload cash photos
CREATE POLICY "Customers can upload cash payments"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'payment-verifications' AND
  (storage.foldername(name))[1] = 'cash-payments' AND
  (storage.foldername(name))[2] = auth.uid()::text -- Must be their own customer_id
);

-- Only verified users can read
CREATE POLICY "Authenticated users can read"
ON storage.objects FOR SELECT
TO authenticated
USING (
  bucket_id = 'payment-verifications' AND
  (
    -- Customers can see their own
    (storage.foldername(name))[2] = auth.uid()::text OR
    -- Talyer owners can see all
    auth.uid() IN (
      SELECT id FROM user_profiles WHERE user_type = 'talyer_owner'
    ) OR
    -- Admins can see all
    auth.uid() IN (
      SELECT id FROM user_profiles WHERE user_type = 'admin'
    )
  )
);
```

## Testing the Setup

### Test 1: Upload from Flutter
```dart
final service = CashPaymentVerificationService();
final testFile = File('path/to/test/image.jpg');

final url = await service.uploadCashPhoto(
  imageFile: testFile,
  invoiceId: 'test-invoice',
  customerId: 'test-customer',
);

print('Upload successful: $url');
```

### Test 2: Verify Public URL
```dart
// After upload, check if URL is accessible
final publicUrl = supabase.storage
    .from('payment-verifications')
    .getPublicUrl('cash-payments/test-customer/test.jpg');

print('Public URL: $publicUrl');
// Open this URL in browser to verify
```

## Common Issues and Solutions

### Issue 1: "StorageApiError: Bucket not found"
**Solution**: Make sure bucket name is exactly `payment-verifications` (with hyphen, not underscore)

### Issue 2: "Permission denied" when uploading
**Solution**: Check RLS policies are correctly set up and user is authenticated

### Issue 3: "Public URL not accessible"
**Solution**: Ensure "Public bucket" is enabled in bucket settings

### Issue 4: File size too large
**Solution**: 
- Compress image before upload
- Or increase bucket file size limit
- Or implement image compression in Flutter:

```dart
import 'package:image/image.dart' as img;

Future<File> compressImage(File imageFile) async {
  final bytes = await imageFile.readAsBytes();
  final image = img.decodeImage(bytes);
  
  // Resize if too large
  final resized = img.copyResize(image!, width: 1024);
  
  // Compress
  final compressed = img.encodeJpg(resized, quality: 85);
  
  // Save to temp file
  final tempDir = await getTemporaryDirectory();
  final tempFile = File('${tempDir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg');
  await tempFile.writeAsBytes(compressed);
  
  return tempFile;
}
```

## Security Best Practices

1. ✅ **Always authenticate users** before allowing upload
2. ✅ **Validate file types** - only allow images
3. ✅ **Limit file sizes** - prevent abuse (5MB recommended)
4. ✅ **Use unique filenames** - prevent overwrites (use timestamps)
5. ✅ **Organize by user ID** - privacy and organization
6. ✅ **Enable RLS policies** - control who can access what
7. ✅ **Log all uploads** - for audit trail

## Quick Command Reference

### Get Public URL
```dart
final url = supabase.storage
    .from('payment-verifications')
    .getPublicUrl('path/to/file.jpg');
```

### Upload File
```dart
await supabase.storage
    .from('payment-verifications')
    .upload('path/to/file.jpg', file);
```

### Delete File
```dart
await supabase.storage
    .from('payment-verifications')
    .remove(['path/to/file.jpg']);
```

### List Files
```dart
final files = await supabase.storage
    .from('payment-verifications')
    .list(path: 'cash-payments/customer-123');
```

---

## Summary Checklist

Before deploying:
- [ ] Created `payment-verifications` bucket
- [ ] Set bucket to public
- [ ] Configured RLS policies (4 policies)
- [ ] Set file size limit (5MB)
- [ ] Allowed MIME types (jpg, jpeg, png)
- [ ] Tested upload functionality
- [ ] Verified public URLs work
- [ ] Tested from Flutter app

**Status**: 🔄 NEEDS MANUAL SETUP IN SUPABASE
**Priority**: HIGH - Required for cash payment verification feature

**Created**: October 2, 2025
