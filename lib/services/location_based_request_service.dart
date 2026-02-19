import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math';

class LocationBasedRequestService {
  static final supabase = Supabase.instance.client;

  /// Get service requests near a mechanic's location using optimized database function
  static Future<List<Map<String, dynamic>>> getRequestsNearMechanic({
    required String mechanicId,
    required double mechanicLatitude,
    required double mechanicLongitude,
    double maxDistanceKm = 50.0,
  }) async {
    try {
      print('🗺️ Finding requests near mechanic at: $mechanicLatitude, $mechanicLongitude');
      print('📏 Maximum distance: ${maxDistanceKm}km');

      // Use optimized database function for better performance
      final result = await supabase.rpc('get_nearby_requests_for_mechanic', params: {
        'p_mechanic_id': mechanicId,
        'p_mechanic_lat': mechanicLatitude,
        'p_mechanic_lng': mechanicLongitude,
        'p_max_distance_km': maxDistanceKm,
      });

      if (result == null) {
        print('📋 No nearby requests found');
        return [];
      }

      final List<Map<String, dynamic>> requests = List<Map<String, dynamic>>.from(result);
      
      // Transform the database result to match the expected format
      final transformedRequests = requests.map((request) {
        return {
          'id': request['request_id'],
          'customer_id': request['customer_id'],
          'title': request['title'],
          'description': request['description'],
          'pickup_latitude': request['pickup_latitude'],
          'pickup_longitude': request['pickup_longitude'],
          'pickup_address': request['pickup_address'],
          'service_type': request['service_type'],
          'priority': request['priority'],
          'status': request['status'],
          'created_at': request['created_at'],
          'estimated_price': request['estimated_price'],
          'request_type': request['request_type'],
          'distance_km': request['distance_km'],
          'distance_text': _formatDistance(request['distance_km']),
          'estimated_arrival_minutes': request['estimated_arrival_minutes'],
          'urgency': request['urgency_level'],
          'urgency_text': _getUrgencyText(request['urgency_level'], request['created_at']),
          'user_profiles': {
            'first_name': request['customer_first_name'],
            'last_name': request['customer_last_name'],
            'phone_number': request['customer_phone'],
            'profile_image_url': request['customer_profile_image'],
          },
          'is_eligible': request['is_eligible'],
        };
      }).toList();

      print('🎯 Found ${transformedRequests.length} nearby eligible requests');
      return transformedRequests;

    } catch (e) {
      print('❌ Error getting nearby requests: $e');
      // Fallback to the original method if the database function fails
      return _getRequestsNearMechanicFallback(
        mechanicId: mechanicId,
        mechanicLatitude: mechanicLatitude,
        mechanicLongitude: mechanicLongitude,
        maxDistanceKm: maxDistanceKm,
      );
    }
  }

  /// Fallback method using the original approach
  static Future<List<Map<String, dynamic>>> _getRequestsNearMechanicFallback({
    required String mechanicId,
    required double mechanicLatitude,
    required double mechanicLongitude,
    double maxDistanceKm = 50.0,
  }) async {
    try {
      print('🔄 Using fallback method for nearby requests');
      
      // Get all pending service requests with location data
      final requests = await supabase
          .from('service_requests')
          .select('''
            id,
            customer_id,
            title,
            description,
            pickup_latitude,
            pickup_longitude,
            pickup_address,
            service_type,
            priority,
            status,
            created_at,
            estimated_price,
            request_type,
            shop_id,
            can_accept_by_any_mechanic,
            broadcast_radius_km,
            customer_id,
            user_profiles!service_requests_customer_id_fkey(
              first_name,
              last_name,
              phone_number,
              profile_image_url
            )
          ''')
          .inFilter('status', ['pending', 'awaiting_payment', 'ready_to_assign'])
          .not('pickup_latitude', 'is', null)
          .not('pickup_longitude', 'is', null);

      print('📋 Found ${requests.length} total requests with location data');

      // Filter requests by distance and eligibility
      final nearbyRequests = <Map<String, dynamic>>[];

      for (final request in requests) {
        final requestLat = request['pickup_latitude'] as double;
        final requestLng = request['pickup_longitude'] as double;
        
        // Calculate distance between mechanic and pickup location
        final distance = _calculateDistance(
          mechanicLatitude, 
          mechanicLongitude, 
          requestLat, 
          requestLng
        );

        print('📍 Request ${request['id']}: ${distance.toStringAsFixed(1)}km from mechanic');

        // Check if request is within range
        if (distance <= maxDistanceKm) {
          // Check if mechanic is eligible for this request
          final isEligible = await _isMechanicEligibleForRequest(
            mechanicId: mechanicId,
            requestId: request['id'],
            requestType: request['request_type'],
            preferredShopId: request['shop_id'], // use shop_id for shop-based checks
            canAcceptByAnyMechanic: request['can_accept_by_any_mechanic'] ?? true,
          );

          if (isEligible) {
            // Add distance info to the request data
            final enrichedRequest = Map<String, dynamic>.from(request);
            enrichedRequest['distance_km'] = distance;
            enrichedRequest['distance_text'] = _formatDistance(distance);
            enrichedRequest['estimated_arrival_minutes'] = _estimateArrivalTime(distance);
            
            // Add urgency information
            final createdAt = DateTime.parse(request['created_at']);
            final hoursSinceCreated = DateTime.now().difference(createdAt).inHours;
            
            if (hoursSinceCreated >= 2) {
              enrichedRequest['urgency'] = 'high';
              enrichedRequest['urgency_text'] = 'Urgent - ${hoursSinceCreated}h waiting';
            } else if (hoursSinceCreated >= 1) {
              enrichedRequest['urgency'] = 'medium';
              enrichedRequest['urgency_text'] = 'Moderate - ${hoursSinceCreated}h waiting';
            } else {
              enrichedRequest['urgency'] = 'normal';
              enrichedRequest['urgency_text'] = 'New request';
            }
            
            nearbyRequests.add(enrichedRequest);
            print('✅ Request ${request['id']} is eligible for mechanic $mechanicId');
          } else {
            print('❌ Request ${request['id']} not eligible for mechanic $mechanicId');
          }
        }
      }

      // Sort by distance (closest first)
      nearbyRequests.sort((a, b) => 
        (a['distance_km'] as double).compareTo(b['distance_km'] as double));

      print('🎯 Found ${nearbyRequests.length} nearby eligible requests');
      return nearbyRequests;

    } catch (e) {
      print('❌ Error in fallback method: $e');
      return [];
    }
  }

  /// Get urgency text based on urgency level and created time
  static String _getUrgencyText(String urgencyLevel, String createdAt) {
    final createdTime = DateTime.parse(createdAt);
    final hoursSinceCreated = DateTime.now().difference(createdTime).inHours;
    
    switch (urgencyLevel) {
      case 'high':
        return 'Urgent - ${hoursSinceCreated}h waiting';
      case 'medium':
        return 'Moderate - ${hoursSinceCreated}h waiting';
      default:
        return 'New request';
    }
  }

  /// Check if a mechanic is eligible for a specific request
  static Future<bool> _isMechanicEligibleForRequest({
    required String mechanicId,
    required String requestId,
    required String? requestType,
    required String? preferredShopId,
    required bool canAcceptByAnyMechanic,
  }) async {
    try {
      // For direct mechanic requests (broadcast to all)
      if (requestType == 'broadcast' || requestType == 'direct_mechanic') {
        if (canAcceptByAnyMechanic) {
          // Check if mechanic is available and accepting requests
          final availability = await supabase
              .from('mechanic_availability_status')
              .select('current_status, is_accepting_requests')
              .eq('mechanic_id', mechanicId)
              .maybeSingle();

          if (availability != null && 
              availability['current_status'] == 'available' && 
              availability['is_accepting_requests'] == true) {
            return true;
          }
        }
        return false;
      }

      // For shop-based requests
      if (requestType == 'shop_based' && preferredShopId != null) {
        // Check if mechanic works at the preferred shop (using separate queries - no FK relationship exists)
        final shopMechanic = await supabase
            .from('shop_mechanics')
            .select('mechanic_id, is_active')
            .eq('shop_id', preferredShopId)
            .eq('mechanic_id', mechanicId)
            .eq('is_active', true)
            .maybeSingle();

        if (shopMechanic == null) {
          return false; // Mechanic doesn't work at this shop
        }

        // Check mechanic availability separately (no FK between shop_mechanics and mechanic_availability_status)
        final availability = await supabase
            .from('mechanic_availability_status')
            .select('current_status, is_accepting_requests')
            .eq('mechanic_id', mechanicId)
            .maybeSingle();

        if (availability != null && 
            availability['current_status'] == 'available' && 
            availability['is_accepting_requests'] == true) {
          return true;
        }

        return false;
      }

      return false;
    } catch (e) {
      print('❌ Error checking mechanic eligibility: $e');
      return false;
    }
  }

  /// Calculate distance between two points using Haversine formula
  static double _calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    const double earthRadius = 6371; // Earth's radius in kilometers
    
    final double dLat = _toRadians(lat2 - lat1);
    final double dLng = _toRadians(lng2 - lng1);
    
    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) *
        sin(dLng / 2) * sin(dLng / 2);
    
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    
    return earthRadius * c;
  }

  static double _toRadians(double degree) {
    return degree * (pi / 180);
  }

  /// Format distance for display
  static String _formatDistance(double distanceKm) {
    if (distanceKm < 1) {
      return '${(distanceKm * 1000).round()}m away';
    } else if (distanceKm < 10) {
      return '${distanceKm.toStringAsFixed(1)}km away';
    } else {
      return '${distanceKm.round()}km away';
    }
  }

  /// Estimate arrival time based on distance
  static int _estimateArrivalTime(double distanceKm) {
    // Assume average speed of 30 km/h in city traffic
    final double hours = distanceKm / 30.0;
    final int minutes = (hours * 60).round();
    
    // Add 5 minutes for preparation
    return minutes + 5;
  }

  /// Get real-time nearby requests for mechanic dashboard
  static Future<List<Map<String, dynamic>>> getRealtimeNearbyRequests({
    required String mechanicId,
    required double mechanicLatitude,
    required double mechanicLongitude,
    double maxDistanceKm = 50.0,
  }) async {
    try {
      // Get requests with real-time filtering
      final requests = await getRequestsNearMechanic(
        mechanicId: mechanicId,
        mechanicLatitude: mechanicLatitude,
        mechanicLongitude: mechanicLongitude,
        maxDistanceKm: maxDistanceKm,
      );

      // Add real-time status information
      for (final request in requests) {
        // Check if request is still available (not taken by another mechanic)
        final currentStatus = await supabase
            .from('service_requests')
            .select('status, assigned_mechanic_id, accepted_by')
            .eq('id', request['id'])
            .single();

        request['current_status'] = currentStatus['status'];
        request['is_available'] = currentStatus['status'] == 'pending' &&
            currentStatus['assigned_mechanic_id'] == null &&
            currentStatus['accepted_by'] == null;

        // Add urgency level based on how long the request has been pending
        final createdAt = DateTime.parse(request['created_at']);
        final hoursSinceCreated = DateTime.now().difference(createdAt).inHours;
        
        if (hoursSinceCreated >= 2) {
          request['urgency'] = 'high';
          request['urgency_text'] = 'Urgent - ${hoursSinceCreated}h waiting';
        } else if (hoursSinceCreated >= 1) {
          request['urgency'] = 'medium';
          request['urgency_text'] = 'Moderate - ${hoursSinceCreated}h waiting';
        } else {
          request['urgency'] = 'normal';
          request['urgency_text'] = 'New request';
        }
      }

      // Filter out unavailable requests and sort by urgency and distance
      final availableRequests = requests
          .where((request) => request['is_available'] == true)
          .toList();

      availableRequests.sort((a, b) {
        // First sort by urgency
        final urgencyOrder = {'high': 0, 'medium': 1, 'normal': 2};
        final urgencyComparison = urgencyOrder[a['urgency']]!
            .compareTo(urgencyOrder[b['urgency']]!);
        
        if (urgencyComparison != 0) return urgencyComparison;
        
        // Then sort by distance
        return (a['distance_km'] as double).compareTo(b['distance_km'] as double);
      });

      return availableRequests;

    } catch (e) {
      print('❌ Error getting real-time nearby requests: $e');
      return [];
    }
  }

  /// Accept a service request based on location proximity using optimized database function
  static Future<bool> acceptNearbyRequest({
    required String mechanicId,
    required String requestId,
    required double mechanicLatitude,
    required double mechanicLongitude,
  }) async {
    try {
      print('📍 Mechanic $mechanicId accepting request $requestId');

      // Use optimized database function for acceptance
      final result = await supabase.rpc('accept_nearby_request', params: {
        'p_mechanic_id': mechanicId,
        'p_request_id': requestId,
        'p_mechanic_lat': mechanicLatitude,
        'p_mechanic_lng': mechanicLongitude,
      });

      if (result == null || result.isEmpty) {
        print('❌ No result from accept function');
        return false;
      }

      final resultData = result.first;
      final success = resultData['success'] as bool;
      final message = resultData['message'] as String;
      final distance = resultData['distance_km'] as double;

      print('📊 Accept result: $message (Distance: ${distance.toStringAsFixed(1)}km)');

      if (success) {
        print('✅ Request accepted successfully');
        return true;
      } else {
        print('❌ Failed to accept request: $message');
        return false;
      }

    } catch (e) {
      print('❌ Error accepting request: $e');
      // Fallback to the original method if the database function fails
      return _acceptNearbyRequestFallback(
        mechanicId: mechanicId,
        requestId: requestId,
        mechanicLatitude: mechanicLatitude,
        mechanicLongitude: mechanicLongitude,
      );
    }
  }

  /// Fallback method for accepting requests
  static Future<bool> _acceptNearbyRequestFallback({
    required String mechanicId,
    required String requestId,
    required double mechanicLatitude,
    required double mechanicLongitude,
  }) async {
    try {
      print('🔄 Using fallback method for request acceptance');

      // Get request details to verify location and eligibility
      final request = await supabase
          .from('service_requests')
          .select('''
            id,
            pickup_latitude,
            pickup_longitude,
            status,
            request_type,
            preferred_shop_id,
            can_accept_by_any_mechanic,
            assigned_mechanic_id,
            accepted_by
          ''')
          .eq('id', requestId)
          .single();

      // Verify request is still available
      if (request['status'] != 'pending' || 
          request['assigned_mechanic_id'] != null ||
          request['accepted_by'] != null) {
        print('❌ Request is no longer available');
        return false;
      }

      // Calculate distance to ensure mechanic is still nearby
      final distance = _calculateDistance(
        mechanicLatitude,
        mechanicLongitude,
        request['pickup_latitude'],
        request['pickup_longitude'],
      );

      print('📏 Distance to pickup: ${distance.toStringAsFixed(1)}km');

      // Verify eligibility
      final isEligible = await _isMechanicEligibleForRequest(
        mechanicId: mechanicId,
        requestId: requestId,
        requestType: request['request_type'],
        preferredShopId: request['preferred_shop_id'],
        canAcceptByAnyMechanic: request['can_accept_by_any_mechanic'] ?? true,
      );

      if (!isEligible) {
        print('❌ Mechanic not eligible for this request');
        return false;
      }

      // Accept the request
      await supabase
          .from('service_requests')
          .update({
            'status': 'accepted',
            'accepted_by': mechanicId,
            'assigned_mechanic_id': mechanicId,
            'accepted_at': DateTime.now().toIso8601String(),
            'distance_to_customer': distance,
            'estimated_arrival_minutes': _estimateArrivalTime(distance),
          })
          .eq('id', requestId);

      // Update mechanic status
      await supabase
          .from('mechanic_availability_status')
          .update({
            'current_status': 'on_job',
            'is_accepting_requests': false,
            'last_active_at': DateTime.now().toIso8601String(),
          })
          .eq('mechanic_id', mechanicId);

      print('✅ Request accepted successfully using fallback method');
      return true;

    } catch (e) {
      print('❌ Error in fallback acceptance method: $e');
      return false;
    }
  }
}