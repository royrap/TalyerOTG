# Shop-Based Request Filtering & Persistent Bottom Sheet Implementation

## Overview
This document provides a comprehensive implementation for:
1. **Shop-Based Request Filtering**: Ensures mechanics only see requests from their assigned shop
2. **Persistent Bottom Sheet**: Keeps the bottom sheet visible during active jobs

## Task 1: Shop-Based Request Filtering

### Database Function (Already Implemented)
The `get_nearby_requests_for_mechanic()` function in `FIX_LOCATION_FUNCTION_SHOP_ID.sql` already filters by shop_id:

```sql
-- For shop-based requests
WHEN dc.request_type = 'shop_based' AND dc.shop_id IS NOT NULL THEN
    EXISTS (
        SELECT 1 FROM shop_mechanics sm
        INNER JOIN mechanic_availability_status mas ON sm.mechanic_id = mas.mechanic_id
        WHERE sm.mechanic_id = p_mechanic_id
        AND sm.shop_id = dc.shop_id
        AND sm.is_active = true
        AND mas.current_status = 'available'
        AND mas.is_accepting_requests = true
    )
```

### Dart Implementation Updates

#### 1. Update `_processIncomingRequest` to Filter by Shop
File: `lib/services/mechanic_request_service.dart`

Add shop validation before processing:

```dart
/// Process and display incoming request
Future<void> _processIncomingRequest(Map<String, dynamic> routing) async {
  try {
    final requestId = routing['request_id'];
    
    // ✅ DUPLICATE PREVENTION: Skip if already notified
    if (_notifiedRequestIds.contains(requestId)) {
      print('⚠️ Skipping duplicate request notification: $requestId');
      return;
    }
    
    // Mark as notified immediately to prevent race conditions
    _notifiedRequestIds.add(requestId);
    
    // Get full service request details
    final serviceRequest = await _supabase
        .from('service_requests')
        .select('''
          id, title, description, service_type, pickup_latitude, pickup_longitude,
          pickup_address, estimated_price, customer_id, vehicle_id, is_emergency,
          priority, created_at, distance_km, estimated_arrival_minutes, status,
          request_type, shop_id
        ''')
        .eq('id', requestId)
        .maybeSingle();
    
    // Skip if request not found
    if (serviceRequest == null) {
      print('⚠️ Service request not found: $requestId');
      return;
    }
    
    // ✅ SKIP IF REQUEST IS NO LONGER PENDING
    final status = serviceRequest['status']?.toString().toLowerCase();
    if (status == null || !['pending', 'broadcasted'].contains(status)) {
      print('⚠️ Skipping request $requestId - not pending (status: $status)');
      return;
    }

    // ✅ SHOP-BASED FILTERING: Validate shop assignment
    final requestType = serviceRequest['request_type']?.toString() ?? 'direct_mechanic';
    final requestShopId = serviceRequest['shop_id'];
    
    if (requestType == 'shop_based' && requestShopId != null) {
      // Get mechanic's shop assignment
      final mechanicShop = await _getMechanicShopId();
      
      // Only show request if mechanic belongs to the same shop
      if (mechanicShop != requestShopId) {
        print('🚫 Skipping shop-based request $requestId - mechanic not assigned to shop $requestShopId');
        return;
      }
      
      print('✅ Shop-based request validated - mechanic belongs to shop $requestShopId');
    }
    
    // ... rest of the existing code
```

#### 2. Add Helper Method to Get Mechanic's Shop
File: `lib/services/mechanic_request_service.dart`

```dart
/// Get mechanic's assigned shop ID
Future<String?> _getMechanicShopId() async {
  try {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;
    
    // Check mechanic_availability_status for shop assignment
    final availability = await _supabase
        .from('mechanic_availability_status')
        .select('shop_id')
        .eq('mechanic_id', user.id)
        .maybeSingle();
    
    if (availability != null && availability['shop_id'] != null) {
      return availability['shop_id'].toString();
    }
    
    // Fallback: Check user_profiles
    final profile = await _supabase
        .from('user_profiles')
        .select('shop_id')
        .eq('id', user.id)
        .maybeSingle();
    
    return profile?['shop_id']?.toString();
  } catch (e) {
    print('❌ Error getting mechanic shop ID: $e');
    return null;
  }
}
```

## Task 2: Persistent Bottom Sheet Implementation

### Current Implementation Review
The bottom sheet already has logic to stay visible (from lines 991-1000 in `angkas_mechanic_dashboard.dart`):

```dart
// Bottom sheet for active job tracking (always visible for ongoing jobs, regardless of tab)
if (_hasActiveJob && _activeJobData != null && _activeServiceRequestId != null &&
    !['completed', 'cancelled', 'invoice_paid'].contains(_activeJobData!['job_status']?.toString().toLowerCase())) ...[
  _buildPersistentJobBottomSheet(),
],
```

### Enhancements Needed

#### 1. Ensure Active Job State is Properly Set on Acceptance
File: `lib/services/mechanic_request_service.dart`

Add a callback to notify dashboard of job acceptance:

```dart
// Add this property at the top of the class
final _jobAcceptedController = StreamController<Map<String, dynamic>>.broadcast();

// Add this getter
Stream<Map<String, dynamic>> get jobAcceptedStream => _jobAcceptedController.stream;

// Update acceptRequest method to trigger job accepted event
Future<Map<String, dynamic>> acceptRequest({
  required String routingId,
  required String requestId,
  bool isLocationBased = false,
}) async {
  try {
    // ... existing acceptance logic ...
    
    if (response == true) {
      print('✅ Request accepted successfully');
      
      // Fetch full job details for bottom sheet
      final jobDetails = await _supabase
          .from('service_requests')
          .select('''
            id, customer_id, title, description, status,
            pickup_latitude, pickup_longitude, pickup_address,
            estimated_price, service_type, created_at
          ''')
          .eq('id', requestId)
          .single();
      
      // Get customer info
      final customer = await _supabase
          .from('user_profiles')
          .select('first_name, last_name, phone_number')
          .eq('id', jobDetails['customer_id'])
          .single();
      
      // Emit job accepted event with full details
      _jobAcceptedController.add({
        'request_id': requestId,
        'job_details': jobDetails,
        'customer_details': customer,
        'accepted_at': DateTime.now().toIso8601String(),
      });
      
      return {
        'success': true,
        'message': 'Request accepted successfully',
        'request_id': requestId,
      };
    }
    
    // ... rest of existing code ...
  } catch (e) {
    print('❌ Error accepting request: $e');
    return {
      'success': false,
      'error': e.toString(),
    };
  }
}
```

#### 2. Update Dashboard to Listen for Job Acceptance
File: `lib/mechanic/angkas_mechanic_dashboard.dart`

Update the `initState` method:

```dart
@override
void initState() {
  super.initState();
  
  // ... existing initialization ...
  
  // Listen for job accepted events
  _jobAcceptedSubscription = MechanicRequestService.instance.jobAcceptedStream.listen((event) {
    if (mounted) {
      setState(() {
        _hasActiveJob = true;
        _activeServiceRequestId = event['request_id'];
        _activeJobData = {
          'job_status': event['job_details']['status'],
          'customer_name': '${event['customer_details']['first_name']} ${event['customer_details']['last_name']}',
          'customer_phone': event['customer_details']['phone_number'],
          'pickup_address': event['job_details']['pickup_address'],
          'service_type': event['job_details']['service_type'],
          'title': event['job_details']['title'],
        };
      });
      
      // Expand bottom sheet
      _bottomSheetController.forward();
      
      print('✅ Active job set from acceptance: $_activeServiceRequestId');
    }
  });
}
```

Add subscription cleanup:

```dart
StreamSubscription? _jobAcceptedSubscription;

@override
void dispose() {
  _jobAcceptedSubscription?.cancel();
  // ... existing dispose code ...
  super.dispose();
}
```

#### 3. Ensure Bottom Sheet Stays Visible During Status Updates
File: `lib/mechanic/angkas_mechanic_dashboard.dart`

Add periodic check to ensure bottom sheet stays expanded:

```dart
Timer? _bottomSheetCheckTimer;

void _startBottomSheetMonitoring() {
  _bottomSheetCheckTimer?.cancel();
  _bottomSheetCheckTimer = Timer.periodic(Duration(seconds: 2), (timer) {
    if (_hasActiveJob && _activeJobData != null && !_bottomSheetController.isCompleted) {
      // Force bottom sheet to stay expanded
      _bottomSheetController.forward();
      print('🔧 Bottom sheet re-expanded for active job');
    }
  });
}

@override
void initState() {
  super.initState();
  // ... existing code ...
  
  // Start bottom sheet monitoring
  _startBottomSheetMonitoring();
}

@override
void dispose() {
  _bottomSheetCheckTimer?.cancel();
  // ... existing dispose code ...
  super.dispose();
}
```

## Testing Checklist

### Shop-Based Filtering Tests
- [ ] Customer selects Shop A, creates request
- [ ] Only mechanics assigned to Shop A see the request
- [ ] Mechanics from Shop B do NOT see the request
- [ ] Emergency requests follow same shop filtering
- [ ] Broadcast requests (non-shop) visible to all available mechanics

### Bottom Sheet Tests
- [ ] Bottom sheet appears immediately after accepting a request
- [ ] Bottom sheet remains visible while navigating between tabs
- [ ] Bottom sheet shows live location and route updates
- [ ] Bottom sheet only disappears when job status is 'completed' or 'cancelled'
- [ ] Bottom sheet cannot be manually dismissed during active job
- [ ] Bottom sheet survives app resume/pause cycles

## Database Queries for Verification

### Check Mechanic Shop Assignment
```sql
SELECT m.mechanic_id, m.shop_id, s.shop_name
FROM shop_mechanics m
JOIN shops s ON m.shop_id = s.id
WHERE m.mechanic_id = 'YOUR_MECHANIC_ID'
AND m.is_active = true;
```

### Check Request Shop Assignment
```sql
SELECT id, title, request_type, shop_id, status
FROM service_requests
WHERE id = 'YOUR_REQUEST_ID';
```

### Verify Filtering Logic
```sql
SELECT * FROM get_nearby_requests_for_mechanic(
  'YOUR_MECHANIC_ID'::UUID,
  14.9321542,  -- Mechanic latitude
  120.8807335, -- Mechanic longitude
  50.0         -- Max distance km
);
```

## Key Points

1. **Shop Filtering is Already in SQL**: The database function handles shop filtering correctly
2. **Dart Validation Adds Extra Safety**: Additional checks in Dart prevent edge cases
3. **Bottom Sheet State Management**: Uses three sources of truth:
   - `_hasActiveJob` boolean
   - `_activeJobData` map
   - `_activeServiceRequestId` string
4. **Real-time Updates**: Both location tracking and job status updates keep the UI synchronized

## Files Modified

1. `lib/services/mechanic_request_service.dart`
   - Added shop validation in `_processIncomingRequest`
   - Added `_getMechanicShopId` helper method
   - Added job accepted stream and event emission

2. `lib/mechanic/angkas_mechanic_dashboard.dart`
   - Added job accepted stream subscription
   - Added bottom sheet monitoring timer
   - Enhanced state management for active jobs

3. Database: `FIX_LOCATION_FUNCTION_SHOP_ID.sql` (already correct)

## Next Steps

1. Apply the Dart code changes above
2. Test with multiple mechanics assigned to different shops
3. Verify bottom sheet persistence across all job statuses
4. Test edge cases (app backgrounding, network interruptions)
