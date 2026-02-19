import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'location_service.dart';
import 'supabase_service.dart';
import 'logging_service.dart';

class MapsService {
  static const String _apiKey = 'AIzaSyDZBJKJt1UOHT_vvAuSDWz4MCSl77yPY5k';
  static const String _directionsBaseUrl = 'https://maps.googleapis.com/maps/api/directions/json';
  static const String _geocodingBaseUrl = 'https://maps.googleapis.com/maps/api/geocode/json';
  
  // Singleton pattern
  static final MapsService _instance = MapsService._internal();
  factory MapsService() => _instance;
  MapsService._internal();
  
  // Stream controllers for real-time tracking
  final StreamController<List<LatLng>> _routeController = StreamController<List<LatLng>>.broadcast();
  final StreamController<Map<String, dynamic>> _trackingDataController = StreamController<Map<String, dynamic>>.broadcast();
  
  // Streams
  Stream<List<LatLng>> get routeStream => _routeController.stream;
  Stream<Map<String, dynamic>> get trackingDataStream => _trackingDataController.stream;
  
  // Timers for real-time updates
  Timer? _routeUpdateTimer;
  Timer? _locationUpdateTimer;
  // Supabase realtime subscription for mechanic_locations
  StreamSubscription<dynamic>? _mechanicLocationRealtimeSub;
  StreamSubscription<dynamic>? _mechanicLocationRealtimeSubUserId;
    // Tracking state
  bool _isTracking = false;
  LatLng? _lastKnownMechanicLocation;
  String? _currentServiceRequestId;
  LatLng? _destinationLocation;
  
  /// Get directions between two points
  Future<Map<String, dynamic>> getDirections({
    required LatLng origin,
    required LatLng destination,
    String travelMode = 'driving',
  }) async {
    try {
      final String url = '$_directionsBaseUrl?'
          'origin=${origin.latitude},${origin.longitude}&'
          'destination=${destination.latitude},${destination.longitude}&'
          'mode=$travelMode&'
          'key=$_apiKey';
      
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == 'OK' && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final leg = route['legs'][0];
          
          // Decode polyline to get route points
          final List<LatLng> routePoints = _decodePolyline(route['overview_polyline']['points']);
          
          return {
            'success': true,
            'route_points': routePoints,
            'distance': leg['distance']['text'],
            'duration': leg['duration']['text'],
            'distance_value': leg['distance']['value'], // in meters
            'duration_value': leg['duration']['value'], // in seconds
            'start_address': leg['start_address'],
            'end_address': leg['end_address'],
            'bounds': route['bounds'],
          };
        } else {
          throw Exception('No routes found: ${data['status']}');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('❌ Error getting directions: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
  
  /// Get last known mechanic location (for fallback)
  LatLng? get lastKnownMechanicLocation => _lastKnownMechanicLocation;
  
  /// Get current service request ID
  String? get currentServiceRequestId => _currentServiceRequestId;
  
  /// Get destination location
  LatLng? get destinationLocation => _destinationLocation;
  Future<void> startRealTimeTracking({
    required String serviceRequestId,
    required LatLng customerLocation,
    required String mechanicId,
  }) async {
    try {
  LoggingService().info('🗺️ Starting real-time tracking for service request: $serviceRequestId');

      // If we're already tracking the same request, do nothing (idempotent)
      if (_isTracking && _currentServiceRequestId == serviceRequestId) {
        LoggingService().debug('ℹ️ Already tracking serviceRequestId=$serviceRequestId — startRealTimeTracking is idempotent; returning');
        return;
      }

      // Normalize mechanic id and try to resolve if empty
      String localMechanicId = mechanicId;
      if (localMechanicId.trim().isEmpty) {
        try {
          LoggingService().debug('⚠️ mechanicId is empty — attempting to resolve from service request');
          final mechInfo = await SupabaseService.getMechanicLocationForRequest(serviceRequestId);
          if (mechInfo != null && mechInfo['user_id'] != null) {
            final candidate = mechInfo['user_id'];
            if (candidate is String && candidate.trim().isNotEmpty) {
              localMechanicId = candidate;
              LoggingService().info('✅ Resolved mechanicId: $localMechanicId');
            }
          }
        } catch (e) {
    LoggingService().debug('⚠️ Failed to resolve mechanicId from request: $e');
        }
      }

      if (localMechanicId.trim().isEmpty) {
  LoggingService().info('⚠️ No mechanicId available — cannot start real-time tracking');
        return;
      }

  _isTracking = true;
      _currentServiceRequestId = serviceRequestId;
      _destinationLocation = customerLocation;

      // Update route every 10 seconds
      _routeUpdateTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
        if (_isTracking) {
          _updateRoute(localMechanicId, customerLocation);
        }
      });

      // Update mechanic location every 5 seconds
      _locationUpdateTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
        if (_isTracking) {
          _updateMechanicLocation(localMechanicId);
        }
      });

      // Initial route calculation
      await _updateRoute(localMechanicId, customerLocation);

      // Also subscribe to Supabase realtime updates for mechanic_locations for this request
      try {
        _mechanicLocationRealtimeSub?.cancel();
        // Subscribe by service_request_id (preferred)
        _mechanicLocationRealtimeSub?.cancel();
        _mechanicLocationRealtimeSub = SupabaseService.client
            .from('mechanic_locations')
            .stream(primaryKey: ['id'])
            .eq('service_request_id', serviceRequestId)
            .listen((List<Map<String, dynamic>> data) {
          if (data.isNotEmpty) {
            final latest = data.last;
            _processMechanicLocationRow(latest, customerLocation);
          }
        });

        // Additionally, subscribe by user_id to catch updates when service_request_id
        // is not present on the upsert. Keep a lightweight second subscription.
        try {
          final userSub = SupabaseService.client
              .from('mechanic_locations')
              .stream(primaryKey: ['id'])
              .eq('user_id', localMechanicId)
              .listen((List<Map<String, dynamic>> data) {
            if (data.isNotEmpty) {
              final latest = data.last;
              _processMechanicLocationRow(latest, customerLocation);
            }
          });

          // Combine both subscriptions into a single cancelable subscription wrapper
          // by storing the user-sub under _mechanicLocationRealtimeSubUserId
          _mechanicLocationRealtimeSubUserId = userSub;
        } catch (e) {
          LoggingService().debug('⚠️ Failed to create user_id subscription: $e');
        }
      } catch (e) {
          LoggingService().debug('⚠️ Failed to subscribe to mechanic_locations realtime: $e');
      }
      
    } catch (e) {
      print('❌ Error starting real-time tracking: $e');
    }
  }
  
  /// Stop real-time tracking
  void stopRealTimeTracking() {
  LoggingService().info('🛑 Stopping real-time tracking');
    
    _isTracking = false;
    _lastKnownMechanicLocation = null;
    _currentServiceRequestId = null;
    _destinationLocation = null;
    
    _routeUpdateTimer?.cancel();
    _locationUpdateTimer?.cancel();
  _mechanicLocationRealtimeSub?.cancel();
  _mechanicLocationRealtimeSubUserId?.cancel();
    
    if (!_routeController.isClosed) {
      _routeController.add([]);
    }
    if (!_trackingDataController.isClosed) {
      _trackingDataController.add({});
    }
  }
  
  /// Update route between mechanic and customer
  Future<void> _updateRoute(String mechanicId, LatLng customerLocation) async {
    try {
      // Get current mechanic location
      final mechanicLocation = await _getMechanicCurrentLocation(mechanicId);
      if (mechanicLocation == null) {
    LoggingService().debug('⚠️ Mechanic location not available');
        return;
      }

      _lastKnownMechanicLocation = mechanicLocation;

      // Calculate route
      final directions = await getDirections(
        origin: mechanicLocation,
        destination: customerLocation,
      );

      if (directions['success'] == true && directions['route_points'] != null) {
        final List<LatLng> routePoints = List<LatLng>.from(directions['route_points']);

        // Update route stream
        if (!_routeController.isClosed) {
          _routeController.add(routePoints);
        }

        // Update tracking data stream
        if (!_trackingDataController.isClosed) {
          _trackingDataController.add({
            'mechanic_location': mechanicLocation,
            'customer_location': customerLocation,
            'distance': directions['distance'] ?? 'Unknown',
            'duration': directions['duration'] ?? 'Unknown',
            'distance_value': directions['distance_value'] ?? 0,
            'duration_value': directions['duration_value'] ?? 0,
            'eta': _calculateETA(directions['duration_value'] ?? 0),
            'route_points': routePoints,
          });
        }
      } else {
  LoggingService().debug('❌ Failed to get directions: ${directions['error'] ?? 'Unknown error'}');
      }
    } catch (e) {
      LoggingService().error('❌ Error updating route: $e');
    }
  }

  /// Process a mechanic_locations row received from realtime subscription
  Future<void> _processMechanicLocationRow(Map<String, dynamic> row, LatLng customerLocation) async {
    try {
  if (row['latitude'] == null || row['longitude'] == null) return;
      final mechanicLocation = LatLng((row['latitude'] as num).toDouble(), (row['longitude'] as num).toDouble());
      _lastKnownMechanicLocation = mechanicLocation;

  // Calculate route from mechanic to customer
  final directions = await getDirections(origin: mechanicLocation, destination: customerLocation);
  if (directions['success'] == true && directions['route_points'] != null) {
        final List<LatLng> routePoints = List<LatLng>.from(directions['route_points']);

        if (!_routeController.isClosed) {
          _routeController.add(routePoints);
        }

        if (!_trackingDataController.isClosed) {
          _trackingDataController.add({
            'mechanic_location': mechanicLocation,
            'customer_location': customerLocation,
            'distance': directions['distance'] ?? 'Unknown',
            'duration': directions['duration'] ?? 'Unknown',
            'distance_value': directions['distance_value'] ?? 0,
            'duration_value': directions['duration_value'] ?? 0,
            'eta': _calculateETA(directions['duration_value'] ?? 0),
            'route_points': routePoints,
          });
        }

        // Throttled debug: log route length occasionally to avoid log spam
        LoggingService().debug('🗺️ route points received: ${routePoints.length}', throttleMs: 5000);
      }
    } catch (e) {
      print('❌ Error processing mechanic location row: $e');
    }
  }
  
  /// Update mechanic location in database
  Future<void> _updateMechanicLocation(String mechanicId) async {
    try {
      if (mechanicId.trim().isEmpty) {
        print('⚠️ _updateMechanicLocation called with empty mechanicId, skipping DB update');
        return;
      }

      final currentLocation = await LocationService().getCurrentLocation();
      if (currentLocation != null) {
        // Update mechanic location in database using SupabaseService
        await SupabaseService.updateMechanicLocation(
          mechanicId, 
          currentLocation.latitude, 
          currentLocation.longitude
        );
      }
    } catch (e) {
      print('❌ Error updating mechanic location: $e');
    }
  }
  
  /// Get mechanic's current location from database
  Future<LatLng?> _getMechanicCurrentLocation(String mechanicId) async {
    try {
      if (mechanicId.trim().isEmpty) {
        print('⚠️ _getMechanicCurrentLocation called with empty mechanicId, returning null');
        return null;
      }
      final response = await SupabaseService.getMechanicLocation(mechanicId);
      
      if (response != null && 
          response['latitude'] != null && 
          response['longitude'] != null) {
        return LatLng(
          response['latitude'].toDouble(),
          response['longitude'].toDouble(),
        );
      }
      // Fallback: try to get latest location from mechanic_locations table (live upserts)
      try {
        print('ℹ️ Falling back to mechanic_locations table for mechanicId=$mechanicId');
        final mechLoc = await SupabaseService.client
            .from('mechanic_locations')
            .select('latitude, longitude, updated_at')
            .eq('user_id', mechanicId)
            .order('updated_at', ascending: false)
            .limit(1)
            .maybeSingle();

        if (mechLoc != null && mechLoc['latitude'] != null && mechLoc['longitude'] != null) {
          return LatLng((mechLoc['latitude'] as num).toDouble(), (mechLoc['longitude'] as num).toDouble());
        }
      } catch (e) {
        print('❌ Error falling back to mechanic_locations: $e');
      }
      
      return null;
    } catch (e) {
      print('❌ Error getting mechanic location: $e');
      return null;
    }
  }
  
  /// Calculate ETA based on duration in seconds
  String _calculateETA(int durationSeconds) {
    final now = DateTime.now();
    final eta = now.add(Duration(seconds: durationSeconds));
    return '${eta.hour.toString().padLeft(2, '0')}:${eta.minute.toString().padLeft(2, '0')}';
  }
  
  /// Decode Google Maps polyline
  List<LatLng> _decodePolyline(String polyline) {
    List<LatLng> points = [];
    int index = 0;
    int len = polyline.length;
    int lat = 0;
    int lng = 0;
    
    while (index < len) {
      int b;
      int shift = 0;
      int result = 0;
      
      do {
        b = polyline.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;
      
      shift = 0;
      result = 0;
      
      do {
        b = polyline.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;
      
      points.add(LatLng(lat / 1E5, lng / 1E5));
    }
    
    return points;
  }
  
  /// Get address from coordinates (reverse geocoding)
  Future<String?> getAddressFromCoordinates(LatLng location) async {
    try {
      final String url = '$_geocodingBaseUrl?'
          'latlng=${location.latitude},${location.longitude}&'
          'key=$_apiKey';
      
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == 'OK' && data['results'].isNotEmpty) {
          return data['results'][0]['formatted_address'];
        }
      }
      
      return null;
    } catch (e) {
      print('❌ Error getting address: $e');
      return null;
    }
  }
  
  /// Calculate distance between two points
  double calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371; // Earth's radius in kilometers
    
    double lat1Rad = point1.latitude * pi / 180;
    double lat2Rad = point2.latitude * pi / 180;
    double deltaLatRad = (point2.latitude - point1.latitude) * pi / 180;
    double deltaLngRad = (point2.longitude - point1.longitude) * pi / 180;
    
    double a = sin(deltaLatRad / 2) * sin(deltaLatRad / 2) +
        cos(lat1Rad) * cos(lat2Rad) *
        sin(deltaLngRad / 2) * sin(deltaLngRad / 2);
    
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    
    return earthRadius * c;
  }
  
  /// Create custom markers for map
  Set<Marker> createTrackingMarkers({
    LatLng? mechanicLocation,
    LatLng? customerLocation,
    VoidCallback? onMechanicMarkerTap,
    VoidCallback? onCustomerMarkerTap,
  }) {
    Set<Marker> markers = {};
    
    if (mechanicLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('mechanic'),
          position: mechanicLocation,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: const InfoWindow(
            title: 'Mechanic',
            snippet: 'On the way to your location',
          ),
          onTap: onMechanicMarkerTap,
        ),
      );
    }
    
    if (customerLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('customer'),
          position: customerLocation,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: const InfoWindow(
            title: 'Your Location',
            snippet: 'Service destination',
          ),
          onTap: onCustomerMarkerTap,
        ),
      );
    }
    
    return markers;
  }

  /// Build a BitmapDescriptor for mechanic marker (async, reusable)
  Future<BitmapDescriptor> getMechanicMarkerIcon() async {
    try {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  const size = ui.Size(120, 120);

      final paint = Paint()
        ..color = const Color(0xFFEF5350)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(const Offset(60, 60), 50, paint);

      final borderPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6;

      canvas.drawCircle(const Offset(60, 60), 50, borderPaint);

      final textPainter = TextPainter(
        text: const TextSpan(
          text: '🔧',
          style: TextStyle(fontSize: 40),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, const Offset(40, 40));

  final picture = recorder.endRecording();
  final image = await picture.toImage(size.width.toInt(), size.height.toInt());
  final pngBytes = await image.toByteData(format: ui.ImageByteFormat.png);
      return BitmapDescriptor.fromBytes(pngBytes!.buffer.asUint8List());
    } catch (_) {
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
    }
  }

  /// Build a BitmapDescriptor for customer marker
  Future<BitmapDescriptor> getCustomerMarkerIcon() async {
    try {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  const size = ui.Size(120, 120);

      final paint = Paint()
        ..color = const Color(0xFF1976D2)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(const Offset(60, 60), 50, paint);

      final borderPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6;

      canvas.drawCircle(const Offset(60, 60), 50, borderPaint);

      final textPainter = TextPainter(
        text: const TextSpan(
          text: '👤',
          style: TextStyle(fontSize: 40),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, const Offset(40, 40));

  final picture = recorder.endRecording();
  final image = await picture.toImage(size.width.toInt(), size.height.toInt());
  final pngBytes = await image.toByteData(format: ui.ImageByteFormat.png);
      return BitmapDescriptor.fromBytes(pngBytes!.buffer.asUint8List());
    } catch (_) {
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
    }
  }
  
  /// Create polyline for route
  Polyline createRoutePolyline(List<LatLng> routePoints, {Color? color, int width = 6, List<PatternItem>? patterns}) {
    // Default to a solid blue line (match mechanic map style). Callers may override color/patterns.
    final polyColor = color ?? const Color(0xFF1976D2); // Blue 700
    final polyPatterns = patterns; // null means solid line

    return Polyline(
      polylineId: const PolylineId('route'),
      points: routePoints,
      color: polyColor,
      width: width,
  patterns: polyPatterns ?? [],
      startCap: Cap.roundCap,
      endCap: Cap.roundCap,
      geodesic: true,
    );
  }
  
  /// Calculate camera bounds to show both markers
  CameraUpdate calculateCameraBounds(LatLng point1, LatLng point2) {
    double minLat = min(point1.latitude, point2.latitude);
    double maxLat = max(point1.latitude, point2.latitude);
    double minLng = min(point1.longitude, point2.longitude);
    double maxLng = max(point1.longitude, point2.longitude);
    
    // Add padding
    double latPadding = (maxLat - minLat) * 0.2;
    double lngPadding = (maxLng - minLng) * 0.2;
    
    return CameraUpdate.newLatLngBounds(
      LatLngBounds(
        southwest: LatLng(minLat - latPadding, minLng - lngPadding),
        northeast: LatLng(maxLat + latPadding, maxLng + lngPadding),
      ),
      100.0, // padding
    );
  }
  
  /// Dispose resources
  void dispose() {
    stopRealTimeTracking();
    if (!_routeController.isClosed) {
      _routeController.close();
    }
    if (!_trackingDataController.isClosed) {
      _trackingDataController.close();
    }
  }
}










