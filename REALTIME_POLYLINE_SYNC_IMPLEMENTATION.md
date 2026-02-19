# Real-Time Polyline Synchronization Implementation

## Overview
This guide shows how to add synchronized real-time polylines between mechanic and customer maps for active service tracking.

## Current Status
- ✅ **Mechanic Side**: Already has polylines implemented in `mechanic_job_tracking_bottom_sheet.dart`
- ❌ **Customer Side**: Missing polylines in `main.dart` (ServiceDetailsBottomSheet)
- ❌ **Real-time Sync**: Both sides need to update polylines when locations change

## Implementation Steps

### 1. Customer Side - Add Polyline Drawing Method

Add this method to `_ServiceDetailsBottomSheetState` in `main.dart` after the `_showFallbackRoute()` method:

```dart
// Draw polyline between mechanic and customer with real-time updates
Future<void> _drawPolyline() async {
  if (_mechanicLocation == null || _customerPickupLocation == null) {
    print('⚠️ Cannot draw polyline - missing locations');
    return;
  }

  try {
    print('🎨 Drawing polyline from mechanic to customer');
    
    // Get route from Google Maps API
    final routePoints = await GoogleMapsService.getRoutePoints(
      origin: _mechanicLocation!,
      destination: _customerPickupLocation!,
    );

    if (routePoints != null && routePoints.isNotEmpty && mounted) {
      setState(() {
        _polylines.clear();
        _polylines.add(
          Polyline(
            polylineId: const PolylineId('mechanic_to_customer_route'),
            points: routePoints,
            color: const Color(0xFFB00C01), // RoadAid red color
            width: 5,
            patterns: [
              PatternItem.dash(30),
              PatternItem.gap(15),
            ],
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
            geodesic: true,
            jointType: JointType.round,
          ),
        );
      });

      print('✅ Polyline drawn with ${routePoints.length} points');
      
      // Animate camera to show full route
      _animateCameraToShowRoute(routePoints);
    } else {
      // Fallback to straight line if API fails
      print('⚠️ API failed, drawing straight line polyline');
      _drawStraightLinePolyline();
    }
  } catch (e) {
    print('❌ Error drawing polyline: $e');
    _drawStraightLinePolyline();
  }
}

// Fallback method for straight-line polyline
void _drawStraightLinePolyline() {
  if (_mechanicLocation != null && _customerPickupLocation != null && mounted) {
    setState(() {
      _polylines.clear();
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('mechanic_to_customer_straight'),
          points: [_mechanicLocation!, _customerPickupLocation!],
          color: const Color(0xFFB00C01).withOpacity(0.7),
          width: 4,
          patterns: [
            PatternItem.dot,
            PatternItem.gap(10),
          ],
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          geodesic: true,
        ),
      );
    });
    
    print('✅ Straight line polyline drawn');
    _animateCameraToShowPoints();
  }
}
```

### 2. Customer Side - Call Polyline Drawing

Update the `_updateMechanicLocationFromDatabase()` method in `main.dart` to draw polylines:

```dart
// Inside _processMechanicLocationUpdate method, after updating _mechanicLocation:
await _updateDistanceAndDuration();
await _updateMarkers();
await _drawPolyline(); // ← ADD THIS LINE
```

Also call it in `_getCurrentLocation()` after setting up locations:

```dart
await _updateMarkers();
await _updateDistanceAndDuration();
await _drawPolyline(); // ← ADD THIS LINE
```

### 3. Customer Side - Add Polyline to GoogleMap Widget

Find the GoogleMap widget in the `build()` method and add the polylines property:

```dart
GoogleMap(
  initialCameraPosition: CameraPosition(
    target: _customerPickupLocation ?? const LatLng(14.6760, 121.0437),
    zoom: 14,
  ),
  onMapCreated: (controller) {
    _mapController = controller;
  },
  markers: _markers,
  polylines: _polylines, // ← ADD THIS LINE
  myLocationEnabled: false,
  myLocationButtonEnabled: false,
  zoomControlsEnabled: true,
  mapToolbarEnabled: false,
  mapType: _currentMapType,
  gestureRecognizers: Set()
    ..add(Factory<PanGestureRecognizer>(() => PanGestureRecognizer()))
    ..add(Factory<ScaleGestureRecognizer>(() => ScaleGestureRecognizer()))
    ..add(Factory<TapGestureRecognizer>(() => TapGestureRecognizer()))
    ..add(Factory<VerticalDragGestureRecognizer>(() => VerticalDragGestureRecognizer())),
  onTap: _handleMapTap,
  onLongPress: _handleMapLongPress,
  onCameraIdle: _onCameraIdle,
),
```

### 4. Mechanic Side - Ensure Real-time Polyline Updates

The mechanic side already has polylines. Update the `_updateLocationFromDatabase()` method in `mechanic_job_tracking_bottom_sheet.dart`:

```dart
// Inside _updateLocationFromDatabase method, after updating location:
await _updateDistanceAndDuration();
await _updateMarkers();
await _showRouteAutomatically(); // This already draws polylines
```

### 5. Add Real-time Synchronization

Both sides should redraw polylines when location updates occur:

**In Customer Side (`main.dart`):**

```dart
void _processMechanicLocationUpdate(List<Map<String, dynamic>> data) async {
  // ... existing code ...
  
  if (userId != null) {
    final lat = locationData['latitude'] as double?;
    final lng = locationData['longitude'] as double?;
    
    if (lat != null && lng != null && mounted) {
      setState(() {
        _mechanicLocation = LatLng(lat, lng);
      });
      
      print('📍 Updated mechanic location: $lat, $lng');
      await _updateDistanceAndDuration();
      await _updateMarkers();
      await _drawPolyline(); // ← Real-time polyline update
    }
  }
}
```

**In Mechanic Side (`mechanic_job_tracking_bottom_sheet.dart`):**

```dart
void _processCustomerLocationUpdate(List<Map<String, dynamic>> data) {
  // ... existing code ...
  
  if (lat != null && lng != null && mounted) {
    setState(() {
      _customerLocation = LatLng(lat, lng);
    });
    
    print('📍 Updated customer location: $lat, $lng');
    _updateDistanceAndDuration();
    _updateMarkers();
    _showRouteAutomatically(); // ← Real-time polyline update
  }
}
```

### 6. Polyline Styling Consistency

Ensure both sides use the same polyline styling:

```dart
Polyline(
  polylineId: const PolylineId('route_polyline'),
  points: routePoints,
  color: const Color(0xFFB00C01), // RoadAid red
  width: 5,
  patterns: [
    PatternItem.dash(30),
    PatternItem.gap(15),
  ],
  startCap: Cap.roundCap,
  endCap: Cap.roundCap,
  geodesic: true, // Follow Earth's curvature
  jointType: JointType.round,
)
```

## Testing Checklist

- [ ] Customer sees polyline when mechanic is assigned
- [ ] Mechanic sees polyline when accepting job
- [ ] Polyline updates in real-time when mechanic moves
- [ ] Polyline updates in real-time when customer location changes
- [ ] Both sides show the same route
- [ ] Polyline is visible with proper styling (red, dashed)
- [ ] Camera auto-adjusts to show full route
- [ ] Fallback to straight line works when API fails

## Key Files to Modify

1. **`lib/main.dart`** - Customer side tracking (ServiceDetailsBottomSheet)
   - Add `_drawPolyline()` method
   - Add `_drawStraightLinePolyline()` method
   - Update location tracking methods
   - Add `polylines: _polylines` to GoogleMap widget

2. **`lib/mechanic/widgets/mechanic_job_tracking_bottom_sheet.dart`** - Mechanic side tracking
   - Already has polylines - just ensure real-time updates
   - Verify `_showRouteAutomatically()` is called on location updates

## Benefits

✅ **Visual Clarity**: Both parties see the exact route
✅ **Real-time Updates**: Route updates as positions change
✅ **Synchronized View**: Mechanic and customer see matching routes
✅ **Better UX**: Clear ETA and distance visualization
✅ **Professional Look**: Matches ride-hailing app standards

## Notes

- Polylines use Google Maps API for accurate routing
- Falls back to straight lines if API unavailable
- Updates automatically via Supabase real-time listeners
- Styling matches RoadAid brand colors (red #B00C01)
- Geodesic lines follow Earth's curvature for accuracy
