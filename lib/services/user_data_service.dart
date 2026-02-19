import 'dart:convert' show json;
import 'dart:math' as math;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import 'talyer_owner_service.dart';
import 'paymongo_service.dart';

class UserDataService {
  static final SupabaseClient _client = SupabaseService.client;
  
  // Get current user ID or throw error if not logged in
  static String get _currentUserId {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('User must be logged in to perform this operation');
    }
    return userId;
  }
  
  // Check if user is logged in
  static bool get isLoggedIn => _client.auth.currentUser != null;

  // ========================================
  // PAYMENT METHOD OPERATIONS
  // ========================================
  
  /// Get all payment methods for the current user
  static Future<List<Map<String, dynamic>>> getPaymentMethods() async {
    final userId = _currentUserId;

    try {
      final response = await SupabaseService.client
          .from('payment_methods')
          .select('*')
          .eq('user_id', userId) // This should match your payment_methods table schema
          .eq('is_active', true)
          .order('is_default', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('❌ Error fetching payment methods: $e');
      throw Exception('Failed to load payment methods: $e');
    }
  }

  /// Add a new payment method
  static Future<Map<String, dynamic>> addPaymentMethod({
    required String methodType,
    required String displayName,
    bool isDefault = false,
    String? cardLastFour,
    String? cardBrand,
    String? gcashNumber,
    String? paymayaNumber,
  }) async {
    final userId = _currentUserId; // Changed from AuthService.instance.userId

    try {
      // If this is set as default, unset other default payment methods
      if (isDefault) {
        await SupabaseService.client
            .from('payment_methods')
            .update({'is_default': false})
            .eq('user_id', userId);
      }

      final paymentMethodData = {
        'user_id': userId,
        'method_type': methodType,
        'display_name': displayName,
        'is_default': isDefault,
        'card_last_four': cardLastFour,
        'card_brand': cardBrand,
        'gcash_number': gcashNumber,
        'paymaya_number': paymayaNumber,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      final response = await SupabaseService.client
          .from('payment_methods')
          .insert(paymentMethodData)
          .select()
          .single();

      return response;
    } catch (e) {
      print('❌ Error adding payment method: $e');
      throw Exception('Failed to add payment method: $e');
    }
  }

  /// Set a payment method as default
  static Future<void> setDefaultPaymentMethod(String paymentMethodId) async {
    final userId = _currentUserId; // Changed from AuthService.instance.userId

    try {
      // First, unset all default payment methods for this user
      await SupabaseService.client
          .from('payment_methods')
          .update({'is_default': false})
          .eq('user_id', userId);

      // Then set the selected one as default
      await SupabaseService.client
          .from('payment_methods')
          .update({
            'is_default': true,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', paymentMethodId)
          .eq('user_id', userId);
    } catch (e) {
      print('❌ Error setting default payment method: $e');
      throw Exception('Failed to set default payment method: $e');
    }
  }

  /// Delete a payment method
  static Future<void> deletePaymentMethod(String paymentMethodId) async {
    final userId = _currentUserId; // Changed from AuthService.instance.userId

    try {
      await SupabaseService.client
          .from('payment_methods')
          .delete()
          .eq('id', paymentMethodId)
          .eq('user_id', userId);
    } catch (e) {
      print('❌ Error deleting payment method: $e');
      throw Exception('Failed to delete payment method: $e');
    }
  }

  // ========================================
  // PAYMENT OPERATIONS
  // ========================================
  
  /// Record a payment
  static Future<String> recordPayment({
    required String serviceRequestId,
    required String paymentMethodId,
    required double amount,
    String? transactionId,
    Map<String, dynamic>? providerResponse,  }) async {
    try {
      final paymentData = {
        'service_request_id': serviceRequestId,
        'payment_method_id': paymentMethodId,
        'amount': amount,
        'status': 'pending',
        'transaction_id': transactionId,
        'provider_response': providerResponse,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      final response = await SupabaseService.client
          .from('payments')
          .insert(paymentData)
          .select()
          .single();

      return response['id'];
    } catch (e) {
      print('❌ Error recording payment: $e');
      throw Exception('Failed to record payment: $e');
    }
  }

  /// Update payment status
  static Future<void> updatePaymentStatus({
    required String paymentId,
    required String status,
    String? transactionId,
    Map<String, dynamic>? providerResponse,
  }) async {
    try {
      final updateData = {
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (status == 'completed') {
        updateData['paid_at'] = DateTime.now().toIso8601String();
      }

      if (transactionId != null) {
        updateData['transaction_id'] = transactionId;
      }      if (providerResponse != null) {
        updateData['provider_response'] = json.encode(providerResponse);
      }

      await SupabaseService.client
          .from('payments')
          .update(updateData)
          .eq('id', paymentId);
    } catch (e) {
      print('❌ Error updating payment status: $e');
      throw Exception('Failed to update payment status: $e');
    }
  }

  /// Get payment history for current user
  static Future<List<Map<String, dynamic>>> getPaymentHistory() async {
    final userId = _currentUserId;

    try {
      print('🔧 UserDataService.getPaymentHistory() - Getting payments for user: $userId');
      
      // Get basic payment data
      final paymentsResponse = await SupabaseService.client
          .from('payments')
          .select('*')
          .order('created_at', ascending: false);

      print('🔧 Found ${paymentsResponse.length} payments, enriching with related data...');
      
      List<Map<String, dynamic>> enrichedPayments = [];
      
      for (final payment in paymentsResponse) {
        final enrichedPayment = Map<String, dynamic>.from(payment);
        
        // Get service request data
        if (payment['service_request_id'] != null) {
          try {
            final serviceRequest = await SupabaseService.client
                .from('service_requests')
                .select('id, title, description, created_at, customer_id')
                .eq('id', payment['service_request_id'])
                .single();
            
            // Only include payments for this user's service requests
            if (serviceRequest['customer_id'] == userId) {
              enrichedPayment['service_requests'] = serviceRequest;
              
              // Get payment method data
              if (payment['payment_method_id'] != null) {
                try {
                  final paymentMethod = await SupabaseService.client
                      .from('payment_methods')
                      .select('display_name, method_type')
                      .eq('id', payment['payment_method_id'])
                      .single();
                  enrichedPayment['payment_methods'] = paymentMethod;
                } catch (e) {
                  print('Warning: Could not fetch payment method: $e');
                }
              }
              
              enrichedPayments.add(enrichedPayment);
            }
          } catch (e) {
            print('Warning: Could not fetch service request for payment ${payment['id']}: $e');
          }
        }
      }

      print('🔧 Payment history enriched successfully: ${enrichedPayments.length} payments');
      return enrichedPayments;
    } catch (e) {
      print('❌ Error fetching payment history: $e');
      throw Exception('Failed to load payment history: $e');
    }
  }

  // ========================================
  // EXISTING METHODS (USER PROFILE, VEHICLES, SERVICE REQUESTS)
  // ========================================
  
  /// Create user profile (called during signup)
  static Future<void> createUserProfile({
    required String firstName,
    required String lastName,
    required String email,
    required String phoneNumber,
  }) async {
    final userId = _currentUserId;
    
    await _client.from('user_profiles').insert({
      'id': userId,
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'phone_number': phoneNumber,
      'status': 'active',
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });
  }
  
  /// Get current user's profile
  static Future<Map<String, dynamic>> getUserProfile() async {
    final userId = _currentUserId;
    
    return await _client
        .from('user_profiles')
        .select()
        .eq('id', userId)
        .single();
  }
  
  /// Update current user's profile
  static Future<void> updateUserProfile(Map<String, dynamic> updates) async {
    final userId = _currentUserId;
    
    await _client
        .from('user_profiles')
        .update({
          ...updates,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', userId);
  }

  /// Get all vehicles for the current user
  static Future<List<Map<String, dynamic>>> getUserVehicles() async {
    final userId = _currentUserId;

    try {
      final response = await SupabaseService.client
          .from('vehicles')
          .select('*')
          .eq('user_id', userId) // Make sure your vehicles table has user_id column
          .order('is_primary', ascending: false)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('❌ Error fetching user vehicles: $e');
      throw Exception('Failed to load vehicles: $e');
    }
  }

  /// Add a vehicle for the current user
  static Future<Map<String, dynamic>> addVehicle({
    required String brandName,
    required String modelName,
    required int year,
    String? color,
    String? plateNumber,
    String vehicleType = 'car',
    bool isPrimary = false,
    // Legacy support
    String? make,
    String? model,
    String? licensePlate,
  }) async {
    final userId = _currentUserId; // Changed from AuthService.instance.userId

    try {
      if (isPrimary) {
        await SupabaseService.client
            .from('vehicles')
            .update({'is_primary': false})
            .eq('user_id', userId);
      }      final vehicleData = {
        'user_id': userId,
        'brand_name': brandName,
        'model_name': modelName,
        'year': year,
        'color': color,
        'plate_number': plateNumber ?? licensePlate,
        'vehicle_type': vehicleType,
        'is_primary': isPrimary,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      final response = await SupabaseService.client
          .from('vehicles')
          .insert(vehicleData)
          .select()
          .single();

      return response;
    } catch (e) {
      print('❌ Error adding vehicle: $e');
      throw Exception('Failed to add vehicle: $e');
    }
  }

  /// Update a vehicle
  static Future<void> updateVehicle(String vehicleId, Map<String, dynamic> updates) async {
    final userId = _currentUserId; // Changed from AuthService.instance.userId
    
    try {
      if (updates['is_primary'] == true) {
        await SupabaseService.client
            .from('vehicles')
            .update({'is_primary': false})
            .eq('user_id', userId);
      }
      
      await SupabaseService.client
          .from('vehicles')
          .update({
            ...updates,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', vehicleId)
          .eq('user_id', userId);
    } catch (e) {
      print('❌ Error updating vehicle: $e');
      throw Exception('Failed to update vehicle: $e');
    }
  }
  
  /// Delete a vehicle
  static Future<void> deleteVehicle(String vehicleId) async {
    final userId = _currentUserId; // Changed from AuthService.instance.userId
    
    try {
      await SupabaseService.client
          .from('vehicles')
          .delete()
          .eq('id', vehicleId)
          .eq('user_id', userId);
    } catch (e) {
      print('❌ Error deleting vehicle: $e');
      throw Exception('Failed to delete vehicle: $e');
    }
  }

  /// Create a new service request
  static Future<Map<String, dynamic>> createServiceRequest({
    required String vehicleId,
    required String issueType,
    required String description,
    required double latitude,
    required double longitude,
    String? title,
    double? estimatedCost,
  }) async {
    final userId = _currentUserId;

    try {
      // Get or create category_id based on issue type
      String categoryId = await _getCategoryId(issueType);
      
      final response = await SupabaseService.client
          .from('service_requests')
          .insert({
            'customer_id': userId,
            'vehicle_id': vehicleId,
            'category_id': categoryId, // Add the required category_id
            'title': title ?? _mapIssueTypeToTitle(issueType),
            'description': description,
            'pickup_latitude': latitude,
            'pickup_longitude': longitude,
            'status': 'pending',
            'payment_status': 'pending',
            'created_at': DateTime.now().toIso8601String(), // Use created_at instead of requested_at
          })
          .select()
          .single();

      return response;
    } catch (e) {
      print('❌ Error creating service request: $e');
      throw Exception('Failed to create service request: $e');
    }
  }

  /// Helper method to get category_id based on issue type
  static Future<String> _getCategoryId(String issueType) async {
    try {
      // Map issue type to category name
      String categoryName = _mapIssueTypeToCategory(issueType);
      
      // Try to find existing category
      final response = await SupabaseService.client
          .from('service_categories')
          .select('id')
          .eq('name', categoryName)
          .maybeSingle();
      
      if (response != null) {
        return response['id'];
      }
      
      // If category doesn't exist, create it
      final newCategory = await SupabaseService.client
          .from('service_categories')
          .insert({
            'name': categoryName,
            'description': _getCategoryDescription(issueType),
            'is_active': true,
          })
          .select('id')
          .single();
      
      return newCategory['id'];
    } catch (e) {
      print('❌ Error getting/creating category: $e');
      
      // Fallback: try to get any existing category or create a default one
      try {
        final fallbackResponse = await SupabaseService.client
            .from('service_categories')
            .select('id')
            .limit(1)
            .maybeSingle();
        
        if (fallbackResponse != null) {
          print('⚠️ Using fallback category');
          return fallbackResponse['id'];
        }
        
        // Create a default category if none exist
        final defaultCategory = await SupabaseService.client
            .from('service_categories')
            .insert({
              'name': 'General Service',
              'description': 'General automotive assistance',
              'is_active': true,
            })
            .select('id')
            .single();
        
        return defaultCategory['id'];
      } catch (fallbackError) {
        print('❌ Fallback category creation failed: $fallbackError');
        throw Exception('Failed to get or create category: $e');
      }
    }
  }

  /// Helper method to map issue types to category names
  static String _mapIssueTypeToCategory(String issueType) {
    switch (issueType.toLowerCase()) {
      case 'mechanical':
        return 'Mechanical Repair';
      case 'electrical':
        return 'Electrical Repair';
      case 'tire':
        return 'Tire Service';
      case 'fuel':
        return 'Fuel Service';
      case 'towing':
        return 'Towing Service';
      case 'lockout':
        return 'Lockout Service';
      case 'other':
        return 'General Service';
      default:
        return 'General Service';
    }
  }

  /// Helper method to map issue types to titles
  static String _mapIssueTypeToTitle(String issueType) {
    switch (issueType.toLowerCase()) {
      case 'mechanical':
        return 'Mechanical Issue';
      case 'electrical':
        return 'Electrical Issue';
      case 'tire':
        return 'Tire Issue';
      case 'fuel':
        return 'Fuel Issue';
      case 'towing':
        return 'Towing Service';
      case 'lockout':
        return 'Lockout Service';
      case 'other':
        return 'Other Issue';
      default:
        return 'Service Request';
    }
  }

  /// Helper method to get category descriptions
  static String _getCategoryDescription(String issueType) {
    switch (issueType.toLowerCase()) {
      case 'mechanical':
        return 'Engine problems, overheating, mechanical repairs';
      case 'electrical':
        return 'Battery, lights, starting problems';
      case 'tire':
        return 'Flat tire, tire replacement, tire repair';
      case 'fuel':
        return 'Out of gas, fuel system issues';
      case 'lockout':
        return 'Car lockout and key-related assistance';
      case 'towing':
        return 'Vehicle transport and towing services';
      case 'other':
        return 'General automotive assistance and other services';
      default:
        return 'General automotive assistance';
    }
  }
  // Update the getUserServiceRequests method to match your schema
  static Future<List<Map<String, dynamic>>> getUserServiceRequests() async {
    final userId = _currentUserId;

    try {
      final response = await SupabaseService.client
          .from('service_requests')
          .select('''
            id,
            title,
            description,
            service_type,
            status,
            priority,
            payment_method,
            payment_status,
            estimated_price,
            final_price,
            pickup_address,
            pickup_latitude,
            pickup_longitude,
            assigned_at,
            service_start_time,
            service_completion_time,
            completed_at,
            cancelled_at,
            notes,
            created_at,
            updated_at,
            service_providers(
              id,
              company_name,
              rating,
              user_profiles!service_providers_user_id_fkey(
                first_name,
                last_name,
                phone_number,
                email,
                current_latitude,
                current_longitude
              )
            ),
            vehicles(
              id,
              brand_name,
              model_name,
              year,
              vehicle_type,
              plate_number,
              color
            ),
            service_categories(
              id,
              name,
              description,
              icon_name,
              base_price
            ),
            invoices(
              id,
              invoice_number,
              issued_at,
              status,
              subtotal,
              platform_fee,
              total_amount,
              provider_net_amount,
              notes
            )
          ''')
          .eq('customer_id', userId)
          .order('created_at', ascending: false);

      // Convert response to a typed list and return
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('❌ Error fetching service requests: $e');
      throw Exception('Failed to load service requests: $e');
    }
  }

  /// Create payment record
  static Future<Map<String, dynamic>> createPayment({
    required String serviceRequestId,
    required String paymentMethodId,
    required double amount,
    required String transactionId,
    Map<String, dynamic>? providerResponse,
  }) async {
    try {
      final response = await SupabaseService.client
          .from('payments')
          .insert({
            // Note: Your payments table doesn't have user_id, only references through service_request
            'service_request_id': serviceRequestId,
            'payment_method_id': paymentMethodId,
            'amount': amount,
            'transaction_id': transactionId,
            'provider_response': providerResponse, // This is already jsonb in your schema
            'status': 'completed',
            'paid_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      print('✅ Payment created successfully');
      return response;
    } catch (e) {
      print('❌ Error creating payment: $e');
      throw Exception('Failed to create payment: $e');
    }
  }

  /// Create a review
  static Future<Map<String, dynamic>> createReview({
    required String serviceProviderId,
    required String serviceRequestId,
    required int rating,
    String? comment,
  }) async {
    final userId = _currentUserId;

    try {
      final response = await SupabaseService.client
          .from('reviews')
          .insert({
            'user_id': userId,
            'service_provider_id': serviceProviderId,
            'service_request_id': serviceRequestId,
            'rating': rating,
            'comment': comment,
          })
          .select()
          .single();

      return response;
    } catch (e) {
      print('❌ Error creating review: $e');
      throw Exception('Failed to create review: $e');
    }
  }

  /// Get reviews for a service provider
  static Future<List<Map<String, dynamic>>> getServiceProviderReviews(String serviceProviderId) async {
    try {
      final response = await SupabaseService.client
          .from('reviews')
          .select('''
            *,
            user_profiles (
              first_name,
              last_name
            )
          ''')
          .eq('service_provider_id', serviceProviderId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('❌ Error fetching reviews: $e');
      throw Exception('Failed to load reviews: $e');
    }
  }

  /// Submit a review for a completed service
  static Future<Map<String, dynamic>> submitReview({
    required String requestId,
    required String providerId,
    required int rating,
    String? comment,
  }) async {
    final userId = _currentUserId;

    try {
      // First check if review already exists
      final existingReview = await _client
          .from('reviews')
          .select('id')
          .eq('request_id', requestId)
          .eq('customer_id', userId)
          .maybeSingle();

      if (existingReview != null) {
        throw Exception('Review already submitted for this service');
      }

      // ✅ FIX: If providerId is actually a user_id (mechanic), look up the correct provider_id
      String actualProviderId = providerId;
      
      // Check if this is a user_id by querying service_providers table
      final providerCheck = await _client
          .from('service_providers')
          .select('id')
          .eq('id', providerId)
          .maybeSingle();
      
      if (providerCheck == null) {
        // This is likely a user_id (mechanic), so look up their provider record
        print('🔍 Provided ID is not a provider_id, looking up provider record for user: $providerId');
        
        final providerLookup = await _client
            .from('service_providers')
            .select('id')
            .eq('user_id', providerId)
            .maybeSingle();
        
        if (providerLookup != null) {
          actualProviderId = providerLookup['id'];
          print('✅ Found provider_id: $actualProviderId for user_id: $providerId');
        } else {
          throw Exception('Could not find service provider record for mechanic');
        }
      }

      final response = await _client
          .from('reviews')
          .insert({
            'request_id': requestId,
            'customer_id': userId,
            'provider_id': actualProviderId,
            'rating': rating,
            'comment': comment,
            'is_verified': true,
          })
          .select()
          .single();

      print('✅ Review submitted successfully');
      return {
        'success': true,
        'message': 'Review submitted successfully',
        'data': response,
      };
    } catch (e) {
      print('❌ Error submitting review: $e');
      throw Exception('Failed to submit review: $e');
    }
  }

  /// Check if user has already reviewed a service
  static Future<bool> hasUserReviewed(String requestId) async {
    final userId = _currentUserId;

    try {
      final response = await _client
          .from('reviews')
          .select('id')
          .eq('request_id', requestId)
          .eq('customer_id', userId)
          .maybeSingle();

      return response != null;
    } catch (e) {
      print('❌ Error checking review status: $e');
      return false;
    }
  }

  /// Get review for a specific service request
  static Future<Map<String, dynamic>?> getServiceReview(String requestId) async {
    final userId = _currentUserId;

    try {
      final response = await _client
          .from('reviews')
          .select('*')
          .eq('request_id', requestId)
          .eq('customer_id', userId)
          .maybeSingle();

      return response;
    } catch (e) {
      print('❌ Error fetching review: $e');
      return null;
    }
  }

  /// Get service request from the view (includes all related data)
  static Future<Map<String, dynamic>?> getServiceRequestFromView(String requestId) async {
    try {
      final response = await SupabaseService.client
          .from('service_request_history_view')
          .select()
          .eq('id', requestId)
          .single();
    
      return response;
    } catch (e) {
      print('Error getting service request from view: $e');
      return null;
    }
  }

  /// Get service request from the main table (for status updates)
  static Future<Map<String, dynamic>?> getServiceRequest(String requestId) async {
    try {
      print('🔧 UserDataService.getServiceRequest() - Getting service request: $requestId');
      
      // Get basic service request data
      final serviceRequest = await SupabaseService.client
          .from('service_requests')
          .select('*')
          .eq('id', requestId)
          .single();

      print('🔧 Service request found, enriching with related data...');
      
      // Get service category data
      Map<String, dynamic>? serviceCategory;
      if (serviceRequest['category_id'] != null) {
        try {
          serviceCategory = await SupabaseService.client
              .from('service_categories')
              .select('name, description, icon_name, base_price')
              .eq('id', serviceRequest['category_id'])
              .single();
        } catch (e) {
          print('Warning: Could not fetch service category: $e');
        }
      }
      
      // Get vehicle data
      Map<String, dynamic>? vehicle;
      if (serviceRequest['vehicle_id'] != null) {
        try {
          vehicle = await SupabaseService.client
              .from('vehicles')
              .select('brand_name, model_name, year, vehicle_type, plate_number')
              .eq('id', serviceRequest['vehicle_id'])
              .single();
        } catch (e) {
          print('Warning: Could not fetch vehicle data: $e');
        }
      }
      
      // Get customer data
      Map<String, dynamic>? customer;
      if (serviceRequest['customer_id'] != null) {
        try {
          customer = await SupabaseService.client
              .from('user_profiles')
              .select('first_name, last_name, email, phone_number')
              .eq('id', serviceRequest['customer_id'])
              .single();
        } catch (e) {
          print('Warning: Could not fetch customer data: $e');
        }
      }
      
      // Get service provider data
      Map<String, dynamic>? serviceProvider;
      if (serviceRequest['provider_id'] != null) {
        try {
          serviceProvider = await SupabaseService.client
              .from('service_providers')
              .select('company_name, license_number, years_experience')
              .eq('id', serviceRequest['provider_id'])
              .single();
        } catch (e) {
          print('Warning: Could not fetch service provider data: $e');
        }
      }
      
      // Combine all data
      final enrichedRequest = {
        ...serviceRequest,
        'service_categories': serviceCategory,
        'vehicles': vehicle,
        'user_profiles': customer,
        'service_providers': serviceProvider,
      };
      
      print('🔧 Service request enriched successfully');
      return enrichedRequest;
    } catch (e) {
      print('❌ Error getting service request: $e');
      return null;
    }
  }

  /// Update service request status (for mechanics to accept/reject)
  static Future<bool> updateServiceRequestStatus(String requestId, String status, {String? providerId}) async {
    try {
      print('🔧 Updating service request $requestId status to: $status');
      
      Map<String, dynamic> updateData = {
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
      };
        if (status == 'assigned' || status == 'accepted' || status == 'awaiting_payment' || status == 'ready_to_assign') {
        updateData['assigned_at'] = DateTime.now().toIso8601String();
        if (providerId != null) {
          updateData['provider_id'] = providerId;
        }
      } else if (status == 'in_progress') {
        updateData['service_start_time'] = DateTime.now().toIso8601String();
      } else if (status == 'completed') {
        updateData['service_completion_time'] = DateTime.now().toIso8601String();
        updateData['completed_at'] = DateTime.now().toIso8601String();
      } else if (status == 'cancelled') {
        updateData['cancelled_at'] = DateTime.now().toIso8601String();
      }

      // Get current service request to find provider_id
      final currentRequest = await SupabaseService.client
          .from('service_requests')
          .select('provider_id')
          .eq('id', requestId)
          .single();

      // Update the service request status
      await SupabaseService.client
          .from('service_requests')
          .update(updateData)
          .eq('id', requestId);

      print('✅ Service request status updated successfully');

      // Update mechanic availability if job is completed or cancelled
      if ((status == 'completed' || status == 'cancelled') && currentRequest['provider_id'] != null) {
        try {
          // Import and use TalyerOwnerService to update mechanic status
          await TalyerOwnerService.instance.updateMechanicStatusOnJobCompletion(
            currentRequest['provider_id'], 
            status
          );
        } catch (mechanicStatusError) {
          print('⚠️ Warning: Could not update mechanic availability: $mechanicStatusError');
          // Don't fail the main operation if mechanic status update fails
        }
      }
    
      return true;
    } catch (e) {
      print('Error updating service request status: $e');
      return false;
    }
  }
  /// Check if mechanic has accepted any requests recently
  static Future<List<Map<String, dynamic>>> getMechanicAcceptedRequests(String mechanicId) async {
    try {      final response = await SupabaseService.client
          .from('service_request_history_view')
          .select()
          .eq('provider_id', mechanicId)
          .inFilter('status', ['accepted', 'awaiting_payment', 'paid', 'ready_to_assign', 'in_progress'])
          .order('created_at', ascending: false);
    
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error getting mechanic accepted requests: $e');
      return [];
    }
  }

  /// Get pending service requests for mechanics to accept
  static Future<List<Map<String, dynamic>>> getPendingServiceRequests({
    double? latitude,
    double? longitude,
    double? radiusKm = 10.0,
  }) async {
    try {
      var query = SupabaseService.client
          .from('service_request_history_view')
          .select()
          .eq('status', 'pending')
          .order('created_at', ascending: false);
    
      // If location is provided, you can add distance filtering here
      // This would require a database function or additional filtering
    
      final response = await query;
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error getting pending service requests: $e');
      return [];
    }
  }

  /// Cancel a service request
  static Future<void> cancelServiceRequest(String requestId) async {
    final userId = _currentUserId;

    try {
      // Update the service request status to cancelled
      await SupabaseService.client
          .from('service_requests')
          .update({
            'status': 'cancelled',
            'cancelled_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', requestId)
          .eq('customer_id', userId); // Ensure user can only cancel their own requests

      print('✅ Service request cancelled successfully');
    } catch (e) {
      print('❌ Error cancelling service request: $e');
      throw Exception('Failed to cancel service request: $e');
    }
  }

  /// Check if a service request can be cancelled
  static Future<bool> canCancelServiceRequest(String requestId) async {
    try {
      final response = await SupabaseService.client
          .from('service_requests')
          .select('status')
          .eq('id', requestId)
          .single();

      final status = response['status']?.toString().toLowerCase();
      
      // Service can be cancelled if it's pending or assigned but not yet in progress
      return status == 'pending' || status == 'assigned' || status == 'accepted';
    } catch (e) {
      print('❌ Error checking if service can be cancelled: $e');
      return false;
    }
  }

  // Create a notification when status changes
  static Future<void> createStatusChangeNotification(
    String userId,
    String serviceRequestId,
    String oldStatus,
    String newStatus,
  ) async {
    try {
      String title;
      String body;
      
      switch (newStatus.toLowerCase()) {
        case 'assigned':
        case 'accepted':
          title = 'Mechanic Assigned!';
          body = 'A mechanic has accepted your service request.';
          break;
        case 'in_progress':
          title = 'Service Started';
          body = 'Your mechanic has started working on your vehicle.';
          break;
        case 'completed':
          title = 'Service Completed';
          body = 'Your service has been completed successfully!';
          break;
        case 'cancelled':
          title = 'Service Cancelled';
          body = 'Your service request has been cancelled.';
          break;
        default:
          title = 'Status Update';
          body = 'Your service request status has been updated.';
      }
      
      await createNotification(
        userId: userId,
        title: title,
        body: body,
        type: 'service_request',
        data: {
          'service_request_id': serviceRequestId,
          'old_status': oldStatus,
          'new_status': newStatus,
        },
      );
    } catch (e) {
      print('Error creating status change notification: $e');
    }
  }

  /// Create a generic notification for a user
  static Future<Map<String, dynamic>> createNotification({
    required String userId,
    required String title,
    required String body,
    required String type,
    Map<String, dynamic>? data,
  }) async {
    try {
      final response = await SupabaseService.client
          .from('notifications')
          .insert({
            'user_id': userId,
            'title': title,
            'body': body,
            'type': type,
            'data': data != null ? json.encode(data) : null,
            'read': false,
            'created_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      return response;
    } catch (e) {
      print('❌ Error creating notification: $e');
      throw Exception('Failed to create notification: $e');
    }
  }

  /// Process payment using PayMongo and redirect to PayMongo site
  static Future<Map<String, dynamic>> processPaymentWithPayMongo({
    required String serviceRequestId,
    required String paymentMethod,
    required double amount,
    String? phoneNumber,
  }) async {
    try {
      print('💳 Processing PayMongo payment for service request: $serviceRequestId');
      print('💳 Payment method: $paymentMethod, Amount: ₱${amount.toStringAsFixed(2)}');
      
      // Determine PayMongo payment type based on method
      Map<String, dynamic>? paymentResult;
      
      if (paymentMethod.toLowerCase() == 'gcash' || paymentMethod.toLowerCase() == 'paymaya') {
        // Create QR code payment for e-wallets using checkout session
        paymentResult = await PayMongoService.instance.createCheckoutSession(
          amount: amount,
          description: 'RoadAid Service Payment - Request $serviceRequestId',
          invoiceId: serviceRequestId, // Use service request ID as invoice ID
          // Use an https callback that works on device; deep link handler can be added later
          successUrl: 'https://RoadAid.app/payment/success?request_id=$serviceRequestId&amount=$amount',
          cancelUrl: 'https://RoadAid.app/payment/cancel?request_id=$serviceRequestId',
        );
        
        if (paymentResult != null) {
          // Record payment as pending first
          await SupabaseService.recordPayment(
            serviceRequestId: serviceRequestId,
            paymentMethod: paymentMethod,
            amount: amount,
            phoneNumber: phoneNumber,
            paymentGateway: 'paymongo',
            transactionId: paymentResult['id'],
            status: 'pending',
          );
          
          // Get checkout URL and return it for direct browser redirect
          final checkoutUrl = paymentResult['attributes']['checkout_url'];
          print('🎯 QR Payment created: ${paymentResult['id']}');
          print('🌐 Redirecting to PayMongo: $checkoutUrl');
          
          return {
            'success': true,
            'payment_id': paymentResult['id'],
            'checkout_url': checkoutUrl,
            'requires_redirect': true,
            'transaction_id': paymentResult['id'],
            'amount': amount,
            'method': paymentMethod,
            'gateway': 'paymongo',
          };
        } else {
          throw Exception('Failed to create PayMongo checkout session');
        }
        
      } else {
        // Create payment intent for cards or other methods
        paymentResult = await PayMongoService.instance.createPaymentIntent(
          amount: amount,
          description: 'RoadAid Service Payment - Request $serviceRequestId',
          invoiceId: serviceRequestId, // Use service request ID as invoice ID
        );
        
        if (paymentResult != null) {
          print('💳 Payment Intent created: ${paymentResult['id']}');
          
          // Record successful payment intent creation
          await SupabaseService.recordPayment(
            serviceRequestId: serviceRequestId,
            paymentMethod: paymentMethod,
            amount: amount,
            phoneNumber: phoneNumber,
            paymentGateway: 'paymongo',
            transactionId: paymentResult['id'],
            status: 'processed',
          );
        } else {
          throw Exception('Failed to create PayMongo payment intent');
        }
      }
      
      print('✅ PayMongo payment processed successfully');
      return {
        'success': true,
        'payment_id': paymentResult['id'],
        'payment_method': paymentMethod,
        'amount': amount,
        'gateway': 'paymongo',
        'status': paymentMethod.toLowerCase() == 'gcash' || paymentMethod.toLowerCase() == 'paymaya' ? 'pending' : 'processed',
      };
      
    } catch (e) {
      print('❌ Error processing PayMongo payment: $e');
      throw Exception('Failed to process PayMongo payment: $e');
    }
  }

  /// Process payment and update service request status (Legacy method - now uses PayMongo)
  static Future<Map<String, dynamic>> processPayment({
    required String serviceRequestId,
    required String paymentMethod,
    required double amount,
    String? phoneNumber,
  }) async {
    // Redirect to PayMongo payment processing
    return await processPaymentWithPayMongo(
      serviceRequestId: serviceRequestId,
      paymentMethod: paymentMethod,
      amount: amount,
      phoneNumber: phoneNumber,
    );
  }

  /// Get service request by ID for the current user
  static Future<Map<String, dynamic>?> getServiceRequestById(String serviceRequestId) async {
    try {
      return await SupabaseService.getServiceRequestById(serviceRequestId);
    } catch (e) {
      print('❌ Error getting service request: $e');
      throw Exception('Failed to get service request: $e');
    }
  }

  // ========================================
  // MESSAGING OPERATIONS
  // ========================================
  
  /// Get all messages for the current user across all service requests
  static Future<List<Map<String, dynamic>>> getUserMessages() async {
    final userId = _currentUserId;

    try {
      return await SupabaseService.getMessagesForUser(userId);
    } catch (e) {
      print('❌ Error fetching user messages: $e');
      throw Exception('Failed to fetch messages: $e');
    }
  }

  /// Get messages for a specific service request
  static Future<List<Map<String, dynamic>>> getServiceRequestMessages(String serviceRequestId) async {
    final userId = _currentUserId;

    try {
      return await SupabaseService.getMessagesForServiceRequest(
        serviceRequestId: serviceRequestId,
        userId: userId,
      );
    } catch (e) {
      print('❌ Error fetching service request messages: $e');
      throw Exception('Failed to fetch service request messages: $e');
    }
  }

  /// Send a message in a service request
  static Future<String> sendMessage({
    required String serviceRequestId,
    required String receiverId,
    required String message,
  }) async {
    final userId = _currentUserId;

    try {
      // Verify user has access to this service request
      final serviceRequest = await SupabaseService.client
          .from('service_requests')
          .select('user_id, service_provider_id')
          .eq('id', serviceRequestId)
          .single();

      if (serviceRequest['user_id'] != userId) {
        throw Exception('Access denied: Not your service request');
      }

      return await SupabaseService.sendMessage(
        serviceRequestId: serviceRequestId,
        senderId: userId,
        receiverId: receiverId,
        message: message,
      );
    } catch (e) {
      print('❌ Error sending message: $e');
      throw Exception('Failed to send message: $e');
    }
  }

  /// Mark messages as read in a service request
  static Future<void> markMessagesAsRead(String serviceRequestId) async {
    final userId = _currentUserId;

    try {
      await SupabaseService.markServiceRequestMessagesAsRead(
        serviceRequestId: serviceRequestId,
        userId: userId,
      );
    } catch (e) {
      print('❌ Error marking messages as read: $e');
      throw Exception('Failed to mark messages as read: $e');
    }
  }

  /// Mark individual message as read by message ID
  static Future<void> markMessageAsRead(String messageId) async {
    try {
      await SupabaseService.markMessageAsRead(messageId);
    } catch (e) {
      print('❌ Error marking message as read: $e');
      throw Exception('Failed to mark message as read: $e');
    }
  }

  /// Get mechanic info for a service request (for messaging)
  static Future<Map<String, dynamic>?> getMechanicForServiceRequest(String serviceRequestId) async {
    final userId = _currentUserId;

    try {
      print('🔧 UserDataService.getMechanicForServiceRequest() - Getting mechanic for request: $serviceRequestId');
      
      // Get service request with provider_id
      final serviceRequest = await SupabaseService.client
          .from('service_requests')
          .select('provider_id')
          .eq('id', serviceRequestId)
          .eq('customer_id', userId)
          .single();

      if (serviceRequest['provider_id'] == null) {
        print('🔧 No provider assigned to this request');
        return null;
      }

      // Get service provider details
      final serviceProvider = await SupabaseService.client
          .from('service_providers')
          .select('id, company_name, business_address, phone_number, email')
          .eq('id', serviceRequest['provider_id'])
          .single();

      print('🔧 Mechanic info retrieved successfully');
      return serviceProvider;
    } catch (e) {
      print('❌ Error fetching mechanic info: $e');
      return null;
    }
  }

  /// Get invoice details for a specific service request
  static Future<Map<String, dynamic>?> getInvoiceForServiceRequest(String serviceRequestId) async {
    final userId = _currentUserId;

    try {
      final response = await SupabaseService.client
          .from('invoices')
          .select('''
            id,
            request_id,
            invoice_number,
            issued_at,
            status,
            subtotal,
            platform_fee,
            total_amount,
            provider_net_amount,
            notes
          ''')
          .eq('request_id', serviceRequestId)
          .eq('customer_id', userId)
          .maybeSingle();

      return response;
    } catch (e) {
      print('❌ Error fetching invoice: $e');
      return null;
    }
  }

  /// Get all invoices for the current user
  static Future<List<Map<String, dynamic>>> getUserInvoices() async {
    final userId = _currentUserId;

    try {
      print('🔧 UserDataService.getUserInvoices() - Getting invoices for user: $userId');
      
      // Get basic invoice data
      final invoicesResponse = await SupabaseService.client
          .from('invoices')
          .select('''
            id,
            request_id,
            invoice_number,
            issued_at,
            due_date,
            status,
            subtotal,
            platform_fee,
            total_amount,
            provider_net_amount,
            notes
          ''')
          .eq('customer_id', userId)
          .order('issued_at', ascending: false);

      print('🔧 Found ${invoicesResponse.length} invoices, enriching with service request data...');
      
      List<Map<String, dynamic>> enrichedInvoices = [];
      
      for (final invoice in invoicesResponse) {
        final enrichedInvoice = Map<String, dynamic>.from(invoice);
        
        // Get service request data
        if (invoice['request_id'] != null) {
          try {
            final serviceRequest = await SupabaseService.client
                .from('service_requests')
                .select('id, title, description, service_type, status, created_at')
                .eq('id', invoice['request_id'])
                .single();
            enrichedInvoice['service_requests'] = serviceRequest;
          } catch (e) {
            print('Warning: Could not fetch service request for invoice ${invoice['id']}: $e');
          }
        }
        
        enrichedInvoices.add(enrichedInvoice);
      }

      print('🔧 User invoices enriched successfully: ${enrichedInvoices.length} invoices');
      return enrichedInvoices;
    } catch (e) {
      print('❌ Error fetching user invoices: $e');
      throw Exception('Failed to fetch invoices: $e');
    }
  }

  /// Load unread notifications count and update state
    /// Load unread notifications count and update state
  static Future<int> loadUnreadNotifications() async {
    try {
      return await getUnreadNotificationCount();
    } catch (e) {
      // Silently handle error
      print('Error loading notification count: $e');
      return 0;
    }
  }
  
  static Future<int> getUnreadNotificationCount() async {
    try {
      final userId = _currentUserId;
      final response = await SupabaseService.client
          .from('notifications')
          .select('id')
          .eq('user_id', userId)
          .eq('read', false);

  // Supabase select returns a List on success
  final listResponse = response as List<dynamic>?;
  return listResponse?.length ?? 0;
    } catch (e) {
      print('Error getting unread notification count: $e');
      return 0;
    }
  }

  // ========================================
  // SERVICE PROVIDER OPERATIONS
  // ========================================

  /// Get nearby service providers
  static Future<List<Map<String, dynamic>>> getNearbyServiceProviders({
    double? latitude,
    double? longitude,
    double? radiusKm = 10.0,
  }) async {
    try {
      print('🔧 UserDataService.getNearbyServiceProviders() - Getting providers...');
      
      // Get basic service providers data
      final providersResponse = await SupabaseService.client
          .from('service_providers')
          .select('*')
          .eq('is_active', true)
          .order('rating', ascending: false);

      print('🔧 Found ${providersResponse.length} providers, enriching with user profile data...');
      
      List<Map<String, dynamic>> enrichedProviders = [];
      
      for (final provider in providersResponse) {
        final enrichedProvider = Map<String, dynamic>.from(provider);
        
        // Get user profile data
        if (provider['user_id'] != null) {
          try {
            final userProfile = await SupabaseService.client
                .from('user_profiles')
                .select('first_name, last_name, email, phone_number')
                .eq('id', provider['user_id'])
                .single();
            enrichedProvider['user_profiles'] = userProfile;
          } catch (e) {
            print('Warning: Could not fetch user profile for provider ${provider['id']}: $e');
          }
        }
        
        enrichedProviders.add(enrichedProvider);
      }
      
      // Calculate distance if coordinates are provided
      if (latitude != null && longitude != null) {
        List<Map<String, dynamic>> providersWithDistance = [];
        
        for (var provider in enrichedProviders) {
          final providerLat = provider['latitude'];
          final providerLng = provider['longitude'];
          
          if (providerLat != null && providerLng != null) {
            // Calculate distance using Haversine formula
            final distance = _calculateDistance(
              latitude,
              longitude,
              double.parse(providerLat.toString()),
              double.parse(providerLng.toString()),
            );
            
            // Only include providers within radius
            if (distance <= radiusKm!) {
              provider['distance'] = distance;
              providersWithDistance.add(provider);
            }
          }
        }
        
        // Sort by distance
        providersWithDistance.sort((a, b) => 
          (a['distance'] as double).compareTo(b['distance'] as double));
        
        print('🔧 Nearby service providers retrieved successfully: ${providersWithDistance.length} providers');
        return providersWithDistance;
      }
      
      print('🔧 Service providers retrieved successfully: ${enrichedProviders.length} providers');
      return enrichedProviders;
    } catch (e) {
      print('❌ Error fetching nearby service providers: $e');
      throw Exception('Failed to load service providers: $e');
    }
  }

  /// Calculate distance between two points using Haversine formula
  static double _calculateDistance(
    double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // Earth's radius in kilometers
    
    final double dLat = _toRadians(lat2 - lat1);
    final double dLon = _toRadians(lon2 - lon1);
    
    final double a = 
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_toRadians(lat1)) * math.cos(_toRadians(lat2)) * 
      math.sin(dLon / 2) * math.sin(dLon / 2);
    
    final double c = 2 * math.asin(math.sqrt(a));
    
    return earthRadius * c;
  }

  /// Convert degrees to radians
  static double _toRadians(double degrees) {
    return degrees * (math.pi / 180.0);
  }

  /// Get service provider by ID
  static Future<Map<String, dynamic>?> getServiceProviderById(String providerId) async {
    try {
      print('🔧 UserDataService.getServiceProviderById() - Getting provider: $providerId');
      
      // Get basic service provider data
      final serviceProvider = await SupabaseService.client
          .from('service_providers')
          .select('*')
          .eq('id', providerId)
          .maybeSingle();

      if (serviceProvider == null) {
        print('🔧 Service provider not found');
        return null;
      }

      // Get user profile data
      Map<String, dynamic>? userProfile;
      if (serviceProvider['user_id'] != null) {
        try {
          userProfile = await SupabaseService.client
              .from('user_profiles')
              .select('first_name, last_name, email, phone_number')
              .eq('id', serviceProvider['user_id'])
              .single();
        } catch (e) {
          print('Warning: Could not fetch user profile for provider $providerId: $e');
        }
      }

      // Combine the data
      final enrichedProvider = {
        ...serviceProvider,
        'user_profiles': userProfile,
      };

      print('🔧 Service provider retrieved successfully');
      return enrichedProvider;
    } catch (e) {
      print('❌ Error fetching service provider: $e');
      return null;
    }
  }

  /// Get service provider operating status
  static Future<Map<String, dynamic>> getServiceProviderStatus(String providerId) async {
    try {
      final provider = await getServiceProviderById(providerId);
      if (provider == null) {
        return {
          'isOpen': false,
          'status': 'Provider not found',
          'nextOpen': null,
        };
      }

      final now = DateTime.now();
      final isOpen = _isProviderCurrentlyOpen(provider, now);
      
      return {
        'isOpen': isOpen,
        'status': isOpen ? 'Open' : 'Closed',
        'operatingHours': provider['operating_hours'],
        'nextOpen': isOpen ? null : _getNextOpenTime(provider, now),
      };
    } catch (e) {
      print('❌ Error getting provider status: $e');
      return {
        'isOpen': false,
        'status': 'Status unavailable',
        'nextOpen': null,
      };
    }
  }

  /// Check if service provider is currently open
  static bool _isProviderCurrentlyOpen(Map<String, dynamic> provider, DateTime now) {
    final operatingHours = provider['operating_hours'] as String?;
    if (operatingHours == null || operatingHours.isEmpty) {
      return false;
    }

    try {
      final parts = operatingHours.split('-');
      if (parts.length != 2) return false;

      final openTime = _parseTimeString(parts[0].trim());
      final closeTime = _parseTimeString(parts[1].trim());

      if (openTime == null || closeTime == null) return false;

      final currentMinutes = now.hour * 60 + now.minute;
      return currentMinutes >= openTime && currentMinutes <= closeTime;
    } catch (e) {
      return false;
    }
  }

  /// Parse time string to minutes from midnight
  static int? _parseTimeString(String timeString) {
    try {
      final parts = timeString.split(':');
      if (parts.length != 2) return null;
      
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      
      return hour * 60 + minute;
    } catch (e) {
      return null;
    }
  }

  /// Get next open time for a provider
  static DateTime? _getNextOpenTime(Map<String, dynamic> provider, DateTime now) {
    final operatingHours = provider['operating_hours'] as String?;
    if (operatingHours == null || operatingHours.isEmpty) {
      return null;
    }

    try {
      final parts = operatingHours.split('-');
      if (parts.length != 2) return null;

      final openTime = _parseTimeString(parts[0].trim());
      if (openTime == null) return null;

      final openHour = openTime ~/ 60;
      final openMinute = openTime % 60;

      // If it's past opening time today, next open is tomorrow
      final currentMinutes = now.hour * 60 + now.minute;
      if (currentMinutes >= openTime) {
        return DateTime(now.year, now.month, now.day + 1, openHour, openMinute);
      } else {
        return DateTime(now.year, now.month, now.day, openHour, openMinute);
      }
    } catch (e) {
      return null;
    }
  }

  // ========================================
  // QR CODE OPERATIONS
  // ========================================

  /// Generate QR code data for completed service
  static Map<String, dynamic> generateQRCodeData({
    required String serviceRequestId,
    required String customerName,
    required String serviceSummary,
    required double totalAmount,
    required DateTime completionTime,
  }) {
    return {
      'service_id': serviceRequestId,
      'customer': customerName,
      'service': serviceSummary,
      'amount': totalAmount,
      'completed_at': completionTime.toIso8601String(),
      'verified': true,
      'qr_generated_at': DateTime.now().toIso8601String(),
    };
  }

  /// Verify QR code data
  static Future<bool> verifyQRCodeData(Map<String, dynamic> qrData) async {
    try {
      final serviceRequestId = qrData['service_id'] as String?;
      if (serviceRequestId == null) return false;

      final serviceRequest = await getServiceRequestById(serviceRequestId);
      if (serviceRequest == null) return false;

      // Verify the service is completed and matches QR data
      final isCompleted = serviceRequest['status'] == 'completed';
      final amountMatches = serviceRequest['final_price'] == qrData['amount'];
      
      return isCompleted && amountMatches;
    } catch (e) {
      print('❌ Error verifying QR code: $e');
      return false;
    }
  }

  // ========================================
  // NOTIFICATION OPERATIONS  
  // ========================================

  /// Send notification about service provider status change
  static Future<void> notifyServiceProviderStatusChange({
    required String providerId,
    required bool isOpen,
    required String businessName,
  }) async {
  try {
    // Get users who have this provider as favorite or recent
    await SupabaseService.client
        .from('notifications')
        .insert({
          'user_id': _currentUserId,
          'title': isOpen ? 'Service Provider Open' : 'Service Provider Closed',
          'body': '$businessName is now ${isOpen ? 'open' : 'closed'}',
          'type': 'provider_status',
          'data': {
            'provider_id': providerId,
            'is_open': isOpen,
            'business_name': businessName,
          },
          'created_at': DateTime.now().toIso8601String(),
        });

    print('✅ Provider status notification sent');
  } catch (e) {
    print('❌ Error sending provider status notification: $e');
  }
  }
}










