import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'location_based_request_service.dart';

class MechanicRequestService {
  static final MechanicRequestService _instance = MechanicRequestService._internal();
  static MechanicRequestService get instance => _instance;
  MechanicRequestService._internal();

  final _supabase = Supabase.instance.client;
  StreamSubscription? _requestSubscription; // legacy stream subscription (kept for cleanup)
  RealtimeChannel? _routingChannel;
  RealtimeChannel? _broadcastChannel; // For monitoring broadcast requests
  RealtimeChannel? _statusChannel; // For monitoring service request status changes
  final _incomingRequestController = StreamController<Map<String, dynamic>>.broadcast();
  final _requestTimeoutController = StreamController<String>.broadcast();
  final _jobAcceptedController = StreamController<Map<String, dynamic>>.broadcast();

  // Streams for UI
  Stream<Map<String, dynamic>> get incomingRequestStream => _incomingRequestController.stream;
  Stream<String> get requestTimeoutStream => _requestTimeoutController.stream;
  Stream<Map<String, dynamic>> get jobAcceptedStream => _jobAcceptedController.stream;

  Timer? _requestTimeoutTimer;
  String? _currentPendingRequestId;
  static const int REQUEST_TIMEOUT_SECONDS = 30;

  // Location-based request monitoring
  Timer? _locationCheckTimer;
  Set<String> _notifiedRequestIds = {}; // Track already notified requests

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
      final shopId = availabilityStatus['shop_id'];

      print('🔧 Starting request listener for mechanic: $mechanicId, shop: $shopId');

      // Listen ONLY for requests targeted to THIS SPECIFIC mechanic
      // No need for separate shop handling - all routing goes to mechanics directly
      // Tear down any existing channel
      _routingChannel?.unsubscribe();
      _broadcastChannel?.unsubscribe();
      _requestSubscription?.cancel();

      // 🎯 CHANNEL 1: Listen for DIRECT routing to this specific mechanic
      _routingChannel = _supabase.channel('public:request_routing')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'request_routing',
          callback: (payload) async {
            try {
              final newRow = payload.newRecord;
              if (newRow['eligible_mechanic_id'] != user.id) return; // manual filter
              if (newRow['is_notified'] == true) return; // skip already shown
              print('📨 Direct routing notification received for mechanic: $mechanicId');
              await _processIncomingRequest(Map<String, dynamic>.from(newRow));
            } catch (e) {
              print('❌ Realtime INSERT handling error: $e');
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'request_routing',
          callback: (payload) async {
            final updated = payload.newRecord;
            if (updated['eligible_mechanic_id'] != user.id) return;
            // Future: handle cancellation or reassignment
          },
        )
        .subscribe();

      // 📡 CHANNEL 2: Listen for BROADCAST requests to ALL mechanics
      print('📡 Setting up broadcast listener for mechanic: $mechanicId');
      _broadcastChannel = _supabase.channel('public:request_broadcasts:$mechanicId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'request_broadcasts',
          callback: (payload) async {
            try {
              final newRow = payload.newRecord;
              
              // Check if this broadcast is for this mechanic
              final mechanicIdFromBroadcast = newRow['mechanic_id'];
              final providerIdFromBroadcast = newRow['provider_id'];
              
              // Skip if not for this mechanic
              if (mechanicIdFromBroadcast != user.id && providerIdFromBroadcast != mechanicId) {
                return;
              }
              
              // Skip if not in pending status
              if (newRow['response_status'] != 'pending') {
                return;
              }
              
              print('📡 Broadcast notification received for mechanic: $mechanicId, request: ${newRow['request_id']}');
              await _processBroadcastRequest(Map<String, dynamic>.from(newRow));
            } catch (e) {
              print('❌ Broadcast handling error: $e');
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'request_broadcasts',
          callback: (payload) async {
            final updated = payload.newRecord;
            final mechanicIdFromBroadcast = updated['mechanic_id'];
            
            if (mechanicIdFromBroadcast != user.id) return;
            
            // Handle status changes (e.g., expired, accepted by another mechanic)
            if (updated['response_status'] == 'expired' || updated['response_status'] == 'accepted') {
              final requestId = updated['request_id'];
              print('🚫 Broadcast request $requestId is no longer available');
              _requestTimeoutController.add(requestId);
            }
          },
        )
        .subscribe();

      print('✅ Broadcast channel subscribed for mechanic: $mechanicId');

      // Start location-based request monitoring
      await _startLocationBasedMonitoring(user.id);

      // Listen for service request status changes to hide popups when someone else accepts
      await _startServiceRequestStatusMonitoring();

      // Proactively pull any pending (race: created before subscribe) routes not yet notified
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
    _broadcastChannel?.unsubscribe();
    _broadcastChannel = null;
    _statusChannel?.unsubscribe();
    _statusChannel = null;
    _locationCheckTimer?.cancel();
    _locationCheckTimer = null;
    _notifiedRequestIds.clear();
    _cancelCurrentRequestTimeout();
    print('🔧 Request listener stopped (routing + broadcast channels)');
  }

  // Legacy _handleIncomingRequest removed (superseded by granular realtime channel)

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
      
      // ✅ DUPLICATE PREVENTION: Skip if already notified
      if (_notifiedRequestIds.contains(requestId)) {
        print('⚠️ Skipping duplicate request notification: $requestId');
        return;
      }
      
      // Mark as notified immediately to prevent race conditions
      _notifiedRequestIds.add(requestId);
      
      // Get full service request details
      final serviceRequest = await _supabase
          .from('service_requests')
          .select('''
            id, title, description, service_type, pickup_latitude, pickup_longitude,
            pickup_address, estimated_price, customer_id, vehicle_id, is_emergency,
            priority, created_at, distance_km, estimated_arrival_minutes, status,
            request_type, shop_id
          ''')
          .eq('id', requestId)
          .maybeSingle();
      
      // Skip if request not found
      if (serviceRequest == null) {
        print('⚠️ Service request not found: $requestId');
        return;
      }
      
      // ✅ SKIP IF REQUEST IS NO LONGER PENDING
      final status = serviceRequest['status']?.toString().toLowerCase();
      if (status == null || !['pending', 'broadcasted'].contains(status)) {
        print('⚠️ Skipping request $requestId - not pending (status: $status)');
        return;
      }

      // ✅ SHOP-BASED FILTERING: Validate shop assignment
      final requestType = serviceRequest['request_type']?.toString() ?? 'direct_mechanic';
      final requestShopId = serviceRequest['shop_id'];
      
      if (requestType == 'shop_based' && requestShopId != null) {
        // Get mechanic's shop assignment
        final mechanicShopId = await _getMechanicShopId();
        
        // Only show request if mechanic belongs to the same shop
        if (mechanicShopId == null || mechanicShopId != requestShopId) {
          print('🚫 Skipping shop-based request $requestId - mechanic not assigned to shop $requestShopId (mechanic shop: $mechanicShopId)');
          return;
        }
        
        print('✅ Shop-based request validated - mechanic belongs to shop $requestShopId');
      }

      // Get customer details
      final customer = await _supabase
          .from('user_profiles')
          .select('id, first_name, last_name, phone_number')
          .eq('id', serviceRequest['customer_id'])
          .maybeSingle();
      
      // Use fallback if customer not found
      if (customer == null) {
        print('⚠️ Customer profile not found: ${serviceRequest['customer_id']}');
        // Still show notification but with placeholder data
      }

      // Get vehicle details if available
      Map<String, dynamic>? vehicle;
      if (serviceRequest['vehicle_id'] != null) {
        vehicle = await _supabase
            .from('vehicles')
            .select('brand_name, model_name, year, color, plate_number')
            .eq('id', serviceRequest['vehicle_id'])
            .maybeSingle();
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
        ) / 1000; // Convert to kilometers
      }

      // Set response deadline but don't mark as notified yet (that happens during acceptance)
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
        'customer_name': customer != null ? '${customer['first_name']} ${customer['last_name']}' : 'Unknown Customer',
        'customer_phone': customer?['phone_number'] ?? 'N/A',
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

  /// Process broadcast request from request_broadcasts table
  Future<void> _processBroadcastRequest(Map<String, dynamic> broadcast) async {
    try {
      final requestId = broadcast['request_id'];
      
      // ✅ DUPLICATE PREVENTION: Skip if already notified
      if (_notifiedRequestIds.contains(requestId)) {
        print('⚠️ Skipping duplicate broadcast notification: $requestId');
        return;
      }
      
      // Mark as notified immediately to prevent race conditions
      _notifiedRequestIds.add(requestId);
      
      print('📡 Processing broadcast request: $requestId');
      
      // Get full service request details
      final serviceRequest = await _supabase
          .from('service_requests')
          .select('''
            id, title, description, service_type, pickup_latitude, pickup_longitude,
            pickup_address, estimated_price, customer_id, vehicle_id, is_emergency,
            priority, created_at, distance_km, estimated_arrival_minutes, status
          ''')
          .eq('id', requestId)
          .maybeSingle();
      
      // Skip if request not found or not available
      if (serviceRequest == null) {
        print('⚠️ Service request not found: $requestId');
        return;
      }
      
      // Skip if request already taken
      if (serviceRequest['status'] != 'pending' && serviceRequest['status'] != 'broadcasted') {
        print('⚠️ Request already taken or cancelled: $requestId (status: ${serviceRequest['status']})');
        return;
      }

      // Get customer details
      final customer = await _supabase
          .from('user_profiles')
          .select('id, first_name, last_name, phone_number')
          .eq('id', serviceRequest['customer_id'])
          .maybeSingle();

      // Get vehicle details if available
      Map<String, dynamic>? vehicle;
      if (serviceRequest['vehicle_id'] != null) {
        vehicle = await _supabase
            .from('vehicles')
            .select('brand_name, model_name, year, color, plate_number')
            .eq('id', serviceRequest['vehicle_id'])
            .maybeSingle();
      }

      // Get distance from broadcast record
      final distanceKm = broadcast['distance_km'] ?? serviceRequest['distance_km'];

      // Update broadcast status to 'viewed'
      await _supabase
          .from('request_broadcasts')
          .update({
            'viewed_at': DateTime.now().toIso8601String(),
            'response_status': 'viewed',
          })
          .eq('id', broadcast['id']);

      // Prepare request data for UI (SAME FORMAT as routing requests)
      final requestData = {
        'broadcast_id': broadcast['id'], // Use broadcast_id instead of routing_id
        'request_id': requestId,
        'service_type': serviceRequest['service_type'],
        'title': serviceRequest['title'],
        'description': serviceRequest['description'],
        'customer_name': customer != null ? '${customer['first_name']} ${customer['last_name']}' : 'Unknown Customer',
        'customer_phone': customer?['phone_number'] ?? 'N/A',
        'pickup_address': serviceRequest['pickup_address'],
        'pickup_latitude': serviceRequest['pickup_latitude'],
        'pickup_longitude': serviceRequest['pickup_longitude'],
        'estimated_price': serviceRequest['estimated_price'],
        'is_emergency': serviceRequest['is_emergency'] ?? false,
        'priority': serviceRequest['priority'] ?? 'normal',
        'distance_km': distanceKm,
        'estimated_arrival_minutes': serviceRequest['estimated_arrival_minutes'],
        'vehicle': vehicle,
        'created_at': serviceRequest['created_at'],
        'timeout_seconds': REQUEST_TIMEOUT_SECONDS,
        'is_broadcast': true, // Flag to indicate this is a broadcast request
      };

      // Set current pending request and start timeout
      _currentPendingRequestId = requestId;
      _startRequestTimeout(requestId);

      // Emit to UI
      _incomingRequestController.add(requestData);

      print('✅ Broadcast request processed and sent to UI: $requestId');
    } catch (e) {
      print('❌ Error processing broadcast request: $e');
    }
  }

  /// Start monitoring for location-based requests
  Future<void> _startLocationBasedMonitoring(String mechanicUserId) async {
    try {
      print('🗺️ Starting location-based request monitoring for mechanic: $mechanicUserId');
      
      // Cancel any existing timer
      _locationCheckTimer?.cancel();
      
      // Start periodic check for nearby requests
      _locationCheckTimer = Timer.periodic(Duration(seconds: 10), (timer) {
        _checkForNearbyRequests(mechanicUserId);
      });
      
      // Do initial check
      await _checkForNearbyRequests(mechanicUserId);
      
      print('✅ Location-based monitoring started');
    } catch (e) {
      print('❌ Error starting location-based monitoring: $e');
    }
  }

  /// Check for nearby location-based requests
  Future<void> _checkForNearbyRequests(String mechanicUserId) async {
    try {
      // Get mechanic's current location
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      // Get nearby requests using the location service
      final nearbyRequests = await LocationBasedRequestService.getRequestsNearMechanic(
        mechanicId: mechanicUserId,
        mechanicLatitude: position.latitude,
        mechanicLongitude: position.longitude,
        maxDistanceKm: 50.0,
      );
      
      if (nearbyRequests.isEmpty) return;
      
      print('🗺️ Found ${nearbyRequests.length} nearby location-based requests');
      
      for (final request in nearbyRequests) {
        final requestId = request['id'];
        
        // Skip if already notified
        if (_notifiedRequestIds.contains(requestId)) continue;
        
        // Mark as notified
        _notifiedRequestIds.add(requestId);
        
        // Process as incoming request with location data
        await _processLocationBasedRequest(request);
      }
    } catch (e) {
      print('❌ Error checking for nearby requests: $e');
    }
  }

  /// Process a location-based request for popup display
  Future<void> _processLocationBasedRequest(Map<String, dynamic> request) async {
    try {
      print('🗺️ Processing location-based request: ${request['id']}');
      
      // Get customer details
      final customer = await _supabase
          .from('user_profiles')
          .select('id, first_name, last_name, phone_number')
          .eq('id', request['customer_id'])
          .single();

      // Get vehicle details if available
      Map<String, dynamic>? vehicle;
      if (request['vehicle_id'] != null) {
        vehicle = await _supabase
            .from('vehicles')
            .select('brand_name, model_name, year, color, plate_number')
            .eq('id', request['vehicle_id'])
            .single();
      }

      // Prepare request data for UI with location-based flag
      final requestData = {
        'routing_id': null, // No routing for location-based requests
        'request_id': request['id'],
        'service_type': request['service_type'],
        'title': request['title'],
        'description': request['description'],
        'customer_name': '${customer['first_name']} ${customer['last_name']}',
        'customer_phone': customer['phone_number'],
        'pickup_address': request['pickup_address'],
        'pickup_latitude': request['pickup_latitude'],
        'pickup_longitude': request['pickup_longitude'],
        'estimated_price': request['estimated_price'],
        'is_emergency': request['is_emergency'] ?? false,
        'priority': request['priority'] ?? 'normal',
        'distance_km': request['distance_km'],
        'estimated_arrival_minutes': request['estimated_arrival_minutes'],
        'vehicle': vehicle,
        'created_at': request['created_at'],
        'timeout_seconds': REQUEST_TIMEOUT_SECONDS,
        'is_location_based': true, // Flag to identify location-based requests
      };

      // Set current pending request and start timeout
      _currentPendingRequestId = request['id'];
      _startRequestTimeout(request['id']);

      // Emit to UI
      _incomingRequestController.add(requestData);

      print('✅ Location-based request processed and sent to UI: ${request['id']}');
    } catch (e) {
      print('❌ Error processing location-based request: $e');
    }
  }

  /// Start monitoring service request status changes to hide popups when someone else accepts
  Future<void> _startServiceRequestStatusMonitoring() async {
    try {
      print('👀 Starting service request status monitoring');
      
      // Cancel any existing status channel
      _statusChannel?.unsubscribe();
      
      // Listen for service request status changes
      _statusChannel = _supabase.channel('public:service_requests_status')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'service_requests',
          callback: (payload) async {
            try {
              final updatedRequest = payload.newRecord;
              final requestId = updatedRequest['id'];
              final newStatus = updatedRequest['status'];
              final assignedMechanicId = updatedRequest['assigned_mechanic_id'];
              
              print('📡 Service request status change: $requestId -> $newStatus');
              
              // If a location-based request was assigned to someone else, hide popup
              if ((newStatus == 'in_progress' || newStatus == 'awaiting_payment') && assignedMechanicId != null) {
                if (_notifiedRequestIds.contains(requestId)) {
                  print('🚫 Request $requestId was accepted by another mechanic, hiding popup');
                  
                  // Remove from notified set
                  _notifiedRequestIds.remove(requestId);
                  
                  // Cancel timeout if this is current pending request
                  if (_currentPendingRequestId == requestId) {
                    _cancelCurrentRequestTimeout();
                    _currentPendingRequestId = null;
                  }
                  
                  // Emit timeout signal to hide popup
                  _requestTimeoutController.add(requestId);
                }
              }
            } catch (e) {
              print('❌ Error handling service request status change: $e');
            }
          },
        )
        .subscribe();
      
      print('✅ Service request status monitoring started');
    } catch (e) {
      print('❌ Error starting service request status monitoring: $e');
    }
  }

  /// Get mechanic's assigned shop ID
  Future<String?> _getMechanicShopId() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return null;
      
      // Check mechanic_availability_status for shop assignment
      final availability = await _supabase
          .from('mechanic_availability_status')
          .select('shop_id')
          .eq('mechanic_id', user.id)
          .maybeSingle();
      
      if (availability != null && availability['shop_id'] != null) {
        return availability['shop_id'].toString();
      }
      
      // Fallback: Check user_profiles
      final profile = await _supabase
          .from('user_profiles')
          .select('shop_id')
          .eq('id', user.id)
          .maybeSingle();
      
      return profile?['shop_id']?.toString();
    } catch (e) {
      print('❌ Error getting mechanic shop ID: $e');
      return null;
    }
  }

  /// Accept a service request using an atomic RPC to enforce FIFO
  Future<bool> acceptRequest(String? routingId, String requestId, {bool isLocationBased = false}) async {
    try {
      print('🔧 Starting acceptance process for routing: $routingId, request: $requestId, location-based: $isLocationBased');
      _cancelCurrentRequestTimeout();
      
      // Clean up notification tracking
      _notifiedRequestIds.remove(requestId);
      _currentPendingRequestId = null;
      
      final mechanicUserId = _supabase.auth.currentUser!.id;
      print('🔧 Mechanic user ID: $mechanicUserId');

      // Handle location-based requests differently
      if (isLocationBased || routingId == null) {
        return await _acceptLocationBasedRequest(requestId, mechanicUserId);
      }

      // Original routing-based acceptance logic
      // First check if the routing entry still exists and is valid
      final routingCheck = await _supabase
          .from('request_routing')
          .select('id, request_id, eligible_mechanic_id, is_notified')
          .eq('id', routingId)
          .maybeSingle();

      if (routingCheck == null) {
        print('❌ Routing entry not found: $routingId');
        return false;
      }

      print('🔧 Routing check result: $routingCheck');

      // Don't check is_notified here since we no longer mark it during popup display
      // The database function will handle the atomic check and update

      if (routingCheck['eligible_mechanic_id'] != mechanicUserId) {
        print('❌ Mechanic not eligible for this routing: $routingId');
        return false;
      }

      // Check if service request still exists and is available
      final requestCheck = await _supabase
          .from('service_requests')
          .select('id, status, assigned_mechanic_id')
          .eq('id', requestId)
          .maybeSingle();

      if (requestCheck == null) {
        print('❌ Service request not found: $requestId');
        return false;
      }

      print('🔧 Service request check result: $requestCheck');

      if (requestCheck['status'] != 'pending') {
        print('❌ Service request no longer pending, status: ${requestCheck['status']}');
        
        // Check if this mechanic was actually assigned (success case)
        if ((requestCheck['status'] == 'in_progress' || 
             requestCheck['status'] == 'awaiting_payment') && 
            requestCheck['assigned_mechanic_id'] == mechanicUserId) {
          print('✅ Request was already successfully accepted by this mechanic (status: ${requestCheck['status']})');
          return true; // This is actually a success case
        }
        
        return false;
      }

      if (requestCheck['assigned_mechanic_id'] != null) {
        print('❌ Service request already assigned to: ${requestCheck['assigned_mechanic_id']}');
        return false;
      }

      print('🔧 Pre-checks passed, calling accept_request_fifo...');

      // Use an RPC that atomically assigns the request if still available
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
          print('🔧 Calling debug function for detailed error...');
          final debugResult = await _supabase.rpc('accept_request_fifo_debug', params: {
            'p_routing_id': routingId,
            'p_mechanic_user_id': mechanicUserId,
          });
          
          print('🔧 Debug result: $debugResult');
          
          // 🎯 NEW: Check if request was successfully accepted but with new payment-first flow
          if (debugResult is Map) {
            final status = debugResult['status']?.toString();
            final message = debugResult['message']?.toString();
            
            // Success cases for payment-before-service flow
            if (status == 'awaiting_payment' || 
                (message != null && message.contains('Request accepted successfully'))) {
              print('✅ Request actually accepted successfully (payment-first flow): $status');
              return true; // This is a success case in the new flow!
            }
            
            if (debugResult['error'] != null) {
              print('❌ Detailed error: ${debugResult['error']} - ${debugResult['message']}');
            }
          }
        } catch (debugError) {
          print('❌ Error running debug function: $debugError');
        }
        
        return false;
      }

      print('🔧 RPC acceptance successful, updating local availability status...');

      // Reflect availability locally (RPC already updates server-side state)
      // Use UPDATE instead of UPSERT to avoid duplicate key errors
      await _supabase.from('mechanic_availability_status').update({
        'current_status': 'in_service',
        'current_request_id': requestId,
        'is_accepting_requests': false,
        'last_status_update': DateTime.now().toIso8601String(),
      }).eq('mechanic_id', mechanicUserId);

      _currentPendingRequestId = null;
      print('✅ Request accepted successfully: $requestId');
      
      // Emit job accepted event for bottom sheet
      await _emitJobAcceptedEvent(requestId);
      
      return true;
    } catch (e) {
      print('❌ Error accepting request: $e');
      print('❌ Stack trace: ${StackTrace.current}');
      return false;
    }
  }

  /// Emit job accepted event with full details for dashboard
  Future<void> _emitJobAcceptedEvent(String requestId) async {
    try {
      // Fetch full job details for bottom sheet
      final jobDetails = await _supabase
          .from('service_requests')
          .select('''
            id, customer_id, title, description, status,
            pickup_latitude, pickup_longitude, pickup_address,
            estimated_price, service_type, created_at
          ''')
          .eq('id', requestId)
          .maybeSingle();
      
      if (jobDetails == null) {
        print('⚠️ Could not fetch job details for accepted request: $requestId');
        return;
      }
      
      // Get customer info
      final customer = await _supabase
          .from('user_profiles')
          .select('first_name, last_name, phone_number, profile_image_url')
          .eq('id', jobDetails['customer_id'])
          .maybeSingle();
      
      if (customer == null) {
        print('⚠️ Could not fetch customer details for request: $requestId');
        return;
      }
      
      // Emit job accepted event with full details
      _jobAcceptedController.add({
        'request_id': requestId,
        'job_details': jobDetails,
        'customer_details': customer,
        'accepted_at': DateTime.now().toIso8601String(),
      });
      
      print('✅ Job accepted event emitted for request: $requestId');
    } catch (e) {
      print('❌ Error emitting job accepted event: $e');
    }
  }

  /// Accept a location-based service request
  Future<bool> _acceptLocationBasedRequest(String requestId, String mechanicUserId) async {
    try {
      print('🗺️ Accepting location-based request: $requestId');

      // Check if service request still exists and is available
      final requestCheck = await _supabase
          .from('service_requests')
          .select('id, status, assigned_mechanic_id')
          .eq('id', requestId)
          .maybeSingle();

      if (requestCheck == null) {
        print('❌ Service request not found: $requestId');
        return false;
      }

      if (requestCheck['status'] != 'pending') {
        print('❌ Service request no longer pending, status: ${requestCheck['status']}');
        return false;
      }

      if (requestCheck['assigned_mechanic_id'] != null) {
        print('❌ Service request already assigned to: ${requestCheck['assigned_mechanic_id']}');
        return false;
      }

      // Assign the request directly
      final updateResult = await _supabase
          .from('service_requests')
          .update({
            'assigned_mechanic_id': mechanicUserId,
            'status': 'awaiting_payment', // Set to awaiting_payment to trigger customer notification
            'accepted_at': DateTime.now().toIso8601String(),
          })
          .eq('id', requestId)
          .eq('status', 'pending') // Ensure it's still pending
          .select('id')
          .maybeSingle();

      if (updateResult == null) {
        print('❌ Failed to assign location-based request (already taken)');
        return false;
      }

      // Update mechanic availability status
      await _supabase.from('mechanic_availability_status').update({
        'current_status': 'in_service',
        'current_request_id': requestId,
        'is_accepting_requests': false,
        'last_status_update': DateTime.now().toIso8601String(),
      }).eq('mechanic_id', mechanicUserId);

      _currentPendingRequestId = null;
      
      // Remove from notified set
      _notifiedRequestIds.remove(requestId);
      
      print('✅ Location-based request accepted successfully: $requestId');
      return true;
    } catch (e) {
      print('❌ Error accepting location-based request: $e');
      return false;
    }
  }

  /// Reject a service request
  Future<bool> rejectRequest(String? routingId, String requestId, {bool isLocationBased = false}) async {
    try {
      _cancelCurrentRequestTimeout();
      
      // Clean up notification tracking for all request types
      _notifiedRequestIds.remove(requestId);
      _currentPendingRequestId = null;

      // Handle location-based requests differently
      if (isLocationBased || routingId == null) {
        print('✅ Location-based request rejected: $requestId');
        return true;
      }

      // Original routing-based rejection logic
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

        // TODO: Send notification to customer
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
          .eq('is_notified', false); // Only timeout requests that haven't been processed

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
        // Create default availability status using upsert to avoid duplicate key errors
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

      // If no coordinates passed and going available, try to read device location
      double? lat = latitude;
      double? lng = longitude;
      if (isAcceptingRequests && status == 'available' && (lat == null || lng == null)) {
        try {
          final pos = await Geolocator.getCurrentPosition();
          lat = pos.latitude;
          lng = pos.longitude;
        } catch (_) {
          // Ignore location failures; server will fallback
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

      // Start/stop listening based on status
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

  /// Complete job and return to available status
  Future<bool> completeJobAndReturnToAvailable(String requestId) async {
    try {
      final mechanicId = _supabase.auth.currentUser!.id;

      // Update request status to completed
      await _supabase.from('service_requests').update({
        'status': 'completed',
        'completed_at': DateTime.now().toIso8601String(),
        'service_completion_time': DateTime.now().toIso8601String(),
      }).eq('id', requestId);

      // Return mechanic to available status
      await _supabase.from('mechanic_availability_status').update({
        'current_status': 'available',
        'current_request_id': null,
        'is_accepting_requests': true,
        'last_status_update': DateTime.now().toIso8601String(),
      }).eq('mechanic_id', mechanicId);

      // Restart listening for new requests
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
      // Get customer ID from request
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

  /// Check for overdue jobs (more than 24 hours)
  Future<List<Map<String, dynamic>>> checkOverdueJobs() async {
    try {
      final mechanicId = _supabase.auth.currentUser!.id;
      final twentyFourHoursAgo = DateTime.now().subtract(Duration(hours: 24));

      final overdueJobs = await _supabase
          .from('service_requests')
          .select('*')
          .eq('assigned_mechanic_id', mechanicId)
          .inFilter('status', ['accepted', 'in_progress'])
          .lt('accepted_at', twentyFourHoursAgo.toIso8601String());

      return overdueJobs;
    } catch (e) {
      print('❌ Error checking overdue jobs: $e');
      return [];
    }
  }

  /// Dispose resources
  void dispose() {
    stopListening();
    _incomingRequestController.close();
    _requestTimeoutController.close();
  }
}
