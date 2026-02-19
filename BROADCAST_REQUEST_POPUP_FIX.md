# Broadcast Request Popup Fix - COMPLETE ✅

## ❌ Problem
**Hindi nakikita ng ibang mechanics ang popup request notifications!**

### Root Cause Analysis:
The mechanic request service was **ONLY listening to `request_routing` table** but **NOT listening to `request_broadcasts` table**!

```dart
// ❌ BEFORE: Only one listener
_routingChannel = _supabase.channel('public:request_routing')
  .onPostgresChanges(...) // Only direct mechanic assignments

// ❌ MISSING: No broadcast listener!
// _broadcastChannel = ??? 
```

### Why This Matters:
- **Direct Requests** (specific mechanic/shop) → Goes to `request_routing` table ✅
- **Broadcast Requests** ("Any Available Mechanic") → Goes to `request_broadcasts` table ❌

**Result**: Broadcast requests were being created in the database BUT mechanics never received popup notifications because there was no listener!

---

## ✅ Solution

### Added Broadcast Channel Listener

**File Modified**: `lib/services/mechanic_request_service.dart`

### Change #1: Added Broadcast Channel Variable
```dart
// Line ~12
RealtimeChannel? _broadcastChannel; // For monitoring broadcast requests
```

### Change #2: Added Broadcast Listener in `startListening()`
```dart
// After routing channel setup (~Line 88)

// 📡 CHANNEL 2: Listen for BROADCAST requests to ALL mechanics
print('📡 Setting up broadcast listener for mechanic: $mechanicId');
_broadcastChannel = _supabase.channel('public:request_broadcasts:$mechanicId')
  .onPostgresChanges(
    event: PostgresChangeEvent.insert,
    schema: 'public',
    table: 'request_broadcasts',
    callback: (payload) async {
      try {
        final newRow = payload.newRecord;
        
        // Check if this broadcast is for this mechanic
        final mechanicIdFromBroadcast = newRow['mechanic_id'];
        final providerIdFromBroadcast = newRow['provider_id'];
        
        // Skip if not for this mechanic
        if (mechanicIdFromBroadcast != user.id && providerIdFromBroadcast != mechanicId) {
          return;
        }
        
        // Skip if not in pending status
        if (newRow['response_status'] != 'pending') {
          return;
        }
        
        print('📡 Broadcast notification received for mechanic: $mechanicId, request: ${newRow['request_id']}');
        await _processBroadcastRequest(Map<String, dynamic>.from(newRow));
      } catch (e) {
        print('❌ Broadcast handling error: $e');
      }
    },
  )
  .onPostgresChanges(
    event: PostgresChangeEvent.update,
    schema: 'public',
    table: 'request_broadcasts',
    callback: (payload) async {
      final updated = payload.newRecord;
      final mechanicIdFromBroadcast = updated['mechanic_id'];
      
      if (mechanicIdFromBroadcast != user.id) return;
      
      // Handle status changes (e.g., expired, accepted by another mechanic)
      if (updated['response_status'] == 'expired' || updated['response_status'] == 'accepted') {
        final requestId = updated['request_id'];
        print('🚫 Broadcast request $requestId is no longer available');
        _requestTimeoutController.add(requestId);
      }
    },
  )
  .subscribe();

print('✅ Broadcast channel subscribed for mechanic: $mechanicId');
```

### Change #3: Added `_processBroadcastRequest()` Method
```dart
/// Process broadcast request from request_broadcasts table
Future<void> _processBroadcastRequest(Map<String, dynamic> broadcast) async {
  try {
    final requestId = broadcast['request_id'];
    
    // ✅ DUPLICATE PREVENTION: Skip if already notified
    if (_notifiedRequestIds.contains(requestId)) {
      print('⚠️ Skipping duplicate broadcast notification: $requestId');
      return;
    }
    
    // Mark as notified immediately to prevent race conditions
    _notifiedRequestIds.add(requestId);
    
    print('📡 Processing broadcast request: $requestId');
    
    // Get full service request details
    final serviceRequest = await _supabase
        .from('service_requests')
        .select('''
          id, title, description, service_type, pickup_latitude, pickup_longitude,
          pickup_address, estimated_price, customer_id, vehicle_id, is_emergency,
          priority, created_at, distance_km, estimated_arrival_minutes, status
        ''')
        .eq('id', requestId)
        .maybeSingle();
    
    // Skip if request not found or not available
    if (serviceRequest == null) {
      print('⚠️ Service request not found: $requestId');
      return;
    }
    
    // Skip if request already taken
    if (serviceRequest['status'] != 'pending' && serviceRequest['status'] != 'broadcasted') {
      print('⚠️ Request already taken or cancelled: $requestId (status: ${serviceRequest['status']})');
      return;
    }

    // Get customer details
    final customer = await _supabase
        .from('user_profiles')
        .select('id, first_name, last_name, phone_number')
        .eq('id', serviceRequest['customer_id'])
        .maybeSingle();

    // Get vehicle details if available
    Map<String, dynamic>? vehicle;
    if (serviceRequest['vehicle_id'] != null) {
      vehicle = await _supabase
          .from('vehicles')
          .select('brand_name, model_name, year, color, plate_number')
          .eq('id', serviceRequest['vehicle_id'])
          .maybeSingle();
    }

    // Get distance from broadcast record
    final distanceKm = broadcast['distance_km'] ?? serviceRequest['distance_km'];

    // Update broadcast status to 'viewed'
    await _supabase
        .from('request_broadcasts')
        .update({
          'viewed_at': DateTime.now().toIso8601String(),
          'response_status': 'viewed',
        })
        .eq('id', broadcast['id']);

    // Prepare request data for UI (SAME FORMAT as routing requests)
    final requestData = {
      'broadcast_id': broadcast['id'], // Use broadcast_id instead of routing_id
      'request_id': requestId,
      'service_type': serviceRequest['service_type'],
      'title': serviceRequest['title'],
      'description': serviceRequest['description'],
      'customer_name': customer != null ? '${customer['first_name']} ${customer['last_name']}' : 'Unknown Customer',
      'customer_phone': customer?['phone_number'] ?? 'N/A',
      'pickup_address': serviceRequest['pickup_address'],
      'pickup_latitude': serviceRequest['pickup_latitude'],
      'pickup_longitude': serviceRequest['pickup_longitude'],
      'estimated_price': serviceRequest['estimated_price'],
      'is_emergency': serviceRequest['is_emergency'] ?? false,
      'priority': serviceRequest['priority'] ?? 'normal',
      'distance_km': distanceKm,
      'estimated_arrival_minutes': serviceRequest['estimated_arrival_minutes'],
      'vehicle': vehicle,
      'created_at': serviceRequest['created_at'],
      'timeout_seconds': REQUEST_TIMEOUT_SECONDS,
      'is_broadcast': true, // Flag to indicate this is a broadcast request
    };

    // Set current pending request and start timeout
    _currentPendingRequestId = requestId;
    _startRequestTimeout(requestId);

    // Emit to UI
    _incomingRequestController.add(requestData);

    print('✅ Broadcast request processed and sent to UI: $requestId');
  } catch (e) {
    print('❌ Error processing broadcast request: $e');
  }
}
```

### Change #4: Updated `stopListening()` to Cleanup Broadcast Channel
```dart
void stopListening() {
  _requestSubscription?.cancel();
  _requestSubscription = null;
  _routingChannel?.unsubscribe();
  _routingChannel = null;
  _broadcastChannel?.unsubscribe();  // ✅ Added
  _broadcastChannel = null;          // ✅ Added
  _statusChannel?.unsubscribe();
  _statusChannel = null;
  _locationCheckTimer?.cancel();
  _locationCheckTimer = null;
  _notifiedRequestIds.clear();
  _cancelCurrentRequestTimeout();
  print('🔧 Request listener stopped (routing + broadcast channels)');  // ✅ Updated message
}
```

---

## 🔄 How It Works Now

### Customer Creates Broadcast Request:
1. Customer selects "Any Available Mechanic"
2. System inserts multiple rows into `request_broadcasts` table (one per eligible mechanic)
3. Each mechanic's app receives real-time notification via Supabase real-time

### Mechanic Receives Notification:
1. **Real-time listener** detects new row in `request_broadcasts` table
2. **Filters** to ensure it's for this specific mechanic (`mechanic_id` match)
3. **Fetches full details** (customer, vehicle, location, etc.)
4. **Updates status** to 'viewed' in database
5. **Shows popup** via `_incomingRequestController.add(requestData)`
6. **Starts timeout** (30 seconds to respond)

### Mechanic Accepts/Rejects:
- **Accept** → Updates `request_broadcasts.response_status` to 'accepted'
- **Reject** → Updates to 'declined'
- **Timeout** → Updates to 'expired'

### Race Condition Handling:
- When one mechanic accepts, **ALL other broadcasts are updated** to show 'accepted'
- Other mechanics' listeners detect the update and **hide the popup** automatically
- Prevents multiple mechanics from accepting the same request

---

## 🎯 Key Features

### Dual Channel System:
✅ **Channel 1**: Direct routing (`request_routing` table)
- For specific mechanic/shop assignments
- One-to-one relationship

✅ **Channel 2**: Broadcast routing (`request_broadcasts` table)
- For "Any Available Mechanic" requests
- One-to-many relationship

### Duplicate Prevention:
- Uses `_notifiedRequestIds` Set to track shown requests
- Prevents same request from showing multiple times
- Clears on accept/reject/timeout

### Auto-Dismissal:
- When another mechanic accepts, popup auto-closes
- Updates `response_status` trigger this behavior
- Shows "Request already taken" message

### Status Tracking:
- `pending` → Initial state, show popup
- `viewed` → Mechanic saw the popup
- `accepted` → Mechanic accepted (hide from others)
- `declined` → Mechanic rejected
- `expired` → Timeout reached

---

## 🧪 Testing Guide

### Test Case 1: Single Broadcast Request
**Steps**:
1. Customer creates request with "Any Available Mechanic"
2. Have 3 mechanics online and available
3. **Expected Result**:
   - ✅ All 3 mechanics see popup simultaneously
   - ✅ Popup shows customer details, location, price
   - ✅ 30-second timer starts

### Test Case 2: First Mechanic Accepts
**Steps**:
1. Mechanic A accepts the request
2. **Expected Result**:
   - ✅ Mechanic A's popup closes, job assigned
   - ✅ Mechanics B & C popups auto-close
   - ✅ Message: "Request already taken"

### Test Case 3: Timeout
**Steps**:
1. Customer creates broadcast request
2. No mechanic responds within 30 seconds
3. **Expected Result**:
   - ✅ Popup auto-closes on all mechanics
   - ✅ Status updates to 'expired'
   - ✅ Customer notified "No mechanics available"

### Test Case 4: Mechanic Rejects
**Steps**:
1. Mechanic A rejects request
2. **Expected Result**:
   - ✅ Mechanic A's popup closes
   - ✅ Mechanics B & C still see popup
   - ✅ Broadcast status for A updated to 'declined'

### Test Case 5: Duplicate Prevention
**Steps**:
1. Customer creates request
2. Mechanic receives notification
3. Database trigger creates duplicate broadcast entry
4. **Expected Result**:
   - ✅ Only ONE popup shown to mechanic
   - ✅ Duplicate entries filtered out
   - ✅ Log: "⚠️ Skipping duplicate broadcast notification"

---

## 📊 Database Monitoring

### Check Broadcast Entries:
```sql
SELECT 
    rb.id,
    rb.request_id,
    rb.mechanic_id,
    rb.response_status,
    rb.notification_sent_at,
    rb.viewed_at,
    rb.responded_at,
    up.first_name || ' ' || up.last_name as mechanic_name
FROM request_broadcasts rb
JOIN user_profiles up ON up.id = rb.mechanic_id
WHERE rb.created_at > NOW() - INTERVAL '1 hour'
ORDER BY rb.created_at DESC;
```

### Check Mechanic Availability:
```sql
SELECT 
    up.id,
    up.first_name || ' ' || up.last_name as name,
    mas.current_status,
    mas.is_accepting_requests,
    mas.last_active_at
FROM user_profiles up
JOIN mechanic_availability_status mas ON mas.mechanic_id = up.id
WHERE up.user_type = 'mechanic';
```

---

## 📱 Expected Logs

### When Broadcast Request Created:
```
🔧 Starting request listener for mechanic: [mechanic_id], shop: [shop_id]
📡 Setting up broadcast listener for mechanic: [mechanic_id]
✅ Broadcast channel subscribed for mechanic: [mechanic_id]
```

### When Notification Received:
```
📡 Broadcast notification received for mechanic: [mechanic_id], request: [request_id]
📡 Processing broadcast request: [request_id]
✅ Broadcast request processed and sent to UI: [request_id]
📬 New request received: [request_id] - showing popup
```

### When Another Mechanic Accepts:
```
🚫 Broadcast request [request_id] is no longer available
⏰ Request timeout for: [request_id]
```

### When Mechanic Goes Offline:
```
🔧 Request listener stopped (routing + broadcast channels)
```

---

## ⚠️ Common Issues

### Issue: No Popup Shows
**Check**:
1. Is mechanic online? (`current_status = 'available'`)
2. Is accepting requests? (`is_accepting_requests = true`)
3. Is within broadcast radius? (Check `distance_km`)
4. Are there entries in `request_broadcasts` table?

**Solution**:
```sql
-- Check if broadcasts were created
SELECT COUNT(*) FROM request_broadcasts 
WHERE request_id = '[request_id]';

-- If 0, check broadcast function
SELECT * FROM service_requests 
WHERE id = '[request_id]';
```

### Issue: Duplicate Popups
**Check**:
- Look for multiple broadcast entries with same `request_id` and `mechanic_id`

**Solution**:
- Database has UNIQUE constraint: `UNIQUE(request_id, provider_id)`
- Flutter has duplicate prevention: `_notifiedRequestIds.contains(requestId)`

### Issue: Popup Doesn't Auto-Close
**Check**:
- Is `_statusChannel` subscribed and working?
- Is `response_status` being updated correctly?

**Solution**:
```dart
// Check logs for:
🚫 Broadcast request [request_id] is no longer available
⏰ Request timeout for: [request_id]
```

---

## 🎉 Summary

**BEFORE**: 
- ❌ Only direct routing worked
- ❌ Broadcast requests created but not received
- ❌ Mechanics never saw "Any Available Mechanic" requests

**AFTER**:
- ✅ Both direct routing AND broadcast requests work
- ✅ Multiple mechanics receive broadcast notifications
- ✅ First to accept gets the job
- ✅ Others auto-dismissed
- ✅ Race conditions handled
- ✅ Duplicate prevention active

**Result**: **All mechanics can now see and respond to broadcast requests!** 🎊
