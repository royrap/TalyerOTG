// Enhanced Service Request Service with Guaranteed Broadcast
// Fixes the issue where only rafaelpineda471@gmail.com sees requests

import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';

class ServiceRequestServiceEnhanced {
  static final supabase = Supabase.instance.client;

  static Future<Map<String, dynamic>?> createServiceRequest({
    required String vehicleId,
    required String title,
    required String description,
    required String serviceType,
    required double latitude,
    required double longitude,
    required String locationAddress,
    String? priority,
    int? estimatedDuration,
    String? categories,
    List<Map<String, dynamic>>? selectedIssues,
    String? shopId,
    String? providerId,
    Map<String, dynamic>? shopData,
  }) async {
    try {
      print('🔍 Creating service request with proper routing...');
      
      // Get current user with better error handling
      final user = await AuthService.getCurrentUser();
      if (user == null) {
        throw Exception('User not authenticated. Please log in again.');
      }
      
      print('  - User ID: ${user.id}');
      print('  - Vehicle ID: $vehicleId');
      print('  - Title: $title');
      print('  - Service Type: $serviceType');
      print('  - Priority: ${priority ?? 'normal'}');
      print('  - Location: $latitude, $longitude');
      
      // Determine request type based on shop data
      String requestType = 'broadcast'; // Default to broadcast (all mechanics)
      bool isShopBased = false;
      
      if (shopData != null && shopData['serviceType'] == 'shop_based') {
        requestType = 'shop_based';
        isShopBased = true;
        print('  - SHOP-BASED REQUEST: Will notify only mechanics from shop: ${shopData['shopName']}');
      } else {
        print('  - DIRECT MECHANIC REQUEST: Will broadcast to ALL available mechanics');
      }
      
      // Validate required parameters
      if (vehicleId.trim().isEmpty) {
        throw Exception('Vehicle ID is required');
      }
      if (title.trim().isEmpty) {
        throw Exception('Service title is required');
      }
      if (description.trim().isEmpty) {
        throw Exception('Service description is required');
      }
      
      // Ensure title length fits DB constraints
      String safeTitle = title.trim();
      if (safeTitle.length > 100) {
        safeTitle = safeTitle.substring(0, 97) + '...';
      }

      // Create service request data
      final requestData = {
        'customer_id': user.id,
        'vehicle_id': vehicleId.trim(),
        'title': safeTitle,
        'description': description.trim(),
        'service_type': serviceType.trim(),
        'pickup_latitude': latitude,
        'pickup_longitude': longitude,
        'pickup_address': locationAddress.trim(),
        'status': 'pending',
        'payment_status': 'pending',
        'priority': priority?.trim() ?? 'normal',
        'created_at': DateTime.now().toIso8601String(),
        'request_type': requestType,
        'broadcast_radius_km': isShopBased ? 5.0 : 50.0, // Smaller radius for shop-based
        'is_broadcast_request': !isShopBased, // Only true for direct mechanic requests
        'can_accept_by_any_mechanic': !isShopBased, // Only true for direct mechanic requests
        // Shop-specific fields
        if (isShopBased && shopId != null) 'shop_id': shopId.trim(),
        if (isShopBased && providerId != null) 'provider_id': providerId.trim(),
        // Additional details
        'additional_details': {
          'request_source': 'mobile_app',
          'is_shop_based': isShopBased,
          'service_categories': categories ?? 'general',
          'estimated_duration': estimatedDuration ?? 30,
          if (selectedIssues != null) 'selected_issues': _cleanSelectedIssues(selectedIssues),
          if (shopData != null) 'shop_info': _cleanMapForSerialization(shopData),
        },
        'notes': _buildServiceNotes(selectedIssues, estimatedDuration, categories),
      };
      
      print('  - Request data: $requestData');
      
      // Create the service request
      final response = await supabase
          .from('service_requests')
          .insert(requestData)
          .select()
          .single();
      
      print('✅ Service request created: ${response['id']}');
      
      // Route to appropriate mechanics based on request type
      if (isShopBased && shopId != null) {
        await _routeToShopMechanics(response['id'], shopId, latitude, longitude);
      } else {
        await _routeToAllMechanics(response['id'], latitude, longitude);
      }
      
      // Log status history
      await _logStatusHistory(
        response['id'], 
        'pending', 
        isShopBased 
            ? 'Service request created for shop: ${shopData?['shopName'] ?? 'Selected Shop'}'
            : 'Service request created and broadcast to ALL available mechanics'
      );
      
      return response;
      
    } catch (e, stackTrace) {
      print('❌ Error creating service request: $e');
      print('📚 Stack trace: $stackTrace');
      
      String errorMessage = 'Failed to create service request';
      if (e.toString().contains('not authenticated')) {
        errorMessage = 'Please log in to create a service request';
      } else if (e.toString().contains('foreign key')) {
        errorMessage = 'Invalid vehicle or user data. Please try again.';
      } else if (e.toString().contains('permission')) {
        errorMessage = 'Permission denied. Please check your account access.';
      } else {
        errorMessage = 'Failed to create service request: ${e.toString()}';
      }
      
      throw Exception(errorMessage);
    }
  }

  /// Route request to mechanics from a specific shop
  static Future<void> _routeToShopMechanics(
    String requestId, 
    String shopId,
    double latitude, 
    double longitude
  ) async {
    try {
      print('🏪 Routing request $requestId to mechanics from shop: $shopId');
      
      // Get mechanics associated with the specific shop
      final shopMechanics = await supabase
          .from('shop_mechanics')
          .select('''
            mechanic_id,
            user_profiles!inner(id, first_name, last_name, email),
            mechanic_availability_status!inner(
              current_status,
              is_accepting_requests,
              location_latitude,
              location_longitude
            )
          ''')
          .eq('shop_id', shopId)
          .eq('is_active', true)
          .eq('mechanic_availability_status.current_status', 'available')
          .eq('mechanic_availability_status.is_accepting_requests', true);
      
      print('Found ${shopMechanics.length} available mechanics in shop $shopId');

      // If no mechanics are available in this shop, do NOT fallback to global
      // broadcast. Instead, mark the request as rejected and bubble up the
      // failure so the customer can be informed.
      if (shopMechanics.isEmpty) {
        print('⚠️ No available mechanics in shop $shopId - rejecting shop-based request $requestId');
        await supabase.from('service_requests').update({
          'status': 'rejected',
          'rejection_reason': 'no_available_mechanics_in_shop',
          'rejected_at': DateTime.now().toIso8601String(),
        }).eq('id', requestId);

        // Optionally notify the customer
        try {
          final req = await supabase.from('service_requests').select('customer_id').eq('id', requestId).maybeSingle();
          if (req != null && req['customer_id'] != null) {
            await supabase.from('notifications').insert({
              'user_id': req['customer_id'],
              'title': 'No mechanics available',
              'body': 'No available mechanics in the selected shop. Please try another shop or try again later.',
              'type': 'service_request_update',
              'data': {'request_id': requestId, 'error': 'no_available_mechanics_in_shop'},
              'created_at': DateTime.now().toIso8601String(),
            });
          }
        } catch (e) {
          print('⚠️ Failed to notify customer about no mechanics: $e');
        }

        return; // Stop routing
      }
      
      // Create routing entries for each shop mechanic
      for (final mechanicData in shopMechanics) {
        final mechanicId = mechanicData['mechanic_id'];
        final availability = mechanicData['mechanic_availability_status'];
        final profile = mechanicData['user_profiles'];
        
        // Calculate distance if mechanic location is available
        double distance = 0.0;
        if (availability['location_latitude'] != null && availability['location_longitude'] != null) {
          final mechanicLat = availability['location_latitude'];
          final mechanicLng = availability['location_longitude'];
          distance = _calculateDistance(latitude, longitude, mechanicLat, mechanicLng);
        }
        
        await supabase.from('request_routing').insert({
          'request_id': requestId,
          'eligible_mechanic_id': mechanicId,
          'eligible_shop_id': shopId,
          'distance_km': distance,
          'routing_type': 'shop_based',
          'is_notified': false,
          'created_at': DateTime.now().toIso8601String(),
          'response_deadline': DateTime.now().add(Duration(minutes: 10)).toIso8601String(),
        });
        
        print('  ✅ Added routing for shop mechanic: ${profile['first_name']} ${profile['last_name']} (${profile['email']}) - ${distance.toStringAsFixed(1)}km');
      }
      
      // Also create broadcast entry for the shop
      await supabase.from('request_broadcasts').insert({
        'request_id': requestId,
        'provider_id': shopId, // Using shop as provider
        'provider_type': 'shop',
        'shop_id': shopId,
        'distance_km': 0.0, // Shop is the target
        'notification_sent_at': DateTime.now().toIso8601String(),
        'notification_method': 'push',
        'response_status': 'pending',
        'is_eligible': true,
        'eligibility_reasons': ['shop_selected_by_customer'],
        'created_at': DateTime.now().toIso8601String(),
      });
      
      print('✅ Routed request to ${shopMechanics.length} mechanics from shop $shopId');
      
    } catch (e) {
      print('❌ Error routing to shop mechanics: $e');
      // Fallback: still try to route to all mechanics if shop routing fails
      await _routeToAllMechanics(requestId, latitude, longitude);
    }
  }

  /// Route request to all available mechanics (direct mechanic request)
  static Future<void> _routeToAllMechanics(
    String requestId, 
    double latitude, 
    double longitude
  ) async {
    try {
      print('🚀 Routing request $requestId to ALL available mechanics...');
      
      // Use the existing broadcast function
      await _forceBroadcastToAllMechanics(requestId, latitude, longitude);
      
    } catch (e) {
      print('❌ Error routing to all mechanics: $e');
    }
  }
  static Future<void> _forceBroadcastToAllMechanics(
    String requestId, 
    double latitude, 
    double longitude
  ) async {
    try {
      print('🚀 Force broadcasting request $requestId to ALL mechanics...');
      
      // Call the database function directly to ensure broadcast
      final result = await supabase.rpc('manual_broadcast_request', params: {
        'p_request_id': requestId,
      });
      
      print('📡 Broadcast result: $result');
      
      // Also verify routing entries were created
      final routingEntries = await supabase
          .from('request_routing')
          .select('eligible_mechanic_id, distance_km')
          .eq('request_id', requestId);
      
      print('✅ Created ${routingEntries.length} routing entries for request $requestId');
      
      // If no routing entries, create them manually
      if (routingEntries.isEmpty) {
        await _createManualRoutingEntries(requestId, latitude, longitude);
      }
      
    } catch (e) {
      print('❌ Error in force broadcast: $e');
      // Try alternative method
      await _createManualRoutingEntries(requestId, latitude, longitude);
    }
  }

  /// Create routing entries manually if broadcast function fails
  static Future<void> _createManualRoutingEntries(
    String requestId, 
    double latitude, 
    double longitude
  ) async {
    try {
      print('🔧 Creating manual routing entries for request $requestId...');
      
      // Get all available mechanics
      final mechanics = await supabase
          .from('mechanic_availability_status')
          .select('''
            mechanic_id,
            location_latitude,
            location_longitude
          ''')
          .eq('current_status', 'available')
          .eq('is_accepting_requests', true)
          .not('location_latitude', 'is', null)
          .not('location_longitude', 'is', null);
      
      print('Found ${mechanics.length} available mechanics');
      
      // Create routing entry for each mechanic
      for (final mechanic in mechanics) {
        // Calculate simple distance (for nearby locations)
        final double mechanicLat = mechanic['location_latitude'];
        final double mechanicLng = mechanic['location_longitude'];
        final double distance = _calculateDistance(latitude, longitude, mechanicLat, mechanicLng);
        
        await supabase.from('request_routing').insert({
          'request_id': requestId,
          'eligible_mechanic_id': mechanic['mechanic_id'],
          'distance_km': distance,
          'routing_type': 'broadcast',
          'is_notified': false,
          'created_at': DateTime.now().toIso8601String(),
          'response_deadline': DateTime.now().add(Duration(minutes: 5)).toIso8601String(),
        });
        
        print('  ✅ Added routing for mechanic: ${mechanic['mechanic_id']} (${distance.toStringAsFixed(1)}km)');
      }
      
      print('✅ Manual routing entries created: ${mechanics.length}');
      
    } catch (e) {
      print('❌ Error creating manual routing entries: $e');
    }
  }

  /// Simple distance calculation for nearby locations
  static double _calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    // Simple Euclidean distance for nearby points (good enough for city-level)
    final double deltaLat = lat1 - lat2;
    final double deltaLng = lng1 - lng2;
    return ((deltaLat * deltaLat + deltaLng * deltaLng) * 111.0); // Rough km conversion
  }

  static String _buildServiceNotes(List<Map<String, dynamic>>? selectedIssues, int? estimatedDuration, String? categories) {
    final notes = <String>[];
    
    if (selectedIssues != null && selectedIssues.isNotEmpty) {
      notes.add('Selected Services: ${selectedIssues.map((issue) => issue['title']).join(', ')}');
    }
    
    if (estimatedDuration != null) {
      notes.add('Estimated Duration: ${estimatedDuration} minutes');
    }
    
    if (categories != null && categories.isNotEmpty) {
      notes.add('Categories: $categories');
    }
    
    notes.add('Request created via mobile app (BROADCAST MODE)');
    notes.add('Sent to ALL available mechanics');
    
    return notes.join('\\n');
  }

  // Clean selectedIssues to remove non-serializable objects
  static List<Map<String, dynamic>> _cleanSelectedIssues(List<Map<String, dynamic>> selectedIssues) {
    return selectedIssues.map((issue) {
      final cleanedIssue = <String, dynamic>{};
      
      issue.forEach((key, value) {
        if (key == 'icon') {
          // Convert IconData to a serializable string representation
          cleanedIssue['icon_code'] = value.toString();
        } else if (value is String || value is num || value is bool) {
          // Keep primitive types as-is
          cleanedIssue[key] = value;
        } else if (value is List) {
          // Clean lists recursively if they contain non-serializable objects
          try {
            cleanedIssue[key] = value.map((item) {
              if (item is Map<String, dynamic>) {
                return _cleanMapForSerialization(item);
              } else if (item is String || item is num || item is bool) {
                return item;
              } else {
                return item.toString();
              }
            }).toList();
          } catch (e) {
            cleanedIssue[key] = value.toString();
          }
        } else if (value is Map) {
          // Clean maps recursively
          try {
            cleanedIssue[key] = _cleanMapForSerialization(value as Map<String, dynamic>);
          } catch (e) {
            cleanedIssue[key] = value.toString();
          }
        } else {
          // Convert everything else to string
          cleanedIssue[key] = value.toString();
        }
      });
      
      return cleanedIssue;
    }).toList();
  }

  // Helper method to clean maps for JSON serialization
  static Map<String, dynamic> _cleanMapForSerialization(Map<String, dynamic> map) {
    final cleanedMap = <String, dynamic>{};
    
    map.forEach((key, value) {
      if (key == 'icon') {
        // Convert IconData to string
        cleanedMap['icon_code'] = value.toString();
      } else if (value is String || value is num || value is bool) {
        cleanedMap[key] = value;
      } else if (value is List) {
        cleanedMap[key] = value.map((item) {
          if (item is Map<String, dynamic>) {
            return _cleanMapForSerialization(item);
          } else if (item is String || item is num || item is bool) {
            return item;
          } else {
            return item.toString();
          }
        }).toList();
      } else if (value is Map) {
        cleanedMap[key] = _cleanMapForSerialization(value as Map<String, dynamic>);
      } else {
        cleanedMap[key] = value.toString();
      }
    });
    
    return cleanedMap;
  }

  static Future<void> _logStatusHistory(String requestId, String status, String notes) async {
    try {
      final user = await AuthService.getCurrentUser();
      
      await supabase.from('request_status_history').insert({
        'request_id': requestId,
        'status': status,
        'notes': notes,
        'changed_by': user?.id,
        'created_at': DateTime.now().toIso8601String(),
      });
      
      print('✅ Status history logged: $status');
    } catch (e) {
      print('⚠️ Failed to log status history: $e');
    }
  }
  
  static Future<Map<String, dynamic>?> getServiceRequest(String requestId) async {
    try {
      if (requestId.trim().isEmpty) {
        throw Exception('Service request ID is required');
      }
      
      final response = await supabase
          .from('service_requests')
          .select('*')
          .eq('id', requestId.trim())
          .maybeSingle();
      
      return response;
    } catch (e) {
      print('❌ Error getting service request: $e');
      return null;
    }
  }
  
  static Future<bool> cancelServiceRequest(String requestId) async {
    try {
      if (requestId.trim().isEmpty) {
        throw Exception('Service request ID is required');
      }
      
      await supabase
          .from('service_requests')
          .update({
            'status': 'cancelled',
            'cancelled_at': DateTime.now().toIso8601String(),
          })
          .eq('id', requestId.trim());
      
      // Log status change
      await _logStatusHistory(requestId, 'cancelled', 'Service request cancelled by user');
      
      print('✅ Service request cancelled: $requestId');
      return true;
    } catch (e) {
      print('❌ Error cancelling service request: $e');
      return false;
    }
  }

  /// Debug function to check routing entries for a request
  static Future<void> debugRequestRouting(String requestId) async {
    try {
      print('🔍 DEBUG: Checking routing for request $requestId');
      
      final routingEntries = await supabase
          .from('request_routing')
          .select('''
            eligible_mechanic_id,
            distance_km,
            is_notified,
            created_at,
            user_profiles!inner(email, first_name, last_name)
          ''')
          .eq('request_id', requestId);
      
      print('Found ${routingEntries.length} routing entries:');
      for (final entry in routingEntries) {
        final profile = entry['user_profiles'];
        print('  - ${profile['first_name']} ${profile['last_name']} (${profile['email']}) - ${entry['distance_km']}km - Notified: ${entry['is_notified']}');
      }
      
      // Check mechanic availability
      final mechanics = await supabase
          .from('mechanic_availability_status')
          .select('''
            mechanic_id,
            current_status,
            is_accepting_requests,
            user_profiles!inner(email, first_name, last_name)
          ''');
      
      print('\\nAll mechanics availability:');
      for (final mechanic in mechanics) {
        final profile = mechanic['user_profiles'];
        print('  - ${profile['first_name']} ${profile['last_name']} (${profile['email']}) - Status: ${mechanic['current_status']} - Accepting: ${mechanic['is_accepting_requests']}');
      }
      
    } catch (e) {
      print('❌ Error in debug routing: $e');
    }
  }
}