import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static const String supabaseUrl = 'https://olxquclxgtrbyxfxxscj.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9seHF1Y2x4Z3RyYnl4Znh4c2NqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDg5MTQ3OTksImV4cCI6MjA2NDQ5MDc5OX0.8cZ6-Y5e1E8KK4znvQAzI6RkX3XMfgdgPyVAVj2hfh0';
  
  static SupabaseClient get client => Supabase.instance.client;
  
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  }

  // Authentication methods
  static Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String? phoneNumber,
    String? userType,
    String? companyName, // Add company name parameter
  }) async {
    print('📡 SupabaseService.signUp called');
    print('📧 Email: $email');
    print('👤 Name: $firstName $lastName');
    print('📱 Phone: $phoneNumber');
    print('👥 User Type: $userType');
      final response = await client.auth.signUp(
      email: email,
      password: password,
      data: {
        'first_name': firstName,
        'last_name': lastName,
        'phone_number': phoneNumber,
        'user_type': userType ?? 'customer',
        'company_name': companyName, // Add company name to user metadata
      },
  // Use the redirect matching SUPABASE_REDIRECT_CONFIG.md
  // Ensure this exact URL is added to Supabase Dashboard -> Authentication -> URL Configuration
  emailRedirectTo: 'RoadAid://confirm-signup', // Email confirmation redirects to app
    );
    
    print('📡 Supabase signUp response: ${response.user?.id}');
    print('📡 User metadata sent: ${response.user?.userMetadata}');
    return response;
  }
  
  static Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    final response = await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    return response;
  }
  
  static Future<void> signOut() async {
    await client.auth.signOut();
  }
  
  static Future<void> resetPassword(String email) async {
    await client.auth.resetPasswordForEmail(
      email,
      redirectTo: 'RoadAid://reset-password', // This ensures the password reset opens in the app
    );
  }
  
  static User? get currentUser => client.auth.currentUser;
  
  static bool get isSignedIn => currentUser != null;
  
  // Helper method to get current user ID
  static String? get currentUserId => client.auth.currentUser?.id;
  
  // Helper method to ensure user is logged in
  static void _ensureUserLoggedIn() {
    if (currentUserId == null) {
      throw Exception('User must be logged in to perform this operation');
    }
  }
  
  // User profile methods
  static Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    print('📡 Getting user profile for: $userId');
    final response = await client
        .from('user_profiles')
        .select()
        .eq('id', userId)
        .single();
    print('📡 Profile response: $response');
    return response;
  }

  static Future<void> updateUserProfile({
    required String userId,
    required Map<String, dynamic> data,
  }) async {
    print('📡 Updating user profile for: $userId');
    print('📡 Profile data: $data');
    
    await client
        .from('user_profiles')
        .upsert({
          'id': userId,
          ...data,
        });
    print('📡 Profile updated successfully');  }
  
  // Service request methods
  static Future<String> createServiceRequest({
    required String userId,
    required String vehicleId,
    required String issueType,
    required String issueTitle,
    required String issueDescription,
    required String address,
    double? latitude,
    double? longitude,
  }) async {
    final response = await client
        .from('service_requests')
        .insert({
          'user_id': userId,
          'vehicle_id': vehicleId,
          'issue_type': issueType,
          'issue_title': issueTitle,
          'issue_description': issueDescription,
          'service_location': address,
          'latitude': latitude,
          'longitude': longitude,
        })
        .select()
        .single();
    return response['id'];
  }
  
  // Payment methods
  static Future<List<Map<String, dynamic>>> getUserPaymentMethods(String userId) async {
    final response = await client
        .from('payment_methods')
        .select()
        .eq('user_id', userId)
        .order('is_default', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  static Future<String> addPaymentMethod({
    required String userId,
    required String methodType,
    String? provider,
    String? cardLastFour,
    String? cardholderName,
    int? expiryMonth,
    int? expiryYear,
    bool isDefault = false,
  }) async {
    final response = await client
        .from('payment_methods')
        .insert({
          'user_id': userId,
          'method_type': methodType,
          'provider': provider,
          'card_last_four': cardLastFour,
          'cardholder_name': cardholderName,
          'expiry_month': expiryMonth,
          'expiry_year': expiryYear,
          'is_default': isDefault,
        })
        .select()
        .single();
    return response['id'];
  }

  static Future<String> createPayment({
    required String serviceRequestId,
    required String userId,
    required String paymentMethodId,
    required double amount,
    Map<String, dynamic>? providerResponse,
  }) async {
    final response = await client
        .from('payments')
        .insert({
          'service_request_id': serviceRequestId,
          'user_id': userId,
          'payment_method_id': paymentMethodId,
          'amount': amount,
          'provider_response': providerResponse,
        })
        .select()
        .single();
    return response['id'];
  }

  static Future<void> updatePaymentStatus({
    required String paymentId,
    required String status,
    Map<String, dynamic>? providerResponse,
  }) async {
    await client
        .from('payments')
        .update({
          'status': status,
          'provider_response': providerResponse,
          if (status == 'completed') 'paid_at': DateTime.now().toIso8601String(),
        })
        .eq('id', paymentId);
  }

  static Future<void> setDefaultPaymentMethod(String userId, String paymentMethodId) async {
    // First, set all payment methods to not default
    await client
        .from('payment_methods')
        .update({'is_default': false})
        .eq('user_id', userId);
    
    // Then set the selected one as default
    await client
        .from('payment_methods')
        .update({'is_default': true})
        .eq('id', paymentMethodId);
  }

  static Future<void> deletePaymentMethod(String paymentMethodId) async {
    await client
        .from('payment_methods')
        .delete()
        .eq('id', paymentMethodId);
  }
  // Messages methods - Clean implementation for customer-mechanic communication
    /// Get all messages for a user across all their service requests
  static Future<List<Map<String, dynamic>>> getMessagesForUser(String userId) async {
    final response = await client
        .from('messages')
        .select('''
          id,
          service_request_id,
          sender_id,
          receiver_id,
          message_text,
          is_read,
          created_at,
          service_requests!inner (
            id,
            issue_type,
            issue_title,
            service_provider_id,
            user_id,
            service_providers (
              business_name,
              phone_number
            )
          ),
          sender_profile:sender_id (
            user_profiles (
              full_name,
              phone_number
            )
          )
        ''')
        .or('sender_id.eq.$userId,receiver_id.eq.$userId')
        .order('created_at', ascending: false);
    
    return List<Map<String, dynamic>>.from(response);
  }
  /// Get messages for a specific service request (chat view)
  static Future<List<Map<String, dynamic>>> getMessagesForServiceRequest({
    required String serviceRequestId,
    required String userId,
  }) async {
    final response = await client
        .from('messages')
        .select('''
          id,
          service_request_id,
          sender_id,
          receiver_id,
          message_text,
          is_read,
          created_at,
          sender_profile:sender_id (
            user_profiles (
              full_name
            )
          )
        ''')
        .eq('service_request_id', serviceRequestId)
        .order('created_at', ascending: true);
    
    return List<Map<String, dynamic>>.from(response);
  }
  /// Send a message in a service request chat
  static Future<String> sendMessage({
    required String serviceRequestId,
    required String senderId,
    required String receiverId,
    required String message,
  }) async {
    final response = await client
        .from('messages')
        .insert({
          'service_request_id': serviceRequestId,
          'sender_id': senderId,
          'receiver_id': receiverId,
          'message_text': message,
          'is_read': false,
          'created_at': DateTime.now().toIso8601String(),
        })
        .select()
        .single();
    return response['id'];
  }

  /// Mark a message as read
  static Future<void> markMessageAsRead(String messageId) async {
    await client
        .from('messages')
        .update({'is_read': true})
        .eq('id', messageId);
  }

  /// Mark all messages in a service request as read for a user
  static Future<void> markServiceRequestMessagesAsRead({
    required String serviceRequestId,
    required String userId,
  }) async {
    await client
        .from('messages')
        .update({'is_read': true})
        .eq('service_request_id', serviceRequestId)
        .eq('receiver_id', userId);
  }
  // Service Request Status Update Methods
  static Future<void> updateServiceRequestStatus({
    required String serviceRequestId,
    required String status,
    String? paymentStatus,
    String? paymentMethod,
    double? finalPrice,
  }) async {
    _ensureUserLoggedIn();
    
    final updateData = <String, dynamic>{
      'status': status,
      'updated_at': DateTime.now().toIso8601String(),
    };
    
    // Add optional fields if provided
    if (paymentStatus != null) updateData['payment_status'] = paymentStatus;
    if (paymentMethod != null) updateData['payment_method'] = paymentMethod;
    if (finalPrice != null) updateData['final_price'] = finalPrice;
    
    // Add timestamps based on status
    if (status == 'in_progress') {
      updateData['service_start_time'] = DateTime.now().toIso8601String();
    } else if (status == 'completed') {
      updateData['service_completion_time'] = DateTime.now().toIso8601String();
      updateData['completed_at'] = DateTime.now().toIso8601String();
    }
    
    try {
      await client
          .from('service_requests')
          .update(updateData)
          .eq('id', serviceRequestId);
      
      print('✅ Service request status updated successfully');
    } catch (e) {
      print('❌ Error updating service request status: $e');
      // Try alternative approach without user_id filter
      throw Exception('Failed to update service request status: $e');
    }
  }  // Payment Recording Method
  static Future<Map<String, dynamic>> recordPayment({
    required String serviceRequestId,
    required String paymentMethod,
    required double amount,
    String? phoneNumber,
    String? paymentGateway,
    String? transactionId,
    String? status,
  }) async {
    _ensureUserLoggedIn();
    
    try {
      print('💳 Recording payment for service request: $serviceRequestId');
      print('💳 Gateway: ${paymentGateway ?? 'legacy'}, Transaction ID: ${transactionId ?? 'N/A'}');
      
      // Determine the final status
      String finalStatus = status ?? 'completed';
      String requestStatus = finalStatus == 'pending' ? 'pending' : 'in_progress';
      
      // First, get the service request details to get customer_id and provider_id
      final serviceRequestResponse = await client
          .from('service_requests')
          .select('customer_id, provider_id')
          .eq('id', serviceRequestId)
          .single();
      
      if (serviceRequestResponse.isEmpty) {
        throw Exception('Service request not found');
      }
      
      final customerId = serviceRequestResponse['customer_id'];
      final providerId = serviceRequestResponse['provider_id'];
      
      // Create payment record in payments table
      final paymentData = <String, dynamic>{
        'request_id': serviceRequestId,
        'customer_id': customerId,
        'amount': amount,
        'platform_fee': amount * 0.05, // 5% platform fee
        'provider_amount': amount * 0.95, // 95% to provider
        'payment_method': paymentMethod,
        'payment_gateway': paymentGateway ?? 'legacy',
        'transaction_id': transactionId,
        'status': finalStatus,
        'processed_at': finalStatus == 'completed' ? DateTime.now().toIso8601String() : null,
        'created_at': DateTime.now().toIso8601String(),
      };
      
      // Handle provider_id - try to use actual provider, or find a system provider as placeholder
      if (providerId != null) {
        paymentData['provider_id'] = providerId;
        print('💳 Using actual provider: $providerId');
      } else {
        // Try to get any valid service provider as a placeholder
        try {
          final systemProvider = await client
              .from('service_providers')
              .select('id')
              .limit(1)
              .maybeSingle();
          
          if (systemProvider != null) {
            paymentData['provider_id'] = systemProvider['id'];
            print('💳 Using system provider placeholder: ${systemProvider['id']}');
          } else {
            // If no service providers exist, create a system one
            final systemProviderId = 'system-${DateTime.now().millisecondsSinceEpoch}';
            final newSystemProvider = await client
                .from('service_providers')
                .insert({
                  'id': systemProviderId,
                  'user_id': customerId,
                  'business_name': 'System Placeholder',
                  'business_address': 'System',
                  'phone_number': '00000000000',
                  'is_verified': false,
                  'created_at': DateTime.now().toIso8601String(),
                })
                .select('id')
                .single();
            
            paymentData['provider_id'] = newSystemProvider['id'];
            print('💳 Created system provider placeholder: ${newSystemProvider['id']}');
          }
        } catch (e) {
          print('❌ Error handling provider_id: $e');
          throw Exception('Cannot process payment without valid provider_id');
        }
      }
      
      final paymentResponse = await client
          .from('payments')
          .insert(paymentData)
          .select()
          .single();
      
      print('✅ Payment record created: ${paymentResponse['id']}');
      
      // Update service request with basic payment info only
      final updateData = <String, dynamic>{
        'status': requestStatus,
        'payment_status': finalStatus,
        'payment_method': paymentMethod,
        'final_price': amount,
        'updated_at': DateTime.now().toIso8601String(),
      };
      
      await client
          .from('service_requests')
          .update(updateData)
          .eq('id', serviceRequestId);
      
      print('✅ Service request updated with payment status');
      
      return {
        'success': true,
        'payment_id': paymentResponse['id'],
        'transaction_id': transactionId ?? paymentResponse['id'],
        'amount': amount,
        'method': paymentMethod,
        'gateway': paymentGateway ?? 'legacy',
        'status': requestStatus,
        'payment_status': finalStatus,
      };
    } catch (e) {
      print('❌ Error recording payment: $e');
      throw Exception('Failed to record payment: $e');
    }
  }// Get Service Request by ID
  static Future<Map<String, dynamic>?> getServiceRequestById(String serviceRequestId) async {
    _ensureUserLoggedIn();
    
    try {
      final response = await client
          .from('service_requests')
          .select('*')
          .eq('id', serviceRequestId)
          .maybeSingle();
      
      return response;
    } catch (e) {
      print('❌ Error getting service request: $e');
      return null;
    }
  }

  /// Update mechanic location in database
  static Future<void> updateMechanicLocation(String mechanicId, double latitude, double longitude) async {
    try {
      if (mechanicId.trim().isEmpty) {
        print('⚠️ SupabaseService.updateMechanicLocation called with empty mechanicId, skipping DB update');
        return;
      }
      // Update service_providers table
      await client
          .from('service_providers')
          .update({
            'current_latitude': latitude,
            'current_longitude': longitude,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', mechanicId);

      // Also update user_profiles location
      await client
          .from('user_profiles')
          .update({
            'current_latitude': latitude,
            'current_longitude': longitude,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', mechanicId);
    } catch (e) {
      print('Error updating mechanic location: $e');
      throw e;
    }
  }

  /// Get mechanic location from database
  static Future<Map<String, dynamic>?> getMechanicLocation(String mechanicId) async {
    try {
      final response = await client
          .from('user_profiles')
          .select('current_latitude, current_longitude, updated_at')
          .eq('id', mechanicId)
          .eq('user_type', 'mechanic')
          .maybeSingle();

      if (response != null) {
        return {
          'latitude': response['current_latitude'],
          'longitude': response['current_longitude'],
          'updated_at': response['updated_at'],
        };
      }
      return null;
    } catch (e) {
      print('Error getting mechanic location: $e');
      return null;
    }
  }

  /// Get mechanic location for service request
  static Future<Map<String, dynamic>?> getMechanicLocationForRequest(String requestId) async {
    try {
      // First get the service request with assigned mechanic
      final request = await client
          .from('service_requests')
          .select('assigned_mechanic_id')
          .eq('id', requestId)
          .maybeSingle();

      if (request == null || request['assigned_mechanic_id'] == null) {
        print('No assigned mechanic for request: $requestId');
        return null;
      }

      final mechanicId = request['assigned_mechanic_id'];
      
      // Then get the service provider details for the mechanic
      // Using .limit(1).maybeSingle() to handle potential duplicates gracefully
      final response = await client
          .from('service_providers')
          .select('''
            user_id,
            current_latitude,
            current_longitude,
            company_name,
            user_profiles!service_providers_user_id_fkey(
              first_name,
              last_name,
              phone_number,
              profile_image_url
            )
          ''')
          .eq('user_id', mechanicId)
          .limit(1)
          .maybeSingle();

      if (response != null && response['user_profiles'] != null) {
        final userProfile = response['user_profiles'];
        return {
          'latitude': response['current_latitude'],
          'longitude': response['current_longitude'],
          'name': response['company_name'] ?? 
                  '${userProfile['first_name']} ${userProfile['last_name']}',
          'phone_number': userProfile['phone_number'],
          'profile_image_url': userProfile['profile_image_url'],
          'user_id': response['user_id'],
        };
      }
      // If service_providers / user_profiles don't have current location,
      // fall back to the mechanic_locations table which is updated by the
      // mechanic's live-tracking upserts. This ensures the customer view can
      // still retrieve the mechanic's live coordinates even when we don't
      // update the profile/service_providers rows.
      try {
        final mechLoc = await client
            .from('mechanic_locations')
            .select('latitude, longitude, user_id, updated_at')
            .eq('user_id', mechanicId)
            .order('updated_at', ascending: false)
            .limit(1)
            .maybeSingle();

        if (mechLoc != null && mechLoc['latitude'] != null && mechLoc['longitude'] != null) {
          return {
            'latitude': mechLoc['latitude'],
            'longitude': mechLoc['longitude'],
            'name': null,
            'phone_number': null,
            'profile_image_url': null,
            'user_id': mechLoc['user_id'],
          };
        }
      } catch (e) {
        print('Error falling back to mechanic_locations: $e');
      }

      return null;
    } catch (e) {
      print('Error getting mechanic location for request: $e');
      // If it's a PostgrestException with multiple rows, provide more context
      if (e.toString().contains('multiple') && e.toString().contains('rows')) {
        print('🚨 Database integrity issue: Multiple service_provider entries detected');
        print('💡 Solution: Run DEBUG_DATABASE_INTEGRITY.sql to identify duplicates');
      }
      return null;
    }
  }
}
