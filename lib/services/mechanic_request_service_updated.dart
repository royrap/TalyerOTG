// Updated mechanic_request_service.dart with broadcast support
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';

class MechanicRequestService {
  static final MechanicRequestService _instance = MechanicRequestService._internal();
  static MechanicRequestService get instance => _instance;
  MechanicRequestService._internal();

  final _supabase = Supabase.instance.client;
  StreamSubscription? _requestSubscription;
  RealtimeChannel? _routingChannel;
  final _incomingRequestController = StreamController<Map<String, dynamic>>.broadcast();
  final _requestTimeoutController = StreamController<String>.broadcast();

  // Streams for UI
  Stream<Map<String, dynamic>> get incomingRequestStream => _incomingRequestController.stream;
  Stream<String> get requestTimeoutStream => _requestTimeoutController.stream;

  Timer? _requestTimeoutTimer;
  String? _currentPendingRequestId;
  static const int REQUEST_TIMEOUT_SECONDS = 30;

  /// Start listening for incoming service requests
  Future<void> startListening() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        print('❌ No authenticated user found');
        return;
      }

      // Get mechanic's availability status
      final availabilityStatus = await _getMechanicAvailabilityStatus();
      if (!availabilityStatus['is_accepting_requests']) {
        print('🔧 Mechanic not accepting requests, skipping request listener');
        return;
      }

      final mechanicId = user.id;
      print('🔧 Starting request listener for mechanic: $mechanicId');

      // Listen for requests targeted to THIS SPECIFIC mechanic
      _routingChannel?.unsubscribe();
      _requestSubscription?.cancel();

      _routingChannel = _supabase.channel('public:request_routing')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'request_routing',
          callback: (payload) async {
            try {
              final newRow = payload.newRecord;
              if (newRow['eligible_mechanic_id'] != user.id) return;
              if (newRow['is_notified'] == true) return;
              await _processIncomingRequest(Map<String, dynamic>.from(newRow));
            } catch (e) {
              print('❌ Realtime INSERT handling error: $e');
            }
          },
        )
        .subscribe();

      // Proactively pull any pending routes
      await _primePendingRequests(user.id);

      print('✅ Request realtime channel subscribed');
    } catch (e) {
      print('❌ Error starting request listener: $e');
    }
  }

  /// Stop listening for requests
  void stopListening() {
    _requestSubscription?.cancel();
    _requestSubscription = null;
    _routingChannel?.unsubscribe();
    _routingChannel = null;
    _cancelCurrentRequestTimeout();
    print('🔧 Request listener stopped');
  }

  /// Fetch any pending routing rows that might have been inserted before subscription setup
  Future<void> _primePendingRequests(String mechanicUserId) async {
    try {
      final rows = await _supabase
          .from('request_routing')
          .select('id, request_id, eligible_mechanic_id, is_notified')
          .eq('eligible_mechanic_id', mechanicUserId)
          .eq('is_notified', false)
          .limit(10);
      if (rows.isEmpty) return;
      print('🔄 Priming ${rows.length} pending routing entries');
      for (final r in rows) {
        await _processIncomingRequest(r);
      }
    } catch (e) {
      print('❌ Error priming pending requests: $e');
    }
  }

  /// Process and display incoming request
  Future<void> _processIncomingRequest(Map<String, dynamic> routing) async {
    try {
      final requestId = routing['request_id'];
      
      // Get full service request details
      final serviceRequest = await _supabase
          .from('service_requests')
          .select('''
            id, title, description, service_type, pickup_latitude, pickup_longitude,
            pickup_address, estimated_price, customer_id, vehicle_id, is_emergency,
            priority, created_at, distance_km, estimated_arrival_minutes, request_type
          ''')
          .eq('id', requestId)
          .single();

      // Skip if request is no longer pending
      if (serviceRequest['assigned_mechanic_id'] != null || serviceRequest['status'] != 'pending') {
        print('⚠️ Skipping request that is no longer available: $requestId');
        return;
      }

      // Get customer details
      final customer = await _supabase
          .from('user_profiles')
          .select('id, first_name, last_name, phone_number')
          .eq('id', serviceRequest['customer_id'])
          .single();

      // Get vehicle details if available
      Map<String, dynamic>? vehicle;
      if (serviceRequest['vehicle_id'] != null) {
        vehicle = await _supabase
            .from('vehicles')
            .select('brand_name, model_name, year, color, plate_number')
            .eq('id', serviceRequest['vehicle_id'])
            .single();
      }

      // Calculate distance from mechanic to customer
      final mechanicLocation = await _getCurrentMechanicLocation();
      double? distanceKm;
      if (mechanicLocation != null) {
        distanceKm = Geolocator.distanceBetween(
          mechanicLocation['latitude'],
          mechanicLocation['longitude'],
          serviceRequest['pickup_latitude'],
          serviceRequest['pickup_longitude'],
        ) / 1000;
      }

      // Set response deadline
      await _supabase
          .from('request_routing')
          .update({
            'response_deadline': DateTime.now()
                .add(Duration(seconds: REQUEST_TIMEOUT_SECONDS))
                .toIso8601String(),
          })
          .eq('id', routing['id']);

      // Prepare request data for UI
      final requestData = {
        'routing_id': routing['id'],
        'request_id': requestId,
        'service_type': serviceRequest['service_type'],
        'title': serviceRequest['title'],
        'description': serviceRequest['description'],
        'customer_id': customer['id'],
        'customer_name': '${customer['first_name']} ${customer['last_name']}',
        'customer_phone': customer['phone_number'],
        'pickup_address': serviceRequest['pickup_address'],
        'pickup_latitude': serviceRequest['pickup_latitude'],
        'pickup_longitude': serviceRequest['pickup_longitude'],
        'estimated_price': serviceRequest['estimated_price'],
        'is_emergency': serviceRequest['is_emergency'] ?? false,
        'priority': serviceRequest['priority'] ?? 'normal',
        'distance_km': distanceKm ?? serviceRequest['distance_km'],
        'estimated_arrival_minutes': serviceRequest['estimated_arrival_minutes'],
        'vehicle': vehicle,
        'created_at': serviceRequest['created_at'],
        'timeout_seconds': REQUEST_TIMEOUT_SECONDS,
        'request_type': serviceRequest['request_type'] ?? 'direct_mechanic',
      };

      // Set current pending request and start timeout
      _currentPendingRequestId = requestId;
      _startRequestTimeout(requestId);

      // Emit to UI
      _incomingRequestController.add(requestData);

      print('✅ Incoming request processed and sent to UI: $requestId');
    } catch (e) {
      print('❌ Error processing incoming request: $e');
    }
  }

  /// Accept a service request with improved error handling
  Future<bool> acceptRequest(String routingId, String requestId) async {
    try {
      print('🔧 Starting acceptance process for routing: $routingId, request: $requestId');
      _cancelCurrentRequestTimeout();
      
      final mechanicUserId = _supabase.auth.currentUser!.id;
      print('🔧 Mechanic user ID: $mechanicUserId');

      // Use improved acceptance function that handles race conditions
      final result = await _supabase.rpc('accept_request_fifo', params: {
        'p_routing_id': routingId,
        'p_mechanic_user_id': mechanicUserId,
      });

      print('🔧 RPC result: $result');

      final bool accepted = result == true;
      if (!accepted) {
        print('⚠️ Request already taken or not eligible (RPC returned false)');
        
        // Use debug function to get detailed error information
        try {
          final debugResult = await _supabase.rpc('debug_request_acceptance', params: {
            'p_request_id': requestId,
            'p_mechanic_id': mechanicUserId,
          });
          
          print('🔧 Debug result: $debugResult');
        } catch (debugError) {
          print('❌ Error running debug function: $debugError');
        }
        
        return false;
      }

      _currentPendingRequestId = null;
      print('✅ Request accepted successfully: $requestId');
      return true;
    } catch (e) {
      print('❌ Error accepting request: $e');
      print('❌ Stack trace: ${StackTrace.current}');
      return false;
    }
  }

  /// Accept broadcast request using new broadcast function
  Future<bool> acceptBroadcastRequest({
    required String requestId,
    required String providerId,
    String? mechanicId,
  }) async {
    try {
      print('🔧 Accepting broadcast request: $requestId');
      _cancelCurrentRequestTimeout();
      
      final mechId = mechanicId ?? _supabase.auth.currentUser!.id;
      
      final result = await _supabase.rpc('accept_broadcast_request', params: {
        'p_request_id': requestId,
        'p_provider_id': providerId,
        'p_mechanic_id': mechId,
      });

      print('🔧 Broadcast acceptance result: $result');

      if (result is Map && result['success'] == true) {
        _currentPendingRequestId = null;
        print('✅ Broadcast request accepted successfully: $requestId');
        return true;
      } else {
        print('⚠️ Broadcast request not accepted: ${result['error'] ?? 'Unknown error'}');
        return false;
      }
    } catch (e) {
      print('❌ Error accepting broadcast request: $e');
      return false;
    }
  }

  /// Reject a service request
  Future<bool> rejectRequest(String routingId, String requestId) async {
    try {
      _cancelCurrentRequestTimeout();

      // Remove this mechanic from routing for this request
      await _supabase
          .from('request_routing')
          .delete()
          .eq('id', routingId);

      // Check if there are other available mechanics for this request
      final otherRoutings = await _supabase
          .from('request_routing')
          .select('id')
          .eq('request_id', requestId);

      if (otherRoutings.isEmpty) {
        // No other mechanics available, notify customer
        await _supabase.from('service_requests').update({
          'status': 'rejected',
          'rejection_reason': 'No available mechanics',
          'rejected_at': DateTime.now().toIso8601String(),
        }).eq('id', requestId);

        await _sendCustomerNotification(requestId, 'no_mechanics_available');
      }

      _currentPendingRequestId = null;
      print('✅ Request rejected successfully: $requestId');
      return true;
    } catch (e) {
      print('❌ Error rejecting request: $e');
      return false;
    }
  }

  /// Start timeout timer for current request
  void _startRequestTimeout(String requestId) {
    _requestTimeoutTimer?.cancel();
    _requestTimeoutTimer = Timer(Duration(seconds: REQUEST_TIMEOUT_SECONDS), () {
      if (_currentPendingRequestId == requestId) {
        _handleRequestTimeout(requestId);
      }
    });
  }

  /// Cancel current request timeout
  void _cancelCurrentRequestTimeout() {
    _requestTimeoutTimer?.cancel();
    _requestTimeoutTimer = null;
  }

  /// Handle request timeout (auto-reject)
  void _handleRequestTimeout(String requestId) async {
    try {
      print('⏰ Request timeout for: $requestId');
      
      // Find routing entry and auto-reject
      final routings = await _supabase
          .from('request_routing')
          .select('id')
          .eq('request_id', requestId)
          .eq('eligible_mechanic_id', _supabase.auth.currentUser!.id)
          .eq('is_notified', false);

      for (final routing in routings) {
        await rejectRequest(routing['id'], requestId);
      }

      _requestTimeoutController.add(requestId);
      _currentPendingRequestId = null;
    } catch (e) {
      print('❌ Error handling request timeout: $e');
    }
  }

  /// Get mechanic availability status
  Future<Map<String, dynamic>> _getMechanicAvailabilityStatus() async {
    try {
      final mechanicId = _supabase.auth.currentUser!.id;
      
      final status = await _supabase
          .from('mechanic_availability_status')
          .select('*')
          .eq('mechanic_id', mechanicId)
          .maybeSingle();

      if (status == null) {
        await _supabase.from('mechanic_availability_status').upsert({
          'mechanic_id': mechanicId,
          'current_status': 'available',
          'is_accepting_requests': true,
          'last_status_update': DateTime.now().toIso8601String(),
        }, onConflict: 'mechanic_id');

        return {
          'current_status': 'available',
          'is_accepting_requests': true,
          'shop_id': null,
        };
      }

      return status;
    } catch (e) {
      print('❌ Error getting mechanic availability: $e');
      return {
        'current_status': 'offline',
        'is_accepting_requests': false,
        'shop_id': null,
      };
    }
  }

  /// Get current mechanic location
  Future<Map<String, dynamic>?> _getCurrentMechanicLocation() async {
    try {
      final mechanicId = _supabase.auth.currentUser!.id;
      
      final availability = await _supabase
          .from('mechanic_availability_status')
          .select('location_latitude, location_longitude')
          .eq('mechanic_id', mechanicId)
          .maybeSingle();

      if (availability?['location_latitude'] != null && 
          availability?['location_longitude'] != null) {
        return {
          'latitude': availability!['location_latitude'],
          'longitude': availability['location_longitude'],
        };
      }

      return null;
    } catch (e) {
      print('❌ Error getting mechanic location: $e');
      return null;
    }
  }

  /// Update mechanic availability status
  Future<bool> updateAvailabilityStatus({
    required String status,
    required bool isAcceptingRequests,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final mechanicId = _supabase.auth.currentUser!.id;

      double? lat = latitude;
      double? lng = longitude;
      if (isAcceptingRequests && status == 'available' && (lat == null || lng == null)) {
        try {
          final pos = await Geolocator.getCurrentPosition();
          lat = pos.latitude;
          lng = pos.longitude;
        } catch (_) {
          // Ignore location failures
        }
      }

      await _supabase.from('mechanic_availability_status').upsert({
        'mechanic_id': mechanicId,
        'current_status': status,
        'is_accepting_requests': isAcceptingRequests,
        'location_latitude': lat,
        'location_longitude': lng,
        'last_status_update': DateTime.now().toIso8601String(),
      }, onConflict: 'mechanic_id');

      if (isAcceptingRequests && status == 'available') {
        await startListening();
      } else {
        stopListening();
      }

      return true;
    } catch (e) {
      print('❌ Error updating availability status: $e');
      return false;
    }
  }

  /// Get available broadcast requests for this mechanic
  Future<List<Map<String, dynamic>>> getAvailableBroadcastRequests() async {
    try {
      final mechanicId = _supabase.auth.currentUser!.id;
      
      final requests = await _supabase.rpc('get_available_requests_for_mechanic', params: {
        'p_mechanic_id': mechanicId,
      });

      return List<Map<String, dynamic>>.from(requests);
    } catch (e) {
      print('❌ Error getting available broadcast requests: $e');
      return [];
    }
  }

  /// Complete job and return to available status
  Future<bool> completeJobAndReturnToAvailable(String requestId) async {
    try {
      final mechanicId = _supabase.auth.currentUser!.id;

      await _supabase.from('service_requests').update({
        'status': 'completed',
        'completed_at': DateTime.now().toIso8601String(),
        'service_completion_time': DateTime.now().toIso8601String(),
      }).eq('id', requestId);

      await _supabase.from('mechanic_availability_status').update({
        'current_status': 'available',
        'current_request_id': null,
        'is_accepting_requests': true,
        'last_status_update': DateTime.now().toIso8601String(),
      }).eq('mechanic_id', mechanicId);

      await startListening();

      return true;
    } catch (e) {
      print('❌ Error completing job: $e');
      return false;
    }
  }

  /// Send notification to customer
  Future<void> _sendCustomerNotification(String requestId, String type) async {
    try {
      final request = await _supabase
          .from('service_requests')
          .select('customer_id')
          .eq('id', requestId)
          .single();

      String title = '';
      String body = '';

      switch (type) {
        case 'no_mechanics_available':
          title = 'No Mechanics Available';
          body = 'All mechanics are currently busy. Please try again later.';
          break;
        case 'mechanic_assigned':
          title = 'Mechanic Assigned';
          body = 'A mechanic has been assigned to your request and is on the way.';
          break;
      }

      await _supabase.from('notifications').insert({
        'user_id': request['customer_id'],
        'title': title,
        'body': body,
        'type': 'service_request_update',
        'data': {'request_id': requestId, 'notification_type': type},
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('❌ Error sending customer notification: $e');
    }
  }

  /// Dispose resources
  void dispose() {
    stopListening();
    _incomingRequestController.close();
    _requestTimeoutController.close();
  }
}










