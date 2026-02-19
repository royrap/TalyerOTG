import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapsDirectionService {
  static final MapsDirectionService _instance = MapsDirectionService._internal();
  static MapsDirectionService get instance => _instance;
  MapsDirectionService._internal();

  // Your API Configuration
  static const String _baseUrl = 'https://your-RoadAid-api.com'; // Replace with your actual API
  static const String _apiKey = 'your_api_key_here'; // Replace with your API key

  /// Get directions with polyline from your API for mechanics
  Future<Map<String, dynamic>?> getDirectionsWithPolyline({
    required LatLng origin,
    required LatLng destination,
    String travelMode = 'driving',
  }) async {
    try {
      print('🗺️ Getting directions from your API...');
      print('🚀 Origin: ${origin.latitude}, ${origin.longitude}');
      print('🏁 Destination: ${destination.latitude}, ${destination.longitude}');

      // Construct request to your API
      final Map<String, dynamic> requestBody = {
        'origin': {
          'latitude': origin.latitude,
          'longitude': origin.longitude,
        },
        'destination': {
          'latitude': destination.latitude,
          'longitude': destination.longitude,
        },
        'travel_mode': travelMode,
        'include_polyline': true,
        'include_steps': true,
        'optimize_route': true,
      };

      final response = await http.post(
        Uri.parse('$_baseUrl/api/directions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
          'User-Agent': 'RoadAid-Mobile/1.0',
        },
        body: jsonEncode(requestBody),
      );

      print('🔗 API Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        
        if (data['success'] == true && data['route'] != null) {
          final route = data['route'] as Map<String, dynamic>;
          
          // Extract polyline points from your API response
          final polylinePoints = _decodePolyline(route['polyline'] ?? '');
          
          // Extract turn-by-turn directions
          final steps = <Map<String, dynamic>>[];
          if (route['steps'] != null) {
            for (final step in route['steps'] as List) {
              steps.add({
                'instruction': step['instruction'] ?? '',
                'distance': step['distance'] ?? 0,
                'duration': step['duration'] ?? 0,
                'maneuver': step['maneuver'] ?? 'straight',
                'location': LatLng(
                  (step['location']?['latitude'] ?? 0).toDouble(),
                  (step['location']?['longitude'] ?? 0).toDouble(),
                ),
              });
            }
          }

          print('✅ Got ${polylinePoints.length} polyline points from your API');
          print('✅ Got ${steps.length} direction steps');
          
          return {
            'polyline_points': polylinePoints,
            'total_distance': route['total_distance'] ?? '0 km',
            'total_duration': route['total_duration'] ?? '0 mins',
            'steps': steps,
            'traffic_info': route['traffic_info'],
            'route_quality': route['route_quality'] ?? 'good',
          };
        } else {
          print('❌ API returned error: ${data['error'] ?? 'Unknown error'}');
          return _fallbackToGoogleDirections(origin, destination);
        }
      } else {
        print('❌ API request failed: ${response.statusCode}');
        print('❌ Response: ${response.body}');
        return _fallbackToGoogleDirections(origin, destination);
      }
    } catch (e) {
      print('❌ Error getting directions from your API: $e');
      return _fallbackToGoogleDirections(origin, destination);
    }
  }

  /// Fallback to Google Directions API if your API is unavailable
  Future<Map<String, dynamic>?> _fallbackToGoogleDirections(
    LatLng origin,
    LatLng destination,
  ) async {
    try {
      print('🔄 Falling back to Google Directions API...');
      
      const String googleApiKey = 'AIzaSyBCOoWsQw9rqA7KmwMEG6kXOzUcT8h7234'; // Replace with your Google API key
      
      final String url = 'https://maps.googleapis.com/maps/api/directions/json?'
          'origin=${origin.latitude},${origin.longitude}&'
          'destination=${destination.latitude},${destination.longitude}&'
          'mode=driving&'
          'alternatives=false&'
          'key=$googleApiKey';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['status'] == 'OK' && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final leg = route['legs'][0];
          
          // Decode polyline from Google
          final polylinePoints = _decodePolyline(route['overview_polyline']['points']);
          
          // Extract steps from Google
          final steps = <Map<String, dynamic>>[];
          for (final step in leg['steps']) {
            steps.add({
              'instruction': _stripHtml(step['html_instructions']),
              'distance': step['distance']['text'],
              'duration': step['duration']['text'],
              'maneuver': step['maneuver'] ?? 'straight',
              'location': LatLng(
                step['start_location']['lat'].toDouble(),
                step['start_location']['lng'].toDouble(),
              ),
            });
          }

          print('✅ Fallback: Got ${polylinePoints.length} polyline points from Google');
          
          return {
            'polyline_points': polylinePoints,
            'total_distance': leg['distance']['text'],
            'total_duration': leg['duration']['text'],
            'steps': steps,
            'traffic_info': null,
            'route_quality': 'fallback',
          };
        }
      }
      
      print('❌ Google Directions API also failed');
      return null;
    } catch (e) {
      print('❌ Error with Google fallback: $e');
      return null;
    }
  }

  /// Get optimized route for multiple stops (for mechanics with multiple jobs)
  Future<Map<String, dynamic>?> getOptimizedRoute({
    required LatLng start,
    required List<LatLng> waypoints,
    LatLng? end,
  }) async {
    try {
      print('🗺️ Getting optimized route for ${waypoints.length} waypoints...');

      final Map<String, dynamic> requestBody = {
        'start': {
          'latitude': start.latitude,
          'longitude': start.longitude,
        },
        'waypoints': waypoints.map((point) => {
          'latitude': point.latitude,
          'longitude': point.longitude,
        }).toList(),
        'end': end != null ? {
          'latitude': end.latitude,
          'longitude': end.longitude,
        } : null,
        'optimize': true,
        'travel_mode': 'driving',
      };

      final response = await http.post(
        Uri.parse('$_baseUrl/api/optimize-route'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
          'User-Agent': 'RoadAid-Mobile/1.0',
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        
        if (data['success'] == true) {
          final optimizedRoute = data['optimized_route'] as Map<String, dynamic>;
          
          return {
            'polyline_points': _decodePolyline(optimizedRoute['polyline'] ?? ''),
            'waypoint_order': optimizedRoute['waypoint_order'] ?? [],
            'total_distance': optimizedRoute['total_distance'] ?? '0 km',
            'total_duration': optimizedRoute['total_duration'] ?? '0 mins',
            'estimated_fuel_cost': optimizedRoute['fuel_cost'],
            'route_segments': optimizedRoute['segments'] ?? [],
          };
        }
      }
      
      return null;
    } catch (e) {
      print('❌ Error getting optimized route: $e');
      return null;
    }
  }

  /// Get real-time traffic information for a route
  Future<Map<String, dynamic>?> getTrafficInfo({
    required LatLng origin,
    required LatLng destination,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/traffic'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'origin': {
            'latitude': origin.latitude,
            'longitude': origin.longitude,
          },
          'destination': {
            'latitude': destination.latitude,
            'longitude': destination.longitude,
          },
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        return {
          'traffic_level': data['traffic_level'] ?? 'unknown',
          'delays': data['delays'] ?? [],
          'alternate_routes': data['alternate_routes'] ?? [],
          'estimated_delay': data['estimated_delay'] ?? '0 mins',
          'road_conditions': data['road_conditions'] ?? [],
        };
      }
      
      return null;
    } catch (e) {
      print('❌ Error getting traffic info: $e');
      return null;
    }
  }

  /// Create polyline for Google Maps from route points
  Polyline createPolyline({
    required String polylineId,
    required List<LatLng> points,
    Color color = const Color(0xFF176C12), // RoadAid red color
    int width = 4,
  }) {
    return Polyline(
      polylineId: PolylineId(polylineId),
      points: points,
      color: color,
      width: width,
      patterns: [], // Solid line
      geodesic: true,
    );
  }

  /// Create animated polyline (for showing route progression)
  Polyline createAnimatedPolyline({
    required String polylineId,
    required List<LatLng> points,
    required double progress, // 0.0 to 1.0
    Color color = const Color(0xFF176C12),
    int width = 4,
  }) {
    final animatedPoints = <LatLng>[];
    final totalPoints = points.length;
    final progressIndex = (totalPoints * progress).floor();
    
    if (progressIndex > 0) {
      animatedPoints.addAll(points.take(progressIndex));
      
      // Add interpolated point for smooth animation
      if (progressIndex < totalPoints - 1) {
        final currentPoint = points[progressIndex - 1];
        final nextPoint = points[progressIndex];
        final segmentProgress = (totalPoints * progress) - progressIndex + 1;
        
        final interpolatedLat = currentPoint.latitude + 
            (nextPoint.latitude - currentPoint.latitude) * segmentProgress;
        final interpolatedLng = currentPoint.longitude + 
            (nextPoint.longitude - currentPoint.longitude) * segmentProgress;
        
        animatedPoints.add(LatLng(interpolatedLat, interpolatedLng));
      }
    }

    return Polyline(
      polylineId: PolylineId(polylineId),
      points: animatedPoints,
      color: color,
      width: width,
      patterns: [],
      geodesic: true,
    );
  }

  /// Decode polyline string to LatLng points
  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }

    return points;
  }

  /// Strip HTML tags from text
  String _stripHtml(String html) {
    RegExp exp = RegExp(r"<[^>]*>", multiLine: true, caseSensitive: true);
    return html.replaceAll(exp, '');
  }

  /// Get estimated arrival time based on current traffic
  Future<DateTime?> getEstimatedArrival({
    required LatLng origin,
    required LatLng destination,
  }) async {
    try {
      final directions = await getDirectionsWithPolyline(
        origin: origin,
        destination: destination,
      );

      if (directions != null) {
        final durationText = directions['total_duration'] as String;
        final minutes = _parseDurationToMinutes(durationText);
        
        return DateTime.now().add(Duration(minutes: minutes));
      }
      
      return null;
    } catch (e) {
      print('❌ Error calculating ETA: $e');
      return null;
    }
  }

  /// Parse duration string to minutes
  int _parseDurationToMinutes(String duration) {
    // Parse strings like "15 mins", "1 hour 30 mins", etc.
    final hourMatch = RegExp(r'(\d+)\s*hour').firstMatch(duration);
    final minMatch = RegExp(r'(\d+)\s*min').firstMatch(duration);
    
    int totalMinutes = 0;
    
    if (hourMatch != null) {
      totalMinutes += int.parse(hourMatch.group(1)!) * 60;
    }
    
    if (minMatch != null) {
      totalMinutes += int.parse(minMatch.group(1)!);
    }
    
    return totalMinutes > 0 ? totalMinutes : 15; // Default 15 minutes
  }

  /// Create markers for route waypoints
  Set<Marker> createRouteMarkers({
    required LatLng start,
    required LatLng end,
    List<LatLng>? waypoints,
  }) {
    final markers = <Marker>[];

    // Start marker
    markers.add(Marker(
      markerId: const MarkerId('route_start'),
      position: start,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      infoWindow: const InfoWindow(
        title: 'Start',
        snippet: 'Your current location',
      ),
    ));

    // End marker
    markers.add(Marker(
      markerId: const MarkerId('route_end'),
      position: end,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      infoWindow: const InfoWindow(
        title: 'Destination',
        snippet: 'Customer location',
      ),
    ));

    // Waypoint markers
    if (waypoints != null) {
      for (int i = 0; i < waypoints.length; i++) {
        markers.add(Marker(
          markerId: MarkerId('waypoint_$i'),
          position: waypoints[i],
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: InfoWindow(
            title: 'Stop ${i + 1}',
            snippet: 'Waypoint',
          ),
        ));
      }
    }

    return markers.toSet();
  }
}










