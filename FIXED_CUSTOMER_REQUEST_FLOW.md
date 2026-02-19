# FIXED: Customer Service Request Flow - Proper Mechanic Routing

## Problem Summary
The original flow was sending ALL customer requests to ALL mechanics regardless of whether the customer wanted:
1. **Direct Mechanic Request** - Any available mechanic in the area
2. **Shop-based Request** - Only mechanics from a specific shop

## Solution Implemented

### 1. New Service Type Selection Screen
Created `service_type_selection_screen.dart` that gives customers a clear choice:

**Option A: Find Any Available Mechanic**
- Broadcasts to ALL nearby mechanics
- Fastest response time
- Usually cheaper rates
- Good for urgent repairs

**Option B: Choose a Specific Shop**
- Browse nearby shops with ratings and services
- Compare prices and reviews
- Only mechanics from selected shop are notified
- Professional facilities with specialized equipment

### 2. Shop Selection Flow
Created `shop_selection_screen.dart` and `shop_service_selection_screen.dart`:

**Shop Selection:**
- Shows nearby shops with distance, ratings, and services
- Filters by open/closed status, distance, ratings
- Search functionality
- Shows service count and price range

**Service Selection:**
- Browse specific services offered by the selected shop
- Compare prices and estimated duration
- Option to request custom service not listed
- Clear indication this is a shop-based request

### 3. Enhanced Service Request Routing
Updated `service_request_service_enhanced.dart` to handle two distinct routing types:

#### Direct Mechanic Request (`request_type: 'broadcast'`)
```dart
'request_type': 'broadcast',
'broadcast_radius_km': 50.0,
'is_broadcast_request': true,
'can_accept_by_any_mechanic': true,
```
- Notifies ALL available mechanics within 50km
- Any mechanic can accept
- Faster response time

#### Shop-based Request (`request_type: 'shop_based'`)
```dart
'request_type': 'shop_based',
'broadcast_radius_km': 5.0,
'is_broadcast_request': false,
'can_accept_by_any_mechanic': false,
'preferred_shop_id': shopId,
```
- Only notifies mechanics from the selected shop
- Smaller radius (5km vs 50km)
- Creates routing entries only for shop mechanics
- Links request to specific shop and provider

### 4. Database Routing Logic

#### For Direct Mechanic Requests:
1. Gets ALL available mechanics from `mechanic_availability_status`
2. Creates `request_routing` entries for each mechanic
3. Creates `request_broadcasts` entries
4. Uses existing broadcast functions

#### For Shop-based Requests:
1. Gets only mechanics from `shop_mechanics` table for the selected shop
2. Filters by `is_active = true` and `current_status = 'available'`
3. Creates targeted `request_routing` entries only for shop mechanics
4. Creates shop-specific `request_broadcasts` entry

### 5. Updated Customer Dashboard
- Replaced direct service request with service type selection
- Customers now must choose their preferred approach
- Maintains existing functionality while adding proper routing

## Technical Implementation

### Key Files Created/Modified:

1. **`service_type_selection_screen.dart`** - NEW
   - Main choice screen between direct mechanic vs shop selection

2. **`shop_selection_screen.dart`** - NEW  
   - Browse and search nearby shops
   - Filter by distance, ratings, open status

3. **`shop_service_selection_screen.dart`** - NEW
   - View specific shop's services and prices
   - Select service or request custom service

4. **`service_request_service_enhanced.dart`** - MODIFIED
   - Added proper routing logic based on request type
   - `_routeToShopMechanics()` for shop-based requests
   - `_routeToAllMechanics()` for direct requests

5. **`customer_dashboard.dart`** - MODIFIED
   - Updated to use new service type selection screen

### Database Impact:

#### Service Request Fields:
- `request_type`: 'broadcast' | 'shop_based'
- `preferred_shop_id`: Set for shop-based requests
- `is_broadcast_request`: true for direct, false for shop-based
- `can_accept_by_any_mechanic`: true for direct, false for shop-based

#### Routing Tables:
- `request_routing`: Only contains eligible mechanics based on request type
- `request_broadcasts`: Targeted to appropriate providers

## User Experience Flow

### Direct Mechanic Flow:
1. Customer: "Find Any Available Mechanic"
2. Describe issue → Select vehicle → Create request
3. System broadcasts to ALL mechanics within 50km
4. First available mechanic can accept
5. **Result: Fastest response, any qualified mechanic**

### Shop-based Flow:
1. Customer: "Choose a Specific Shop"
2. Browse shops → Select preferred shop
3. View shop services → Select service (or custom)
4. Describe issue → Select vehicle → Create request
5. System notifies ONLY mechanics from selected shop
6. **Result: Specific shop handling, professional service**

## Benefits

✅ **Clear Customer Choice** - No confusion about service type
✅ **Proper Mechanic Routing** - Right mechanics get the right requests  
✅ **Better Shop Integration** - Shops get targeted requests
✅ **Maintained Flexibility** - Both urgent and planned service options
✅ **Improved User Experience** - Customers know what to expect

## Testing Verification

To verify the fix works:

1. **Test Direct Mechanic Request:**
   - Choose "Find Any Available Mechanic"
   - Complete request creation
   - Verify ALL mechanics receive notification
   - Check `request_broadcasts` table shows multiple entries

2. **Test Shop-based Request:**
   - Choose "Choose a Specific Shop"
   - Select a shop and service
   - Complete request creation  
   - Verify ONLY mechanics from selected shop receive notification
   - Check `request_routing` table shows only shop mechanics
   - Verify `preferred_shop_id` is set correctly

This fix ensures customers get exactly the type of service they want while mechanics receive only relevant requests they can fulfill.