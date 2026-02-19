# Fix: "Unknown Customer" sa Invoice Generation Screen

## 🐛 Problema

Nakikita sa screenshot:
- Invoice screen shows "**Unknown Customer**" sa customer name
- Pero natatanggap naman ng customer ang invoice
- Customer information (first_name, last_name) hindi naka-load

## 🔍 Root Cause

Sa file: `lib/mechanic/widgets/mechanic_job_tracking_bottom_sheet.dart`

**Line 228-232 (BEFORE):**
```dart
final serviceRequest = await SupabaseService.client
    .from('service_requests')
    .select('*')  // ❌ HINDI kasama ang customer info
    .eq('id', widget.serviceRequestId)
    .single();
```

Problem: Query lang ang `service_requests` table WITHOUT joining customer's `user_profiles` table.

## ✅ Solution Applied

### File 1: `mechanic_job_tracking_bottom_sheet.dart` (FIXED ✅)

**Lines 225-270 (AFTER):**
```dart
// Get service request details for invoice screen WITH customer info
final serviceRequest = await SupabaseService.client
    .from('service_requests')
    .select('''
      *,
      customer:user_profiles!service_requests_customer_id_fkey(
        id,
        first_name,
        last_name,
        phone_number,
        email
      )
    ''')
    .eq('id', widget.serviceRequestId)
    .single();

print('📋 Navigating to invoice generation for service: ${widget.serviceRequestId}');
print('👤 Customer info: ${serviceRequest['customer']}');
```

**Changes:**
1. ✅ Added JOIN to `user_profiles` table using foreign key
2. ✅ Fetch customer: first_name, last_name, phone_number, email
3. ✅ Added debug print to verify customer data
4. ✅ Customer data now passed to `EnhancedInvoiceGenerationScreen`

### File 2: `enhanced_invoice_generation_screen.dart` (No change needed)

**Lines 395-435:**
```dart
final customer = widget.jobDetails['customer'] ?? {};
final customerName = '${customer['first_name'] ?? ''} ${customer['last_name'] ?? ''}'.trim();

// Display customer name
Text(
  customerName.isNotEmpty ? customerName : 'Unknown Customer',
  style: const TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
  ),
),
```

This code was already correct. The problem was that `widget.jobDetails['customer']` was empty.

## 📋 How to Test

### Test Steps:
1. Login as **Mechanic**
2. Accept a service request
3. Navigate through the job flow
4. Click "**Generate Invoice**" button
5. ✅ Check: Customer name should now display correctly (not "Unknown Customer")

### Expected Results:
- **BEFORE:** "Invoice for: **Unknown Customer**"
- **AFTER:** "Invoice for: **Juan Dela Cruz**" (actual customer name)

## 🔧 Technical Details

### Database Query Pattern:

**Supabase Foreign Key Join Syntax:**
```dart
.select('''
  *,
  customer:user_profiles!service_requests_customer_id_fkey(
    id,
    first_name,
    last_name,
    phone_number,
    email
  )
''')
```

**Result Structure:**
```dart
{
  'id': 'request-id',
  'status': 'in_progress',
  'customer_id': 'customer-uuid',
  // ... other service_request fields
  'customer': {  // ✅ Joined customer data
    'id': 'customer-uuid',
    'first_name': 'Juan',
    'last_name': 'Dela Cruz',
    'phone_number': '+639171234567',
    'email': 'juan@example.com'
  }
}
```

## 📝 Files Modified

1. ✅ `lib/mechanic/widgets/mechanic_job_tracking_bottom_sheet.dart`
   - Lines 225-270: Added customer profile join to query
   - Added debug logging for customer data

## 🎯 Related Code Locations

### Other places that fetch job details (Already Working ✅):

**File: `lib/services/mechanic_service.dart` - Lines 567-621**
```dart
Future<Map<String, dynamic>?> getJobDetails(String requestId) async {
  // ...
  customer = await _supabase
      .from('user_profiles')
      .select('id, first_name, last_name, phone_number, email')
      .eq('id', serviceRequest['customer_id'])
      .single();
  
  final jobData = {
    ...serviceRequest,
    'customer': customer,  // ✅ Already includes customer
    'vehicle': vehicle,
  };
  return jobData;
}
```

This method is used by `enhanced_job_details_screen.dart` and already works correctly.

## 🚀 Deployment

### No Database Changes Required
- ✅ No new tables
- ✅ No new columns
- ✅ No schema modifications
- ✅ Only code changes

### How to Deploy:
1. Save the modified file
2. Hot reload (Press `r` in terminal) OR
3. Hot restart (Press `R` in terminal)
4. Test invoice generation
5. Verify customer name appears

## ⚠️ Common Issues

### If customer name still shows "Unknown Customer":

**Check 1: Verify customer_id exists**
```sql
SELECT id, customer_id, status 
FROM service_requests 
WHERE id = 'your-request-id';
```

**Check 2: Verify customer profile exists**
```sql
SELECT id, first_name, last_name, phone_number
FROM user_profiles
WHERE id = 'customer-id-from-above';
```

**Check 3: Check console logs**
Look for this in debug console:
```
📋 Navigating to invoice generation for service: xxx
👤 Customer info: {id: xxx, first_name: Juan, last_name: Dela Cruz, ...}
```

If customer info shows `null` or `{}`, then the foreign key relationship might be missing.

## 🎉 Summary

**Problem:** "Unknown Customer" displayed in invoice
**Cause:** Missing customer data in query
**Fix:** Added JOIN to user_profiles table
**Impact:** Customer name now displays correctly ✅
**Testing:** Generate invoice → See customer name
**Deployment:** Hot reload/restart - NO database changes needed

---

**Status:** ✅ FIXED AND READY TO TEST
**Date:** 2025-01-06
**Files Changed:** 1 file
**Lines Changed:** ~25 lines
