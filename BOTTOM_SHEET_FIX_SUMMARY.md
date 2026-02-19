# Bottom Sheet Fix - Quick Summary

## ✅ FIXED: Mechanic bottom sheet now shows until job is complete

### Problem
- Bottom sheet was hiding when payment received (invoice_paid status)
- Mechanic needs to see job details until service is completed

### Solution
Changed condition from:
```dart
!['completed', 'cancelled', 'invoice_paid'].contains(status)
```

To:
```dart
!['completed', 'cancelled'].contains(status)
```

### Result
Bottom sheet now shows for:
- ✅ Job accepted
- ✅ Invoice sent
- ✅ Invoice accepted
- ✅ **Payment received (invoice_paid)** ← PREVIOUSLY HIDDEN, NOW VISIBLE
- ✅ Service in progress
- ✅ Ready for QR scan
- ❌ Completed (QR scanned) ← HIDES HERE

### Files Modified
1. `lib/mechanic/angkas_mechanic_dashboard.dart`
   - Lines 1044-1053: Updated visibility conditions
   - Lines 192-206: Updated monitoring logic

### Testing
1. Accept a job → ✅ Bottom sheet appears
2. Customer pays → ✅ Bottom sheet STAYS visible
3. Complete service → ✅ Bottom sheet disappears
4. Switch tabs → ✅ Bottom sheet respects home tab only

**Date:** October 16, 2025
**Status:** READY FOR TESTING
