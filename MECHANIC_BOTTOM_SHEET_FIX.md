# Mechanic Bottom Sheet Visibility Fix

## Problem
The bottom sheet for active jobs was not showing or disappearing prematurely because:
1. The condition was excluding `invoice_paid` status
2. Bottom sheet should remain visible until job is `completed` or `cancelled`

## Root Cause
The visibility condition was:
```dart
!['completed', 'cancelled', 'invoice_paid'].contains(_activeJobData!['job_status']?.toString().toLowerCase())
```

This caused the bottom sheet to hide when payment was received (`invoice_paid` status), but the mechanic still needs to see the job details and complete the service.

## Solution Applied

### 1. Updated Bottom Sheet Visibility Condition
**File:** `lib/mechanic/angkas_mechanic_dashboard.dart`

**Lines 1044-1053:** Updated to only exclude `completed` and `cancelled`:
```dart
// Bottom sheet for active job tracking (only visible on home tab)
// Shows for ALL active jobs until they are completed or cancelled
if (_currentIndex == 0 && _hasActiveJob && _activeJobData != null && _activeServiceRequestId != null &&
    !['completed', 'cancelled'].contains(_activeJobData!['job_status']?.toString().toLowerCase())) ...[
  _buildPersistentJobBottomSheet(),
],

// Floating toggle button (only visible on home tab)
if (_currentIndex == 0 && _hasActiveJob && _activeJobData != null && _activeServiceRequestId != null &&
    !['completed', 'cancelled'].contains(_activeJobData!['job_status']?.toString().toLowerCase()))
  _buildJobToggleButton(),
```

### 2. Updated Bottom Sheet Monitoring
**Lines 192-206:** Added home tab check to monitoring:
```dart
void _startBottomSheetMonitoring() {
  print('🔍 Starting bottom sheet monitoring...');
  _bottomSheetCheckTimer?.cancel();
  _bottomSheetCheckTimer = Timer.periodic(Duration(seconds: 2), (timer) {
    // Only keep expanded if on home tab and job is not completed/cancelled
    if (_currentIndex == 0 && _hasActiveJob && _activeJobData != null && 
        !['completed', 'cancelled'].contains(_activeJobData!['job_status']?.toString().toLowerCase()) &&
        !_bottomSheetController.isCompleted) {
      // Force bottom sheet to stay expanded
      _bottomSheetController.forward();
      print('🔧 Bottom sheet re-expanded for active job on home tab');
    }
  });
  print('✅ Bottom sheet monitoring started');
}
```

## Bottom Sheet Lifecycle

### When Bottom Sheet SHOWS:
✅ **Mechanic accepts job** → Bottom sheet appears on home tab
✅ **Customer accepts invoice** → Bottom sheet stays visible
✅ **Customer pays invoice** → Bottom sheet stays visible (invoice_paid status)
✅ **Mechanic performs service** → Bottom sheet stays visible
✅ **Mechanic ready to scan QR** → Bottom sheet stays visible

### When Bottom Sheet HIDES:
❌ **Job status = 'completed'** → Bottom sheet disappears
❌ **Job status = 'cancelled'** → Bottom sheet disappears
❌ **Mechanic switches to Jobs/History/Profile tabs** → Bottom sheet temporarily hidden
❌ **Mechanic returns to Home tab** → Bottom sheet reappears (if job still active)

## Job Status Flow

```
1. pending → broadcasted
2. accepted (by mechanic)
3. invoice_sent
4. invoice_accepted (by customer)
5. invoice_paid (customer paid) ← BOTTOM SHEET STAYS VISIBLE
6. in_progress (mechanic working)
7. awaiting_completion (ready for QR scan)
8. completed (QR scanned) ← BOTTOM SHEET HIDES
```

## Testing Checklist

### Test Case 1: Job Acceptance
- [ ] Mechanic goes online
- [ ] Accepts incoming job request
- [ ] Bottom sheet appears on home tab
- [ ] Bottom sheet shows job details

### Test Case 2: Invoice Payment
- [ ] Customer receives invoice
- [ ] Customer pays invoice
- [ ] Bottom sheet STAYS VISIBLE on mechanic's home tab
- [ ] Bottom sheet shows "Payment received" status

### Test Case 3: Tab Navigation
- [ ] Bottom sheet visible on Home tab with active job
- [ ] Switch to Jobs tab → bottom sheet disappears
- [ ] Switch back to Home tab → bottom sheet reappears
- [ ] Switch to History tab → bottom sheet disappears
- [ ] Switch back to Home tab → bottom sheet reappears

### Test Case 4: Job Completion
- [ ] Mechanic scans customer QR code
- [ ] Job status changes to 'completed'
- [ ] Bottom sheet disappears immediately
- [ ] Success message shows

### Test Case 5: Bottom Sheet Persistence
- [ ] Active job with bottom sheet visible
- [ ] Close and reopen app
- [ ] Bottom sheet reappears on home tab
- [ ] Job details correctly loaded

### Test Case 6: Bottom Sheet Monitoring
- [ ] Active job visible on home tab
- [ ] Bottom sheet stays expanded (monitoring works)
- [ ] Try to minimize → automatically re-expands every 2 seconds
- [ ] Complete job → monitoring stops, sheet disappears

## Key Behaviors

### 1. Home Tab Only
Bottom sheet only appears on the **Home tab** (index 0). This prevents UI conflicts with Jobs, History, and Profile screens.

### 2. Auto-Expansion
The bottom sheet automatically stays expanded while a job is active through periodic monitoring every 2 seconds.

### 3. Status-Based Visibility
Bottom sheet visibility is tied to job status, not invoice status. This ensures mechanics can see job details throughout the entire service lifecycle.

### 4. Persistent State
Active job state is restored when:
- App resumes from background
- Dashboard is recreated
- Mechanic navigates between tabs

## Debug Logs

When troubleshooting, look for these console logs:

```
🔍 Starting bottom sheet monitoring...
✅ Bottom sheet monitoring started
🔧 Bottom sheet re-expanded for active job on home tab
🔄 Checking for existing active job to restore...
✅ Active job found: [request_id]
📌 Active job detected - expanding bottom sheet.
```

## Related Files

- `lib/mechanic/angkas_mechanic_dashboard.dart` - Main dashboard with bottom sheet logic
- `lib/mechanic/widgets/mechanic_job_tracking_bottom_sheet.dart` - Bottom sheet content
- `lib/services/mechanic_service.dart` - Active job state management
- `lib/services/mechanic_request_service.dart` - Job acceptance and events

## Date Applied
October 16, 2025

## Status
✅ **FIXED** - Bottom sheet now correctly shows until job is completed or cancelled
