import 'dart:async';
import 'dart:math' as math;
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'supabase_service.dart';
import 'auth_service.dart';
import 'audit_logging_service.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  LatLng? _currentLocation;
  String? _currentAddress;
  bool _isTracking = false;
  StreamSubscription<Position>? _locationSubscription;
  StreamSubscription? _realtimeSubscription;
  
  // Debouncing variables
  DateTime? _lastLocationUpdate;
  static const Duration _locationUpdateCooldown = Duration(seconds: 5);
  
  // Real-time location stream controller
  final StreamController<Map<String, dynamic>> _locationStreamController = 
      StreamController<Map<String, dynamic>>.broadcast();
  
  Stream<Map<String, dynamic>> get locationStream => _locationStreamController.stream;
  
  // Get current device location and save to database
  Future<LatLng?> getCurrentLocation() async {
    try {
      // Check if location service is enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('Location services are disabled');
        return null;
      }

      // Check permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('Location permissions are denied');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print('Location permissions are permanently denied');
        return null;
      }

      // Get location with timeout
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      
      _currentLocation = LatLng(
        position.latitude,
        position.longitude,
      );
      
      // SAVE TO DATABASE - This is the key part
      await _updateUserLocationInDatabase(_currentLocation!);
      
      return _currentLocation;
    } catch (e) {
      print('Error getting location: $e');
      // Return default location (Metro Manila)
      return const LatLng(14.6760, 121.0437);
    }
  }

  // Get location with address
  Future<Map<String, dynamic>?> getCurrentLocationWithAddress() async {
    final location = await getCurrentLocation();
    if (location == null) return null;

    final address = await _getAddressFromCoordinates(location);
    _currentAddress = address;

    return {
      'latitude': location.latitude,
      'longitude': location.longitude,
      'address': address,
    };
  }

  // Public method to get address from coordinates
  Future<String> getAddressFromCoordinates(double latitude, double longitude) async {
    return _getAddressFromCoordinates(LatLng(latitude, longitude));
  }

  // Convert coordinates to address
  Future<String> _getAddressFromCoordinates(LatLng location) async {
    try {
      // Validate coordinates
      if (location.latitude == 0.0 && location.longitude == 0.0) {
        return 'Location unavailable';
      }
      
      List<geo.Placemark> placemarks = await geo.placemarkFromCoordinates(
        location.latitude, 
        location.longitude
      );
      
      if (placemarks.isNotEmpty) {
        final place = placemarks[0];
        final street = place.street ?? '';
        final locality = place.locality ?? '';
        final adminArea = place.administrativeArea ?? '';
        
        return '$street, $locality, $adminArea'.replaceAll(RegExp(r'^,\s*|,\s*$'), '');
      }
    } catch (e) {
      print('Error getting address: $e');
    }
    
    return 'Lat: ${location.latitude.toStringAsFixed(4)}, Lng: ${location.longitude.toStringAsFixed(4)}';
  }

  // Update user location in database with real-time broadcast
  Future<void> _updateUserLocationInDatabase(LatLng location) async {
    try {
      // Debounce location updates to prevent spam
      final now = DateTime.now();
      if (_lastLocationUpdate != null && 
          now.difference(_lastLocationUpdate!).inSeconds < _locationUpdateCooldown.inSeconds) {
        print('Location update debounced, skipping...');
        return;
      }
      
      final userId = AuthService.instance.userId;
      if (userId == null) {
        print('No user ID available, cannot save location');
        return;
      }

      print('Saving location to database: ${location.latitude}, ${location.longitude}');
      _lastLocationUpdate = now;

      // Update user_profiles with location
      await SupabaseService.client
          .from('user_profiles')
          .update({
            'current_latitude': location.latitude,
            'current_longitude': location.longitude,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', userId);

      // Log location update for audit trail
      try {
        final userProfile = AuthService.instance.userProfile;
        final userType = userProfile?['user_type'] ?? 'unknown';
        
        final auditService = AuditLoggingService();
        await auditService.logLocationUpdate(
          userId: userId,
          role: userType,
          latitude: location.latitude,
          longitude: location.longitude,
          activity: _isTracking ? 'real_time_tracking' : 'location_update',
        );
      } catch (auditError) {
        print('Failed to log location update audit: $auditError');
      }

      print('Location saved successfully to user_profiles');

      // Check if user is mechanic and update service provider location
      await _updateMechanicLocationIfApplicable(location);

      // Broadcast location update to stream
      _locationStreamController.add({
        'user_id': userId,
        'latitude': location.latitude,
        'longitude': location.longitude,
        'address': _currentAddress ?? '',
        'timestamp': DateTime.now().toIso8601String(),
      });

    } catch (e) {
      print('Error updating user location in database: $e');
      // Don't rethrow to prevent app crashes
    }
  }

  // Enhanced mechanic location update with real-time
  Future<void> _updateMechanicLocationIfApplicable(LatLng location) async {
    try {
      final userId = AuthService.instance.userId;
      if (userId == null || userId.isEmpty) {
        print('No valid user ID available for location update');
        return;
      }

      // Check if user is a mechanic
      final userProfile = await SupabaseService.client
          .from('user_profiles')
          .select('user_type')
          .eq('id', userId)
          .maybeSingle();

      if (userProfile?['user_type'] == 'mechanic') {
        print('User is mechanic, updating service_providers location');
        
        // Update service provider location for mechanic
        await SupabaseService.client
            .from('service_providers')
            .update({
              'current_latitude': location.latitude,
              'current_longitude': location.longitude,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('user_id', userId);
        
        print('Mechanic service provider location updated successfully');
      }
    } catch (e) {
      print('Error updating mechanic location: $e');
      // Don't rethrow to prevent app crashes
    }
  }

  // Start real-time location tracking with Supabase real-time subscriptions
  Stream<LatLng> startLocationTracking() {
    if (_isTracking) {
      // Return existing stream if already tracking
      return Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).map((position) => LatLng(position.latitude, position.longitude));
    }

    _isTracking = true;
    print('Starting location tracking...');
    
    // Start device location tracking with Geolocator
    _locationSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Update every 10 meters
      ),
    ).listen(
      (position) {
        final newLocation = LatLng(position.latitude, position.longitude);
        _currentLocation = newLocation; // Update cached location
        
        // Update database every 30 seconds to avoid too many requests
        _throttledLocationUpdate(newLocation);
      },
      onError: (error) {
        print('Location stream error: $error');
      }
    );

    // Start Supabase real-time subscription for other users/mechanics
    _startRealtimeSubscription();
    
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).map((position) => LatLng(position.latitude, position.longitude));
  }

  // Start Supabase real-time subscription
  void _startRealtimeSubscription() {
    try {
      // Cancel existing subscription if any
      _realtimeSubscription?.cancel();

      // Subscribe to user_profiles changes for location updates
      _realtimeSubscription = SupabaseService.client
          .from('user_profiles')
          .stream(primaryKey: ['id'])
          .listen(
            (List<Map<String, dynamic>> data) {
              for (final user in data) {
                if (user['current_latitude'] != null && user['current_longitude'] != null) {
                  _locationStreamController.add({
                    'user_id': user['id'],
                    'latitude': user['current_latitude'],
                    'longitude': user['current_longitude'],
                    'user_type': user['user_type'],
                    'first_name': user['first_name'],
                    'last_name': user['last_name'],
                    'is_available': user['is_available'],
                    'timestamp': user['updated_at'],
                  });
                }
              }
            },
            onError: (error) {
              print('Real-time subscription error: $error');
            }
          );

      print('Real-time subscription started for user locations');
    } catch (e) {
      print('Error starting real-time subscription: $e');
    }
  }

  // Get real-time mechanic locations for active service requests
  Stream<List<Map<String, dynamic>>> getMechanicLocationsStream({String? requestId}) {
    try {
      // Get mechanic locations from service_providers with user profiles
      return SupabaseService.client
          .from('service_providers')
          .stream(primaryKey: ['id'])
          .eq('status', 'online')
          .map((data) => data.cast<Map<String, dynamic>>());
    } catch (e) {
      print('Error getting mechanic locations stream: $e');
      return Stream.value([]);
    }
  }

  // Get real-time location updates for a specific user
  Stream<Map<String, dynamic>?> getUserLocationStream(String userId) {
    try {
      return SupabaseService.client
          .from('user_profiles')
          .stream(primaryKey: ['id'])
          .eq('id', userId)
          .map((data) {
            if (data.isNotEmpty) {
              final user = data.first;
              if (user['current_latitude'] != null && user['current_longitude'] != null) {
                return {
                  'user_id': user['id'],
                  'latitude': user['current_latitude'],
                  'longitude': user['current_longitude'],
                  'timestamp': user['updated_at'],
                };
              }
            }
            return null;
          });
    } catch (e) {
      print('Error getting user location stream: $e');
      return Stream.value(null);
    }
  }

  DateTime? _lastUpdateTime;
  
  // Throttled location update - saves every 30 seconds
  void _throttledLocationUpdate(LatLng location) {
    final now = DateTime.now();
    if (_lastUpdateTime == null || 
        now.difference(_lastUpdateTime!).inSeconds >= 30) {
      _lastUpdateTime = now;
      print('Throttled location update triggered');
      _updateUserLocationInDatabase(location);
    }
  }

  // Stop location tracking and clean up subscriptions
  void stopLocationTracking() {
    _isTracking = false;
    _locationSubscription?.cancel();
    _realtimeSubscription?.cancel();
    _locationSubscription = null;
    _realtimeSubscription = null;
    print('Location tracking stopped');
  }

  // Force immediate location save (for manual updates)
  Future<void> forceLocationUpdate() async {
    final location = await getCurrentLocation();
    if (location != null) {
      await _updateUserLocationInDatabase(location);
    }
  }

  // Get nearby mechanics in real-time
  Stream<List<Map<String, dynamic>>> getNearbyMechanicsStream({
    required LatLng userLocation,
    double radiusKm = 10.0,
  }) async* {
    try {
      await for (final data in SupabaseService.client
          .from('user_profiles')
          .stream(primaryKey: ['id'])) {
        
        List<Map<String, dynamic>> nearbyMechanics = [];
        
        for (final mechanic in data) {
          // Filter for mechanics that are active and available
          if (mechanic['user_type'] == 'mechanic' && 
              mechanic['status'] == 'active' &&
              mechanic['is_available'] == true &&
              mechanic['current_latitude'] != null && 
              mechanic['current_longitude'] != null) {
            
            try {
              final mechanicLocation = LatLng(
                (mechanic['current_latitude'] as num).toDouble(),
                (mechanic['current_longitude'] as num).toDouble(),
              );

              final distance = calculateDistance(userLocation, mechanicLocation);

              if (distance <= radiusKm) {
                nearbyMechanics.add({
                  ...mechanic,
                  'distance': distance,
                  'location': mechanicLocation,
                });
              }
            } catch (e) {
              print('Error processing mechanic location: $e');
              continue;
            }
          }
        }

        // Sort by distance
        nearbyMechanics.sort((a, b) => a['distance'].compareTo(b['distance']));
        yield nearbyMechanics;
      }
    } catch (e) {
      print('Error in nearby mechanics stream: $e');
      yield [];
    }
  }

  // Calculate distance between two points
  double calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371; // Earth's radius in kilometers
    
    final double lat1Rad = point1.latitude * (math.pi / 180);
    final double lat2Rad = point2.latitude * (math.pi / 180);
    final double deltaLatRad = (point2.latitude - point1.latitude) * (math.pi / 180);
    final double deltaLngRad = (point2.longitude - point1.longitude) * (math.pi / 180);
    
    final double a = math.pow(math.sin(deltaLatRad / 2), 2) +
        math.cos(lat1Rad) * math.cos(lat2Rad) *
        math.pow(math.sin(deltaLngRad / 2), 2);
    final double c = 2 * math.asin(math.sqrt(a));
    
    return earthRadius * c;
  }

  // Get cached current location
  LatLng? get cachedLocation => _currentLocation;
  
  // Get cached current address
  String? get cachedAddress => _currentAddress;
  
  // Check if currently tracking location
  bool get isTracking => _isTracking;

  // Cleanup method
  void dispose() {
    stopLocationTracking();
    _locationStreamController.close();
  }
}