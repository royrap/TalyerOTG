# Review Submission Foreign Key Fix

## Problem Summary

**Error**: `PostgrestException - insert or update on table "reviews" violates foreign key constraint "reviews_provider_id_fkey"`

**Root Cause**: 
- The customer was trying to submit a review by passing the mechanic's `user_id` as the `provider_id`
- The `reviews` table requires a `provider_id` that exists in the `service_providers` table
- The code was passing `assigned_mechanic_id` (from `service_requests` table) which is a `user_id`, not a `provider_id`

## Database Relationship

```
service_requests.assigned_mechanic_id 
  → user_profiles.id (mechanic's user account)
  
user_profiles.id (mechanic)
  → service_providers.user_id
  
service_providers.id 
  → reviews.provider_id ✅ (This is what we need!)
```

## Solution Implemented

### Modified: `lib/services/user_data_service.dart`

**Function**: `submitReview()`

**Changes**:
1. Added automatic lookup logic to convert `user_id` → `provider_id`
2. First checks if the provided ID is already a valid `provider_id`
3. If not, queries `service_providers` table using `user_id` to get the correct `provider_id`
4. Uses the resolved `provider_id` for the review insertion

### Code Flow

```dart
submitReview(providerId: mechanicUserId) {
  1. Check if review already exists ✅
  
  2. Validate providerId:
     - Query service_providers WHERE id = providerId
     - If NOT found → This is a user_id, look up provider record
     - Query service_providers WHERE user_id = providerId
     - Get the correct provider_id
  
  3. Insert review with correct provider_id ✅
}
```

## Testing Steps

1. **Hot Restart** the customer app
2. Complete a service with mechanic: `da0aade5-1e11-4901-898c-3fd67379262f`
3. Click "Rate Mechanic" button
4. Submit a 5-star review
5. **Expected Result**: ✅ Review submitted successfully
6. **Previous Result**: ❌ Foreign key constraint violation

## Verification Query

To verify the fix works, you can run this SQL query:

```sql
-- Check mechanic's provider_id
SELECT 
  up.id as user_id,
  up.first_name,
  up.last_name,
  sp.id as provider_id
FROM user_profiles up
JOIN service_providers sp ON sp.user_id = up.id
WHERE up.id = 'da0aade5-1e11-4901-898c-3fd67379262f';

-- After review submission, check reviews table
SELECT 
  r.id,
  r.request_id,
  r.customer_id,
  r.provider_id,
  r.rating,
  r.comment,
  up.first_name || ' ' || up.last_name as mechanic_name
FROM reviews r
JOIN service_providers sp ON sp.id = r.provider_id
JOIN user_profiles up ON up.id = sp.user_id
WHERE r.request_id = 'b63e7dd9-f77d-4d93-a2bd-5f6957fb3537';
```

## Impact

- **Fixes**: Customer review submission error
- **Backwards Compatible**: ✅ Yes - works with both user_id and provider_id
- **Performance**: Minimal - adds 1-2 extra queries only if needed
- **User Experience**: ✅ Reviews now work properly

## Related Files

- `lib/services/user_data_service.dart` - Fixed submitReview() method
- `lib/widgets/review_dialog.dart` - Calls submitReview()
- `lib/customer/widgets/customer_service_tracking_bottom_sheet.dart` - Passes mechanic_id to review dialog

## Notes

- The fix automatically handles the ID type (user_id vs provider_id)
- No changes needed to calling code
- Error handling improved with clearer messages
- Debug logging added for troubleshooting

---

**Status**: ✅ FIXED - Ready for testing
**Date**: October 6, 2025
**Mechanic ID**: da0aade5-1e11-4901-898c-3fd67379262f
**Service Request**: b63e7dd9-f77d-4d93-a2bd-5f6957fb3537
