# Request Creation Debugging Guide

## Issue Found and Fixed ✅

**Problem**: Customer service request creation was failing because shop data wasn't being passed correctly through the navigation flow.

**Root Cause**: In `RequestAssistanceScreen`, the `_navigateToVehicleSelection` method was not passing the shop information from `widget.preSelectedMechanic` to the `VehicleDetailsScreen`.

## Fixed Implementation

### 1. Shop Service Selection → Request Assistance
**File**: `shop_service_selection_screen.dart`
- ✅ Correctly passes shop data including `'serviceType': 'shop_based'`
- ✅ Includes `shopId`, `shopName`, `providerId`, and `shopData`

### 2. Request Assistance → Vehicle Details (FIXED)
**File**: `request_assistance_screen.dart`
- ✅ Now properly merges shop data from `widget.preSelectedMechanic` with analysis data
- ✅ Passes complete mechanic data including shop information to `VehicleDetailsScreen`

### 3. Vehicle Details → Service Request Creation
**File**: `vehicle_details_screen.dart`
- ✅ Correctly extracts `shopId` from `preSelectedMechanic['shopId']`
- ✅ Passes shop data to `ServiceRequestServiceEnhanced.createServiceRequest()`

### 4. Service Request Service
**File**: `service_request_service_enhanced.dart`
- ✅ Correctly detects shop-based requests using `shopData['serviceType'] == 'shop_based'`
- ✅ Routes to shop mechanics only when shop-based
- ✅ Routes to all mechanics when direct request

## How to Test

### Direct Mechanic Request:
1. Customer Dashboard → Service Type Selection
2. Choose "Find Any Available Mechanic"
3. Select issue type → Vehicle → Create request
4. **Expected**: Broadcasts to ALL available mechanics

### Shop-based Request:
1. Customer Dashboard → Service Type Selection  
2. Choose "Choose a Specific Shop"
3. Select shop → Select service → Vehicle → Create request
4. **Expected**: Routes ONLY to mechanics from selected shop

## Debugging Steps if Still Failing

### 1. Check Authentication
```dart
final user = await AuthService.getCurrentUser();
if (user == null) {
  print('❌ User not authenticated');
}
```

### 2. Check Vehicle Data
```dart
if (selectedVehicle['id'] == null) {
  print('❌ Vehicle ID is null');
}
```

### 3. Check Shop Data Passing
```dart
print('🏪 Shop data in RequestAssistanceScreen: ${widget.preSelectedMechanic}');
print('🏪 Shop data in VehicleDetailsScreen: ${widget.preSelectedMechanic}');
print('🏪 Shop data in ServiceRequest: $shopData');
```

### 4. Check Database Permissions
- Ensure user can insert into `service_requests` table
- Ensure user can insert into `request_routing` table
- Check Supabase RLS policies

### 5. Check Required Fields
- `vehicle_id`: Must not be empty
- `title`: Must not be empty (max 100 chars)
- `description`: Must not be empty
- `service_type`: Must not be empty
- `locationAddress`: Must not be empty (was causing issues before)

## Database Flow Verification

### For Shop-based Requests:
1. Request created with `request_type: 'shop_based'`
2. `preferred_shop_id` set to selected shop
3. `is_broadcast_request: false`
4. `can_accept_by_any_mechanic: false`
5. Routing entries created only for mechanics from that shop

### For Direct Requests:
1. Request created with `request_type: 'broadcast'`
2. `is_broadcast_request: true`
3. `can_accept_by_any_mechanic: true`
4. Routing entries created for ALL available mechanics

## Error Messages to Watch For

- "User not authenticated" → Login issue
- "Vehicle ID is required" → Vehicle selection issue
- "Invalid vehicle data" → Database constraint issue
- "Permission denied" → RLS policy issue
- "Failed to create service request" → General database issue

## Success Indicators

✅ Console shows: "✅ Service request created: [REQUEST_ID]"
✅ Console shows proper routing: "✅ Routed request to X mechanics"
✅ Navigation to `MechanicWaitingScreen`
✅ Database entries created in `service_requests` and `request_routing` tables

The fix should resolve the issue where shop data wasn't being passed correctly, allowing both direct and shop-based requests to work properly.