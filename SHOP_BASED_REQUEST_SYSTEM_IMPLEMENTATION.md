# 🏪 Grab/JoyRide-Style Shop-Based Request System
## Implementation Guide

**Status:** ✅ Core Components Completed (Phase 1)  
**Date:** Current Implementation  
**Feature:** Mechanic request flow where customers select a specific shop (like Grab/JoyRide)

---

## 📋 Overview

This system implements a **shop-based mechanic request routing** similar to how Grab, JoyRide, or Angkas work:
- Each **shop** acts like a company (e.g., "Grab", "JoyRide")
- Customers **select a specific shop** to send their request to
- Only **mechanics belonging to that shop** receive the request notification
- System handles **edge cases** (no mechanics, all busy) with user-friendly alerts
- **Real-time status management** (available → busy → available)
- **QR code completion** to mark job as done

---

## ✅ Completed Components (Phase 1)

### 1. **ShopBasedRequestService** ✅
**File:** `lib/services/shop_based_request_service.dart` (470 lines)

**Core Methods:**
```dart
// Shop Discovery
Future<List<Map<String, dynamic>>> getAvailableShops({
  double? customerLat,
  double? customerLng,
  double maxDistanceKm = 50.0,
})

// Availability Checking
Future<Map<String, int>> getMechanicAvailability(String shopId)
// Returns: {total: 5, available: 2, busy: 3}

// Request Creation
Future<Map<String, dynamic>> createShopBasedRequest({
  required String customerId,
  required String shopId,
  required String vehicleId,
  required String categoryId,
  required String title,
  required String description,
  required double pickupLatitude,
  required double pickupLongitude,
  String? pickupAddress,
  Map<String, dynamic>? additionalDetails,
})

// Mechanic Actions
Future<Map<String, dynamic>> acceptRequest({
  required String requestId,
  required String mechanicId,
  required String shopId,
})

Future<Map<String, dynamic>> rejectRequest({
  required String requestId,
  required String mechanicId,
  String? reason,
})

// Job Completion
Future<Map<String, dynamic>> completeJob({
  required String requestId,
  required String mechanicId,
  required String completionCode,
})
```

**Key Features:**
- ✅ Distance calculation (Haversine formula)
- ✅ Multi-table availability checking (`shop_mechanics` + `mechanic_availability_status`)
- ✅ Automatic notification routing to shop's mechanics only
- ✅ Race condition handling (first mechanic to accept wins)
- ✅ Status management (3 tables updated atomically)
- ✅ Edge case detection (no mechanics, all busy)
- ✅ QR code validation with expiration checking

**Database Updates on Accept:**
```sql
-- 1. service_requests table
UPDATE service_requests 
SET status = 'accepted',
    assigned_mechanic_id = 'mechanic_id',
    accepted_at = NOW()
WHERE id = 'request_id';

-- 2. mechanic_availability_status table
UPDATE mechanic_availability_status
SET current_status = 'busy',
    is_accepting_requests = false,
    current_request_id = 'request_id'
WHERE mechanic_id = 'mechanic_id';

-- 3. shop_mechanics table
UPDATE shop_mechanics
SET is_available = false
WHERE shop_id = 'shop_id' AND mechanic_id = 'mechanic_id';
```

**Database Updates on Completion (QR Scan):**
```sql
-- 1. service_requests table
UPDATE service_requests
SET status = 'completed',
    completed_at = NOW(),
    qr_scanned_at = NOW()
WHERE id = 'request_id';

-- 2. mechanic_availability_status table
UPDATE mechanic_availability_status
SET current_status = 'available',
    is_accepting_requests = true,
    current_request_id = NULL
WHERE mechanic_id = 'mechanic_id';

-- 3. shop_mechanics table
UPDATE shop_mechanics
SET is_available = true
WHERE mechanic_id = 'mechanic_id';
```

---

### 2. **Edge Case Alert Dialogs** ✅

#### **NoMechanicsAlertDialog**
**File:** `lib/dialogs/no_mechanics_alert_dialog.dart`

**When Triggered:** Shop has zero mechanics available  
**Features:**
- 🎨 Orange gradient design with icon
- ⏱️ 3-second auto-close countdown
- 🔄 Circular progress indicator
- ✅ Manual OK button
- 📱 Auto-returns user to main screen

**UI:**
```
┌────────────────────────────┐
│   🚫 (Orange Circle Icon)  │
│                             │
│  No Mechanics Available     │
│                             │
│ [Shop Name] currently has   │
│ no mechanics available.     │
│                             │
│ Please try another shop or  │
│ check back later.           │
│                             │
│  ⏳ Returning in 3 seconds  │
│                             │
│      [    OK    ]           │
└────────────────────────────┘
```

#### **AllBusyAlertDialog**
**File:** `lib/dialogs/all_busy_alert_dialog.dart`

**When Triggered:** Shop has mechanics, but all are currently on jobs  
**Features:**
- 🎨 Blue gradient design with people icon
- ⏱️ 3-second auto-close countdown
- 🔄 Circular progress indicator
- 🔘 Two buttons: "Try Another" | "OK"
- 📱 Auto-returns to shop selection

**UI:**
```
┌────────────────────────────┐
│   👥 (Blue Circle Icon)    │
│                             │
│   All Mechanics Busy        │
│                             │
│ All mechanics from [Shop]   │
│ are currently on a job.     │
│                             │
│ Please try again in a few   │
│ minutes or select another   │
│ shop.                       │
│                             │
│  ⏳ Returning in 3 seconds  │
│                             │
│ [ Try Another ] [   OK   ]  │
└────────────────────────────┘
```

---

### 3. **Incoming Request Popup (Mechanic Side)** ✅
**File:** `lib/mechanic/incoming_shop_request_popup.dart` (550 lines)

**When Triggered:** Mechanic receives new shop-based request  
**Features:**
- 🎯 Full-screen modal with dark background overlay
- ⏱️ 30-second countdown timer (pulsing animation)
- 📍 Customer info with profile photo and rating
- 🚗 Vehicle details (brand, model, color, plate)
- 📋 Service description
- 🗺️ Google Maps preview with pickup location marker
- 📏 Distance to customer
- ✅ Accept (green) / ❌ Decline (red) buttons
- 🔒 WillPopScope to prevent accidental dismissal during processing

**UI Layout:**
```
┌─────────────────────────────────┐
│ New Service Request    [30s] ⏱️  │ ← Header (black bg)
├─────────────────────────────────┤
│                                  │
│  ┌────────────────────────────┐ │
│  │  🙍 Customer Name           │ │
│  │     ⭐ 4.5                  │ │
│  │     📞 Phone number         │ │
│  │                             │ │
│  │ ───────────────────────     │ │
│  │                             │ │
│  │ 🔧 Service Requested        │ │
│  │    Title: Oil Change        │ │
│  │    Description: ...         │ │
│  │                             │ │
│  │ 🚗 Vehicle Information      │ │
│  │    Brand: Toyota            │ │
│  │    Model: Vios              │ │
│  │    Color: White             │ │
│  │    Plate: ABC 1234          │ │
│  │                             │ │
│  │ 📍 Pickup Location          │ │
│  │    Customer address         │ │
│  │    📏 2.5 km away           │ │
│  │                             │ │
│  │ ┌──────────────────────┐   │ │
│  │ │   🗺️ Map Preview      │   │ │
│  │ └──────────────────────┘   │ │
│  │                             │ │
│  └────────────────────────────┘ │
│                                  │
│  [ ❌ Decline ]  [ ✅ Accept ]   │ ← Actions
└─────────────────────────────────┘
```

**Behavior:**
- ✅ **Accept:** Calls `acceptRequest()` → updates status → shows success → navigates to job details
- ❌ **Decline:** Shows confirmation dialog → calls `rejectRequest()` → logs rejection
- ⏱️ **Timeout:** Auto-rejects after 30 seconds if no response
- 🔒 **Race Condition:** Shows "Already accepted by another mechanic" if too late

---

## 📊 Database Schema (Key Tables)

### **service_requests**
```sql
CREATE TABLE service_requests (
  id UUID PRIMARY KEY,
  customer_id UUID REFERENCES user_profiles(id),
  shop_id UUID REFERENCES shops(id),
  assigned_mechanic_id UUID REFERENCES user_profiles(id),
  vehicle_id UUID REFERENCES vehicles(id),
  category_id UUID REFERENCES service_categories(id),
  
  title TEXT NOT NULL,
  description TEXT,
  
  pickup_latitude DOUBLE PRECISION,
  pickup_longitude DOUBLE PRECISION,
  pickup_address TEXT,
  
  status TEXT DEFAULT 'pending', -- pending, accepted, in_progress, completed, cancelled
  request_type TEXT DEFAULT 'shop_based', -- shop_based, broadcast
  
  can_accept_by_any_mechanic BOOLEAN DEFAULT false, -- false for shop-based
  preferred_shop_id UUID,
  
  mechanics_notified_count INTEGER DEFAULT 0,
  broadcast_started_at TIMESTAMP,
  accepted_at TIMESTAMP,
  completed_at TIMESTAMP,
  qr_scanned_at TIMESTAMP,
  
  created_at TIMESTAMP DEFAULT NOW()
);
```

### **shop_mechanics**
```sql
CREATE TABLE shop_mechanics (
  id UUID PRIMARY KEY,
  shop_id UUID REFERENCES shops(id),
  mechanic_id UUID REFERENCES user_profiles(id),
  
  is_active BOOLEAN DEFAULT true,
  is_available BOOLEAN DEFAULT true, -- false when on a job
  
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);
```

### **mechanic_availability_status**
```sql
CREATE TABLE mechanic_availability_status (
  mechanic_id UUID PRIMARY KEY REFERENCES user_profiles(id),
  
  current_status TEXT DEFAULT 'offline', -- available, busy, offline, in_service
  is_accepting_requests BOOLEAN DEFAULT false,
  
  current_request_id UUID REFERENCES service_requests(id),
  
  last_status_update TIMESTAMP DEFAULT NOW(),
  last_active_at TIMESTAMP DEFAULT NOW()
);
```

### **service_completions**
```sql
CREATE TABLE service_completions (
  id UUID PRIMARY KEY,
  request_id UUID REFERENCES service_requests(id),
  
  completion_code TEXT NOT NULL UNIQUE, -- QR code value
  
  is_scanned BOOLEAN DEFAULT false,
  scanned_at TIMESTAMP,
  
  verification_status TEXT DEFAULT 'pending', -- pending, verified, expired
  
  expires_at TIMESTAMP, -- QR code expiration
  created_at TIMESTAMP DEFAULT NOW()
);
```

---

## 🔄 Complete Flow Diagram

### **Customer Flow:**
```
1. Customer clicks "Request Shop Service" button
   ↓
2. Opens ShopSelectionScreen
   - Shows shops sorted by distance/rating/mechanics
   - Displays: shop name, rating, distance, available mechanics count
   ↓
3. Customer selects a shop
   ↓
4. ShopBasedRequestService.createShopBasedRequest()
   ├─ Check mechanics availability
   │  ├─ IF total_mechanics == 0 → ❌ Show NoMechanicsAlertDialog → Return to main
   │  └─ IF available_mechanics == 0 → ❌ Show AllBusyAlertDialog → Return to main
   │
   ├─ IF available_mechanics > 0:
   │  ├─ Create service_request (status = 'pending', request_type = 'shop_based')
   │  └─ Call _notifyShopMechanics() → Send notifications to available mechanics
   │
   └─ Return: {success: true, request_id: '...'}
   ↓
5. Show "Waiting for mechanic acceptance..." screen
   ↓
6. (Real-time subscription listens for status change)
   ↓
7. IF mechanic accepts → Navigate to "Job Accepted" screen
```

### **Mechanic Flow:**
```
1. Mechanic app listens to real-time subscriptions
   - Supabase channel: service_requests table
   - Filter: shop_id matches mechanic's shop, status = 'pending'
   ↓
2. New request arrives (INSERT event detected)
   ↓
3. Show IncomingShopRequestPopup (full-screen modal)
   - Display customer info, vehicle, location, service details
   - 30-second countdown timer
   ↓
4. Mechanic clicks "Accept" or "Decline"
   ↓
5A. IF ACCEPT:
    ├─ Call ShopBasedRequestService.acceptRequest()
    ├─ Verify mechanic belongs to shop
    ├─ Check request still pending (race condition)
    ├─ Update 3 tables:
    │  ├─ service_requests.status = 'accepted'
    │  ├─ mechanic_availability_status.current_status = 'busy'
    │  └─ shop_mechanics.is_available = false
    ├─ Show success message
    └─ Navigate to JobDetailsScreen
    ↓
5B. IF DECLINE:
    ├─ Show confirmation dialog
    ├─ Call ShopBasedRequestService.rejectRequest()
    ├─ Log rejection in request_status_history
    └─ Close popup (request still available for other mechanics)
    ↓
6. Mechanic views job details (customer, vehicle, location)
   ↓
7. Mechanic navigates to customer location (Google Maps/Waze)
   ↓
8. Mechanic completes job → Scans customer QR code
   ↓
9. ShopBasedRequestService.completeJob()
   ├─ Validate completion code
   ├─ Check not expired
   ├─ Update 4 tables:
   │  ├─ service_completions.is_scanned = true
   │  ├─ service_requests.status = 'completed'
   │  ├─ mechanic_availability_status.current_status = 'available'
   │  └─ shop_mechanics.is_available = true
   └─ Show completion confirmation
   ↓
10. Mechanic is now AVAILABLE for new requests
```

---

## 🚧 Pending Tasks (Phase 2)

### 4. **Real-Time Request Subscriptions** 🔄 IN PROGRESS
**What:** Implement Supabase real-time subscriptions in mechanic app  
**Where:** Mechanic main screen or background service  
**Code Example:**
```dart
// In MechanicDashboard or MechanicService
RealtimeChannel? _requestChannel;

void _subscribeToShopRequests(String mechanicId, String shopId) {
  _requestChannel = _supabase
      .channel('shop_requests_$mechanicId')
      .onPostgresChanges(
        table: 'service_requests',
        event: PostgresChangeEvent.insert,
        schema: 'public',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'shop_id',
          value: shopId,
        ),
        callback: (payload) {
          final newRequest = payload.newRecord;
          
          // Check if shop-based request
          if (newRequest['request_type'] == 'shop_based' && 
              newRequest['status'] == 'pending') {
            _showIncomingRequestPopup(newRequest);
          }
        },
      )
      .subscribe();
}

void _showIncomingRequestPopup(Map<String, dynamic> requestData) async {
  final accepted = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => IncomingShopRequestPopup(
      requestId: requestData['id'],
      mechanicId: _mechanicId,
      shopId: _shopId,
      requestData: requestData,
    ),
  );

  if (accepted == true) {
    // Navigate to job details screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => JobDetailsScreen(requestId: requestData['id']),
      ),
    );
  }
}
```

---

### 5. **Integrate Shop Selection into Customer Flow** 📱 NOT STARTED
**What:** Add "Choose Shop" option to customer service request screen  
**Where:** Customer home screen or service request screen  
**Implementation:**
```dart
// Add button next to existing "Broadcast Request" button
ElevatedButton.icon(
  onPressed: () async {
    final requestId = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => ShopSelectionScreen(
          customerId: _customerId,
          vehicleId: _vehicleId,
          categoryId: _categoryId,
          title: _serviceTitle,
          description: _serviceDescription,
          customerLocation: _currentLocation,
        ),
      ),
    );

    if (requestId != null) {
      // Show waiting screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => WaitingForMechanicScreen(requestId: requestId),
        ),
      );
    }
  },
  icon: Icon(Icons.store),
  label: Text('Choose Shop'),
)
```

---

### 6. **Job Details & Navigation Screen** 🗺️ NOT STARTED
**What:** Screen showing full job details after mechanic accepts  
**Features:**
- Customer profile (photo, name, rating, phone with call button)
- Vehicle details card
- Service description
- Location map with customer pin
- "Navigate to Customer" button (opens Google Maps/Waze)
- "Mark as Arrived" button
- Real-time distance tracking

**File to Create:** `lib/mechanic/job_details_screen.dart`

---

### 7. **QR Scanner for Job Completion** 📷 NOT STARTED
**What:** QR code scanner to complete jobs  
**Package:** `qr_code_scanner: ^1.0.1`  
**Features:**
- Camera preview
- QR code detection
- Call `ShopBasedRequestService.completeJob()`
- Handle errors (invalid, expired, already used)
- Show completion animation
- Update mechanic to available

**File to Create:** `lib/mechanic/qr_completion_scanner_screen.dart`

---

### 8. **End-to-End Testing** 🧪 NOT STARTED
**Test Scenarios:**
1. ✅ Happy path: Select shop → Accept → Complete
2. ⚠️ No mechanics available → Show alert → Return
3. ⚠️ All mechanics busy → Show alert → Return
4. ⚠️ Race condition: 2 mechanics accept same request (first wins)
5. ⚠️ Request timeout: Mechanic doesn't respond in 30s
6. ⚠️ Multiple simultaneous requests to same mechanic
7. ⚠️ Network failure during acceptance
8. ⚠️ QR code expired
9. ⚠️ QR code already used

---

## 📦 Dependencies

**Required Packages:**
```yaml
dependencies:
  flutter:
    sdk: flutter
  supabase_flutter: ^2.0.0
  google_maps_flutter: ^2.5.0
  geolocator: ^10.1.0
  qr_code_scanner: ^1.0.1  # For job completion
  url_launcher: ^6.2.0     # For navigation to maps
```

---

## 🎯 Key Design Decisions

1. **Why Separate Queries for Availability?**
   - No direct FK between `shop_mechanics` and `mechanic_availability_status`
   - Both tables link through `user_profiles`
   - Solution: Query separately + manual merge by `mechanic_id`

2. **Why 30-Second Timer?**
   - Prevents indefinite request hanging
   - Similar to Grab/JoyRide driver response time
   - Auto-rejects if no response

3. **Why Two Alert Dialogs?**
   - Different messaging for different scenarios
   - "No mechanics" = shop has no mechanics registered
   - "All busy" = shop has mechanics but all on jobs (temporary state)

4. **Why Full-Screen Popup?**
   - High-priority notification (like incoming call)
   - Prevents accidental dismissal
   - Shows all critical info at once

5. **Why QR Code Completion?**
   - Proof of service completion
   - Prevents fraud (mechanic can't mark job complete without being there)
   - Customer has control over completion

---

## 🔧 Configuration

### **Supabase RLS Policies**

**service_requests:**
```sql
-- Customers can create shop-based requests
CREATE POLICY "Customers can create shop requests"
ON service_requests FOR INSERT
TO authenticated
WITH CHECK (
  auth.uid() = customer_id AND
  request_type = 'shop_based'
);

-- Mechanics can view requests for their shop
CREATE POLICY "Mechanics can view shop requests"
ON service_requests FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM shop_mechanics
    WHERE shop_mechanics.mechanic_id = auth.uid()
      AND shop_mechanics.shop_id = service_requests.shop_id
      AND shop_mechanics.is_active = true
  )
);

-- Mechanics can update requests they're assigned to
CREATE POLICY "Mechanics can update assigned requests"
ON service_requests FOR UPDATE
TO authenticated
USING (assigned_mechanic_id = auth.uid())
WITH CHECK (assigned_mechanic_id = auth.uid());
```

---

## 📈 Future Enhancements

1. **Dynamic Pricing:** Show estimated price before sending request
2. **Mechanic Rating Filter:** Let customers filter shops by mechanic ratings
3. **ETA Calculation:** Show estimated arrival time based on traffic
4. **In-App Chat:** Real-time messaging between customer and mechanic
5. **Request Queue:** Handle multiple simultaneous requests per mechanic
6. **Analytics Dashboard:** Show shop owners request acceptance rates
7. **Push Notifications:** Native push notifications for incoming requests
8. **Offline Mode:** Cache shop data for offline browsing

---

## 🐛 Known Issues / Edge Cases

1. **Race Condition:** If 2 mechanics accept simultaneously, database constraints should prevent duplicate assignment, but UI needs better error handling
2. **Location Permissions:** App needs runtime permission handling for customer location
3. **Map API Key:** Google Maps requires API key configuration in Android/iOS
4. **Network Failures:** Need retry mechanism for failed API calls
5. **Background Subscriptions:** Supabase subscriptions may disconnect when app backgrounded

---

## 📚 Related Documentation

- `COMPLETE_SHOP_SERVICES_FLOW_DOCUMENTATION.md` - Existing shop services system
- `COMPLETE_MECHANIC_POV_IMPLEMENTATION_GUIDE.md` - Mechanic-side features
- `COMPLETE_REAL_TIME_TRACKING_IMPLEMENTATION_GUIDE.md` - Real-time subscriptions
- `AI_VERIFICATION_SYSTEM_ENHANCED_README.md` - Document verification for shop registration

---

## ✅ Summary

**Completed (Phase 1):**
- ✅ Core service layer with all business logic
- ✅ Edge case handling (no mechanics, all busy)
- ✅ Mechanic notification UI with full request details
- ✅ Database update flows (accept, reject, complete)
- ✅ QR code completion logic

**Remaining (Phase 2):**
- 🔄 Real-time subscriptions (IN PROGRESS)
- 📱 Customer UI integration
- 🗺️ Job details screen with navigation
- 📷 QR scanner screen
- 🧪 End-to-end testing

**Next Step:** Implement real-time Supabase subscriptions in mechanic app to trigger the incoming request popup when new shop-based requests arrive.
