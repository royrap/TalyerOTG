import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math' as Math;

/// 🏪 Shop-Based Request Service
/// 
/// Implements Grab/JoyRide-style mechanic request flow where:
/// - Each shop acts like a company (JoyRide, Grab, etc.)
/// - Requests are routed only to mechanics of the selected shop
/// - Proper availability checking and status management
class ShopBasedRequestService {
  static ShopBasedRequestService? _instance;
  static ShopBasedRequestService get instance {
    _instance ??= ShopBasedRequestService._();
    return _instance!;
  }

  ShopBasedRequestService._();

  final _supabase = Supabase.instance.client;

  /// ===== SHOP SELECTION =====

  /// Get all active shops with mechanic availability info
  Future<List<Map<String, dynamic>>> getAvailableShops({
    double? customerLat,
    double? customerLng,
    double maxDistanceKm = 50.0,
  }) async {
    try {
      print('🔍 Fetching available shops...');

      // Get all active shops
      final shops = await _supabase
          .from('shops')
          .select('''
            id,
            shop_name,
            shop_address,
            shop_phone,
            shop_description,
            latitude,
            longitude,
            service_radius,
            rating,
            total_reviews,
            current_status,
            is_active
          ''')
          .eq('is_active', true)
          .order('rating', ascending: false);

      print('✅ Found ${shops.length} active shops');

      // Get mechanic counts for each shop
      final shopsWithMechanics = <Map<String, dynamic>>[];

      for (var shop in shops) {
        final shopId = shop['id'];

        // Get mechanics count and availability
        final mechanicsData = await getMechanicAvailability(shopId);

        // Calculate distance if customer location provided
        double? distanceKm;
        if (customerLat != null && customerLng != null && 
            shop['latitude'] != null && shop['longitude'] != null) {
          distanceKm = _calculateDistance(
            customerLat, 
            customerLng,
            shop['latitude'] as double,
            shop['longitude'] as double,
          );
        }

        // Only include shops within service radius
        if (distanceKm == null || distanceKm <= maxDistanceKm) {
          shopsWithMechanics.add({
            ...shop,
            'total_mechanics': mechanicsData['total'],
            'available_mechanics': mechanicsData['available'],
            'busy_mechanics': mechanicsData['busy'],
            'distance_km': distanceKm,
            'has_available_mechanics': (mechanicsData['available'] ?? 0) > 0,
          });
        }
      }

      print('✅ Processed ${shopsWithMechanics.length} shops with mechanic data');
      return shopsWithMechanics;

    } catch (e) {
      print('❌ Error fetching available shops: $e');
      return [];
    }
  }

  /// Get mechanic availability for a specific shop
  Future<Map<String, int>> getMechanicAvailability(String shopId) async {
    try {
      // Get all mechanics for this shop
      final mechanics = await _supabase
          .from('shop_mechanics')
          .select('mechanic_id, is_active, is_available')
          .eq('shop_id', shopId)
          .eq('is_active', true);

      if (mechanics.isEmpty) {
        return {'total': 0, 'available': 0, 'busy': 0};
      }

      final mechanicIds = mechanics
          .map((m) => m['mechanic_id'] as String)
          .toList();

      // Get availability status from mechanic_availability_status
      final availabilityStatus = await _supabase
          .from('mechanic_availability_status')
          .select('mechanic_id, current_status, is_accepting_requests')
          .inFilter('mechanic_id', mechanicIds);

      // Create availability map
      final statusMap = {
        for (var status in availabilityStatus)
          status['mechanic_id']: status
      };

      int available = 0;
      int busy = 0;

      for (var mechanic in mechanics) {
        final mechanicId = mechanic['mechanic_id'];
        final status = statusMap[mechanicId];

        if (status != null) {
          final isAccepting = status['is_accepting_requests'] ?? false;
          final currentStatus = status['current_status'] ?? 'offline';

          if (isAccepting && currentStatus == 'available') {
            available++;
          } else if (currentStatus == 'busy' || currentStatus == 'in_service') {
            busy++;
          }
        } else if (mechanic['is_available'] == true) {
          // Fallback to shop_mechanics.is_available
          available++;
        }
      }

      return {
        'total': mechanics.length,
        'available': available,
        'busy': busy,
      };

    } catch (e) {
      print('❌ Error getting mechanic availability: $e');
      return {'total': 0, 'available': 0, 'busy': 0};
    }
  }

  /// ===== REQUEST CREATION =====

  /// Create service request for specific shop
  Future<Map<String, dynamic>> createShopBasedRequest({
    required String customerId,
    required String shopId,
    required String vehicleId,
    required String categoryId,
    required String title,
    required String description,
    required double pickupLatitude,
    required double pickupLongitude,
    String? pickupAddress,
    Map<String, dynamic>? additionalDetails,
  }) async {
    try {
      print('📝 Creating shop-based service request...');

      // 1. Check if shop has available mechanics
      final mechanicsData = await getMechanicAvailability(shopId);
      
      if (mechanicsData['total'] == 0) {
        return {
          'success': false,
          'error': 'no_mechanics',
          'message': 'No mechanics available for this shop.',
        };
      }

      if (mechanicsData['available'] == 0) {
        return {
          'success': false,
          'error': 'all_busy',
          'message': 'All mechanics are currently busy. Please try again later.',
        };
      }

      // 2. Get shop details for location
      final shop = await _supabase
          .from('shops')
          .select('latitude, longitude, owner_id')
          .eq('id', shopId)
          .single();

      // 3. Create service request
      final request = await _supabase
          .from('service_requests')
          .insert({
            'customer_id': customerId,
            'shop_id': shopId,
            'vehicle_id': vehicleId,
            'category_id': categoryId,
            'title': title,
            'description': description,
            'pickup_latitude': pickupLatitude,
            'pickup_longitude': pickupLongitude,
            'pickup_address': pickupAddress,
            'customer_location_lat': pickupLatitude,
            'customer_location_lng': pickupLongitude,
            'shop_location_lat': shop['latitude'],
            'shop_location_lng': shop['longitude'],
            'status': 'pending',
            'request_type': 'shop_based',
            'preferred_shop_id': shopId,
            'can_accept_by_any_mechanic': false, // Only this shop's mechanics
            'additional_details': additionalDetails,
            'created_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      print('✅ Service request created: ${request['id']}');

      // 4. Notify mechanics of this shop
      await _notifyShopMechanics(shopId, request['id']);

      return {
        'success': true,
        'request_id': request['id'],
        'request': request,
      };

    } catch (e) {
      print('❌ Error creating shop-based request: $e');
      return {
        'success': false,
        'error': 'creation_failed',
        'message': 'Failed to create service request: $e',
      };
    }
  }

  /// Notify all available mechanics in the shop
  Future<void> _notifyShopMechanics(String shopId, String requestId) async {
    try {
      print('📢 Notifying mechanics of shop $shopId...');

      // Get available mechanics
      final mechanics = await _supabase
          .from('shop_mechanics')
          .select('mechanic_id')
          .eq('shop_id', shopId)
          .eq('is_active', true)
          .eq('is_available', true);

      final mechanicIds = mechanics
          .map((m) => m['mechanic_id'] as String)
          .toList();

      if (mechanicIds.isEmpty) {
        print('⚠️ No available mechanics to notify');
        return;
      }

      // Get availability status to filter truly available mechanics
      final availableStatuses = await _supabase
          .from('mechanic_availability_status')
          .select('mechanic_id')
          .inFilter('mechanic_id', mechanicIds)
          .eq('current_status', 'available')
          .eq('is_accepting_requests', true);

      final availableMechanicIds = availableStatuses
          .map((s) => s['mechanic_id'] as String)
          .toList();

      print('✅ Found ${availableMechanicIds.length} available mechanics');

      // Create notifications for each available mechanic
      for (var mechanicId in availableMechanicIds) {
        await _supabase.from('notifications').insert({
          'user_id': mechanicId,
          'title': 'New Service Request',
          'body': 'A new service request is available. Tap to view details.',
          'type': 'service_request',
          'data': {
            'request_id': requestId,
            'shop_id': shopId,
            'action': 'view_request',
          },
          'read': false,
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      // Update service request with notification count
      await _supabase
          .from('service_requests')
          .update({
            'mechanics_notified_count': availableMechanicIds.length,
            'broadcast_started_at': DateTime.now().toIso8601String(),
          })
          .eq('id', requestId);

      print('✅ Notified ${availableMechanicIds.length} mechanics');

    } catch (e) {
      print('❌ Error notifying mechanics: $e');
    }
  }

  /// ===== MECHANIC ACTIONS =====

  /// Mechanic accepts a service request
  Future<Map<String, dynamic>> acceptRequest({
    required String requestId,
    required String mechanicId,
    required String shopId,
  }) async {
    try {
      print('✅ Mechanic $mechanicId accepting request $requestId...');

      // 1. Verify mechanic belongs to the shop
      final shopMechanic = await _supabase
          .from('shop_mechanics')
          .select('id')
          .eq('shop_id', shopId)
          .eq('mechanic_id', mechanicId)
          .eq('is_active', true)
          .maybeSingle();

      if (shopMechanic == null) {
        return {
          'success': false,
          'error': 'not_authorized',
          'message': 'You are not authorized to accept this request.',
        };
      }

      // 2. Check if request is still pending
      final request = await _supabase
          .from('service_requests')
          .select('status, shop_id')
          .eq('id', requestId)
          .single();

      if (request['status'] != 'pending') {
        return {
          'success': false,
          'error': 'already_accepted',
          'message': 'This request has already been accepted by another mechanic.',
        };
      }

      if (request['shop_id'] != shopId) {
        return {
          'success': false,
          'error': 'wrong_shop',
          'message': 'This request is for a different shop.',
        };
      }

      // 3. Update service request
      await _supabase
          .from('service_requests')
          .update({
            'status': 'accepted',
            'assigned_mechanic_id': mechanicId,
            'accepted_at': DateTime.now().toIso8601String(),
            'accepted_by': mechanicId,
          })
          .eq('id', requestId);

      // 4. Update mechanic availability to busy
      await _supabase
          .from('mechanic_availability_status')
          .update({
            'current_status': 'busy',
            'is_accepting_requests': false,
            'current_request_id': requestId,
            'last_status_update': DateTime.now().toIso8601String(),
          })
          .eq('mechanic_id', mechanicId);

      // 5. Update shop_mechanics status
      await _supabase
          .from('shop_mechanics')
          .update({
            'is_available': false,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('shop_id', shopId)
          .eq('mechanic_id', mechanicId);

      print('✅ Request accepted successfully');

      return {
        'success': true,
        'message': 'Request accepted successfully',
      };

    } catch (e) {
      print('❌ Error accepting request: $e');
      return {
        'success': false,
        'error': 'acceptance_failed',
        'message': 'Failed to accept request: $e',
      };
    }
  }

  /// Mechanic rejects a service request
  Future<Map<String, dynamic>> rejectRequest({
    required String requestId,
    required String mechanicId,
    String? reason,
  }) async {
    try {
      print('❌ Mechanic $mechanicId rejecting request $requestId...');

      // Record rejection (don't change request status, let other mechanics accept)
      await _supabase.from('request_status_history').insert({
        'request_id': requestId,
        'status': 'rejected',
        'notes': reason ?? 'Mechanic declined the request',
        'changed_by': mechanicId,
        'created_at': DateTime.now().toIso8601String(),
      });

      print('✅ Request rejection recorded');

      return {
        'success': true,
        'message': 'Request declined',
      };

    } catch (e) {
      print('❌ Error rejecting request: $e');
      return {
        'success': false,
        'error': 'rejection_failed',
        'message': 'Failed to reject request: $e',
      };
    }
  }

  /// ===== JOB COMPLETION =====

  /// Complete job after QR scan
  Future<Map<String, dynamic>> completeJob({
    required String requestId,
    required String mechanicId,
    required String completionCode,
  }) async {
    try {
      print('✅ Completing job $requestId...');

      // 1. Verify completion code
      final completion = await _supabase
          .from('service_completions')
          .select('*')
          .eq('request_id', requestId)
          .eq('completion_code', completionCode)
          .eq('is_scanned', false)
          .maybeSingle();

      if (completion == null) {
        return {
          'success': false,
          'error': 'invalid_code',
          'message': 'Invalid or already used completion code.',
        };
      }

      // Check if expired
      final expiresAt = DateTime.parse(completion['expires_at']);
      if (DateTime.now().isAfter(expiresAt)) {
        return {
          'success': false,
          'error': 'expired_code',
          'message': 'Completion code has expired.',
        };
      }

      // 2. Mark completion code as scanned
      await _supabase
          .from('service_completions')
          .update({
            'is_scanned': true,
            'scanned_at': DateTime.now().toIso8601String(),
            'verification_status': 'verified',
          })
          .eq('request_id', requestId);

      // 3. Update service request to completed
      await _supabase
          .from('service_requests')
          .update({
            'status': 'completed',
            'completed_at': DateTime.now().toIso8601String(),
            'qr_scanned_at': DateTime.now().toIso8601String(),
            'qr_scanned_by': mechanicId,
          })
          .eq('id', requestId);

      // 4. Get shop_id for this mechanic
      final shopMechanic = await _supabase
          .from('shop_mechanics')
          .select('shop_id')
          .eq('mechanic_id', mechanicId)
          .eq('is_active', true)
          .maybeSingle();

      // 5. Set mechanic back to available
      await _supabase
          .from('mechanic_availability_status')
          .update({
            'current_status': 'available',
            'is_accepting_requests': true,
            'current_request_id': null,
            'last_status_update': DateTime.now().toIso8601String(),
          })
          .eq('mechanic_id', mechanicId);

      if (shopMechanic != null) {
        await _supabase
            .from('shop_mechanics')
            .update({
              'is_available': true,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('shop_id', shopMechanic['shop_id'])
            .eq('mechanic_id', mechanicId);
      }

      print('✅ Job completed successfully');

      return {
        'success': true,
        'message': 'Job completed successfully',
      };

    } catch (e) {
      print('❌ Error completing job: $e');
      return {
        'success': false,
        'error': 'completion_failed',
        'message': 'Failed to complete job: $e',
      };
    }
  }

  /// ===== HELPER METHODS =====

  /// Calculate distance between two coordinates (Haversine formula)
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // km

    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);

    final a = (Math.sin(dLat / 2) * Math.sin(dLat / 2)) +
        (Math.cos(_degreesToRadians(lat1)) *
            Math.cos(_degreesToRadians(lat2)) *
            Math.sin(dLon / 2) *
            Math.sin(dLon / 2));

    final c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));

    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * Math.pi / 180;
  }
}
