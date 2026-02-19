import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:math' as math;

/// Service to enforce geographic restrictions to Baliwag, Bulacan only
class LocationRestrictionService {
  static final LocationRestrictionService _instance = LocationRestrictionService._internal();
  factory LocationRestrictionService() => _instance;
  LocationRestrictionService._internal();

  static LocationRestrictionService get instance => _instance;

  // =====================================================
  // BALIWAG, BULACAN BOUNDARIES
  // =====================================================
  
  /// Center of Baliwag, Bulacan
  static const LatLng baliwagCenter = LatLng(14.9541, 120.8938);
  
  /// Maximum radius from center (in kilometers)
  /// Baliwag is approximately 45 km² area, so ~6km radius should cover most of it
  static const double maxRadiusKm = 8.0; // 8km radius to cover entire Baliwag
  
  /// Approximate boundaries of Baliwag, Bulacan
  /// These coordinates roughly define the municipal boundaries
  static const double minLatitude = 14.92; // Southern boundary
  static const double maxLatitude = 14.99; // Northern boundary
  static const double minLongitude = 120.86; // Western boundary
  static const double maxLongitude = 120.93; // Eastern boundary

  // =====================================================
  // LOCATION VALIDATION METHODS
  // =====================================================

  /// Check if a location is within Baliwag, Bulacan boundaries
  bool isWithinBaliwag(LatLng location) {
    // Method 1: Check if within bounding box
    bool withinBoundingBox = location.latitude >= minLatitude &&
        location.latitude <= maxLatitude &&
        location.longitude >= minLongitude &&
        location.longitude <= maxLongitude;
    
    // Method 2: Check distance from center
    double distanceFromCenter = _calculateDistance(
      baliwagCenter.latitude,
      baliwagCenter.longitude,
      location.latitude,
      location.longitude,
    );
    
    bool withinRadius = distanceFromCenter <= maxRadiusKm;
    
    // Location must satisfy both conditions
    return withinBoundingBox && withinRadius;
  }

  /// Get distance from location to Baliwag center (in kilometers)
  double getDistanceFromBaliwag(LatLng location) {
    return _calculateDistance(
      baliwagCenter.latitude,
      baliwagCenter.longitude,
      location.latitude,
      location.longitude,
    );
  }

  /// Check if location is within Baliwag with custom tolerance
  bool isWithinBaliwagWithTolerance(LatLng location, double toleranceKm) {
    double distance = getDistanceFromBaliwag(location);
    return distance <= (maxRadiusKm + toleranceKm);
  }

  /// Validate location and return error message if outside Baliwag
  String? validateLocation(LatLng location) {
    if (!isWithinBaliwag(location)) {
      double distance = getDistanceFromBaliwag(location);
      return 'Lokasyon ay labas ng Baliwag, Bulacan. '
          'Distance: ${distance.toStringAsFixed(1)} km mula sa sentro. '
          'Ang RoadAid ay available lang sa Baliwag, Bulacan.';
    }
    return null; // Valid location
  }

  /// Get user-friendly message about service area
  String getServiceAreaMessage() {
    return 'RoadAid services are currently available only in Baliwag, Bulacan. '
        'Please make sure your location is within Baliwag municipal boundaries.';
  }

  /// Get Tagalog service area message
  String getServiceAreaMessageTagalog() {
    return 'Ang RoadAid ay available lang sa Baliwag, Bulacan. '
        'Siguraduhin na ang iyong lokasyon ay nasa loob ng Baliwag.';
  }

  // =====================================================
  // FILTER METHODS FOR SERVICE PROVIDERS/REQUESTS
  // =====================================================

  /// Filter service requests to only include those within Baliwag
  List<Map<String, dynamic>> filterRequestsWithinBaliwag(
    List<Map<String, dynamic>> requests,
  ) {
    return requests.where((request) {
      final lat = request['pickup_latitude'] ?? request['latitude'];
      final lng = request['pickup_longitude'] ?? request['longitude'];
      
      if (lat == null || lng == null) return false;
      
      final location = LatLng(
        double.parse(lat.toString()),
        double.parse(lng.toString()),
      );
      
      return isWithinBaliwag(location);
    }).toList();
  }

  /// Filter service providers to only include those within Baliwag
  List<Map<String, dynamic>> filterProvidersWithinBaliwag(
    List<Map<String, dynamic>> providers,
  ) {
    return providers.where((provider) {
      final lat = provider['current_latitude'] ?? provider['latitude'];
      final lng = provider['current_longitude'] ?? provider['longitude'];
      
      if (lat == null || lng == null) return false;
      
      final location = LatLng(
        double.parse(lat.toString()),
        double.parse(lng.toString()),
      );
      
      return isWithinBaliwag(location);
    }).toList();
  }

  /// Filter shops to only include those within Baliwag
  List<Map<String, dynamic>> filterShopsWithinBaliwag(
    List<Map<String, dynamic>> shops,
  ) {
    return shops.where((shop) {
      final lat = shop['latitude'];
      final lng = shop['longitude'];
      
      if (lat == null || lng == null) return false;
      
      final location = LatLng(
        double.parse(lat.toString()),
        double.parse(lng.toString()),
      );
      
      return isWithinBaliwag(location);
    }).toList();
  }

  // =====================================================
  // HELPER METHODS
  // =====================================================

  /// Calculate distance between two coordinates using Haversine formula
  /// Returns distance in kilometers
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadiusKm = 6371.0;

    double dLat = _degreesToRadians(lat2 - lat1);
    double dLon = _degreesToRadians(lon2 - lon1);

    double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(lat1)) *
            math.cos(_degreesToRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadiusKm * c;
  }

  /// Convert degrees to radians
  double _degreesToRadians(double degrees) {
    return degrees * math.pi / 180.0;
  }

  /// Get formatted boundary information for debugging
  Map<String, dynamic> getBoundaryInfo() {
    return {
      'center': {
        'lat': baliwagCenter.latitude,
        'lng': baliwagCenter.longitude,
      },
      'radius_km': maxRadiusKm,
      'boundaries': {
        'north': maxLatitude,
        'south': minLatitude,
        'east': maxLongitude,
        'west': minLongitude,
      },
      'area_name': 'Baliwag, Bulacan',
    };
  }

  /// Check if two locations are both within Baliwag
  bool areBothLocationsInBaliwag(LatLng location1, LatLng location2) {
    return isWithinBaliwag(location1) && isWithinBaliwag(location2);
  }

  /// Get nearest point within Baliwag boundaries (for snapping to valid location)
  LatLng getNearestValidLocation(LatLng location) {
    if (isWithinBaliwag(location)) {
      return location; // Already valid
    }

    // If outside, return center of Baliwag
    return baliwagCenter;
  }
}
