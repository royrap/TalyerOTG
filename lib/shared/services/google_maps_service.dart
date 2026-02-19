import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';

class GoogleMapsService {
  static const String _apiKey = 'AIzaSyDZBJKJt1UOHT_vvAuSDWz4MCSl77yPY5k';
  static const String _directionsBaseUrl = 'https://maps.googleapis.com/maps/api/directions/json';
  static const String _geocodingBaseUrl = 'https://maps.googleapis.com/maps/api/geocode/json';
  static const String _placesBaseUrl = 'https://maps.googleapis.com/maps/api/place';
  static const String _distanceMatrixBaseUrl = 'https://maps.googleapis.com/maps/api/distancematrix/json';

  // Get directions between two points
  static Future<Map<String, dynamic>?> getDirections({
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

      print('Making directions API call: $url');
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('Directions API response status: ${data['status']}');
        
        if (data['status'] == 'OK' && data['routes'].isNotEmpty) {
          return data;
        } else {
          print('Directions API error: ${data['status']} - ${data['error_message'] ?? 'No error message'}');
        }
      } else {
        print('HTTP error: ${response.statusCode}');
      }
      return null;
    } catch (e) {
      print('Error getting directions: $e');
      return null;
    }
  }

  // Get polyline points for route visualization
  static List<LatLng> decodePolyline(String polyline) {
    List<LatLng> points = [];
    int index = 0, len = polyline.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = polyline.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = polyline.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return points;
  }

  // Reverse geocoding - convert coordinates to address
  static Future<String?> getAddressFromCoordinates(LatLng location) async {
    try {
      final String url = '$_geocodingBaseUrl?'
          'latlng=${location.latitude},${location.longitude}&'
          'key=$_apiKey';

      print('Making geocoding API call: $url');
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('Geocoding API response status: ${data['status']}');
        
        if (data['status'] == 'OK' && data['results'].isNotEmpty) {
          return data['results'][0]['formatted_address'];
        } else {
          print('Geocoding API error: ${data['status']} - ${data['error_message'] ?? 'No error message'}');
        }
      } else {
        print('HTTP error: ${response.statusCode}');
      }
      return null;
    } catch (e) {
      print('Error getting address: $e');
      return null;
    }
  }

  // Geocoding - convert address to coordinates
  static Future<LatLng?> getCoordinatesFromAddress(String address) async {
    try {
      final String url = '$_geocodingBaseUrl?'
          'address=${Uri.encodeComponent(address)}&'
          'key=$_apiKey';

      print('Making geocoding coordinates API call: $url');
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('Geocoding coordinates API response status: ${data['status']}');
        
        if (data['status'] == 'OK' && data['results'].isNotEmpty) {
          final location = data['results'][0]['geometry']['location'];
          return LatLng(location['lat'], location['lng']);
        } else {
          print('Geocoding coordinates API error: ${data['status']} - ${data['error_message'] ?? 'No error message'}');
        }
      } else {
        print('HTTP error: ${response.statusCode}');
      }
      return null;
    } catch (e) {
      print('Error getting coordinates: $e');
      return null;
    }
  }

  // Place search
  static Future<List<Map<String, dynamic>>> searchPlaces({
    required String query,
    required LatLng location,
    double radius = 5000,
  }) async {
    try {
      final String url = '$_placesBaseUrl/nearbysearch/json?'
          'keyword=${Uri.encodeComponent(query)}&'
          'location=${location.latitude},${location.longitude}&'
          'radius=$radius&'
          'key=$_apiKey';

      print('Making places search API call: $url');
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('Places search API response status: ${data['status']}');
        
        if (data['status'] == 'OK') {
          return List<Map<String, dynamic>>.from(data['results']);
        } else {
          print('Places search API error: ${data['status']} - ${data['error_message'] ?? 'No error message'}');
        }
      } else {
        print('HTTP error: ${response.statusCode}');
      }
      return [];
    } catch (e) {
      print('Error searching places: $e');
      return [];
    }
  }

  // Calculate distance and duration between two points
  static Future<Map<String, dynamic>?> getDistanceMatrix({
    required LatLng origin,
    required LatLng destination,
    String travelMode = 'driving',
  }) async {
    try {
      final String url = '$_distanceMatrixBaseUrl?'
          'origins=${origin.latitude},${origin.longitude}&'
          'destinations=${destination.latitude},${destination.longitude}&'
          'mode=$travelMode&'
          'units=metric&'
          'key=$_apiKey';

      print('Making distance matrix API call: $url');
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('Distance matrix API response status: ${data['status']}');
        
        if (data['status'] == 'OK' && 
            data['rows'].isNotEmpty && 
            data['rows'][0]['elements'].isNotEmpty) {
          final element = data['rows'][0]['elements'][0];
          print('Distance matrix element status: ${element['status']}');
          
          if (element['status'] == 'OK') {
            return {
              'distance': element['distance']['text'],
              'duration': element['duration']['text'],
              'distance_value': element['distance']['value'],
              'duration_value': element['duration']['value'],
            };
          } else {
            print('Distance matrix element error: ${element['status']}');
          }
        } else {
          print('Distance matrix API error: ${data['status']} - ${data['error_message'] ?? 'No error message'}');
        }
      } else {
        print('HTTP error: ${response.statusCode}');
      }
      return null;
    } catch (e) {
      print('Error getting distance matrix: $e');
      return null;
    }
  }

  // Text search for places
  static Future<List<Map<String, dynamic>>> textSearchPlaces({
    required String query,
    LatLng? location,
    double radius = 50000,
  }) async {
    try {
      String url = '$_placesBaseUrl/textsearch/json?'
          'query=${Uri.encodeComponent(query)}&'
          'key=$_apiKey';
      
      if (location != null) {
        url += '&location=${location.latitude},${location.longitude}&radius=$radius';
      }

      print('Making text search API call: $url');
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('Text search API response status: ${data['status']}');
        
        if (data['status'] == 'OK') {
          return List<Map<String, dynamic>>.from(data['results']);
        } else {
          print('Text search API error: ${data['status']} - ${data['error_message'] ?? 'No error message'}');
        }
      } else {
        print('HTTP error: ${response.statusCode}');
      }
      return [];
    } catch (e) {
      print('Error with text search: $e');
      return [];
    }
  }

  // Get place details
  static Future<Map<String, dynamic>?> getPlaceDetails(String placeId) async {
    try {
      final String url = '$_placesBaseUrl/details/json?'
          'place_id=$placeId&'
          'fields=name,formatted_address,geometry,formatted_phone_number,rating,photos&'
          'key=$_apiKey';

      print('Making place details API call: $url');
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('Place details API response status: ${data['status']}');
        
        if (data['status'] == 'OK') {
          return data['result'];
        } else {
          print('Place details API error: ${data['status']} - ${data['error_message'] ?? 'No error message'}');
        }
      } else {
        print('HTTP error: ${response.statusCode}');
      }
      return null;
    } catch (e) {
      print('Error getting place details: $e');
      return null;
    }
  }

  // Snap to roads (useful for location tracking)
  static Future<List<LatLng>?> snapToRoads(List<LatLng> points) async {
    try {
      final String path = points
          .map((point) => '${point.latitude},${point.longitude}')
          .join('|');
      
      final String url = 'https://roads.googleapis.com/v1/snapToRoads?'
          'path=$path&'
          'interpolate=true&'
          'key=$_apiKey';

      print('Making snap to roads API call: $url');
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['snappedPoints'] != null) {
          final List<LatLng> snappedPoints = [];
          for (final point in data['snappedPoints']) {
            final location = point['location'];
            snappedPoints.add(LatLng(location['latitude'], location['longitude']));
          }
          return snappedPoints;
        }
      } else {
        print('HTTP error: ${response.statusCode}');
      }
      return null;
    } catch (e) {
      print('Error snapping to roads: $e');
      return null;
    }
  }

  // Get route points for polyline display - combines directions and polyline decoding
  static Future<List<LatLng>?> getRoutePoints({
    required LatLng origin,
    required LatLng destination,
  }) async {
    try {
      // Get directions data
      final directionsData = await getDirections(
        origin: origin,
        destination: destination,
      );
      
      if (directionsData != null && 
          directionsData['routes'] != null && 
          directionsData['routes'].isNotEmpty) {
        
        final route = directionsData['routes'][0];
        // Try to use the overview polyline first
        final polylineString = route['overview_polyline'] != null ? route['overview_polyline']['points'] : null;

        List<LatLng> routePoints = [];

        if (polylineString != null && polylineString is String && polylineString.isNotEmpty) {
          routePoints = decodePolyline(polylineString);
          print('🗺️ Overview polyline decoded: ${routePoints.length} points');
        }

        // If overview is missing or extremely sparse (<= 2 points), try decoding each step's polyline for denser geometry
        if ((routePoints.isEmpty || routePoints.length <= 2) && route['legs'] != null) {
          try {
            final legs = route['legs'] as List<dynamic>;
            int stepCount = 0;
            for (final leg in legs) {
              if (leg['steps'] != null) {
                final steps = leg['steps'] as List<dynamic>;
                stepCount += steps.length;
                for (final step in steps) {
                  final stepPolyline = step['polyline'] != null ? step['polyline']['points'] : null;
                  if (stepPolyline != null && (stepPolyline as String).isNotEmpty) {
                    final stepPoints = decodePolyline(stepPolyline);
                    routePoints.addAll(stepPoints);
                  }
                }
              }
            }
            print('🗺️ Decoded per-step polylines: steps=$stepCount, totalPoints=${routePoints.length}');
          } catch (e) {
            print('❌ Error decoding step polylines: $e');
          }
        }

        // Deduplicate near-identical consecutive points to avoid zero-length segments
        if (routePoints.isNotEmpty) {
          final List<LatLng> deduped = [];
          LatLng? last;
          for (final p in routePoints) {
            if (last == null || last.latitude != p.latitude || last.longitude != p.longitude) {
              deduped.add(p);
              last = p;
            }
          }
          routePoints = deduped;
        }

        print('🗺️ Final route points count after processing: ${routePoints.length}');
        return routePoints;
      }
      
      print('❌ No route data available');
      return null;
    } catch (e) {
      print('❌ Error getting route points: $e');
      return null;
    }
  }
}










