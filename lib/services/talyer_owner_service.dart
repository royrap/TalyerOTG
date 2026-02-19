import 'package:supabase_flutter/supabase_flutter.dart';
import 'talyer_connection_service.dart';
import 'email_service.dart';
import 'qr_code_service.dart';

class TalyerOwnerService {
  static final TalyerOwnerService _instance = TalyerOwnerService._internal();
  static TalyerOwnerService get instance => _instance;
  TalyerOwnerService._internal();

  final _supabase = Supabase.instance.client;
  
  // Cache shop info
  String? _cachedShopId;
  Map<String, dynamic>? _cachedShopInfo;
  String? _lastUserId; // Track user changes to auto-clear cache
  
  // In-memory fallback for shop hours
  Map<String, Map<String, dynamic>>? _cachedShopHours;

  // Expose supabase client for diagnostics
  SupabaseClient get supabase => _supabase;
  
  // Expose current user for diagnostics
  User? get currentUser => _supabase.auth.currentUser;

  // Clear cache when user changes
  void clearCache() {
    print('🧹 Clearing TalyerOwnerService cache...');
    _cachedShopId = null;
    _cachedShopInfo = null;
    _cachedShopHours = null;
    print('✅ Cache cleared successfully');
  }

  // Force refresh shop data (for troubleshooting)
  Future<Map<String, dynamic>> debugRefreshShopData() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        return {'error': 'No authenticated user'};
      }
      
      print('🔧 DEBUG: Force refreshing shop data for user: ${user.id}');
      
      // Clear all cache
      clearCache();
      
      // Get fresh shop data
      final freshShopId = await getCurrentShopId(forceRefresh: true);
      final freshShopInfo = await getShopInfo();
      
      final result = {
        'user_id': user.id,
        'user_email': user.email,
        'fresh_shop_id': freshShopId,
        'fresh_shop_info': freshShopInfo,
        'cache_cleared': true,
        'timestamp': DateTime.now().toIso8601String(),
      };
      
      print('🔍 DEBUG RESULT: $result');
      return result;
    } catch (e) {
      print('❌ Debug refresh error: $e');
      return {'error': e.toString()};
    }
  }

  // Get current user profile for diagnostics
  Future<Map<String, dynamic>?> getCurrentUserProfile() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return null;

      final profile = await _supabase
          .from('user_profiles')
          .select('*')
          .eq('id', user.id)
          .maybeSingle();

      return profile;
    } catch (e) {
      print('❌ Error getting current user profile: $e');
      return null;
    }
  }

  // Get current user's shop ID
  Future<String?> getCurrentShopId({bool forceRefresh = false}) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return null;

      // Auto-clear cache if user changed
      if (_lastUserId != user.id) {
        print('🔄 User changed detected, clearing cache: $_lastUserId → ${user.id}');
        clearCache();
        _lastUserId = user.id;
      }

      // Return cached value if available and not forcing refresh
      if (_cachedShopId != null && !forceRefresh) {
        print('🔄 Using cached shop ID: $_cachedShopId');
        return _cachedShopId;
      }

      print('🔍 Fetching fresh shop ID for user: ${user.id}');
      
      // Get shop ID for talyer owner
      final shopQuery = await _supabase
          .from('shops')
          .select('id, shop_name, owner_id')
          .eq('owner_id', user.id)
          .eq('is_active', true)
          .maybeSingle();

      if (shopQuery != null) {
        _cachedShopId = shopQuery['id'];
        print('✅ Fresh shop ID retrieved: ${_cachedShopId} (${shopQuery['shop_name']})');
        print('🔐 Owner verification: ${shopQuery['owner_id']} == ${user.id}');
      } else {
        print('❌ No active shop found for user: ${user.id}');
        _cachedShopId = null;
      }
      
      return _cachedShopId;
    } catch (e) {
      print('Error getting shop ID: $e');
      return null;
    }
  }

  // Get shop information
  Future<Map<String, dynamic>?> getShopInfo() async {
    try {
      if (_cachedShopInfo != null) {
        return _cachedShopInfo;
      }

      final shopId = await getCurrentShopId();
      if (shopId == null) return null;

      final shopData = await _supabase
          .from('shops')
          .select('*')
          .eq('id', shopId)
          .single();

      _cachedShopInfo = shopData;
      return _cachedShopInfo;
    } catch (e) {
      print('Error getting shop info: $e');
      return null;
    }
  }

  // Create or update shop
  Future<bool> createOrUpdateShop({
    required String shopName,
    String? shopAddress,
    Map<String, dynamic>? operatingHours,
    double? serviceRadius,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('No authenticated user');

      final shopData = {
        'owner_id': user.id,
        'shop_name': shopName,
        'shop_address': shopAddress,
        'operating_hours': operatingHours,
        'service_radius': serviceRadius ?? 50.0,
        'latitude': latitude,
        'longitude': longitude,
        'is_active': true,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      // Check if shop exists
      final existingShop = await _supabase
          .from('shops')
          .select('id')
          .eq('owner_id', user.id)
          .maybeSingle();

      if (existingShop != null) {
        // Update existing shop
        await _supabase
            .from('shops')
            .update(shopData)
            .eq('id', existingShop['id']);
        
        _cachedShopId = existingShop['id'];
      } else {
        // Create new shop
        final newShop = await _supabase
            .from('shops')
            .insert(shopData)
            .select('id')
            .single();
        
        _cachedShopId = newShop['id'];
      }

      // Clear cached info to force refresh
      _cachedShopInfo = null;
      return true;
    } catch (e) {
      print('Error creating/updating shop: $e');
      return false;
    }
  }

  // Update talyer owner location
  Future<void> updateTalyerOwnerLocation(double latitude, double longitude, {String? address}) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('No authenticated user');

      print('🏪 Updating talyer owner location: $latitude, $longitude');

      // Update user profile location 
      try {
        await _supabase
            .from('user_profiles')
            .update({
              'current_latitude': latitude,
              'current_longitude': longitude,
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            })
            .eq('id', user.id);
      } catch (e) {
        print('Warning: Could not update user_profiles location: $e');
      }

      // Update service provider location (main location storage)
      await _supabase
          .from('service_providers')
          .update({
            'current_latitude': latitude,
            'current_longitude': longitude,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('user_id', user.id);

      print('✅ Talyer owner location updated successfully');
    } catch (e) {
      print('❌ Error updating talyer owner location: $e');
      throw Exception('Failed to update location: $e');
    }
  }

  // Get talyer owner location
  Future<Map<String, dynamic>?> getTalyerOwnerLocation() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('No authenticated user');

      // Get location from service_providers table (primary source)
      final providerList = await _supabase
          .from('service_providers')
          .select('current_latitude, current_longitude, company_name')
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .limit(1);

      final provider = providerList.isNotEmpty ? providerList.first : null;

      if (provider != null && provider['current_latitude'] != null && provider['current_longitude'] != null) {
        // Try to get address from coordinates using reverse geocoding
        String? address;
        try {
          // You can implement reverse geocoding here if needed
          // For now, use company name or a generic address
          address = provider['company_name'] ?? 'Shop Location';
        } catch (e) {
          address = 'Shop Location';
        }

        return {
          'latitude': provider['current_latitude'],
          'longitude': provider['current_longitude'],
          'address': address,
        };
      }
      return null;
    } catch (e) {
      print('Error getting talyer owner location: $e');
      return null;
    }
  }

  // Get incoming service requests for the talyer owner's shop with proper targeting
  Future<List<Map<String, dynamic>>> getIncomingServiceRequests() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('No authenticated user');

      print('🔍 Loading service requests for talyer owner: ${user.id}');

      // Get the shop owned by this user
      final shopResponse = await _supabase
          .from('shops')
          .select('id, shop_name')
          .eq('owner_id', user.id)
          .maybeSingle();

      if (shopResponse == null) {
        print('⚠️ No shop found for talyer owner: ${user.id}');
        return [];
      }

      final shopId = shopResponse['id'];
      final shopName = shopResponse['shop_name'];
      print('🏪 Shop found: $shopName ($shopId)');

      // Get user's location for nearby requests
      final userProfile = await _supabase
          .from('user_profiles')
          .select('current_latitude, current_longitude')
          .eq('id', user.id)
          .maybeSingle();

      final hasLocation = userProfile != null && 
          userProfile['current_latitude'] != null && 
          userProfile['current_longitude'] != null;

      print('📍 Location available: $hasLocation');

      // Build query for targeted requests
      var query = _supabase
          .from('service_requests')
          .select('''
            *,
            customer:user_profiles!service_requests_customer_id_fkey(
              first_name,
              last_name,
              phone_number,
              email
            ),
            category:service_categories(
              name,
              description
            )
          ''')
          .inFilter('status', ['pending', 'awaiting_payment', 'ready_to_assign', 'in_progress']);

      // Apply targeting logic
      if (hasLocation) {
        // Get requests specifically for this shop OR nearby requests without shop targeting
        query = query.or('shop_id.eq.$shopId,and(shop_id.is.null,pickup_latitude.not.is.null,pickup_longitude.not.is.null)');
        print('🎯 Query: Specific shop requests OR nearby untargeted requests');
      } else {
        // Only get requests specifically for this shop
        query = query.eq('shop_id', shopId);
        print('🎯 Query: Only specific shop requests (no location for nearby)');
      }

      final response = await query.order('created_at', ascending: false);

      // Filter nearby requests by distance if location is available
      List<Map<String, dynamic>> filteredRequests = [];
      
      for (final request in response) {
        final requestShopId = request['shop_id'];
        
        if (requestShopId == shopId) {
          // Request specifically for this shop - always include
          request['request_source'] = 'specific_shop';
          request['distance_km'] = 0.0; // At shop
          filteredRequests.add(request);
          print('✅ Added specific shop request: ${request['id']}');
        } else if (requestShopId == null && hasLocation) {
          // Nearby request - check distance
          final pickupLat = request['pickup_latitude'];
          final pickupLng = request['pickup_longitude'];
          
          if (pickupLat != null && pickupLng != null) {
            // Calculate distance using Supabase PostGIS functions
            try {
              final distanceResponse = await _supabase.rpc('calculate_distance', params: {
                'lat1': userProfile['current_latitude'],
                'lng1': userProfile['current_longitude'],
                'lat2': pickupLat,
                'lng2': pickupLng,
              });
              
              final distanceKm = distanceResponse as double;
              
              if (distanceKm <= 15.0) { // 15km radius
                request['request_source'] = 'nearby_shops';
                request['distance_km'] = distanceKm;
                filteredRequests.add(request);
                print('✅ Added nearby request: ${request['id']} (${distanceKm.toStringAsFixed(1)}km)');
              } else {
                print('❌ Request too far: ${request['id']} (${distanceKm.toStringAsFixed(1)}km)');
              }
            } catch (e) {
              print('⚠️ Distance calculation failed, including request anyway: $e');
              request['request_source'] = 'nearby_shops';
              request['distance_km'] = null;
              filteredRequests.add(request);
            }
          }
        } else {
          print('❌ Excluded request: ${request['id']} (for other shop or no location)');
        }
      }

      // Sort by priority: specific shop first, then by urgency and time
      filteredRequests.sort((a, b) {
        // Specific shop requests first
        if (a['request_source'] == 'specific_shop' && b['request_source'] != 'specific_shop') {
          return -1;
        }
        if (b['request_source'] == 'specific_shop' && a['request_source'] != 'specific_shop') {
          return 1;
        }
        
        // Then by emergency status
        final aEmergency = a['is_emergency'] ?? false;
        final bEmergency = b['is_emergency'] ?? false;
        if (aEmergency != bEmergency) {
          return bEmergency ? 1 : -1;
        }
        
        // Then by creation time (newest first)
        final aTime = DateTime.parse(a['created_at']);
        final bTime = DateTime.parse(b['created_at']);
        return bTime.compareTo(aTime);
      });

      print('✅ Filtered requests: ${filteredRequests.length} total');
      print('   - Specific shop: ${filteredRequests.where((r) => r['request_source'] == 'specific_shop').length}');
      print('   - Nearby: ${filteredRequests.where((r) => r['request_source'] == 'nearby_shops').length}');

      return filteredRequests;
    } catch (e) {
      print('❌ Error fetching incoming service requests: $e');
      throw Exception('Failed to fetch service requests: $e');
    }
  }

  // Accept a service request
  Future<void> acceptServiceRequest(String requestId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('No authenticated user');

      print('🎯 Accepting service request: $requestId');

      // Get current request status and payment details
      final currentRequest = await _supabase
          .from('service_requests')
          .select('status, payment_status, customer_id, payment_method, final_price')
          .eq('id', requestId)
          .single();

      String newStatus;
      Map<String, dynamic> updateData = {
        'accepted_at': DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        'accepted_by': user.id,
      };
      
      print('📋 Current request state:');
      print('   Status: ${currentRequest['status']}');
      print('   Payment Status: ${currentRequest['payment_status']}');
      print('   Payment Method: ${currentRequest['payment_method']}');
      print('   Final Price: ${currentRequest['final_price']}');

      // Determine the correct status based on current state
      if (currentRequest['status'] == 'pending') {
        // First time acceptance - move to waiting payment
        newStatus = 'awaiting_payment';
        print('✅ Status transition: pending -> awaiting_payment');
      } else if (currentRequest['status'] == 'awaiting_payment') {
        // Check PayMongo payment status for this request
        await _checkAndUpdatePaymentStatus(requestId);
        
        // Re-fetch request to get updated payment status
        final updatedRequest = await _supabase
            .from('service_requests')
            .select('payment_status')
            .eq('id', requestId)
            .single();
            
        if (updatedRequest['payment_status'] == 'completed') {
          // Payment completed - move to ready to assign
          newStatus = 'ready_to_assign';
          print('✅ Status transition: awaiting_payment -> ready_to_assign (payment completed)');
        } else {
          // Payment still pending, stay in awaiting_payment
          newStatus = 'awaiting_payment';
          print('ℹ️ Payment still pending, staying in awaiting_payment status');
        }
      } else if (currentRequest['status'] == 'ready_to_assign') {
        // Already ready to assign - no change needed
        print('⚠️ Request $requestId is already ready to assign');
        return;
      } else {
        // Invalid state - throw error
        throw Exception('Cannot accept request in status: ${currentRequest['status']}');
      }

      updateData['status'] = newStatus;

      await _supabase
          .from('service_requests')
          .update(updateData)
          .eq('id', requestId);

      // Create notification for customer
      String notificationMessage;
      String notificationType;
      if (newStatus == 'awaiting_payment') {
        notificationMessage = 'Your service request has been accepted. Please proceed with payment to continue.';
        notificationType = 'request_accepted';
      } else if (newStatus == 'ready_to_assign') {
        notificationMessage = 'Payment completed successfully. A mechanic will be assigned shortly.';
        notificationType = 'payment_completed';
        
        // Generate QR code for service verification
        await QRCodeService.instance.generateServiceQRCode(requestId, currentRequest['customer_id']);
      } else {
        notificationMessage = 'Your service request status has been updated.';
        notificationType = 'status_update';
      }

      await _createNotification(
        requestId: requestId,
        type: notificationType,
        title: 'Service Request Update',
        message: notificationMessage,
      );

      // Add to audit trail
      await _addAuditTrail(
        tableName: 'service_requests',
        recordId: requestId,
        action: 'UPDATE',
        newData: {
          'status': newStatus,
          'accepted_by': user.id,
          'payment_status_checked': DateTime.now().toUtc().toIso8601String(),
        },
      );
      
      print('✅ Service request accepted and status updated to: $newStatus');
    } catch (e) {
      print('❌ Error accepting service request: $e');
      throw Exception('Failed to accept service request: $e');
    }
  }

  // Reject a service request
  Future<void> rejectServiceRequest(String requestId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('No authenticated user');

      await _supabase
          .from('service_requests')
          .update({
            'status': 'cancelled',
            'cancelled_at': DateTime.now().toUtc().toIso8601String(),
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', requestId);

      // Create notification for customer
      await _createNotification(
        requestId: requestId,
        type: 'request_rejected',
        title: 'Service Request Declined',
        message: 'Your service request has been declined. Please try another service provider.',
      );

      // Add to audit trail
      await _addAuditTrail(
        tableName: 'service_requests',
        recordId: requestId,
        action: 'UPDATE',
        newData: {'status': 'cancelled'},
      );
    } catch (e) {
      print('Error rejecting service request: $e');
      throw Exception('Failed to reject service request: $e');
    }
  }

  // Get available mechanics for assignment
  Future<List<Map<String, dynamic>>> getAvailableMechanics() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('No authenticated user');

      print('🔧 Getting available mechanics for talyer owner: $user.id');

      // Get mechanics with service provider data - filter on service_providers table
      final response = await _supabase
          .from('user_profiles')
          .select('''
            *,
            service_providers!user_id (
              id,
              company_name,
              status,
              is_available,
              rating,
              total_reviews,
              talyer_owner_id,
              created_at,
              updated_at
            )
          ''')
          .eq('user_type', 'mechanic')
          .eq('status', 'active');

      print('🔧 Raw response: ${response.length} user profiles found');

      // Process the response to flatten the data and filter available mechanics
      final List<Map<String, dynamic>> mechanics = [];
      
      for (final mechanic in response) {
        final serviceProviders = mechanic['service_providers'] as List?;
        
        if (serviceProviders != null && serviceProviders.isNotEmpty) {
          final serviceProvider = serviceProviders[0]; // Take the first service provider
          
          // Only include mechanics that belong to this talyer owner and are available
          if (serviceProvider['talyer_owner_id'] == user.id && 
              serviceProvider['is_available'] == true) {
            
            // Check if mechanic is currently assigned to any active job
            final activeJobsResponse = await _supabase
                .from('service_requests')
                .select('id')
                .eq('provider_id', serviceProvider['id'])
                .inFilter('status', ['awaiting_payment', 'in_progress', 'ready_to_assign']);
            
            final hasActiveJob = activeJobsResponse.isNotEmpty;
            
            // Create enriched mechanic data with online status
            final enrichedMechanic = Map<String, dynamic>.from(mechanic);
            enrichedMechanic.remove('service_providers'); // Remove nested data
            
            // Add service provider info and availability
            enrichedMechanic['service_provider_id'] = serviceProvider['id'];
            enrichedMechanic['is_online'] = serviceProvider['status'] == 'online';
            enrichedMechanic['is_available'] = serviceProvider['is_available'] && !hasActiveJob;
            enrichedMechanic['has_active_job'] = hasActiveJob;
            enrichedMechanic['availability_status'] = hasActiveJob ? 'busy' : (serviceProvider['is_available'] ? 'available' : 'unavailable');
            enrichedMechanic['rating'] = serviceProvider['rating'];
            enrichedMechanic['total_reviews'] = serviceProvider['total_reviews'];
            enrichedMechanic['company_name'] = serviceProvider['company_name'];
            enrichedMechanic['completed_jobs'] = serviceProvider['total_reviews'] ?? 0; // Use reviews as proxy for jobs
            
            mechanics.add(enrichedMechanic);
          }
        }
      }

      print('🔧 Loaded ${mechanics.length} available mechanics');
      return mechanics;
    } catch (e) {
      print('Error fetching available mechanics: $e');
      
      // Fallback to simple query if join fails
      try {
        final response = await _supabase
            .from('user_profiles')
            .select('*')
            .eq('user_type', 'mechanic')
            .eq('status', 'active');

        // Add default values for missing fields
        final List<Map<String, dynamic>> mechanics = [];
        for (final mechanic in response) {
          final enrichedMechanic = Map<String, dynamic>.from(mechanic);
          enrichedMechanic['is_online'] = false; // Default to offline in fallback
          enrichedMechanic['availability_status'] = 'unknown';
          enrichedMechanic['rating'] = 0.0;
          enrichedMechanic['total_reviews'] = 0;
          enrichedMechanic['completed_jobs'] = 0;
          mechanics.add(enrichedMechanic);
        }
        
        return mechanics;
      } catch (fallbackError) {
        print('Fallback query also failed: $fallbackError');
        throw Exception('Failed to fetch available mechanics: $e');
      }
    }
  }

  // Get only mechanics that are truly available for assignment (not busy with active jobs)
  Future<List<Map<String, dynamic>>> getAvailableMechanicsForAssignment() async {
    try {
      final allMechanics = await getAvailableMechanics();
      
      // Filter to only include mechanics that are available and not busy
      final availableForAssignment = allMechanics.where((mechanic) {
        return mechanic['is_available'] == true && 
               mechanic['has_active_job'] != true &&
               mechanic['availability_status'] != 'busy';
      }).toList();
      
      print('🔧 Found ${availableForAssignment.length} mechanics available for assignment');
      return availableForAssignment;
    } catch (e) {
      print('Error getting mechanics available for assignment: $e');
      throw Exception('Failed to get available mechanics: $e');
    }
  }

  // Debug method to check database state
  Future<Map<String, dynamic>> debugMechanicDatabase() async {
    try {
      print('🔍 DEBUG: Checking mechanic database state...');
      
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('No authenticated user');
      
      // Check user_profiles for mechanics
      final userProfiles = await _supabase
          .from('user_profiles')
          .select('*')
          .eq('user_type', 'mechanic')
          .eq('status', 'active');
      
      // Check total service_providers
      final serviceProviders = await _supabase
          .from('service_providers')
          .select('*');
      
      // Check service_providers with talyer_owner_id for this specific owner
      final ownedProviders = await _supabase
          .from('service_providers')
          .select('*')
          .eq('talyer_owner_id', user.id);
      
      // Check joined data (mechanics that belong to this shop)
      final shopMechanics = await _supabase
          .from('service_providers')
          .select('''
            id,
            user_id,
            talyer_owner_id,
            user_profiles!service_providers_user_id_fkey (
              id,
              first_name,
              last_name,
              user_type,
              status
            )
          ''')
          .eq('talyer_owner_id', user.id)
          .eq('user_profiles.user_type', 'mechanic')
          .eq('user_profiles.status', 'active');
      
      print('🔍 DEBUG RESULTS:');
      print('   Total mechanics in system: ${userProfiles.length}');
      print('   Total service providers: ${serviceProviders.length}');
      print('   Service providers owned by current user: ${ownedProviders.length}');
      print('   Active mechanics in current shop: ${shopMechanics.length}');
      
      return {
        'user_profiles_mechanics': userProfiles.length,
        'total_service_providers': serviceProviders.length,
        'owned_service_providers': ownedProviders.length,
        'shop_mechanics': shopMechanics.length,
        'current_user_id': user.id,
      };
    } catch (e) {
      print('❌ Debug error: $e');
      return {'error': e.toString()};
    }
  }

  // Get real-time online status for mechanics
  Future<List<Map<String, dynamic>>> getMechanicsOnlineStatus() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('No authenticated user');

      final response = await _supabase
          .from('service_providers')
          .select('''
            user_id,
            status,
            is_available,
            updated_at,
            user_profiles!user_id (
              id,
              first_name,
              last_name,
              email,
              phone_number
            )
          ''')
          .eq('user_profiles.user_type', 'mechanic')
          .eq('user_profiles.status', 'active');

      final List<Map<String, dynamic>> mechanicsStatus = [];
      
      for (final provider in response) {
        final userProfile = provider['user_profiles'];
        if (userProfile != null) {
          mechanicsStatus.add({
            'user_id': provider['user_id'],
            'is_online': provider['status'] == 'online',
            'availability_status': provider['is_available'] ? 'available' : 'unavailable',
            'last_updated': provider['updated_at'],
            'first_name': userProfile['first_name'],
            'last_name': userProfile['last_name'],
            'email': userProfile['email'],
            'phone_number': userProfile['phone_number'],
          });
        }
      }

      return mechanicsStatus;
    } catch (e) {
      print('Error fetching mechanic online status: $e');
      throw Exception('Failed to fetch mechanic online status: $e');
    }
  }

  // Assign mechanic to service request
  Future<void> assignMechanicToRequest(String requestId, String mechanicId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('No authenticated user');

      print('🔧 Starting assignment process for request: $requestId, mechanic: $mechanicId');

      // SECURITY: Verify that the mechanic belongs to this talyer owner's shop
      print('🔒 Verifying mechanic ownership for assignment...');
      final mechanicServiceProvider = await _supabase
          .from('service_providers')
          .select('id, user_id, talyer_owner_id, company_name, is_available, status')
          .eq('user_id', mechanicId)
          .eq('talyer_owner_id', user.id) // Must belong to this talyer owner
          .maybeSingle();

      if (mechanicServiceProvider == null) {
        print('❌ Security violation: Attempting to assign mechanic not owned by this talyer owner');
        throw Exception('You can only assign mechanics that belong to your shop');
      }

      // Check if mechanic is available in service_providers table
      if (mechanicServiceProvider['is_available'] != true) {
        print('❌ Mechanic is not available for assignment (service_providers)');
        throw Exception('Mechanic is not currently available');
      }

      // Check current mechanic status - prevent assignment if already in service
      final currentStatus = mechanicServiceProvider['status'];
      if (currentStatus == 'in_service') {
        print('❌ Mechanic is currently in service');
        throw Exception('Mechanic is currently in service and cannot be assigned to another job');
      }

      // Double-check availability in shop_mechanics table
      final shopMechanicAvailability = await _supabase
          .from('shop_mechanics')
          .select('is_available')
          .eq('mechanic_id', mechanicId)
          .maybeSingle();

      if (shopMechanicAvailability != null && !shopMechanicAvailability['is_available']) {
        print('❌ Mechanic is marked as unavailable in shop_mechanics table');
        throw Exception('Mechanic is currently unavailable for assignment');
      }

      // Check if mechanic already has an active job
      final activeJobs = await _supabase
          .from('service_requests')
          .select('id')
          .eq('provider_id', mechanicServiceProvider['id'])
          .inFilter('status', ['awaiting_payment', 'in_progress', 'ready_to_assign']);

      if (activeJobs.isNotEmpty) {
        print('❌ Mechanic already has ${activeJobs.length} active job(s)');
        throw Exception('Mechanic is already assigned to another service request and currently in service');
      }

      print('✅ Mechanic ownership verified: ${mechanicServiceProvider['company_name']}');

      // Get service provider ID for the assignment
      final serviceProviderId = mechanicServiceProvider['id'];

      // Update service request with assignment (set to in_progress = in service)
      await _supabase
          .from('service_requests')
          .update({
            'provider_id': serviceProviderId, // Use provider_id instead of mechanic_id
            'status': 'in_progress',
            'assigned_at': DateTime.now().toUtc().toIso8601String(),
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', requestId);

      print('✅ Service request updated with assignment');

      // Update mechanic availability status to in_service (since they now have an active job)
      await _supabase
          .from('service_providers')
          .update({
            'status': 'in_service', // Change status to indicate they're actively working on a job
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', serviceProviderId);

      print('✅ Mechanic status updated to in_service');

      // Update shop_mechanics table to mark as unavailable
      await _supabase
          .from('shop_mechanics')
          .update({
            'is_available': false,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('mechanic_id', mechanicId);

      print('✅ Shop mechanic availability updated to false');

      // Create notifications for customer and mechanic
      await _createNotification(
        requestId: requestId,
        type: 'mechanic_assigned',
        title: 'Mechanic Assigned',
        message: 'A mechanic has been assigned to your service request.',
      );

      // Notification disabled to prevent spam
      /*
      await _createMechanicNotification(
        mechanicId: mechanicId,
        requestId: requestId,
        type: 'job_assigned',
        title: 'New Job Assignment',
        message: 'You have been assigned a new service job.',
      );
      */

      // Add to audit trail
      await _addAuditTrail(
        tableName: 'service_requests',
        recordId: requestId,
        action: 'UPDATE',
        newData: {
          'mechanic_id': mechanicId,
          'status': 'in_progress',
        },
      );
    } catch (e) {
      print('Error assigning mechanic: $e');
      throw Exception('Failed to assign mechanic: $e');
    }
  }

  // Update mechanic status when job is completed or cancelled
  Future<void> updateMechanicStatusOnJobCompletion(String serviceProviderId, String jobStatus) async {
    try {
      if (jobStatus == 'completed' || jobStatus == 'cancelled') {
        // Check if mechanic has any other active jobs
        final otherActiveJobs = await _supabase
            .from('service_requests')
            .select('id')
            .eq('provider_id', serviceProviderId)
            .inFilter('status', ['awaiting_payment', 'in_progress', 'ready_to_assign']);

        // If no other active jobs, set to online/available
        if (otherActiveJobs.isEmpty) {
          // Get the mechanic's user_id from service_providers
          final serviceProvider = await _supabase
              .from('service_providers')
              .select('user_id')
              .eq('id', serviceProviderId)
              .single();

          final mechanicUserId = serviceProvider['user_id'];

          // Update service_providers status to online
          await _supabase
              .from('service_providers')
              .update({
                'status': 'online',
                'updated_at': DateTime.now().toUtc().toIso8601String(),
              })
              .eq('id', serviceProviderId);

          // Update shop_mechanics availability to true
          await _supabase
              .from('shop_mechanics')
              .update({
                'is_available': true,
                'updated_at': DateTime.now().toUtc().toIso8601String(),
              })
              .eq('mechanic_id', mechanicUserId);
          
          print('✅ Mechanic status updated to online and available for new assignments');
        } else {
          print('🔧 Mechanic still has ${otherActiveJobs.length} other active job(s)');
        }
      }
    } catch (e) {
      print('❌ Error updating mechanic status on job completion: $e');
    }
  }

  // Get service request details
  Future<Map<String, dynamic>?> getServiceRequestDetails(String requestId) async {
    try {
      final response = await _supabase
          .from('service_requests')
          .select('''
            *,
            customer:user_profiles!service_requests_customer_id_fkey(
              first_name,
              last_name,
              phone_number,
              email
            ),
            mechanic:user_profiles!service_requests_mechanic_id_fkey(
              first_name,
              last_name,
              phone_number,
              email
            ),
            category:service_categories(
              name,
              description,
              base_price
            ),
            vehicle:vehicles(
              brand_name,
              model_name,
              year,
              color,
              plate_number
            )
          ''')
          .eq('id', requestId)
          .single();

      return response;
    } catch (e) {
      print('Error fetching service request details: $e');
      throw Exception('Failed to fetch service request details: $e');
    }
  }

  // Get talyer owner statistics
  Future<Map<String, dynamic>> getTalyerOwnerStats() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('No authenticated user');

      // Get pending requests count
      final pendingResponse = await _supabase
          .from('service_requests')
          .select('id')
          .eq('status', 'pending');

      // Get active requests count
      final activeResponse = await _supabase
          .from('service_requests')
          .select('id')
          .inFilter('status', ['awaiting_payment', 'in_progress', 'ready_to_assign']);

      // Get completed requests today
      final today = DateTime.now().toUtc();
      final todayStart = DateTime(today.year, today.month, today.day);
      final completedTodayResponse = await _supabase
          .from('service_requests')
          .select('id')
          .eq('status', 'completed')
          .gte('completed_at', todayStart.toIso8601String());

      // Get available mechanics count
      final mechanicsResponse = await _supabase
          .from('user_profiles')
          .select('id')
          .eq('user_type', 'mechanic')
          .eq('is_available', true);

      return {
        'pending_requests': pendingResponse.length,
        'active_requests': activeResponse.length,
        'completed_today': completedTodayResponse.length,
        'available_mechanics': mechanicsResponse.length,
      };
    } catch (e) {
      print('Error fetching talyer owner stats: $e');
      return {
        'pending_requests': 0,
        'active_requests': 0,
        'completed_today': 0,
        'available_mechanics': 0,
      };
    }
  }

  // Create notification for customer
  Future<void> _createNotification({
    required String requestId,
    required String type,
    required String title,
    required String message,
  }) async {
    try {
      // Get customer ID from request
      final request = await _supabase
          .from('service_requests')
          .select('customer_id')
          .eq('id', requestId)
          .single();

      if (request['customer_id'] != null) {
        await _supabase.from('notifications').insert({
          'user_id': request['customer_id'],
          'title': title,
          'body': message,
          'type': type,
          'data': {'request_id': requestId},
          'created_at': DateTime.now().toUtc().toIso8601String(),
        });
      }
    } catch (e) {
      print('Error creating notification: $e');
    }
  }

  // Create notification for mechanic
  Future<void> _createMechanicNotification({
    required String mechanicId,
    required String requestId,
    required String type,
    required String title,
    required String message,
  }) async {
    // Notifications disabled to prevent spam
    return;
    /*
    try {
      await _supabase.from('notifications').insert({
        'user_id': mechanicId,
        'title': title,
        'body': message,
        'type': type,
        'data': {'request_id': requestId},
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      print('Error creating mechanic notification: $e');
    }
    */
  }

  // Add audit trail entry
  Future<void> _addAuditTrail({
    required String tableName,
    required String recordId,
    required String action,
    Map<String, dynamic>? oldData,
    Map<String, dynamic>? newData,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      await _supabase.from('audit_trail').insert({
        'table_name': tableName,
        'record_id': recordId,
        'action': action,
        'changed_by': user.id,
        'old_data': oldData,
        'new_data': newData,
        'changed_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      // If the table doesn't exist or has issues, log it but don't fail the operation
      if (e.toString().contains('404') || e.toString().contains('relation') || e.toString().contains('does not exist')) {
        print('⚠️ Audit trail table not available: $e');
      } else {
        print('Error adding audit trail: $e');
      }
    }
  }

  // Get mechanic performance data
  Future<Map<String, dynamic>> getMechanicPerformance(String mechanicId) async {
    try {
      // Get completed jobs count
      final completedJobsResponse = await _supabase
          .from('service_requests')
          .select('id, rating')
          .eq('mechanic_id', mechanicId)
          .eq('status', 'completed');

      // Calculate average rating
      double averageRating = 0.0;
      if (completedJobsResponse.isNotEmpty) {
        final ratings = completedJobsResponse
            .where((job) => job['rating'] != null)
            .map((job) => (job['rating'] as num).toDouble())
            .toList();
        
        if (ratings.isNotEmpty) {
          averageRating = ratings.reduce((a, b) => a + b) / ratings.length;
        }
      }

      // Get active jobs count
      final activeJobsResponse = await _supabase
          .from('service_requests')
          .select('id')
          .eq('mechanic_id', mechanicId)
          .inFilter('status', ['in_progress']);

      return {
        'completed_jobs': completedJobsResponse.length,
        'active_jobs': activeJobsResponse.length,
        'average_rating': averageRating,
      };
    } catch (e) {
      print('Error fetching mechanic performance: $e');
      return {
        'completed_jobs': 0,
        'active_jobs': 0,
        'average_rating': 0.0,
      };
    }
  }

  // Update service request priority
  Future<void> updateRequestPriority(String requestId, String priority) async {
    try {
      await _supabase
          .from('service_requests')
          .update({
            'priority': priority,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', requestId);

      // Add to audit trail
      await _addAuditTrail(
        tableName: 'service_requests',
        recordId: requestId,
        action: 'UPDATE',
        newData: {'priority': priority},
      );
    } catch (e) {
      print('Error updating request priority: $e');
      throw Exception('Failed to update request priority: $e');
    }
  }

  // Get real-time request updates
  Stream<List<Map<String, dynamic>>> getRequestUpdatesStream() {
    return _supabase
        .from('service_requests')
        .stream(primaryKey: ['id'])
        .map((data) => List<Map<String, dynamic>>.from(data));
  }

  // Add new mechanic to the shop
  Future<void> addMechanic({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String phone,
    required String specialization,
    required int yearsExperience,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('No authenticated user');

      // FIRST: Check if email already exists in user_profiles table
      print('🔍 Checking if email already exists: $email');
      final existingProfile = await _supabase
          .from('user_profiles')
          .select('id, email, user_type')
          .eq('email', email)
          .maybeSingle();

      if (existingProfile != null) {
        print('! User with email $email already exists');
        print('📋 Existing user details: ID=${existingProfile['id']}, Type=${existingProfile['user_type']}');
        
        // Check if user is already a mechanic
        if (existingProfile['user_type'] == 'mechanic') {
          // Check if mechanic already belongs to this talyer owner
          final existingServiceProvider = await _supabase
              .from('service_providers')
              .select('id, talyer_owner_id, company_name')
              .eq('user_id', existingProfile['id'])
              .maybeSingle();

          if (existingServiceProvider != null) {
            if (existingServiceProvider['talyer_owner_id'] == user.id) {
              print('ℹ️ Mechanic already belongs to this shop');
              return;
            } else {
              print('❌ Security violation: Mechanic already belongs to another talyer owner');
              throw Exception('This mechanic is already associated with another shop: ${existingServiceProvider['company_name']}');
            }
          }
        }
        
        // If user exists but is not a mechanic, update their type
        if (existingProfile['user_type'] != 'mechanic') {
          print('🔄 Updating existing user to mechanic type...');
          
          // Update user_type to mechanic
          await _supabase
              .from('user_profiles')
              .update({
                'user_type': 'mechanic',
                'first_name': firstName,
                'last_name': lastName,
                'phone_number': phone,
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('id', existingProfile['id']);

          print('✅ Updated existing user to mechanic type');

          // Create service provider entry
          final talyerOwnerProfile = await _supabase
              .from('user_profiles')
              .select('id, first_name, last_name, current_latitude, current_longitude')
              .eq('id', user.id)
              .single();

          final shopName = "${talyerOwnerProfile['first_name']} ${talyerOwnerProfile['last_name']}'s Auto Shop";

          await _supabase.from('service_providers').insert({
            'user_id': existingProfile['id'],
            'company_name': shopName,
            'years_experience': yearsExperience,
            'service_radius': 50.0,
            'is_verified': true,
            'is_available': true,
            'current_latitude': talyerOwnerProfile['current_latitude'],
            'current_longitude': talyerOwnerProfile['current_longitude'],
            'status': 'offline',
            'rating': 0.00,
            'total_reviews': 0,
            'talyer_owner_id': user.id,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          });

          print('✅ Service provider entry created for existing user');

          // Also create entry in shop_mechanics table for proper shop association
          try {
            // First get the shop ID for this owner
            final shop = await _supabase
                .from('shops')
                .select('id')
                .eq('owner_id', user.id)
                .single();

            await _supabase.from('shop_mechanics').insert({
              'shop_id': shop['id'],
              'mechanic_id': existingProfile['id'],
              'role': 'mechanic',
              'is_active': true,
              'is_available': true,
              'joined_at': DateTime.now().toIso8601String(),
              'created_at': DateTime.now().toIso8601String(),
              'updated_at': DateTime.now().toIso8601String(),
            });

            print('✅ Shop mechanic entry created for existing user');
          } catch (shopMechanicError) {
            print('⚠️ Error creating shop mechanic entry for existing user: $shopMechanicError');
            // Don't fail the entire operation, but log the error
          }

          print('✅ Successfully converted existing user to mechanic');
          return;
        } else {
          // User already exists as mechanic - this is a duplicate email situation
          print('❌ User already exists as mechanic with this email');
          throw Exception('A mechanic with this email already exists. Please use a different email address.');
        }
      }

      // Generate temporary password for email
      final temporaryPassword = EmailService.instance.generateTemporaryPassword();

      // Create mechanic user account and handle session properly
      print('🏭 Creating new mechanic account for: $email');
      print('⚠️ Note: This will temporarily change the auth session');
      
      final AuthResponse authResponse = await _supabase.auth.signUp(
        email: email,
        password: temporaryPassword, // Use temporary password for initial creation
        data: {
          'first_name': firstName,
          'last_name': lastName,
          'phone_number': phone,
          'user_type': 'mechanic', // Set user type in metadata
        },
      );

      if (authResponse.user == null) {
        throw Exception('Failed to create user account');
      }

      final mechanicUserId = authResponse.user!.id;
      print('✅ Mechanic account created with ID: $mechanicUserId');

      // Get the current talyer owner's profile to create shop association
      final talyerOwnerProfile = await _supabase
          .from('user_profiles')
          .select('id, first_name, last_name, current_latitude, current_longitude')
          .eq('id', user.id)
          .single();

      final shopName = "${talyerOwnerProfile['first_name']} ${talyerOwnerProfile['last_name']}'s Auto Shop";

      // Create comprehensive user profile for mechanic
      try {
        print('📝 Creating user profile for mechanic...');
        
        // Double-check email doesn't exist before inserting
        final doubleCheckProfile = await _supabase
            .from('user_profiles')
            .select('id, email')
            .eq('email', email)
            .maybeSingle();

        if (doubleCheckProfile != null) {
          print('❌ Email already exists in database: ${doubleCheckProfile['email']}');
          
          // Clean up the auth user since we can't create the profile
          try {
            await _supabase.auth.admin.deleteUser(mechanicUserId);
            print('🧹 Cleaned up auth user due to duplicate email');
          } catch (cleanupError) {
            print('⚠️ Could not clean up auth user: $cleanupError');
          }
          
          throw Exception('Email already exists in the system. Please use a different email address.');
        }

        await _supabase.from('user_profiles').insert({
          'id': mechanicUserId,
          'first_name': firstName,
          'last_name': lastName,
          'email': email,
          'phone_number': phone,
          'user_type': 'mechanic', // Explicitly set as mechanic
          'status': 'active',
          'is_available': true,
          'current_latitude': talyerOwnerProfile['current_latitude'], // Start at shop location
          'current_longitude': talyerOwnerProfile['current_longitude'],
          'password_change_required': true, // Force password change on first login
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });

        print('✅ Mechanic user profile created with user_type: mechanic');
      } catch (profileError) {
        print('❌ Error creating user profile: $profileError');
        // If profile creation fails, we should clean up the auth user
        try {
          await _supabase.auth.admin.deleteUser(mechanicUserId);
          print('🧹 Cleaned up auth user due to profile creation failure');
        } catch (cleanupError) {
          print('⚠️ Could not clean up auth user: $cleanupError');
        }
        
        // Check if this is a duplicate email error
        if (profileError.toString().contains('duplicate key value violates unique constraint')) {
          throw Exception('This email is already registered in the system. Please use a different email address.');
        }
        
        throw Exception('Failed to create user profile: $profileError');
      }

      // Create comprehensive service provider entry with shop association (use correct column names)
      await _supabase.from('service_providers').insert({
        'user_id': mechanicUserId,
        'company_name': shopName, // Use company_name not business_name
        'years_experience': yearsExperience,
        'service_radius': 50.0, // Default service radius
        'is_verified': true, // Auto-verify since added by talyer owner
        'is_available': true,
        'current_latitude': talyerOwnerProfile['current_latitude'],
        'current_longitude': talyerOwnerProfile['current_longitude'],
        'status': 'offline', // Start offline until they log in
        'rating': 0.00,
        'total_reviews': 0,
        'talyer_owner_id': user.id, // Link to the talyer owner who hired them
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      print('✅ Service provider entry created with talyer_owner_id: ${user.id}');

      // Also create entry in shop_mechanics table for proper shop association
      try {
        // First get the shop ID for this owner
        final shop = await _supabase
            .from('shops')
            .select('id')
            .eq('owner_id', user.id)
            .single();

        await _supabase.from('shop_mechanics').insert({
          'shop_id': shop['id'],
          'mechanic_id': mechanicUserId,
          'role': 'mechanic',
          'is_active': true,
          'is_available': true,
          'joined_at': DateTime.now().toIso8601String(),
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });

        print('✅ Shop mechanic entry created in shop_mechanics table');
      } catch (shopMechanicError) {
        print('⚠️ Error creating shop mechanic entry: $shopMechanicError');
        // Don't fail the entire operation, but log the error
      }

      // Initialize service provider location (instead of mechanic_locations)
      try {
        await _supabase.from('service_providers').update({
          'current_latitude': talyerOwnerProfile['current_latitude'] ?? 14.6760, // Default to Manila if no location
          'current_longitude': talyerOwnerProfile['current_longitude'] ?? 121.0437,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('user_id', mechanicUserId);
        print('✅ Service provider location initialized');
      } catch (locationError) {
        print('⚠️ Error updating service provider location: $locationError');
      }

      // Send welcome email with temporary password and app download links
      try {
        print('📧 Sending welcome email to mechanic...');
        final emailSent = await EmailService.instance.sendMechanicWelcomeEmail(
          mechanicId: mechanicUserId,
          email: email,
          firstName: firstName,
          lastName: lastName,
          temporaryPassword: temporaryPassword,
          talyerOwnerName: "${talyerOwnerProfile['first_name']} ${talyerOwnerProfile['last_name']}",
        );

        if (emailSent) {
          print('✅ Welcome email sent successfully');
        } else {
          print('⚠️ Welcome email failed to send, but mechanic was created');
        }
      } catch (emailError) {
        print('⚠️ Error sending welcome email: $emailError');
        // Don't fail the entire operation if email fails
      }

      // Create audit trail entry for mechanic creation (if table exists)
      try {
        await _supabase.from('audit_trail').insert({
          'table_name': 'user_profiles',
          'record_id': mechanicUserId,
          'action': 'INSERT',
          'changed_by': user.id,
          'changed_at': DateTime.now().toIso8601String(),
          'new_data': {
            'user_type': 'mechanic',
            'first_name': firstName,
            'last_name': lastName,
            'email': email,
            'phone_number': phone,
            'created_by': user.id,
            'specialization': specialization,
            'years_experience': yearsExperience,
          },
        });
        print('✅ Audit trail entry created');
      } catch (auditError) {
        print('⚠️ Audit trail table may not exist: $auditError');
      }

      print('✅ Mechanic ${firstName} ${lastName} successfully added to ${shopName}');
      print('🔗 Associated with Talyer Owner ID: ${user.id}');
      print('👤 User Type: mechanic');
      print('🏢 Company: ${shopName}');
      print('🔧 Specialization: ${specialization}');
      print('📅 Experience: ${yearsExperience} years');
      print('📧 Welcome email sent with temporary password');
      print('🔐 User must change password on first login');
      
      // IMPORTANT: Sign out the newly created mechanic to prevent session conflict
      try {
        await _supabase.auth.signOut();
        print('🚪 Signed out mechanic account to prevent session conflict');
        print('⚠️ Talyer owner will need to refresh/re-login to continue');
      } catch (signOutError) {
        print('⚠️ Could not sign out mechanic session: $signOutError');
      }
      
      // Method completes successfully
    } catch (e) {
      print('❌ Error adding mechanic: $e');
      
      // Provide user-friendly error messages
      if (e.toString().contains('email already exists') || 
          e.toString().contains('duplicate key value violates unique constraint')) {
        throw Exception('This email is already registered in the system. Please use a different email address.');
      } else if (e.toString().contains('already associated with another shop')) {
        throw Exception(e.toString()); // Keep the original message as it's already user-friendly
      } else {
        throw Exception('Failed to add mechanic: ${e.toString()}');
      }
    }
  }

  // Update shop mechanic details (role and availability)
  Future<void> updateShopMechanic({
    required String mechanicId,
    String? role,
    bool? isActive,
    bool? isAvailable,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('No authenticated user');

      // Get the shop ID for this owner
      final shop = await _supabase
          .from('shops')
          .select('id')
          .eq('owner_id', user.id)
          .single();

      final shopId = shop['id'];

      // Update the shop mechanic record
      Map<String, dynamic> updates = {
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (role != null) updates['role'] = role;
      if (isActive != null) updates['is_active'] = isActive;
      if (isAvailable != null) updates['is_available'] = isAvailable;

      await _supabase
          .from('shop_mechanics')
          .update(updates)
          .eq('shop_id', shopId)
          .eq('mechanic_id', mechanicId);

      print('✅ Updated shop mechanic details for mechanic $mechanicId');

    } catch (e) {
      print('❌ Error updating shop mechanic: $e');
      throw Exception('Failed to update shop mechanic: ${e.toString()}');
    }
  }

  // Remove mechanic from shop (deactivate rather than delete for data integrity)
  Future<void> removeShopMechanic(String mechanicId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('No authenticated user');

      // Get the shop ID for this owner
      final shop = await _supabase
          .from('shops')
          .select('id')
          .eq('owner_id', user.id)
          .single();

      final shopId = shop['id'];

      // Deactivate the shop mechanic instead of deleting
      await _supabase
          .from('shop_mechanics')
          .update({
            'is_active': false,
            'is_available': false,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('shop_id', shopId)
          .eq('mechanic_id', mechanicId);

      print('✅ Deactivated shop mechanic $mechanicId');

    } catch (e) {
      print('❌ Error removing shop mechanic: $e');
      throw Exception('Failed to remove shop mechanic: ${e.toString()}');
    }
  }

  // Update mechanic online status
  Future<void> updateMechanicStatus({
    required String mechanicUserId,
    required String status, // 'online' or 'offline'
    bool? isAvailable,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('No authenticated user');

      // Verify mechanic ownership
      final isOwned = await verifyMechanicOwnership(mechanicUserId);
      if (!isOwned) {
        throw Exception('You can only update status for mechanics in your shop');
      }

      final updateData = <String, dynamic>{
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (isAvailable != null) {
        updateData['is_available'] = isAvailable;
      }

      await _supabase
          .from('service_providers')
          .update(updateData)
          .eq('user_id', mechanicUserId)
          .eq('talyer_owner_id', user.id);

      print('✅ Updated mechanic status: $mechanicUserId -> $status');
    } catch (e) {
      print('❌ Error updating mechanic status: $e');
      throw Exception('Failed to update mechanic status: $e');
    }
  }

  // Batch update all shop mechanics to online
  Future<void> setAllMechanicsOnline() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('No authenticated user');

      await _supabase
          .from('service_providers')
          .update({
            'status': 'online',
            'is_available': true,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('talyer_owner_id', user.id);

      print('✅ Set all shop mechanics to online status');
    } catch (e) {
      print('❌ Error setting mechanics online: $e');
      throw Exception('Failed to set mechanics online: $e');
    }
  }

  // Get shop mechanics using RPC (bypasses RLS)
  Future<List<Map<String, dynamic>>> getShopMechanics() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('No authenticated user');

      print('🔍 Getting shop mechanics via RPC for talyer owner ${user.id}...');

      // Use RPC function that bypasses RLS
      final mechanicsData = await _supabase
          .rpc('get_shop_mechanics_for_owner')
          .select();

      print('👥 Found ${mechanicsData.length} mechanics from RPC');

      List<Map<String, dynamic>> result = [];
      
      for (var mechanic in mechanicsData) {
        // Also get service provider data if it exists
        Map<String, dynamic>? serviceProviderData;
        try {
          final serviceProvider = await _supabase
              .from('service_providers')
              .select('*')
              .eq('user_id', mechanic['mechanic_id'])
              .maybeSingle();
          serviceProviderData = serviceProvider;
        } catch (e) {
          print('ℹ️ No service provider record for mechanic ${mechanic['mechanic_id']}');
        }
        
        result.add({
          'id': mechanic['mechanic_id'],
          'first_name': mechanic['first_name'],
          'last_name': mechanic['last_name'],
          'email': mechanic['email'],
          'phone_number': mechanic['phone_number'],
          'user_type': 'mechanic',
          'status': mechanic['is_available'] ? 'available' : 'busy',
          'is_available': mechanic['is_available'],
          'profile_image_url': mechanic['profile_image_url'],
          // Shop mechanics specific data
          'shop_mechanic': {
            'id': mechanic['mechanic_id'],
            'shop_id': mechanic['shop_id'],
            'mechanic_id': mechanic['mechanic_id'],
            'role': 'mechanic',
            'is_active': mechanic['is_active'] ?? true,
            'is_available': mechanic['is_available'] ?? true,
            'specialties': mechanic['specialties'],
            'hourly_rate': mechanic['hourly_rate'],
          },
          // Service provider data if available
          'service_provider': serviceProviderData,
          // Computed fields for display
          'rating': mechanic['rating'] ?? 0.0,
          'total_reviews': mechanic['total_reviews'] ?? 0,
          'years_experience': serviceProviderData?['years_experience'] ?? 0,
          'company_name': serviceProviderData?['company_name'] ?? '',
          'completed_jobs': mechanic['total_reviews'] ?? 0,
        });
      }

      print('✅ Processed ${result.length} shop mechanics for talyer owner');
      return result;

    } catch (e) {
      print('❌ Error fetching shop mechanics: $e');
      throw Exception('Failed to fetch shop mechanics: ${e.toString()}');
    }
  }

  // Get only mechanics owned by this talyer owner for dispatch
  Future<List<Map<String, dynamic>>> getOwnedMechanicsForDispatch() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('No authenticated user');

      print('🔍 Getting mechanics owned by talyer owner ${user.id} for dispatch...');
      
      // First get the shop for this owner
      final shop = await _supabase
          .from('shops')
          .select('id')
          .eq('owner_id', user.id)
          .single();

      final shopId = shop['id'];
      print('🏪 Found shop ${shopId} for owner ${user.id}');

      // Get only available mechanics from shop_mechanics table
      final mechanics = await _supabase
          .from('shop_mechanics')
          .select('''
            id,
            shop_id,
            mechanic_id,
            role,
            specialties,
            hourly_rate,
            is_active,
            is_available,
            user_profiles!shop_mechanics_mechanic_id_fkey(
              id,
              first_name,
              last_name,
              email,
              phone_number,
              user_type,
              status,
              is_available,
              current_latitude,
              current_longitude
            )
          ''')
          .eq('shop_id', shopId)
          .eq('is_active', true)
          .eq('is_available', true)
          .eq('user_profiles.user_type', 'mechanic')
          .eq('user_profiles.status', 'active');

      print('✅ Found ${mechanics.length} available mechanics for dispatch');
      
      // Filter and format results with online status
      final availableMechanics = mechanics.map((mechanic) {
        final userProfile = mechanic['user_profiles'];
        return {
          'shop_mechanic_id': mechanic['id'],
          'mechanic_id': mechanic['mechanic_id'],
          'user_id': userProfile['id'], // For backward compatibility
          'first_name': userProfile['first_name'],
          'last_name': userProfile['last_name'],
          'email': userProfile['email'],
          'phone_number': userProfile['phone_number'],
          'role': mechanic['role'] ?? 'mechanic',
          'specialties': mechanic['specialties'] ?? [],
          'hourly_rate': mechanic['hourly_rate'] ?? 0.0,
          'rating': 0.0, // Will be fetched from service provider if needed
          'total_reviews': 0, // Will be fetched from service provider if needed
          'status': userProfile['status'],
          'is_available': mechanic['is_available'] && userProfile['is_available'],
          'current_latitude': userProfile['current_latitude'],
          'current_longitude': userProfile['current_longitude'],
          'distance_km': null, // Will be calculated based on job location
          // Add online status tracking
          'is_online': userProfile['status'] == 'active',
          'availability_status': mechanic['is_available'] ? 'available' : 'unavailable',
        };
      }).toList();

      return availableMechanics;
    } catch (e) {
      print('❌ Error getting owned mechanics for dispatch: $e');
      return [];
    }
  }

  // Verify mechanic ownership before any operation
  Future<bool> verifyMechanicOwnership(String mechanicUserId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return false;

      final serviceProvider = await _supabase
          .from('service_providers')
          .select('talyer_owner_id')
          .eq('user_id', mechanicUserId)
          .eq('talyer_owner_id', user.id)
          .maybeSingle();

      final isOwned = serviceProvider != null;
      print('🔒 Mechanic ownership verification: ${isOwned ? 'PASSED' : 'FAILED'}');
      return isOwned;
    } catch (e) {
      print('❌ Error verifying mechanic ownership: $e');
      return false;
    }
  }

  // Enhanced method to get service requests that can be assigned to this shop's mechanics
  Future<List<Map<String, dynamic>>> getAssignableServiceRequests() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('No authenticated user');

      // Get service requests that are pending and can be assigned
      final requests = await _supabase
          .from('service_requests')
          .select('''
            id,
            customer_id,
            provider_id,
            category_id,
            title,
            description,
            status,
            pickup_latitude,
            pickup_longitude,
            pickup_address,
            estimated_price,
            service_type,
            priority,
            created_at,
            customer:user_profiles!service_requests_customer_id_fkey(
              first_name,
              last_name,
              phone_number,
              email
            ),
            category:service_categories(
              name,
              description,
              base_price,
              estimated_duration
            )
          ''')
          .inFilter('status', ['pending', 'awaiting_payment', 'ready_to_assign', 'in_progress'])
          .isFilter('provider_id', null); // Not yet assigned

      print('✅ Found ${requests.length} assignable service requests');
      return requests;
    } catch (e) {
      print('❌ Error getting assignable service requests: $e');
      return [];
    }
  }

  // Enhanced assign mechanic with full validation
  Future<void> assignMechanicToRequestSecure(String requestId, String mechanicUserId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('No authenticated user');

      // Step 1: Verify mechanic ownership
      final isOwned = await verifyMechanicOwnership(mechanicUserId);
      if (!isOwned) {
        throw Exception('Security violation: You can only assign mechanics from your shop');
      }

      // Step 2: Get service provider ID
      final serviceProvider = await _supabase
          .from('service_providers')
          .select('id, company_name')
          .eq('user_id', mechanicUserId)
          .eq('talyer_owner_id', user.id)
          .single();

      // Step 3: Verify service request is assignable
      final serviceRequest = await _supabase
          .from('service_requests')
          .select('id, status, provider_id')
          .eq('id', requestId)
          .single();

      print('🔍 Service request status check:');
      print('  Request ID: $requestId');
      print('  Current status: ${serviceRequest['status']}');
      print('  Provider ID: ${serviceRequest['provider_id']}');

      if (serviceRequest['provider_id'] != null) {
        throw Exception('Service request is already assigned to another mechanic');
      }

      // Allow assignment for requests that are accepted, ready to assign, or awaiting payment
      if (!['pending', 'accepted', 'awaiting_payment', 'ready_to_assign', 'in_progress'].contains(serviceRequest['status'])) {
        print('❌ Status ${serviceRequest['status']} is not assignable');
        throw Exception('Service request is not in assignable status');
      }

      print('✅ Service request is assignable (status: ${serviceRequest['status']})');

      // Step 4: Assign mechanic to request and set status to in_progress (in service)
      await _supabase
          .from('service_requests')
          .update({
            'provider_id': serviceProvider['id'],
            'status': 'in_progress',
            'assigned_at': DateTime.now().toUtc().toIso8601String(),
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', requestId);

      print('✅ Mechanic assigned successfully to request $requestId');
      print('   - Service Provider: ${serviceProvider['company_name']}');
      print('   - Mechanic User ID: $mechanicUserId');

      // Step 5: Create talyer-customer connection for QR verification
      try {
        await TalyerConnectionService.instance.createConnection(
          serviceRequestId: requestId,
          customerId: serviceRequest['customer_id'],
          talyerOwnerId: user.id,
          providerId: serviceProvider['id'],
          talyerDetails: {
            'company_name': serviceProvider['company_name'],
            'assigned_at': DateTime.now().toIso8601String(),
            'assigned_by': user.id,
          },
        );
        print('✅ Talyer-customer connection created for QR verification');
      } catch (connectionError) {
        print('⚠️ Warning: Could not create talyer connection: $connectionError');
        // Don't fail the assignment if connection creation fails
      }

      // Step 6: Create notifications
      await _createNotification(
        requestId: requestId,
        type: 'mechanic_assigned',
        title: 'Mechanic Assigned',
        message: 'A mechanic from ${serviceProvider['company_name']} has been assigned to your service request.',
      );

      // Notification disabled to prevent spam
      /*
      await _createMechanicNotification(
        mechanicId: mechanicUserId,
        requestId: requestId,
        type: 'job_assigned',
        title: 'New Job Assignment',
        message: 'You have been assigned a new service job.',
      );
      */

      // Step 6: Add to audit trail
      await _addAuditTrail(
        tableName: 'service_requests',
        recordId: requestId,
        action: 'UPDATE',
        newData: {
          'provider_id': serviceProvider['id'],
          'status': 'in_progress',
          'assigned_by': user.id,
        },
      );

    } catch (e) {
      print('❌ Error in secure mechanic assignment: $e');
      throw Exception('Failed to assign mechanic: $e');
    }
  }

  // Get earnings report for the talyer owner
  Future<Map<String, dynamic>> getEarningsReport() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('No authenticated user');

      // Get all completed service requests for mechanics owned by this talyer owner
      final completedServices = await _supabase
          .from('service_requests')
          .select('''
            id,
            final_price,
            final_price,
            created_at,
            completed_at,
            provider:service_providers!service_requests_provider_id_fkey(
              id,
              talyer_owner_id,
              user_profile:user_profiles!service_providers_user_id_fkey(
                first_name,
                last_name
              )
            )
          ''')
          .eq('status', 'completed')
          .eq('provider.talyer_owner_id', user.id)
          .order('completed_at', ascending: false);

      // Calculate earnings
      double totalEarnings = 0;
      int totalJobs = completedServices.length;
      
      for (final service in completedServices) {
        final finalPrice = service['final_price'] ?? 0;
        totalEarnings += (finalPrice is num) ? finalPrice.toDouble() : 0;
      }

      // Get current month earnings
      final now = DateTime.now();
      final currentMonthStart = DateTime(now.year, now.month, 1);
      final currentMonthServices = completedServices.where((service) {
        final completedAt = service['completed_at'];
        if (completedAt != null) {
          final completedDate = DateTime.parse(completedAt);
          return completedDate.isAfter(currentMonthStart);
        }
        return false;
      }).toList();

      double monthlyEarnings = 0;
      for (final service in currentMonthServices) {
        final finalPrice = service['final_price'] ?? 0;
        monthlyEarnings += (finalPrice is num) ? finalPrice.toDouble() : 0;
      }

      return {
        'totalEarnings': totalEarnings,
        'monthlyEarnings': monthlyEarnings,
        'totalJobs': totalJobs,
        'monthlyJobs': currentMonthServices.length,
        'recentServices': completedServices.take(10).toList(),
      };
    } catch (e) {
      print('❌ Error getting earnings report: $e');
      throw Exception('Failed to get earnings report: $e');
    }
  }

  // Save shop operating hours
  Future<bool> saveShopHours(Map<String, Map<String, dynamic>> shopHours) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('No authenticated user');

      print('💾 Saving shop hours for talyer owner ${user.id}');

      // Convert shop hours to JSON format
      final hoursJson = <String, dynamic>{};
      shopHours.forEach((day, hours) {
        hoursJson[day] = {
          'isOpen': hours['isOpen'] ?? false,
          'openTime': hours['openTime'] ?? '09:00',
          'closeTime': hours['closeTime'] ?? '17:00',
        };
      });

      // Try to save in shops table first (primary location for shop hours)
      bool shopTableSuccess = false;
      try {
        final shopId = await getCurrentShopId();
        if (shopId != null) {
          await _supabase
              .from('shops')
              .update({
                'operating_hours': hoursJson,
                'updated_at': DateTime.now().toUtc().toIso8601String(),
              })
              .eq('id', shopId);
          shopTableSuccess = true;
          print('✅ Shop hours saved to shops table');
        }
      } catch (e) {
        print('⚠️ Could not update shops table: $e');
      }

      // If shops table doesn't work, try creating or updating shop record
      if (!shopTableSuccess) {
        try {
          await createOrUpdateShop(
            shopName: 'My Shop', // Default name
            operatingHours: hoursJson,
          );
          shopTableSuccess = true;
          print('✅ Shop hours saved via createOrUpdateShop');
        } catch (e) {
          print('⚠️ Could not save via createOrUpdateShop: $e');
        }
      }

      // If all else fails, save to a simple shop_hours table or create a settings record
      if (!shopTableSuccess) {
        try {
          // Try to save to a simple settings-like structure
          await _supabase
              .from('shop_settings')
              .upsert({
                'user_id': user.id,
                'setting_key': 'operating_hours',
                'setting_value': hoursJson,
                'updated_at': DateTime.now().toUtc().toIso8601String(),
              });
          shopTableSuccess = true;
          print('✅ Shop hours saved to shop_settings table');
        } catch (e) {
          print('⚠️ Could not save to shop_settings: $e');
          
          // Last resort: save as JSON in user_profiles with a different column name
          try {
            await _supabase
                .from('user_profiles')
                .update({
                  'settings': {'operating_hours': hoursJson},
                  'updated_at': DateTime.now().toUtc().toIso8601String(),
                })
                .eq('id', user.id);
            shopTableSuccess = true;
            print('✅ Shop hours saved to user_profiles.settings');
          } catch (e2) {
            print('❌ Final fallback failed: $e2');
          }
        }
      }

      // Also try to save in user_profiles table as backup (if it has a shop_hours column)
      try {
        await _supabase
            .from('user_profiles')
            .update({
              'shop_hours': hoursJson,
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            })
            .eq('id', user.id);
        print('✅ Shop hours backed up to user_profiles');
      } catch (e) {
        print('⚠️ Could not backup to user_profiles: $e');
      }

      if (shopTableSuccess) {
        // Cache the saved hours
        _cachedShopHours = shopHours;
        print('✅ Shop hours saved successfully');
        return true;
      } else {
        // Even if save failed, cache locally so user can continue working
        _cachedShopHours = shopHours;
        print('❌ Failed to save shop hours to database, but cached locally');
        return false;
      }
    } catch (e) {
      print('❌ Error saving shop hours: $e');
      return false;
    }
  }

  // Get shop operating hours
  Future<Map<String, Map<String, dynamic>>?> getShopHours() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('No authenticated user');

      print('📖 Loading shop hours for talyer owner ${user.id}');

      // Check cache first
      if (_cachedShopHours != null) {
        print('✅ Shop hours loaded from cache');
        return _cachedShopHours;
      }

      // Try to get hours from shops table first
      try {
        final shopId = await getCurrentShopId();
        if (shopId != null) {
          final shopData = await _supabase
              .from('shops')
              .select('operating_hours')
              .eq('id', shopId)
              .maybeSingle();

          if (shopData != null && shopData['operating_hours'] != null) {
            final hoursJson = shopData['operating_hours'] as Map<String, dynamic>;
            
            // Convert back to expected format
            final Map<String, Map<String, dynamic>> shopHours = {};
            hoursJson.forEach((day, hours) {
              if (hours is Map<String, dynamic>) {
                shopHours[day] = {
                  'isOpen': hours['isOpen'] ?? false,
                  'openTime': hours['openTime'] ?? '09:00',
                  'closeTime': hours['closeTime'] ?? '17:00',
                };
              }
            });

            print('✅ Shop hours loaded from shops table');
            _cachedShopHours = shopHours; // Cache the result
            return shopHours;
          }
        }
      } catch (e) {
        print('⚠️ Could not load from shops table: $e');
      }

      // Try to get hours from user_profiles table as backup
      try {
        final userProfile = await _supabase
            .from('user_profiles')
            .select('shop_hours')
            .eq('id', user.id)
            .maybeSingle();

        if (userProfile != null && userProfile['shop_hours'] != null) {
          final hoursJson = userProfile['shop_hours'] as Map<String, dynamic>;
          
          // Convert back to expected format
          final Map<String, Map<String, dynamic>> shopHours = {};
          hoursJson.forEach((day, hours) {
            if (hours is Map<String, dynamic>) {
              shopHours[day] = {
                'isOpen': hours['isOpen'] ?? false,
                'openTime': hours['openTime'] ?? '09:00',
                'closeTime': hours['closeTime'] ?? '17:00',
              };
            }
          });

          print('✅ Shop hours loaded from user_profiles backup');
          _cachedShopHours = shopHours; // Cache the result
          return shopHours;
        }
      } catch (e) {
        print('⚠️ Could not load from user_profiles: $e');
      }

      // Try to get from shop_settings table
      try {
        final settings = await _supabase
            .from('shop_settings')
            .select('setting_value')
            .eq('user_id', user.id)
            .eq('setting_key', 'operating_hours')
            .maybeSingle();

        if (settings != null && settings['setting_value'] != null) {
          final hoursJson = settings['setting_value'] as Map<String, dynamic>;
          
          // Convert back to expected format
          final Map<String, Map<String, dynamic>> shopHours = {};
          hoursJson.forEach((day, hours) {
            if (hours is Map<String, dynamic>) {
              shopHours[day] = {
                'isOpen': hours['isOpen'] ?? false,
                'openTime': hours['openTime'] ?? '09:00',
                'closeTime': hours['closeTime'] ?? '17:00',
              };
            }
          });

          print('✅ Shop hours loaded from shop_settings');
          _cachedShopHours = shopHours; // Cache the result
          return shopHours;
        }
      } catch (e) {
        print('⚠️ Could not load from shop_settings: $e');
      }

      // Try to get from user_profiles.settings as final fallback
      try {
        final userProfile = await _supabase
            .from('user_profiles')
            .select('settings')
            .eq('id', user.id)
            .maybeSingle();

        if (userProfile != null && userProfile['settings'] != null) {
          final settings = userProfile['settings'] as Map<String, dynamic>;
          if (settings['operating_hours'] != null) {
            final hoursJson = settings['operating_hours'] as Map<String, dynamic>;
            
            // Convert back to expected format
            final Map<String, Map<String, dynamic>> shopHours = {};
            hoursJson.forEach((day, hours) {
              if (hours is Map<String, dynamic>) {
                shopHours[day] = {
                  'isOpen': hours['isOpen'] ?? false,
                  'openTime': hours['openTime'] ?? '09:00',
                  'closeTime': hours['closeTime'] ?? '17:00',
                };
              }
            });

            print('✅ Shop hours loaded from user_profiles.settings');
            _cachedShopHours = shopHours; // Cache the result
            return shopHours;
          }
        }
      } catch (e) {
        print('⚠️ Could not load from user_profiles.settings: $e');
      }

      print('ℹ️ No shop hours found, returning default');
      final defaultHours = _getDefaultShopHours();
      _cachedShopHours = defaultHours; // Cache the default hours
      return defaultHours;
    } catch (e) {
      print('❌ Error loading shop hours: $e');
      // Return cached hours if available, otherwise return default
      if (_cachedShopHours != null) {
        print('📦 Returning cached shop hours due to error');
        return _cachedShopHours;
      }
      final defaultHours = _getDefaultShopHours();
      _cachedShopHours = defaultHours;
      return defaultHours;
    }
  }

  // Check if shop is currently open
  Future<bool> isShopCurrentlyOpen() async {
    try {
      final shopHours = await getShopHours();
      if (shopHours == null) return false;

      final now = DateTime.now();
      final currentDay = _getDayKey(now.weekday);
      final currentTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      
      final todayHours = shopHours[currentDay];
      if (todayHours == null) return false;

      final isOpenToday = todayHours['isOpen'] ?? false;
      final openTime = todayHours['openTime'] ?? '09:00';
      final closeTime = todayHours['closeTime'] ?? '17:00';
      
      if (isOpenToday) {
        return currentTime.compareTo(openTime) >= 0 && currentTime.compareTo(closeTime) < 0;
      }

      return false;
    } catch (e) {
      print('❌ Error checking if shop is open: $e');
      return false;
    }
  }

  String _getDayKey(int weekday) {
    final keys = [
      'monday',
      'tuesday', 
      'wednesday',
      'thursday',
      'friday',
      'saturday',
      'sunday',
    ];
    return keys[weekday - 1];
  }

  // Get default shop hours (9 AM to 5 PM, Monday to Friday)
  Map<String, Map<String, dynamic>> _getDefaultShopHours() {
    return {
      'monday': {'isOpen': true, 'openTime': '09:00', 'closeTime': '17:00'},
      'tuesday': {'isOpen': true, 'openTime': '09:00', 'closeTime': '17:00'},
      'wednesday': {'isOpen': true, 'openTime': '09:00', 'closeTime': '17:00'},
      'thursday': {'isOpen': true, 'openTime': '09:00', 'closeTime': '17:00'},
      'friday': {'isOpen': true, 'openTime': '09:00', 'closeTime': '17:00'},
      'saturday': {'isOpen': false, 'openTime': '09:00', 'closeTime': '17:00'},
      'sunday': {'isOpen': false, 'openTime': '09:00', 'closeTime': '17:00'},
    };
  }

  // Debug method to check database relationships
  Future<void> debugMechanicRelationships() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        print('❌ No authenticated user');
        return;
      }

      print('🔍 DEBUG: Checking mechanic relationships for talyer owner ${user.id}');

      // Check service_providers table
      final serviceProviders = await _supabase
          .from('service_providers')
          .select('*')
          .eq('talyer_owner_id', user.id);

      print('📋 Service providers found: ${serviceProviders.length}');
      for (final sp in serviceProviders) {
        print('  - ID: ${sp['id']}, User ID: ${sp['user_id']}, Company: ${sp['company_name']}');
      }

      // Check user_profiles table for mechanics
      final allMechanics = await _supabase
          .from('user_profiles')
          .select('*')
          .eq('user_type', 'mechanic');

      print('👨‍🔧 All mechanics in system: ${allMechanics.length}');
      for (final mechanic in allMechanics) {
        print('  - ID: ${mechanic['id']}, Name: ${mechanic['first_name']} ${mechanic['last_name']}, Email: ${mechanic['email']}');
      }

      // Check if any mechanics belong to this talyer owner
      final userIds = serviceProviders.map((sp) => sp['user_id']).toList();
      if (userIds.isNotEmpty) {
        final ownedMechanics = await _supabase
            .from('user_profiles')
            .select('*')
            .inFilter('id', userIds)
            .eq('user_type', 'mechanic');

        print('🎯 Mechanics owned by this talyer owner: ${ownedMechanics.length}');
        for (final mechanic in ownedMechanics) {
          print('  - Name: ${mechanic['first_name']} ${mechanic['last_name']}, Email: ${mechanic['email']}');
        }
      }

    } catch (e) {
      print('❌ DEBUG Error: $e');
    }
  }

  // =============================================================================
  // SHOP SERVICES MANAGEMENT
  // =============================================================================

  // Default services that every talyer shop should have
  static const List<Map<String, dynamic>> _defaultServices = [
    {
      'name': 'Mechanical Issue',
      'description': 'General mechanical repairs and troubleshooting',
      'base_price': 1500.0,
      'icon_name': 'settings',
      'category_type': 'mechanical'
    },
    {
      'name': 'Electrical Problem',
      'description': 'Electrical system diagnosis and repair',
      'base_price': 1200.0,
      'icon_name': 'electrical_services',
      'category_type': 'electrical'
    },
    {
      'name': 'Tire Issue',
      'description': 'Tire repair, replacement, and maintenance',
      'base_price': 800.0,
      'icon_name': 'tire_repair',
      'category_type': 'tire'
    },
    {
      'name': 'Fuel Problem',
      'description': 'Fuel system cleaning and repair',
      'base_price': 1000.0,
      'icon_name': 'local_gas_station',
      'category_type': 'fuel'
    },
  ];

  // Create or update shop profile with default services
  Future<void> createOrUpdateShopWithDefaults({
    required String shopName,
    String? description,
    String? address,
    String? phone,
    String? email,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      print('🏪 Creating/updating shop with defaults for user: ${user.id}');

      // First, create or update the shop
      await createOrUpdateShop(
        shopName: shopName,
        shopAddress: address,
      );

      // Then initialize default services
      await initializeDefaultServices();

      print('✅ Shop created/updated with default services');
    } catch (e) {
      print('❌ Error creating shop with defaults: $e');
      rethrow;
    }
  }

  // Check if shop has services, if not initialize defaults
  Future<void> ensureDefaultServices() async {
    try {
      final services = await getShopServices();
      if (services.isEmpty) {
        print('ℹ️ No services found, initializing defaults');
        await initializeDefaultServices();
      }
    } catch (e) {
      print('⚠️ Error ensuring default services: $e');
    }
  }
  Future<void> initializeDefaultServices() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      print('🔧 Initializing default services for talyer shop');

      // Get the user's shop ID
      final shopId = await getCurrentShopId();
      if (shopId == null) {
        print('⚠️ No shop found for user, skipping default services initialization');
        return;
      }

      // Check if services already exist in shop_services table
      final existingServices = await _supabase
          .from('shop_services')
          .select('id')
          .eq('shop_id', shopId);

      if (existingServices.isNotEmpty) {
        print('ℹ️ Services already exist for this shop');
        return;
      }

      // Create default service categories if they don't exist
      await _createDefaultServiceCategories();

      // Get the created category IDs
      final categories = await _supabase
          .from('service_categories')
          .select('id, name, description, base_price, estimated_duration')
          .inFilter('name', _defaultServices.map((s) => s['name']).toList());

      // Add default services to shop_services table
      for (final serviceData in _defaultServices) {
        try {
          final matchingCategories = categories.where(
            (cat) => cat['name'] == serviceData['name'],
          );

          if (matchingCategories.isNotEmpty) {
            final category = matchingCategories.first;
            await _supabase.from('shop_services').insert({
              'shop_id': shopId,
              'category_id': category['id'],
              'service_name': category['name'],
              'description': category['description'],
              'base_price': category['base_price'] ?? serviceData['base_price'],
              'custom_price': serviceData['base_price'],
              'estimated_duration': category['estimated_duration'] ?? 30,
              'is_active': true,
              'is_custom': false,
              'availability_status': 'available',
              'service_quality_level': 'standard',
            });
          }
        } catch (e) {
          print('⚠️ Error adding service ${serviceData['name']}: $e');
        }
      }

      print('✅ Default services initialized successfully');
    } catch (e) {
      print('❌ Error initializing default services: $e');
      // Don't rethrow to avoid breaking app initialization
    }
  }

  // Create default service categories if they don't exist
  Future<void> _createDefaultServiceCategories() async {
    try {
      for (final serviceData in _defaultServices) {
        // Check if category already exists
        final existing = await _supabase
            .from('service_categories')
            .select('id')
            .eq('name', serviceData['name'])
            .maybeSingle();

        if (existing == null) {
          // Create the category
          await _supabase.from('service_categories').insert({
            'name': serviceData['name'],
            'description': serviceData['description'],
            'base_price': serviceData['base_price'],
            'icon_name': serviceData['icon_name'],
            'is_active': true,
            'estimated_duration': 60, // Default 1 hour
          });
          print('✅ Created service category: ${serviceData['name']}');
        }
      }
    } catch (e) {
      print('❌ Error creating default service categories: $e');
    }
  }

  // Get all services offered by the shop
  Future<List<Map<String, dynamic>>> getShopServices() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      print('🔍 Loading shop services for user: ${user.id}');

      // Get the user's shop ID
      final shopId = await getCurrentShopId();
      if (shopId == null) {
        print('ℹ️ No shop found for user');
        return [];
      }

      print('🏪 Found shop ID: $shopId');

      // Get services from shop_services table (where custom services are saved)
      // Specify the exact relationship to avoid ambiguity between category_id and parent_category_id
      final response = await _supabase
          .from('shop_services')
          .select('''
            id,
            service_name,
            description,
            base_price,
            custom_price,
            is_active,
            created_at,
            category_id,
            is_custom,
            custom_name,
            custom_description,
            estimated_duration,
            service_categories!shop_services_category_id_fkey(
              id,
              name,
              description,
              base_price,
              icon_name
            )
          ''')
          .eq('shop_id', shopId)
          .eq('is_active', true)
          .order('created_at', ascending: false);

      print('✅ Loaded ${response.length} shop services');

      // Transform the response to handle both custom and standard services
      return response.map<Map<String, dynamic>>((item) {
        final category = item['service_categories!shop_services_category_id_fkey'];
        final isCustom = item['is_custom'] ?? false;
        
        return {
          'id': item['id'],
          'category_id': item['category_id'],
          'category_name': isCustom ? (item['custom_name'] ?? item['service_name']) : (category?['name'] ?? item['service_name']),
          'service_name': item['service_name'],
          'description': isCustom ? (item['custom_description'] ?? item['description']) : (item['description'] ?? category?['description'] ?? ''),
          'base_price': item['base_price'],
          'custom_price': item['custom_price'],
          'icon_name': category?['icon_name'] ?? 'build',
          'is_available': item['is_active'],
          'is_active': item['is_active'],
          'is_custom': isCustom,
          'custom_name': item['custom_name'],
          'custom_description': item['custom_description'],
          'estimated_duration': item['estimated_duration'],
          'created_at': item['created_at'],
        };
      }).toList();
    } catch (e) {
      print('❌ Error loading shop services: $e');
      return []; // Return empty list instead of rethrowing
    }
  }

  // Add a new service to the shop with enhanced shop isolation
  Future<void> addShopService(String categoryId, double? customPrice) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      print('➕ Adding shop service: $categoryId with price: $customPrice');
      print('🔐 Current user ID: ${user.id}');

      // FORCE REFRESH shop ID to avoid cache issues
      print('🔄 Clearing cache and fetching fresh shop ID...');
      clearCache();
      final shopId = await getCurrentShopId(forceRefresh: true);
      if (shopId == null) {
        throw Exception('No shop found for user. Please complete your shop profile first.');
      }

      print('🏪 Target shop ID: $shopId');

      // Verify shop ownership to prevent cross-shop contamination
      final shopOwnership = await _supabase
          .from('shops')
          .select('id, owner_id, shop_name')
          .eq('id', shopId)
          .eq('owner_id', user.id)
          .eq('is_active', true)
          .maybeSingle();

      if (shopOwnership == null) {
        throw Exception('Access denied: You do not own this shop or the shop is inactive');
      }

      print('✅ Shop ownership verified: ${shopOwnership['shop_name']}');

      // Get category information
      final categoryResponse = await _supabase
          .from('service_categories')
          .select('*')
          .eq('id', categoryId)
          .single();

      print('📋 Category: ${categoryResponse['name']}');

      // Check if this service already exists in THIS SPECIFIC SHOP
      final existing = await _supabase
          .from('shop_services')
          .select('id, service_name')
          .eq('shop_id', shopId)
          .eq('category_id', categoryId)
          .eq('is_active', true)
          .maybeSingle();

      if (existing != null) {
        throw Exception('${categoryResponse['name']} is already added to your shop');
      }

      // Prepare service data with explicit shop isolation
      final serviceData = {
        'shop_id': shopId,  // Explicit shop assignment
        'category_id': categoryId,
        'service_name': categoryResponse['name'],
        'description': categoryResponse['description'],
        'base_price': categoryResponse['base_price'],
        'custom_price': customPrice ?? categoryResponse['base_price'],
        'estimated_duration': categoryResponse['estimated_duration'] ?? 30,
        'is_active': true,
        'is_custom': false,
        'is_default': false,
        'availability_status': 'available',
        'service_quality_level': 'standard',
        'requires_appointment': false,
        'advance_notice_hours': 0,
        'display_priority': 1,
        'is_featured': false,
      };

      print('📦 Inserting service data: $serviceData');

      // Add the new service to shop_services table with RLS-compliant method
      final result = await _supabase
          .from('shop_services')
          .insert(serviceData)
          .select('id, service_name, shop_id');

      print('✅ Shop service added successfully: $result');
      
      // Verify the service was added to the correct shop only
      final verification = await _supabase
          .from('shop_services')
          .select('shop_id, service_name')
          .eq('id', result.first['id'])
          .single();
      
      if (verification['shop_id'] != shopId) {
        throw Exception('ERROR: Service was added to wrong shop! Expected: $shopId, Got: ${verification['shop_id']}');
      }
      
      print('✅ Service isolation verified: ${verification['service_name']} belongs to shop $shopId');
      
    } catch (e) {
      print('❌ Error adding shop service: $e');
      rethrow;
    }
  }

  // Add a custom service to the shop with enhanced shop isolation
  Future<void> addCustomShopService(String serviceName, String description, double? price) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      print('🔧 Adding custom service: $serviceName, description: $description, price: $price');
      print('🔐 Current user ID: ${user.id}');

      // FORCE REFRESH shop ID to avoid cache issues
      print('🔄 Clearing cache and fetching fresh shop ID...');
      clearCache();
      final shopId = await getCurrentShopId(forceRefresh: true);
      if (shopId == null) {
        throw Exception('No shop found for user. Please complete your shop profile first.');
      }

      print('🏪 Target shop ID: $shopId');

      // Verify shop ownership to prevent cross-shop contamination
      final shopOwnership = await _supabase
          .from('shops')
          .select('id, owner_id, shop_name')
          .eq('id', shopId)
          .eq('owner_id', user.id)
          .eq('is_active', true)
          .maybeSingle();

      if (shopOwnership == null) {
        throw Exception('Access denied: You do not own this shop or the shop is inactive');
      }

      print('✅ Shop ownership verified: ${shopOwnership['shop_name']}');

      // Check if a custom service with this name already exists in THIS SPECIFIC SHOP
      final existing = await _supabase
          .from('shop_services')
          .select('id, service_name')
          .eq('shop_id', shopId)
          .eq('service_name', serviceName)
          .eq('is_custom', true)
          .eq('is_active', true)
          .maybeSingle();

      if (existing != null) {
        throw Exception('A custom service named "$serviceName" already exists in your shop');
      }

      // Prepare custom service data with explicit shop isolation
      final serviceData = {
        'shop_id': shopId,  // Explicit shop assignment
        'category_id': null,  // NULL for custom services
        'service_name': serviceName,
        'description': description.isNotEmpty ? description : serviceName,
        'base_price': price ?? 0.00,
        'custom_price': price,
        'estimated_duration': 30,
        'is_active': true,
        'is_default': false,
        'availability_status': 'available',
        'service_quality_level': 'standard',
        'requires_appointment': false,
        'advance_notice_hours': 0,
        'display_priority': 999,
        'is_custom_service': true,  // For backward compatibility
        'is_custom': true,          // Main custom service flag
        'custom_name': serviceName,
        'custom_description': description,
        'is_featured': false,
      };

      print('📦 Inserting custom service data: $serviceData');

      // Add the custom service with RLS-compliant method
      final result = await _supabase
          .from('shop_services')
          .insert(serviceData)
          .select('id, service_name, shop_id, is_custom');

      print('✅ Custom service added successfully: $result');
      
      // Verify the service was added to the correct shop only
      final verification = await _supabase
          .from('shop_services')
          .select('shop_id, service_name, is_custom')
          .eq('id', result.first['id'])
          .single();
      
      if (verification['shop_id'] != shopId) {
        throw Exception('ERROR: Custom service was added to wrong shop! Expected: $shopId, Got: ${verification['shop_id']}');
      }
      
      if (verification['is_custom'] != true) {
        throw Exception('ERROR: Service was not marked as custom!');
      }
      
      print('✅ Custom service isolation verified: ${verification['service_name']} belongs to shop $shopId');
      
    } catch (e) {
      print('❌ Error adding custom service: $e');
      rethrow;
    }
  }

  // Update an existing shop service
  Future<void> updateShopService(String serviceId, String categoryId, double? customPrice) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      print('📝 Updating shop service: $serviceId');

      // Get the user's shop ID
      final shopId = await getCurrentShopId();
      if (shopId == null) {
        throw Exception('No shop found for user');
      }

      await _supabase
          .from('shop_services')
          .update({
            'category_id': categoryId,
            'custom_price': customPrice,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', serviceId)
          .eq('shop_id', shopId);

      print('✅ Shop service updated successfully');
    } catch (e) {
      print('❌ Error updating shop service: $e');
      rethrow;
    }
  }

  // Remove a service from the shop
  Future<void> removeShopService(String serviceId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      print('🗑️ Removing shop service: $serviceId');

      // Get the user's shop ID
      final shopId = await getCurrentShopId();
      if (shopId == null) {
        throw Exception('No shop found for user');
      }

      // Instead of deleting, mark as inactive
      await _supabase
          .from('shop_services')
          .update({
            'is_active': false,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', serviceId)
          .eq('shop_id', shopId);

      print('✅ Shop service removed successfully');
    } catch (e) {
      print('❌ Error removing shop service: $e');
      rethrow;
    }
  }

  // Toggle service availability
  Future<void> toggleServiceAvailability(String serviceId, bool isAvailable) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      print('🔄 Toggling service availability: $serviceId to $isAvailable');

      // Get the user's shop ID
      final shopId = await getCurrentShopId();
      if (shopId == null) {
        throw Exception('No shop found for user');
      }

      await _supabase
          .from('shop_services')
          .update({
            'is_active': isAvailable,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', serviceId)
          .eq('shop_id', shopId);

      print('✅ Service availability updated successfully');
    } catch (e) {
      print('❌ Error updating service availability: $e');
      rethrow;
    }
  }

  // Get available service categories that can be added
  Future<List<Map<String, dynamic>>> getAvailableServiceCategories() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      print('🔍 Loading available service categories');

      // Get all active categories that are not already added by this provider
      final response = await _supabase
          .from('service_categories')
          .select('*')
          .eq('is_active', true)
          .not('id', 'in', '(${await _getProviderServiceCategoryIds()})')
          .order('name');

      print('✅ Loaded ${response.length} available service categories');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('❌ Error loading available service categories: $e');
      rethrow;
    }
  }

  // Helper method to get category IDs already added by the provider
  Future<String> _getProviderServiceCategoryIds() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return '';

      // Get the user's service provider ID
      final providerResponse = await _supabase
          .from('service_providers')
          .select('id')
          .eq('user_id', user.id)
          .maybeSingle();

      if (providerResponse == null) return '';
      
      final providerId = providerResponse['id'];

      final response = await _supabase
          .from('provider_services')
          .select('category_id')
          .eq('provider_id', providerId)
          .eq('is_available', true);

      if (response.isEmpty) return '';
      
      return response.map((item) => "'${item['category_id']}'").join(',');
    } catch (e) {
      print('⚠️ Error getting provider service category IDs: $e');
      return '';
    }
  }

  // Check and update PayMongo payment status
  Future<void> _checkAndUpdatePaymentStatus(String requestId) async {
    try {
      print('🔍 Checking payment status for request: $requestId');
      
      final requestData = await _supabase
          .from('service_requests')
          .select('payment_status, payment_method, final_price, status')
          .eq('id', requestId)
          .single();

      final paymentMethod = requestData['payment_method'];
      final currentPaymentStatus = requestData['payment_status'];
      final finalPrice = requestData['final_price'];
      final currentStatus = requestData['status'];
      
      print('💳 Payment details:');
      print('   Status: $currentPaymentStatus');
      print('   Final Price: $finalPrice');
      print('   Method: $paymentMethod');
      print('   Request Status: $currentStatus');
      
      // If payment status is already completed, no need to update payment info
      if (currentPaymentStatus == 'completed') {
        print('✅ Payment already marked as completed');
        
        // But check if status needs to be updated to ready_to_assign
        if (currentStatus == 'awaiting_payment') {
          await _supabase
              .from('service_requests')
              .update({
                'status': 'ready_to_assign',
                'updated_at': DateTime.now().toUtc().toIso8601String(),
              })
              .eq('id', requestId);
          print('✅ Status updated from awaiting_payment to ready_to_assign');
        }
        return;
      }

      // Check if payment is actually received through PayMongo integration
      if (currentPaymentStatus == 'paid' && paymentMethod != null) {
        // Update payment status to completed
        await _supabase
            .from('service_requests')
            .update({
              'payment_status': 'completed',
              'status': 'ready_to_assign', // Also update status if payment is complete
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            })
            .eq('id', requestId);
            
        print('✅ Payment status updated to completed and status to ready_to_assign');
      } else {
        print('ℹ️ Payment not yet received or no payment method specified');
        print('   Current payment status: $currentPaymentStatus');
        print('   Expected: "completed" or "paid"');
      }
    } catch (e) {
      print('❌ Error checking payment status: $e');
      // Don't throw error, just log it to avoid blocking the flow
    }
  }

  // ============================================================================
  // COMPREHENSIVE DASHBOARD DATA METHODS
  // ============================================================================

  /// Get complete dashboard data in a single call
  /// Includes shop info, mechanics, requests, earnings, and ratings
  Future<Map<String, dynamic>> getCompleteDashboardData() async {
    try {
      final shopId = await getCurrentShopId();
      if (shopId == null) {
        throw Exception('No shop found for current user');
      }

      // Fetch all data in parallel for better performance
      final results = await Future.wait([
        getShopInfo(),
        getShopMechanics(),
        getServiceRequestsByStatus(),
        getEarningsReport(),
        getCustomerFeedbackAndRatings(),
        getCompletedJobHistory(),
      ]);

      return {
        'shop_info': results[0],
        'mechanics': results[1],
        'service_requests': results[2],
        'earnings': results[3],
        'feedback_and_ratings': results[4],
        'job_history': results[5],
        'last_updated': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      print('❌ Error getting complete dashboard data: $e');
      rethrow;
    }
  }

  /// Get service requests organized by status
  Future<Map<String, List<Map<String, dynamic>>>> getServiceRequestsByStatus() async {
    try {
      final shopId = await getCurrentShopId();
      if (shopId == null) {
        return {
          'pending': [],
          'accepted': [],
          'in_progress': [],
          'completed': [],
          'cancelled': [],
        };
      }

      // Get all service requests for this shop
      final requests = await _supabase
          .from('service_requests')
          .select('''
            *,
            customer:user_profiles!service_requests_customer_id_fkey(
              id, first_name, last_name, phone_number, profile_image_url
            ),
            assigned_mechanic:user_profiles!service_requests_assigned_mechanic_id_fkey(
              id, first_name, last_name, phone_number, profile_image_url, rating
            ),
            category:service_categories(name, icon_name)
          ''')
          .eq('shop_id', shopId)
          .order('created_at', ascending: false);

      // Organize by status
      final Map<String, List<Map<String, dynamic>>> organized = {
        'pending': [],
        'accepted': [],
        'in_progress': [],
        'completed': [],
        'cancelled': [],
      };

      for (final request in requests) {
        final status = request['status']?.toString().toLowerCase() ?? 'pending';
        
        if (organized.containsKey(status)) {
          organized[status]!.add(request);
        } else if (status == 'awaiting_payment' || status == 'ready_to_assign') {
          organized['pending']!.add(request);
        } else if (status == 'inspection_completed' || status == 'invoice_sent') {
          organized['in_progress']!.add(request);
        }
      }

      return organized;
    } catch (e) {
      print('❌ Error getting service requests by status: $e');
      return {
        'pending': [],
        'accepted': [],
        'in_progress': [],
        'completed': [],
        'cancelled': [],
      };
    }
  }

  /// Get customer feedback and ratings for shop services
  Future<Map<String, dynamic>> getCustomerFeedbackAndRatings() async {
    try {
      final shopId = await getCurrentShopId();
      if (shopId == null) {
        return {
          'average_rating': 0.0,
          'total_reviews': 0,
          'rating_distribution': {'5': 0, '4': 0, '3': 0, '2': 0, '1': 0},
          'recent_feedback': [],
        };
      }

      // Get all completed service requests with ratings
      final completedRequests = await _supabase
          .from('service_requests')
          .select('''
            id,
            rating,
            created_at,
            completed_at,
            customer:user_profiles!service_requests_customer_id_fkey(
              id, first_name, last_name, profile_image_url
            ),
            assigned_mechanic:user_profiles!service_requests_assigned_mechanic_id_fkey(
              id, first_name, last_name
            )
          ''')
          .eq('shop_id', shopId)
          .eq('status', 'completed')
          .not('rating', 'is', null)
          .order('completed_at', ascending: false)
          .limit(50);

      // Get reviews from reviews table
      final reviews = await _supabase
          .from('reviews')
          .select('''
            *,
            customer:user_profiles!reviews_customer_id_fkey(
              id, first_name, last_name, profile_image_url
            ),
            request:service_requests!reviews_request_id_fkey(
              id, title, completed_at,
              assigned_mechanic:user_profiles!service_requests_assigned_mechanic_id_fkey(
                id, first_name, last_name
              )
            )
          ''')
          .eq('provider_id', shopId)
          .order('created_at', ascending: false)
          .limit(20);

      // Calculate statistics
      double totalRating = 0.0;
      int ratingCount = 0;
      Map<String, int> distribution = {'5': 0, '4': 0, '3': 0, '2': 0, '1': 0};

      // Process service request ratings
      for (final request in completedRequests) {
        if (request['rating'] != null) {
          final rating = (request['rating'] as num).toDouble();
          totalRating += rating;
          ratingCount++;
          
          final ratingKey = rating.round().toString();
          if (distribution.containsKey(ratingKey)) {
            distribution[ratingKey] = distribution[ratingKey]! + 1;
          }
        }
      }

      // Process review ratings
      for (final review in reviews) {
        if (review['rating'] != null) {
          final rating = (review['rating'] as num).toDouble();
          totalRating += rating;
          ratingCount++;
          
          final ratingKey = rating.round().toString();
          if (distribution.containsKey(ratingKey)) {
            distribution[ratingKey] = distribution[ratingKey]! + 1;
          }
        }
      }

      final averageRating = ratingCount > 0 ? totalRating / ratingCount : 0.0;

      // Format recent feedback
      final List<Map<String, dynamic>> recentFeedback = [];
      
      for (final review in reviews) {
        recentFeedback.add({
          'id': review['id'],
          'rating': review['rating'],
          'comment': review['comment'],
          'customer_name': review['customer'] != null
              ? '${review['customer']['first_name']} ${review['customer']['last_name']}'
              : 'Anonymous',
          'customer_image': review['customer']?['profile_image_url'],
          'mechanic_name': review['request']?['assigned_mechanic'] != null
              ? '${review['request']['assigned_mechanic']['first_name']} ${review['request']['assigned_mechanic']['last_name']}'
              : null,
          'service_title': review['request']?['title'],
          'completed_at': review['request']?['completed_at'],
          'created_at': review['created_at'],
        });
      }

      return {
        'average_rating': averageRating,
        'total_reviews': ratingCount,
        'rating_distribution': distribution,
        'recent_feedback': recentFeedback,
      };
    } catch (e) {
      print('❌ Error getting customer feedback and ratings: $e');
      return {
        'average_rating': 0.0,
        'total_reviews': 0,
        'rating_distribution': {'5': 0, '4': 0, '3': 0, '2': 0, '1': 0},
        'recent_feedback': [],
      };
    }
  }

  /// Get completed job history with mechanic details
  Future<List<Map<String, dynamic>>> getCompletedJobHistory({int limit = 50}) async {
    try {
      final shopId = await getCurrentShopId();
      if (shopId == null) return [];

      final jobs = await _supabase
          .from('mechanic_job_history')
          .select('''
            *,
            mechanic:user_profiles!mechanic_job_history_mechanic_id_fkey(
              id, first_name, last_name, phone_number, profile_image_url, rating
            ),
            customer:user_profiles!mechanic_job_history_customer_id_fkey(
              id, first_name, last_name, phone_number
            ),
            service_request:service_requests!mechanic_job_history_service_request_id_fkey(
              id, title, pickup_address, category:service_categories(name)
            )
          ''')
          .eq('shop_id', shopId)
          .eq('job_status', 'completed')
          .order('completed_at', ascending: false)
          .limit(limit);

      return jobs.map((job) {
        return {
          'id': job['id'],
          'job_title': job['job_title'],
          'job_description': job['job_description'],
          'total_amount': job['total_amount'],
          'mechanic_earnings': job['mechanic_earnings'],
          'shop_earnings': job['shop_earnings'],
          'platform_fee': job['platform_fee'],
          'rating': job['rating'],
          'review_text': job['review_text'],
          'completed_at': job['completed_at'],
          'job_duration_minutes': job['job_duration_minutes'],
          'mechanic': {
            'id': job['mechanic']?['id'],
            'name': job['mechanic'] != null
                ? '${job['mechanic']['first_name']} ${job['mechanic']['last_name']}'
                : 'Unknown',
            'phone': job['mechanic']?['phone_number'],
            'image': job['mechanic']?['profile_image_url'],
            'rating': job['mechanic']?['rating'],
          },
          'customer': {
            'id': job['customer']?['id'],
            'name': job['customer'] != null
                ? '${job['customer']['first_name']} ${job['customer']['last_name']}'
                : 'Unknown',
            'phone': job['customer']?['phone_number'],
          },
          'service_info': {
            'title': job['service_request']?['title'],
            'address': job['service_request']?['pickup_address'],
            'category': job['service_request']?['category']?['name'],
          },
        };
      }).toList();
    } catch (e) {
      print('❌ Error getting completed job history: $e');
      return [];
    }
  }

  /// Get earnings summary by time period (daily, weekly, monthly)
  Future<Map<String, dynamic>> getEarningsSummary() async {
    try {
      final shopId = await getCurrentShopId();
      if (shopId == null) {
        return {
          'daily': {'total': 0.0, 'shop_earnings': 0.0, 'jobs_count': 0},
          'weekly': {'total': 0.0, 'shop_earnings': 0.0, 'jobs_count': 0},
          'monthly': {'total': 0.0, 'shop_earnings': 0.0, 'jobs_count': 0},
        };
      }

      final now = DateTime.now().toUtc();
      final todayStart = DateTime(now.year, now.month, now.day).toUtc();
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      final weekStartDay = DateTime(weekStart.year, weekStart.month, weekStart.day).toUtc();
      final monthStart = DateTime(now.year, now.month, 1).toUtc();

      // Get daily earnings
      final dailyJobs = await _supabase
          .from('mechanic_job_history')
          .select('total_amount, shop_earnings')
          .eq('shop_id', shopId)
          .eq('job_status', 'completed')
          .gte('completed_at', todayStart.toIso8601String());

      // Get weekly earnings
      final weeklyJobs = await _supabase
          .from('mechanic_job_history')
          .select('total_amount, shop_earnings')
          .eq('shop_id', shopId)
          .eq('job_status', 'completed')
          .gte('completed_at', weekStartDay.toIso8601String());

      // Get monthly earnings
      final monthlyJobs = await _supabase
          .from('mechanic_job_history')
          .select('total_amount, shop_earnings')
          .eq('shop_id', shopId)
          .eq('job_status', 'completed')
          .gte('completed_at', monthStart.toIso8601String());

      double calcTotal(List<dynamic> jobs) {
        return jobs.fold(0.0, (sum, job) => sum + ((job['total_amount'] as num?)?.toDouble() ?? 0.0));
      }

      double calcShopEarnings(List<dynamic> jobs) {
        return jobs.fold(0.0, (sum, job) => sum + ((job['shop_earnings'] as num?)?.toDouble() ?? 0.0));
      }

      return {
        'daily': {
          'total': calcTotal(dailyJobs),
          'shop_earnings': calcShopEarnings(dailyJobs),
          'jobs_count': dailyJobs.length,
        },
        'weekly': {
          'total': calcTotal(weeklyJobs),
          'shop_earnings': calcShopEarnings(weeklyJobs),
          'jobs_count': weeklyJobs.length,
        },
        'monthly': {
          'total': calcTotal(monthlyJobs),
          'shop_earnings': calcShopEarnings(monthlyJobs),
          'jobs_count': monthlyJobs.length,
        },
      };
    } catch (e) {
      print('❌ Error getting earnings summary: $e');
      return {
        'daily': {'total': 0.0, 'shop_earnings': 0.0, 'jobs_count': 0},
        'weekly': {'total': 0.0, 'shop_earnings': 0.0, 'jobs_count': 0},
        'monthly': {'total': 0.0, 'shop_earnings': 0.0, 'jobs_count': 0},
      };
    }
  }

}
