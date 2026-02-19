# 🗺️ BALIWAG, BULACAN LOCATION RESTRICTION

**Date:** October 9, 2025  
**Scope:** Baliwag, Bulacan Only  
**Status:** ✅ IMPLEMENTED

---

## 📍 Overview

Ang RoadAid system ay **limited lang sa Baliwag, Bulacan**. Lahat ng services, mechanics, at customers ay dapat na nasa loob ng Baliwag boundaries.

The RoadAid system is now **restricted to Baliwag, Bulacan only**. All services, mechanics, and customers must be within Baliwag municipal boundaries.

---

## 🎯 Geographic Boundaries

### Baliwag Center:
- **Latitude:** 14.9541
- **Longitude:** 120.8938

### Coverage Area:
- **Radius:** 8 kilometers from center
- **Total Area:** Covers entire Baliwag municipality (~45 km²)

### Boundary Coordinates:
- **North:** 14.99° N
- **South:** 14.92° N
- **East:** 120.93° E
- **West:** 120.86° E

---

## ✅ What's Implemented

### 1. Location Restriction Service
**File:** `lib/services/location_restriction_service.dart`

**Features:**
- ✅ Validate if location is within Baliwag
- ✅ Calculate distance from Baliwag center
- ✅ Filter service requests within Baliwag
- ✅ Filter service providers within Baliwag
- ✅ Filter shops within Baliwag
- ✅ User-friendly error messages (English & Tagalog)

**Key Methods:**
```dart
// Check if location is within Baliwag
bool isWithinBaliwag(LatLng location)

// Get distance from Baliwag center
double getDistanceFromBaliwag(LatLng location)

// Validate and get error message
String? validateLocation(LatLng location)

// Filter requests within Baliwag
List<Map<String, dynamic>> filterRequestsWithinBaliwag(requests)

// Filter providers within Baliwag
List<Map<String, dynamic>> filterProvidersWithinBaliwag(providers)

// Filter shops within Baliwag
List<Map<String, dynamic>> filterShopsWithinBaliwag(shops)
```

---

## 🔧 How To Use

### In Vehicle Details Screen:
```dart
import 'package:your_app/services/location_restriction_service.dart';

// When user selects a location
void _onLocationSelected(LatLng selectedLocation) {
  final restriction = LocationRestrictionService.instance;
  
  // Validate location
  String? error = restriction.validateLocation(selectedLocation);
  
  if (error != null) {
    // Show error to user
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 5),
      ),
    );
    return;
  }
  
  // Location is valid, proceed with service request
  _proceedWithRequest(selectedLocation);
}
```

### In Service Providers Screen:
```dart
// Filter providers to only show those in Baliwag
Future<void> _loadProviders() async {
  final allProviders = await SupabaseService.getServiceProviders();
  final restriction = LocationRestrictionService.instance;
  
  // Filter to only show providers within Baliwag
  final validProviders = restriction.filterProvidersWithinBaliwag(allProviders);
  
  setState(() {
    _providers = validProviders;
  });
}
```

### In Service Request Screen:
```dart
// Validate pickup location before creating request
Future<void> _createServiceRequest(LatLng pickupLocation) async {
  final restriction = LocationRestrictionService.instance;
  
  if (!restriction.isWithinBaliwag(pickupLocation)) {
    _showError(restriction.getServiceAreaMessageTagalog());
    return;
  }
  
  // Proceed with request creation
  await SupabaseService.createServiceRequest(...);
}
```

### In Available Shops Screen:
```dart
// Filter shops within Baliwag
Future<void> _loadShops() async {
  final allShops = await ShopService.getAllShops();
  final restriction = LocationRestrictionService.instance;
  
  // Only show shops in Baliwag
  final validShops = restriction.filterShopsWithinBaliwag(allShops);
  
  setState(() {
    _shops = validShops;
  });
}
```

---

## 📱 User Experience Flow

### For Customers:

**Scenario 1: Valid Location (Within Baliwag)**
```
1. Customer opens app in Baliwag
2. GPS detects location: 14.9541, 120.8938
3. ✅ Location validated - within Baliwag
4. Customer can proceed with service request
5. Shows nearby mechanics within Baliwag
```

**Scenario 2: Invalid Location (Outside Baliwag)**
```
1. Customer opens app outside Baliwag
2. GPS detects location: 15.1234, 121.0567
3. ❌ Location validation fails
4. Error message appears:
   "Lokasyon ay labas ng Baliwag, Bulacan. 
    Ang RoadAid ay available lang sa Baliwag."
5. Customer cannot proceed with request
6. App suggests moving to Baliwag or entering valid address
```

### For Mechanics:

**Scenario 1: Mechanic in Baliwag**
```
1. Mechanic opens app in Baliwag
2. GPS location: 14.9600, 120.8900
3. ✅ Location validated
4. Shows nearby service requests within Baliwag
5. Mechanic can accept jobs
```

**Scenario 2: Mechanic Outside Baliwag**
```
1. Mechanic tries to accept job outside Baliwag
2. GPS location: 15.0500, 121.0000
3. ❌ Location validation fails
4. Error: "You must be in Baliwag, Bulacan to accept jobs"
5. Cannot accept or see requests
```

### For Shop Owners:

**Registering New Shop:**
```
1. Shop owner enters shop address
2. System geocodes address to coordinates
3. ✅/❌ Validates if within Baliwag
4. If outside: "Shop must be located in Baliwag, Bulacan"
5. If inside: Shop registration proceeds
```

---

## 🔍 Validation Rules

### Service Requests:
- ✅ **Pickup location** must be within Baliwag
- ✅ **Destination** (if any) should be within Baliwag
- ❌ Requests from outside Baliwag are **rejected**

### Service Providers:
- ✅ **Shop location** must be in Baliwag
- ✅ **Mechanic location** must be in Baliwag to accept jobs
- ❌ Providers outside Baliwag **cannot accept requests**

### Shops:
- ✅ **Physical address** must be in Baliwag
- ✅ **Coordinates** must fall within boundaries
- ❌ Shops outside Baliwag **cannot be registered**

---

## ⚠️ Error Messages

### English:
```
"This location is outside Baliwag, Bulacan. 
RoadAid services are currently available only in Baliwag, Bulacan. 
Distance from Baliwag center: 12.5 km"
```

### Tagalog:
```
"Lokasyon ay labas ng Baliwag, Bulacan. 
Ang RoadAid ay available lang sa Baliwag, Bulacan. 
Layo mula sa sentro ng Baliwag: 12.5 km"
```

---

## 🗺️ Visual Boundary Map

```
        120.86°E        120.90°E        120.93°E
        ├───────────────┼───────────────┤
14.99°N ┤               │               │
        │    BALIWAG, BULACAN           │
        │         BOUNDARIES             │
14.96°N ┤         ⭐ CENTER             │
        │      (14.9541, 120.8938)      │
        │                                │
14.92°N ┤               │               │
        └───────────────┴───────────────┘
        
Radius: 8 km from center
Area: ~45 km² (entire Baliwag municipality)
```

---

## 📊 Coverage Statistics

- **Municipality:** Baliwag, Bulacan
- **Province:** Bulacan
- **Region:** Central Luzon (Region III)
- **Population:** ~168,470 (2020 Census)
- **Area:** 44.81 km²
- **Service Radius:** 8 km from center
- **Barangays Covered:** All 27 barangays

### Barangays (All Covered):
1. Bagong Nayon
2. Barangca
3. Calantipay
4. Catulinan
5. Concepcion
6. Hinukay
7. Makinabang
8. Matimbo
9. Pagala
10. Paitan
11. Piel
12. Pinagbarilan
13. Poblacion
14. Sabang
15. San Jose
16. San Roque
17. Santa Barbara
18. Santo Cristo
19. Santo Niño
20. Subic
21. Tarcan
22. Tangos
23. Tiaong
24. Villa Cristina
25. Virgen delas Flores
26. San Vicente
27. Tibag

---

## 🔧 Implementation Checklist

### Files to Update:

#### ✅ Already Created:
- [x] `lib/services/location_restriction_service.dart` - Core restriction service

#### ⚠️ Need to Update:
- [ ] `lib/customer/vehicle_details_screen.dart` - Add location validation
- [ ] `lib/customer/service_providers_screen.dart` - Filter providers
- [ ] `lib/customer/available_shops_screen.dart` - Filter shops
- [ ] `lib/mechanic/mechanic_location_based_dashboard.dart` - Validate mechanic location
- [ ] `lib/services/location_service.dart` - Add boundary checks
- [ ] `lib/services/mechanic_request_service.dart` - Filter requests
- [ ] `lib/widgets/nearby_shops_widget.dart` - Filter nearby shops

---

## 🧪 Testing Checklist

### Test Locations:

**Inside Baliwag (Should Work):**
- ✅ Baliwag Center: `14.9541, 120.8938`
- ✅ Poblacion: `14.9546, 120.8931`
- ✅ Sabang: `14.9450, 120.8850`
- ✅ Tangos: `14.9620, 120.9100`

**Outside Baliwag (Should Fail):**
- ❌ Malolos: `14.8433, 120.8114`
- ❌ San Miguel: `15.1442, 120.9770`
- ❌ Manila: `14.5995, 120.9842`
- ❌ San Rafael: `14.9489, 120.9657`

### Test Scenarios:

1. **Customer Request:**
   - [ ] Try to create request inside Baliwag → Should succeed
   - [ ] Try to create request outside Baliwag → Should show error
   - [ ] Select location outside boundary → Should warn user

2. **Mechanic Jobs:**
   - [ ] View requests while in Baliwag → Shows requests
   - [ ] View requests while outside Baliwag → Shows "must be in Baliwag"
   - [ ] Try to accept job outside Baliwag → Rejected

3. **Shops:**
   - [ ] Register shop in Baliwag → Success
   - [ ] Register shop outside Baliwag → Error
   - [ ] View shop list → Only shows Baliwag shops

---

## 📝 Next Steps

### 1. Integrate into Vehicle Details Screen:
Add validation when customer selects pickup location

### 2. Integrate into Service Providers:
Filter list to only show providers within Baliwag

### 3. Integrate into Mechanic Dashboard:
Check mechanic location before showing nearby requests

### 4. Add UI Warnings:
Show boundary map or radius indicator on map

### 5. Database Constraints:
Add CHECK constraints in Supabase to enforce boundaries

---

## 🛡️ Database Level Enforcement

Add these constraints to Supabase:

```sql
-- Add constraint to service_requests table
ALTER TABLE service_requests 
ADD CONSTRAINT check_pickup_in_baliwag 
CHECK (
  pickup_latitude BETWEEN 14.92 AND 14.99 AND
  pickup_longitude BETWEEN 120.86 AND 120.93
);

-- Add constraint to shops table
ALTER TABLE shops 
ADD CONSTRAINT check_shop_in_baliwag 
CHECK (
  latitude BETWEEN 14.92 AND 14.99 AND
  longitude BETWEEN 120.86 AND 120.93
);

-- Add constraint to service_providers table
ALTER TABLE service_providers 
ADD CONSTRAINT check_provider_in_baliwag 
CHECK (
  current_latitude BETWEEN 14.92 AND 14.99 AND
  current_longitude BETWEEN 120.86 AND 120.93
);
```

---

## ✅ Summary

**Baliwag, Bulacan Restriction:**
- ✅ Service created and ready to use
- ✅ Boundaries defined (8km radius from center)
- ✅ Validation methods implemented
- ✅ Filter methods for requests/providers/shops
- ✅ User-friendly error messages
- ⚠️ Needs integration into existing screens
- ⚠️ Needs database constraints

**Next Action:** Integrate `LocationRestrictionService` into all location-dependent screens to enforce Baliwag-only operations.

---

**Implemented:** October 9, 2025  
**Scope:** Baliwag, Bulacan Municipality Only  
**Status:** ✅ Service Ready, Pending Integration
