import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RealTimeETAService {
  static final RealTimeETAService _instance = RealTimeETAService._internal();
  static RealTimeETAService get instance => _instance;
  RealTimeETAService._internal();

  final _supabase = Supabase.instance.client;
  Timer? _etaUpdateTimer;
  StreamController<Map<String, dynamic>>? _etaStreamController;
  
  // Google Maps API key - matches web/index.html configuration
  static const String _googleMapsApiKey = 'AIzaSyDhjpC_z6k8NU2GV6lLXB-YLYnOL4LQNNI';
  
  /// Start real-time ETA tracking between mechanic and customer
  Stream<Map<String, dynamic>> trackMechanicETA({
    required String serviceRequestId,
    required String mechanicId,
    required LatLng customerLocation,
  }) {
    _etaStreamController?.close();
    _etaStreamController = StreamController<Map<String, dynamic>>.broadcast();
    
    print('🚗 Starting real-time ETA tracking for service: $serviceRequestId');
    
    // Update ETA every 30 seconds
    _etaUpdateTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      try {
        final etaData = await _calculateRealTimeETA(
          serviceRequestId: serviceRequestId,
          mechanicId: mechanicId,
          customerLocation: customerLocation,
        );
        
        if (etaData != null && !_etaStreamController!.isClosed) {
          _etaStreamController!.add(etaData);
        }
      } catch (e) {
        print('❌ Error updating ETA: $e');
      }
    });
    
    // Get initial ETA
    _calculateRealTimeETA(
      serviceRequestId: serviceRequestId,
      mechanicId: mechanicId,
      customerLocation: customerLocation,
    ).then((initialETA) {
      if (initialETA != null && !_etaStreamController!.isClosed) {
        _etaStreamController!.add(initialETA);
      }
    });
    
    return _etaStreamController!.stream;
  }
  
  /// Calculate real-time ETA with traffic data
  Future<Map<String, dynamic>?> _calculateRealTimeETA({
    required String serviceRequestId,
    required String mechanicId,
    required LatLng customerLocation,
  }) async {
    try {
      // Get current mechanic location
      final mechanicLocation = await _getCurrentMechanicLocation(mechanicId);
      if (mechanicLocation == null) {
        print('⚠️ Mechanic location not available');
        return null;
      }
      
      // Calculate distance using Google Maps API with traffic
      final routeData = await _getRouteWithTraffic(
        origin: mechanicLocation,
        destination: customerLocation,
      );
      
      if (routeData == null) {
        // Fallback to straight-line calculation
        return _calculateStraightLineETA(mechanicLocation, customerLocation);
      }
      
      // Store ETA in database for persistence
      await _storeETAUpdate(serviceRequestId, routeData);
      
      return {
        'eta_minutes': routeData['duration_minutes'],
        'eta_text': routeData['duration_text'],
        'distance_km': routeData['distance_km'],
        'distance_text': routeData['distance_text'],
        'mechanic_location': {
          'latitude': mechanicLocation.latitude,
          'longitude': mechanicLocation.longitude,
        },
        'traffic_condition': routeData['traffic_condition'],
        'estimated_arrival': DateTime.now().add(
          Duration(minutes: routeData['duration_minutes'])
        ).toIso8601String(),
        'last_updated': DateTime.now().toIso8601String(),
        'route_polyline': routeData['polyline'],
      };
      
    } catch (e) {
      print('❌ Error calculating ETA: $e');
      return null;
    }
  }
  
  /// Get current mechanic location from database
  Future<LatLng?> _getCurrentMechanicLocation(String mechanicId) async {
    try {
      final response = await _supabase
          .from('user_profiles')
          .select('current_latitude, current_longitude')
          .eq('id', mechanicId)
          .maybeSingle();
          
      if (response != null && 
          response['current_latitude'] != null && 
          response['current_longitude'] != null) {
        return LatLng(
          double.parse(response['current_latitude'].toString()),
          double.parse(response['current_longitude'].toString()),
        );
      }
      
      return null;
    } catch (e) {
      print('❌ Error getting mechanic location: $e');
      return null;
    }
  }
  
  /// Get route with traffic data from Google Maps API
  Future<Map<String, dynamic>?> _getRouteWithTraffic({
    required LatLng origin,
    required LatLng destination,
  }) async {
    try {
      if (_googleMapsApiKey == 'YOUR_GOOGLE_MAPS_API_KEY') {
        print('⚠️ Google Maps API key not configured, using fallback calculation');
        return null;
      }
      
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json'
        '?origin=${origin.latitude},${origin.longitude}'
        '&destination=${destination.latitude},${destination.longitude}'
        '&departure_time=now'
        '&traffic_model=best_guess'
        '&key=$_googleMapsApiKey'
      );
      
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == 'OK' && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final leg = route['legs'][0];
          
          // Extract duration with traffic
          final durationInTraffic = leg['duration_in_traffic'] ?? leg['duration'];
          final durationMinutes = (durationInTraffic['value'] / 60).round();
          
          // Extract distance
          final distance = leg['distance'];
          final distanceKm = (distance['value'] / 1000);
          
          // Determine traffic condition
          final normalDuration = leg['duration']['value'];
          final trafficDuration = durationInTraffic['value'];
          final trafficRatio = trafficDuration / normalDuration;
          
          String trafficCondition = 'normal';
          if (trafficRatio > 1.5) {
            trafficCondition = 'heavy';
          } else if (trafficRatio > 1.2) {
            trafficCondition = 'moderate';
          } else {
            trafficCondition = 'light';
          }
          
          return {
            'duration_minutes': durationMinutes,
            'duration_text': durationInTraffic['text'],
            'distance_km': distanceKm,
            'distance_text': distance['text'],
            'traffic_condition': trafficCondition,
            'polyline': route['overview_polyline']['points'],
          };
        }
      }
      
      return null;
    } catch (e) {
      print('❌ Error getting route with traffic: $e');
      return null;
    }
  }
  
  /// Fallback calculation using straight-line distance
  Map<String, dynamic> _calculateStraightLineETA(LatLng origin, LatLng destination) {
    final distanceInMeters = Geolocator.distanceBetween(
      origin.latitude,
      origin.longitude,
      destination.latitude,
      destination.longitude,
    );
    
    final distanceKm = distanceInMeters / 1000;
    
    // Assume average speed of 25 km/h in city traffic
    final etaMinutes = ((distanceKm / 25) * 60).round();
    
    return {
      'eta_minutes': etaMinutes,
      'eta_text': '${etaMinutes}min',
      'distance_km': distanceKm,
      'distance_text': '${distanceKm.toStringAsFixed(1)} km',
      'traffic_condition': 'estimated',
      'estimated_arrival': DateTime.now().add(
        Duration(minutes: etaMinutes)
      ).toIso8601String(),
      'last_updated': DateTime.now().toIso8601String(),
      'is_estimated': true,
    };
  }
  
  /// Store ETA update in database for persistence
  Future<void> _storeETAUpdate(String serviceRequestId, Map<String, dynamic> etaData) async {
    try {
      await _supabase.from('service_requests').update({
        'current_eta_minutes': etaData['duration_minutes'],
        'current_distance_km': etaData['distance_km'],
        'traffic_condition': etaData['traffic_condition'],
        'eta_last_updated': DateTime.now().toIso8601String(),
      }).eq('id', serviceRequestId);
      
      print('📍 ETA update stored: ${etaData['duration_minutes']}min, ${etaData['distance_km'].toStringAsFixed(1)}km');
    } catch (e) {
      print('❌ Error storing ETA update: $e');
    }
  }
  
  /// Get stored ETA data for a service request
  Future<Map<String, dynamic>?> getStoredETA(String serviceRequestId) async {
    try {
      final response = await _supabase
          .from('service_requests')
          .select('current_eta_minutes, current_distance_km, traffic_condition, eta_last_updated')
          .eq('id', serviceRequestId)
          .maybeSingle();
          
      if (response != null && response['current_eta_minutes'] != null) {
        return {
          'eta_minutes': response['current_eta_minutes'],
          'distance_km': response['current_distance_km'],
          'traffic_condition': response['traffic_condition'] ?? 'normal',
          'last_updated': response['eta_last_updated'],
        };
      }
      
      return null;
    } catch (e) {
      print('❌ Error getting stored ETA: $e');
      return null;
    }
  }
  
  /// Stop ETA tracking
  void stopETATracking() {
    _etaUpdateTimer?.cancel();
    _etaStreamController?.close();
    print('🛑 ETA tracking stopped');
  }
  
  /// Format ETA for display
  static String formatETAText(int minutes) {
    if (minutes < 1) {
      return 'Arriving now';
    } else if (minutes == 1) {
      return '1 minute away';
    } else if (minutes < 60) {
      return '$minutes minutes away';
    } else {
      final hours = minutes ~/ 60;
      final remainingMinutes = minutes % 60;
      if (remainingMinutes == 0) {
        return '$hours hour${hours > 1 ? 's' : ''} away';
      } else {
        return '${hours}h ${remainingMinutes}min away';
      }
    }
  }
  
  /// Get traffic condition color
  static Color getTrafficColor(String condition) {
    switch (condition.toLowerCase()) {
      case 'heavy':
        return const Color(0xFFD32F2F); // Red
      case 'moderate':
        return const Color(0xFFF57C00); // Orange  
      case 'light':
        return const Color(0xFF388E3C); // Green
      default:
        return const Color(0xFF1976D2); // Blue
    }
  }
}