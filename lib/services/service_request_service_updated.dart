// Updated service_request_service.dart with automatic broadcast triggering
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ServiceRequestService {
  static final ServiceRequestService _instance = ServiceRequestService._internal();
  static ServiceRequestService get instance => _instance;
  ServiceRequestService._internal();

  final _supabase = Supabase.instance.client;

  /// Create a new service request with automatic broadcast support
  Future<Map<String, dynamic>?> createServiceRequest({
    required String title,
    required String description,
    required String serviceType,
    required double pickupLatitude,
    required double pickupLongitude,
    required String pickupAddress,
    String? vehicleId,
    String? shopId, // null means broadcast to all nearby shops
    double? estimatedPrice,
    bool isEmergency = false,
    String priority = 'normal',
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      print('🚗 Creating service request...');
      print('🎯 Shop target: ${shopId ?? "BROADCAST (all nearby shops)"}');

      // Prepare request data
      final requestData = {
        'customer_id': user.id,
        'title': title,
        'description': description,
        'service_type': serviceType,
        'pickup_latitude': pickupLatitude,
        'pickup_longitude': pickupLongitude,
        'pickup_address': pickupAddress,
        'vehicle_id': vehicleId,
        'shop_id': shopId, // null = broadcast mode
        'estimated_price': estimatedPrice,
        'is_emergency': isEmergency,
        'priority': priority,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
        'request_type': shopId != null ? 'direct_shop' : 'broadcast',
        'additional_data': additionalData,
      };

      // Create the service request
      final response = await _supabase
          .from('service_requests')
          .insert(requestData)
          .select()
          .single();

      final requestId = response['id'];
      print('✅ Service request created with ID: $requestId');

      // If shop_id is null, trigger broadcast to all nearby mechanics
      if (shopId == null) {
        print('📡 Triggering broadcast to nearby mechanics...');
        await _triggerBroadcastToNearbyMechanics(
          requestId: requestId,
          latitude: pickupLatitude,
          longitude: pickupLongitude,
          serviceType: serviceType,
          isEmergency: isEmergency,
        );
      } else {
        print('🎯 Request targeted to specific shop: $shopId');
        await _routeToSpecificShop(requestId, shopId);
      }

      return response;
    } catch (e) {
      print('❌ Error creating service request: $e');
      throw Exception('Failed to create service request: $e');
    }
  }

  /// Trigger broadcast to all nearby mechanics
  Future<void> _triggerBroadcastToNearbyMechanics({
    required String requestId,
    required double latitude,
    required double longitude,
    required String serviceType,
    required bool isEmergency,
    double radiusKm = 10.0,
  }) async {
    try {
      print('📡 Broadcasting request $requestId to mechanics within ${radiusKm}km...');

      // Use the broadcast_service_request function
      final result = await _supabase.rpc('broadcast_service_request', params: {
        'p_request_id': requestId,
        'p_customer_latitude': latitude,
        'p_customer_longitude': longitude,
        'p_radius_km': radiusKm,
        'p_service_type': serviceType,
        'p_is_emergency': isEmergency,
      });

      print('✅ Broadcast result: $result');

      if (result is Map && result['success'] == true) {
        final mechanicsNotified = result['mechanics_notified'] ?? 0;
        print('📲 Successfully notified $mechanicsNotified mechanics');
        
        // Update the service request with broadcast info
        await _supabase.from('service_requests').update({
          'broadcast_radius_km': radiusKm,
          'mechanics_notified_count': mechanicsNotified,
          'broadcast_timestamp': DateTime.now().toIso8601String(),
        }).eq('id', requestId);
      } else {
        print('⚠️ Broadcast failed: ${result['error'] ?? 'Unknown error'}');
        
        // Fallback: create routing entries manually
        await _createManualRoutingEntries(requestId, latitude, longitude, radiusKm);
      }
    } catch (e) {
      print('❌ Error triggering broadcast: $e');
      
      // Fallback: create routing entries manually
      await _createManualRoutingEntries(requestId, latitude, longitude, radiusKm);
    }
  }

  /// Fallback method to create routing entries manually
  Future<void> _createManualRoutingEntries(
    String requestId,
    double latitude,
    double longitude,
    double radiusKm,
  ) async {
    try {
      print('🔄 Creating manual routing entries as fallback...');

      // Find available mechanics within radius
      final availableMechanics = await _supabase
          .from('mechanic_availability_status')
          .select('''
            mechanic_id,
            location_latitude,
            location_longitude,
            current_status,
            is_accepting_requests
          ''')
          .eq('is_accepting_requests', true)
          .eq('current_status', 'available')
          .not('location_latitude', 'is', null)
          .not('location_longitude', 'is', null);

      final routingEntries = <Map<String, dynamic>>[];
      
      for (final mechanic in availableMechanics) {
        final distance = Geolocator.distanceBetween(
          latitude,
          longitude,
          mechanic['location_latitude'],
          mechanic['location_longitude'],
        ) / 1000; // Convert to km

        if (distance <= radiusKm) {
          routingEntries.add({
            'request_id': requestId,
            'eligible_mechanic_id': mechanic['mechanic_id'],
            'distance_km': distance,
            'created_at': DateTime.now().toIso8601String(),
            'is_notified': false,
            'response_deadline': DateTime.now()
                .add(Duration(minutes: 5))
                .toIso8601String(),
          });
        }
      }

      if (routingEntries.isNotEmpty) {
        await _supabase.from('request_routing').insert(routingEntries);
        print('✅ Created ${routingEntries.length} manual routing entries');
      } else {
        print('⚠️ No available mechanics found within ${radiusKm}km');
        
        // Update request status
        await _supabase.from('service_requests').update({
          'status': 'no_mechanics_available',
          'status_reason': 'No mechanics available within ${radiusKm}km radius',
        }).eq('id', requestId);
      }
    } catch (e) {
      print('❌ Error creating manual routing entries: $e');
    }
  }

  /// Route request to specific shop
  Future<void> _routeToSpecificShop(String requestId, String shopId) async {
    try {
      print('🎯 Routing request $requestId to shop $shopId...');

      // Get available mechanics from the specific shop
      final shopMechanics = await _supabase
          .from('mechanic_availability_status')
          .select('mechanic_id')
          .eq('shop_id', shopId)
          .eq('is_accepting_requests', true)
          .eq('current_status', 'available');

      if (shopMechanics.isEmpty) {
        print('⚠️ No available mechanics in shop $shopId');
        
        // Update request status
        await _supabase.from('service_requests').update({
          'status': 'shop_unavailable',
          'status_reason': 'No available mechanics in selected shop',
        }).eq('id', requestId);
        
        return;
      }

      // Create routing entries for all available mechanics in the shop
      final routingEntries = shopMechanics.map((mechanic) => {
        'request_id': requestId,
        'eligible_mechanic_id': mechanic['mechanic_id'],
        'created_at': DateTime.now().toIso8601String(),
        'is_notified': false,
        'response_deadline': DateTime.now()
            .add(Duration(minutes: 5))
            .toIso8601String(),
      }).toList();

      await _supabase.from('request_routing').insert(routingEntries);
      
      print('✅ Created ${routingEntries.length} routing entries for shop $shopId');
    } catch (e) {
      print('❌ Error routing to specific shop: $e');
    }
  }

  /// Get service request details
  Future<Map<String, dynamic>?> getServiceRequest(String requestId) async {
    try {
      final request = await _supabase
          .from('service_requests')
          .select('''
            *,
            customer:user_profiles!customer_id(id, first_name, last_name, phone_number),
            assigned_mechanic:user_profiles!assigned_mechanic_id(id, first_name, last_name, phone_number),
            vehicle:vehicles(id, brand_name, model_name, year, color, plate_number),
            shop:shops(id, shop_name, address)
          ''')
          .eq('id', requestId)
          .single();

      return request;
    } catch (e) {
      print('❌ Error getting service request: $e');
      return null;
    }
  }

  /// Get customer's service requests
  Future<List<Map<String, dynamic>>> getCustomerRequests({
    String? status,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return [];

      PostgrestFilterBuilder query = _supabase
          .from('service_requests')
          .select('''
            *,
            assigned_mechanic:user_profiles!assigned_mechanic_id(id, first_name, last_name, phone_number),
            vehicle:vehicles(id, brand_name, model_name, year, color, plate_number),
            shop:shops(id, shop_name, address)
          ''')
          .eq('customer_id', user.id);

      if (status != null) {
        query = query.eq('status', status);
      }

      final requests = await query
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);
      return List<Map<String, dynamic>>.from(requests);
    } catch (e) {
      print('❌ Error getting customer requests: $e');
      return [];
    }
  }

  /// Cancel a service request
  Future<bool> cancelServiceRequest(String requestId, {String? reason}) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return false;

      // Check if request can be cancelled
      final request = await _supabase
          .from('service_requests')
          .select('status, customer_id')
          .eq('id', requestId)
          .single();

      if (request['customer_id'] != user.id) {
        throw Exception('Unauthorized to cancel this request');
      }

      if (!['pending', 'assigned'].contains(request['status'])) {
        throw Exception('Cannot cancel request in current status: ${request['status']}');
      }

      // Update request status
      await _supabase.from('service_requests').update({
        'status': 'cancelled',
        'cancellation_reason': reason ?? 'Cancelled by customer',
        'cancelled_at': DateTime.now().toIso8601String(),
      }).eq('id', requestId);

      // Remove routing entries
      await _supabase
          .from('request_routing')
          .delete()
          .eq('request_id', requestId);

      // Notify assigned mechanic if any
      if (request['status'] == 'assigned') {
        await _notifyMechanicOfCancellation(requestId);
      }

      print('✅ Service request cancelled: $requestId');
      return true;
    } catch (e) {
      print('❌ Error cancelling service request: $e');
      return false;
    }
  }

  /// Update service request status
  Future<bool> updateRequestStatus({
    required String requestId,
    required String status,
    String? mechanicId,
    String? reason,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final updateData = {
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (mechanicId != null) {
        updateData['assigned_mechanic_id'] = mechanicId;
        updateData['assigned_at'] = DateTime.now().toIso8601String();
      }

      if (reason != null) {
        updateData['status_reason'] = reason;
      }

      if (status == 'completed') {
        updateData['completed_at'] = DateTime.now().toIso8601String();
      }

      if (additionalData != null) {
        additionalData.forEach((key, value) {
          updateData[key] = value;
        });
      }

      await _supabase
          .from('service_requests')
          .update(updateData)
          .eq('id', requestId);

      return true;
    } catch (e) {
      print('❌ Error updating request status: $e');
      return false;
    }
  }

  /// Get nearby shops for customer
  Future<List<Map<String, dynamic>>> getNearbyShops({
    required double latitude,
    required double longitude,
    double radiusKm = 10.0,
    String? serviceType,
  }) async {
    try {
      // Use the get_nearby_shops function if available
      try {
        final shops = await _supabase.rpc('get_nearby_shops', params: {
          'p_latitude': latitude,
          'p_longitude': longitude,
          'p_radius_km': radiusKm,
          'p_service_type': serviceType,
        });

        return List<Map<String, dynamic>>.from(shops);
      } catch (rpcError) {
        print('⚠️ RPC function not available, using fallback query');
        
        // Fallback: basic query without distance calculation
        var query = _supabase
            .from('shops')
            .select('''
              *,
              shop_services(service_type),
              available_mechanics:mechanic_availability_status!shop_id(
                mechanic_id,
                current_status,
                is_accepting_requests
              )
            ''')
            .eq('is_active', true);

        if (serviceType != null) {
          query = query.eq('shop_services.service_type', serviceType);
        }

        final shops = await query;
        return List<Map<String, dynamic>>.from(shops);
      }
    } catch (e) {
      print('❌ Error getting nearby shops: $e');
      return [];
    }
  }

  /// Notify mechanic of cancellation
  Future<void> _notifyMechanicOfCancellation(String requestId) async {
    try {
      final request = await _supabase
          .from('service_requests')
          .select('assigned_mechanic_id, title')
          .eq('id', requestId)
          .single();

      if (request['assigned_mechanic_id'] != null) {
        await _supabase.from('notifications').insert({
          'user_id': request['assigned_mechanic_id'],
          'title': 'Service Request Cancelled',
          'body': 'The customer has cancelled the request: ${request['title']}',
          'type': 'service_request_cancellation',
          'data': {'request_id': requestId},
          'created_at': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      print('❌ Error notifying mechanic of cancellation: $e');
    }
  }

  /// Get request routing status
  Future<Map<String, dynamic>?> getRequestRoutingStatus(String requestId) async {
    try {
      final routings = await _supabase
          .from('request_routing')
          .select('''
            *,
            mechanic:user_profiles!eligible_mechanic_id(id, first_name, last_name)
          ''')
          .eq('request_id', requestId);

      return {
        'total_mechanics_notified': routings.length,
        'pending_responses': routings.where((r) => !r['is_notified']).length,
        'mechanics': routings,
      };
    } catch (e) {
      print('❌ Error getting routing status: $e');
      return null;
    }
  }

  /// Estimate service price
  Future<double?> estimateServicePrice({
    required String serviceType,
    required double distance,
    bool isEmergency = false,
    Map<String, dynamic>? vehicleData,
  }) async {
    try {
      // Base prices for different service types
      const basePrices = {
        'towing': 500.0,
        'flat_tire': 200.0,
        'battery_jump': 150.0,
        'fuel_delivery': 100.0,
        'lockout': 180.0,
        'engine_trouble': 300.0,
        'breakdown': 250.0,
      };

      double basePrice = basePrices[serviceType] ?? 200.0;
      
      // Distance factor (₱10 per km)
      double distanceFee = distance * 10.0;
      
      // Emergency surcharge (50%)
      if (isEmergency) {
        basePrice *= 1.5;
      }
      
      double totalEstimate = basePrice + distanceFee;
      
      // Round to nearest 10
      return (totalEstimate / 10).round() * 10.0;
    } catch (e) {
      print('❌ Error estimating service price: $e');
      return null;
    }
  }

  /// Get service request statistics for customer
  Future<Map<String, dynamic>> getCustomerStatistics() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return ;

      final stats = await _supabase.rpc('get_customer_statistics', params: {
        'p_customer_id': user.id,
      });

      return Map<String, dynamic>.from(stats);
    } catch (e) {
      print('❌ Error getting customer statistics: $e');
      return {
        'total_requests': 0,
        'completed_requests': 0,
        'average_rating': 0.0,
        'total_spent': 0.0,
      };
    }
  }
}










