import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';

class TalyerOwnerApiService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Get shop ID for current owner
  Future<String?> getShopId() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return null;

    final response = await _supabase
        .from('shops')
        .select('id')
        .eq('owner_id', userId)
        .maybeSingle();

    return response?['id'] as String?;
  }

  // Dashboard Overview Data
  Future<Map<String, dynamic>> getDashboardOverview(String shopId) async {
    // Get total mechanics
    final mechanicsResponse = await _supabase
        .from('service_providers')
        .select('id, user_id')
        .eq('shop_id', shopId);

    final totalMechanics = (mechanicsResponse as List).length;

    // Get active mechanics
    final activeMechanicsResponse = await _supabase
        .from('mechanic_availability_status')
        .select('mechanic_id')
        .eq('shop_id', shopId)
        .eq('current_status', 'available');

    final activeMechanics = (activeMechanicsResponse as List).length;

    // Get completed jobs
    final completedJobsResponse = await _supabase
        .from('mechanic_job_history')
        .select('id')
        .eq('shop_id', shopId)
        .eq('job_status', 'completed');

    final completedJobs = (completedJobsResponse as List).length;

    // Get cancelled jobs
    final cancelledJobsResponse = await _supabase
        .from('mechanic_job_history')
        .select('id')
        .eq('shop_id', shopId)
        .inFilter('job_status', ['cancelled', 'rejected']);

    final cancelledJobs = (cancelledJobsResponse as List).length;

    // Get total earnings
    final earningsResponse = await _supabase
        .from('mechanic_job_history')
        .select('shop_earnings')
        .eq('shop_id', shopId)
        .eq('job_status', 'completed');

    double totalEarnings = 0.0;
    for (var job in earningsResponse as List) {
      totalEarnings += (job['shop_earnings'] ?? 0.0) as num;
    }

    // Get today's earnings
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    
    final todayEarningsResponse = await _supabase
        .from('mechanic_job_history')
        .select('shop_earnings')
        .eq('shop_id', shopId)
        .eq('job_status', 'completed')
        .gte('completed_at', startOfDay.toIso8601String());

    double todayEarnings = 0.0;
    for (var job in todayEarningsResponse as List) {
      todayEarnings += (job['shop_earnings'] ?? 0.0) as num;
    }

    // Get service requests in progress
    final inProgressResponse = await _supabase
        .from('service_requests')
        .select('id')
        .eq('shop_id', shopId)
        .inFilter('status', ['accepted', 'in_progress', 'assigned', 'mechanic_assigned']);

    final inProgress = (inProgressResponse as List).length;

    return {
      'totalMechanics': totalMechanics,
      'activeMechanics': activeMechanics,
      'completedJobs': completedJobs,
      'cancelledJobs': cancelledJobs,
      'totalEarnings': totalEarnings,
      'todayEarnings': todayEarnings,
      'inProgress': inProgress,
    };
  }

  // Get all invoices for the shop
  // Query strategy: Only show invoices where mechanic belongs to this shop
  // 1. Get all mechanics for this shop from service_providers
  // 2. Filter invoices by those mechanic IDs only
  Future<List<Map<String, dynamic>>> getInvoices({
    required String shopId,
    String? status,
    DateTime? startDate,
    DateTime? endDate,
    String? mechanicId,
  }) async {
    // Step 1: Get all mechanic IDs that belong to this shop
    // Query: service_providers.select('user_id').eq('shop_id', shopId)
    final shopMechanicsResponse = await _supabase
        .from('service_providers')
        .select('user_id')
        .eq('shop_id', shopId);

    if ((shopMechanicsResponse as List).isEmpty) {
      return []; // No mechanics, no invoices
    }

    // Filter to only actual mechanics (not shop owner)
    List<String> validMechanicIds = [];
    for (var provider in shopMechanicsResponse as List) {
      final userId = provider['user_id'] as String;
      final userProfile = await _supabase
          .from('user_profiles')
          .select('user_type')
          .eq('id', userId)
          .eq('user_type', 'mechanic')
          .maybeSingle();
      
      if (userProfile != null) {
        validMechanicIds.add(userId);
      }
    }

    if (validMechanicIds.isEmpty) {
      return []; // No valid mechanics, no invoices
    }

    // Step 2: Get invoices where mechanic_id is in validMechanicIds
    // Query: invoices.select('*').in('mechanic_id', validMechanicIds)
    var query = _supabase
        .from('invoices')
        .select('*')
        .inFilter('mechanic_id', validMechanicIds);

    if (status != null) {
      query = query.eq('status', status);
    }

    if (startDate != null) {
      query = query.gte('generated_at', startDate.toIso8601String());
    }

    if (endDate != null) {
      query = query.lte('generated_at', endDate.toIso8601String());
    }

    if (mechanicId != null) {
      query = query.eq('mechanic_id', mechanicId);
    }

    final response = await query.order('generated_at', ascending: false);
    final invoices = response as List;

    // Fetch related data separately to avoid relationship ambiguity
    List<Map<String, dynamic>> enrichedInvoices = [];
    for (var invoice in invoices) {
      Map<String, dynamic> enrichedInvoice = Map<String, dynamic>.from(invoice);

      // Get customer data with vehicle info
      // Query: user_profiles.select(...), vehicles.select(...)
      if (invoice['customer_id'] != null) {
        final customerData = await _supabase
            .from('user_profiles')
            .select('first_name, last_name, email, phone_number')
            .eq('id', invoice['customer_id'])
            .maybeSingle();
        enrichedInvoice['customer'] = customerData;
      }

      // Get mechanic data
      // Query: user_profiles.select(...).eq('user_type', 'mechanic')
      if (invoice['mechanic_id'] != null) {
        final mechanicData = await _supabase
            .from('user_profiles')
            .select('first_name, last_name, email')
            .eq('id', invoice['mechanic_id'])
            .eq('user_type', 'mechanic')
            .maybeSingle();
        enrichedInvoice['mechanic'] = mechanicData;
      }

      // Get service request data with vehicle details
      // Query: service_requests.select(...), vehicles.select(...)
      if (invoice['request_id'] != null) {
        final requestData = await _supabase
            .from('service_requests')
            .select('title, description, status, vehicle_id, pickup_address')
            .eq('id', invoice['request_id'])
            .maybeSingle();
        
        if (requestData != null) {
          enrichedInvoice['service_request'] = requestData;
          
          // Get vehicle info if available
          if (requestData['vehicle_id'] != null) {
            final vehicleData = await _supabase
                .from('vehicles')
                .select('brand_name, model_name, plate_number')
                .eq('id', requestData['vehicle_id'])
                .maybeSingle();
            enrichedInvoice['vehicle'] = vehicleData;
          }
        }
      }

      // Get cash payment verification if applicable
      if (invoice['requires_cash_verification'] == true) {
        final cashVerification = await _supabase
            .from('cash_payment_verifications')
            .select('verification_status, cash_photo_url, receipt_photo_url, verified_at')
            .eq('invoice_id', invoice['id'])
            .maybeSingle();
        enrichedInvoice['cash_verification'] = cashVerification;
      }

      enrichedInvoices.add(enrichedInvoice);
    }

    return enrichedInvoices;
  }

  // Get mechanics performance data
  // Query strategy: Filter by user_type = 'mechanic' to exclude shop owner
  Future<List<Map<String, dynamic>>> getMechanicsPerformance(String shopId) async {
    // First get service providers for this shop
    final mechanicsResponse = await _supabase
        .from('service_providers')
        .select('id, user_id, rating')
        .eq('shop_id', shopId);

    List<Map<String, dynamic>> mechanicsData = [];

    for (var mechanic in mechanicsResponse as List) {
      final mechanicId = mechanic['user_id'];

      // Get user profile separately to avoid relationship ambiguity
      // IMPORTANT: Filter by user_type = 'mechanic' to exclude talyer_owner
      final userProfileResponse = await _supabase
          .from('user_profiles')
          .select('first_name, last_name, email, phone_number, profile_image_url, user_type')
          .eq('id', mechanicId)
          .eq('user_type', 'mechanic') // Only include actual mechanics
          .maybeSingle();

      // Skip if not a mechanic or profile not found
      if (userProfileResponse == null) continue;

      // Get job statistics
      final jobsResponse = await _supabase
          .from('mechanic_job_history')
          .select('*')
          .eq('mechanic_id', mechanicId)
          .eq('shop_id', shopId);

      final jobs = jobsResponse as List;
      final totalJobs = jobs.length;
      final completedJobs = jobs.where((j) => j['job_status'] == 'completed').length;
      final cancelledJobs = jobs.where((j) => j['job_status'] == 'cancelled').length;

      double totalEarnings = 0.0;
      for (var job in jobs.where((j) => j['job_status'] == 'completed')) {
        totalEarnings += (job['mechanic_earnings'] ?? 0.0) as num;
      }

      mechanicsData.add({
        'id': mechanicId,
        'name': '${userProfileResponse['first_name']} ${userProfileResponse['last_name']}',
        'email': userProfileResponse['email'],
        'phone': userProfileResponse['phone_number'],
        'profileImage': userProfileResponse['profile_image_url'],
        'rating': mechanic['rating'] ?? 0.0,
        'totalJobs': totalJobs,
        'completedJobs': completedJobs,
        'cancelledJobs': cancelledJobs,
        'totalEarnings': totalEarnings,
      });
    }

    return mechanicsData;
  }

  // Get revenue report data
  Future<Map<String, dynamic>> getRevenueReport({
    required String shopId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final jobsResponse = await _supabase
        .from('mechanic_job_history')
        .select('*')
        .eq('shop_id', shopId)
        .eq('job_status', 'completed')
        .gte('completed_at', startDate.toIso8601String())
        .lte('completed_at', endDate.toIso8601String());

    final jobs = jobsResponse as List;

    double shopEarnings = 0.0;
    double platformFees = 0.0;
    double mechanicEarnings = 0.0;

    Map<String, double> earningsByMechanic = {};
    Map<String, double> earningsByService = {};
    Map<String, int> dailyJobCounts = {};

    for (var job in jobs) {
      shopEarnings += (job['shop_earnings'] ?? 0.0) as num;
      platformFees += (job['platform_fee'] ?? 0.0) as num;
      mechanicEarnings += (job['mechanic_earnings'] ?? 0.0) as num;

      // By mechanic - store ID temporarily for later name lookup
      final mechanicId = job['mechanic_id'] as String?;
      if (mechanicId != null) {
        earningsByMechanic[mechanicId] = 
            (earningsByMechanic[mechanicId] ?? 0.0) + ((job['shop_earnings'] ?? 0.0) as num);
      }

      // By service type
      final serviceType = job['job_title'] as String? ?? 'Unknown';
      earningsByService[serviceType] = 
          (earningsByService[serviceType] ?? 0.0) + ((job['shop_earnings'] ?? 0.0) as num);

      // Daily counts
      final completedDate = DateTime.parse(job['completed_at'] as String);
      final dateKey = '${completedDate.year}-${completedDate.month.toString().padLeft(2, '0')}-${completedDate.day.toString().padLeft(2, '0')}';
      dailyJobCounts[dateKey] = (dailyJobCounts[dateKey] ?? 0) + 1;
    }

    // Convert mechanic IDs to names for display
    // Query: user_profiles.select('id, first_name, last_name, email').eq('user_type', 'mechanic')
    Map<String, Map<String, dynamic>> mechanicDetailsMap = {};
    for (var mechanicId in earningsByMechanic.keys) {
      final mechanicProfile = await _supabase
          .from('user_profiles')
          .select('id, first_name, last_name, email')
          .eq('id', mechanicId)
          .eq('user_type', 'mechanic') // Only actual mechanics
          .maybeSingle();
      
      if (mechanicProfile != null) {
        mechanicDetailsMap[mechanicId] = {
          'name': '${mechanicProfile['first_name']} ${mechanicProfile['last_name']}',
          'email': mechanicProfile['email'],
          'earnings': earningsByMechanic[mechanicId],
        };
      }
    }

    return {
      'totalRevenue': shopEarnings,
      'platformFees': platformFees,
      'mechanicEarnings': mechanicEarnings,
      'totalJobs': jobs.length,
      'earningsByMechanic': earningsByMechanic, // Keep for backward compatibility
      'mechanicDetails': mechanicDetailsMap, // New: mechanic names and emails
      'earningsByService': earningsByService,
      'dailyJobCounts': dailyJobCounts,
    };
  }

  // Get service requests audit
  Future<List<Map<String, dynamic>>> getServiceRequests({
    required String shopId,
    String? status,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    var query = _supabase
        .from('service_requests')
        .select('''
          *,
          customer:customer_id(first_name, last_name, email, phone_number),
          mechanic:assigned_mechanic_id(first_name, last_name),
          category:category_id(name)
        ''')
        .eq('shop_id', shopId);

    if (status != null) {
      query = query.eq('status', status);
    }

    if (startDate != null) {
      query = query.gte('created_at', startDate.toIso8601String());
    }

    if (endDate != null) {
      query = query.lte('created_at', endDate.toIso8601String());
    }

    final response = await query.order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response as List);
  }

  // Get request status history
  Future<List<Map<String, dynamic>>> getRequestStatusHistory(String requestId) async {
    final response = await _supabase
        .from('request_status_history')
        .select('''
          *,
          changed_by_user:changed_by(first_name, last_name)
        ''')
        .eq('request_id', requestId)
        .order('created_at', ascending: true);

    return List<Map<String, dynamic>>.from(response as List);
  }

  // Get shop settings
  // Get shop settings with owner data
  // Query: shops.select('*'), user_profiles.select(...) joined by owner_id
  Future<Map<String, dynamic>?> getShopSettings(String shopId) async {
    final shopResponse = await _supabase
        .from('shops')
        .select('*')
        .eq('id', shopId)
        .single();

    Map<String, dynamic> settings = Map<String, dynamic>.from(shopResponse);

    // Get owner/talyer_owner data
    // Query: user_profiles.select(...).eq('id', owner_id).eq('user_type', 'talyer_owner')
    if (shopResponse['owner_id'] != null) {
      final ownerData = await _supabase
          .from('user_profiles')
          .select('first_name, last_name, email, phone_number, profile_image_url, business_permit_url, drivers_license_url')
          .eq('id', shopResponse['owner_id'])
          .maybeSingle();
      
      if (ownerData != null) {
        settings['owner_first_name'] = ownerData['first_name'];
        settings['owner_last_name'] = ownerData['last_name'];
        settings['owner_email'] = ownerData['email'];
        settings['owner_phone'] = ownerData['phone_number'];
        settings['owner_profile_image'] = ownerData['profile_image_url'];
        settings['business_permit_url'] = ownerData['business_permit_url'];
        settings['drivers_license_url'] = ownerData['drivers_license_url'];
        settings['contact_person'] = '${ownerData['first_name']} ${ownerData['last_name']}';
      }
    }

    return settings;
  }

  // Update shop settings
  Future<void> updateShopSettings({
    required String shopId,
    String? shopName,
    String? shopAddress,
    String? shopPhone,
    String? shopEmail,
    String? shopDescription,
    double? latitude,
    double? longitude,
    Map<String, dynamic>? businessHours,
    double? serviceRadius,
    String? contactPerson,
    String? ownerEmail,
    String? ownerPhone,
  }) async {
    final updateData = <String, dynamic>{};
    
    if (shopName != null) updateData['shop_name'] = shopName;
    if (shopAddress != null) updateData['shop_address'] = shopAddress;
    if (shopPhone != null) updateData['shop_phone'] = shopPhone;
    if (shopEmail != null) updateData['shop_email'] = shopEmail;
    if (shopDescription != null) updateData['shop_description'] = shopDescription;
    if (latitude != null) updateData['latitude'] = latitude;
    if (longitude != null) updateData['longitude'] = longitude;
    if (businessHours != null) updateData['business_hours'] = businessHours;
  if (serviceRadius != null) updateData['service_radius'] = serviceRadius;
  if (contactPerson != null) updateData['contact_person'] = contactPerson;
  // NOTE: owner email/phone belong to the owner user profile (user_profiles)
  // and are not columns on the shops table in some DB schemas. Do not
  // attempt to write owner_email/owner_phone into shops (PostgREST will
  // reject unknown columns). Instead, update the owner row in
  // user_profiles after updating shops.

    updateData['updated_at'] = DateTime.now().toIso8601String();

    await _supabase.from('shops').update(updateData).eq('id', shopId);

    // If owner contact fields were provided, update them on the owner's
    // user_profiles row instead of the shops table.
    if (ownerEmail != null || ownerPhone != null) {
      // Fetch the shop to get owner_id
      final shopRow = await _supabase
          .from('shops')
          .select('owner_id')
          .eq('id', shopId)
          .maybeSingle();

      final ownerId = shopRow?['owner_id'] as String?;
      if (ownerId != null) {
        final ownerUpdate = <String, dynamic>{};
        if (ownerEmail != null) ownerUpdate['email'] = ownerEmail;
        if (ownerPhone != null) ownerUpdate['phone_number'] = ownerPhone;

        if (ownerUpdate.isNotEmpty) {
          await _supabase.from('user_profiles').update(ownerUpdate).eq('id', ownerId);
        }
      }
    }
  }

  // Real-time subscription for dashboard updates
  RealtimeChannel subscribeToDashboardUpdates(String shopId, Function(Map<String, dynamic>) onUpdate) {
    final channel = _supabase.channel('dashboard_updates_$shopId');

    // Subscribe to service requests changes
    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'service_requests',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'shop_id',
        value: shopId,
      ),
      callback: (payload) {
        onUpdate({'type': 'service_request', 'data': payload});
      },
    );

    // Subscribe to invoice changes
    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'invoices',
      callback: (payload) {
        onUpdate({'type': 'invoice', 'data': payload});
      },
    );

    // Subscribe to job history changes
    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'mechanic_job_history',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'shop_id',
        value: shopId,
      ),
      callback: (payload) {
        onUpdate({'type': 'job_history', 'data': payload});
      },
    );

    channel.subscribe();
    return channel;
  }

  // Export invoices to CSV
  String generateInvoiceCSV(List<Map<String, dynamic>> invoices) {
    final buffer = StringBuffer();
    
    // Header
    buffer.writeln('Invoice Number,Date,Customer Name,Mechanic,Amount,Status,Payment Type');

    // Rows
    for (var invoice in invoices) {
      final customerName = invoice['customer'] != null 
          ? '${invoice['customer']['first_name']} ${invoice['customer']['last_name']}'
          : 'N/A';
      final mechanicName = invoice['mechanic'] != null
          ? '${invoice['mechanic']['first_name']} ${invoice['mechanic']['last_name']}'
          : 'N/A';
      
      buffer.writeln(
        '"${invoice['invoice_number']}",'
        '"${invoice['generated_at']}",'
        '"$customerName",'
        '"$mechanicName",'
        '${invoice['total_amount']},'
        '"${invoice['status']}",'
        '"${invoice['selected_payment_method'] ?? 'N/A'}"'
      );
    }

    return buffer.toString();
  }

  // Add new mechanic to shop - Direct creation via RPC function
  // This creates the mechanic immediately without invitation process
  Future<void> addMechanic({
    required String email,
    required String firstName,
    required String lastName,
    required String phone,
    required dynamic profileImage, // File object
    required String specialization,
    required int yearsExperience,
  }) async {
    print('🔧 [ADD MECHANIC] Starting direct creation for: $email');
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) {
      print('❌ [ADD MECHANIC] Not authenticated');
      throw Exception('Not authenticated');
    }
    print('✅ [ADD MECHANIC] User authenticated: ${currentUser.id}');

    // Check if email already exists
    print('🔍 [ADD MECHANIC] Checking if email exists: $email');
    final existingUser = await _supabase
        .from('user_profiles')
        .select('id, email')
        .eq('email', email)
        .maybeSingle();

    if (existingUser != null) {
      print('❌ [ADD MECHANIC] Email already exists');
      throw Exception('A user with this email already exists');
    }
    print('✅ [ADD MECHANIC] Email is available');

    // Upload profile image
    String? profileImageUrl;
    if (profileImage != null) {
      print('� [ADD MECHANIC] Uploading profile image...');
      final bytes = await profileImage.readAsBytes();
      final fileExt = profileImage.path.split('.').last;
      final fileName = 'mechanic_${email.replaceAll('@', '_')}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      final filePath = 'profile_images/$fileName';

      await _supabase.storage
          .from('profile-images')
          .uploadBinary(filePath, bytes);

      profileImageUrl = _supabase.storage
          .from('profile-images')
          .getPublicUrl(filePath);
      
      print('✅ [ADD MECHANIC] Profile image uploaded: $profileImageUrl');
    }

    // Generate temporary password
    print('🔑 [ADD MECHANIC] Generating temporary password');
    final random = Random.secure();
    final tempPassword = List.generate(12, (index) {
      const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#\$%^&*';
      return chars[random.nextInt(chars.length)];
    }).join();
    print('✅ [ADD MECHANIC] Temp password: $tempPassword');

    // Call RPC function to create mechanic directly
    print('🚀 [ADD MECHANIC] Calling RPC function to create mechanic...');
    try {
      final result = await _supabase.rpc('add_mechanic_to_shop', params: {
        'p_email': email,
        'p_first_name': firstName,
        'p_last_name': lastName,
        'p_phone': phone,
        'p_specialization': specialization,
        'p_years_experience': yearsExperience,
        'p_profile_image_url': profileImageUrl,
      });

      print('✅ [ADD MECHANIC] RPC result: $result');
      
      if (result != null && result['success'] == true) {
        print('✅ [ADD MECHANIC] Mechanic created successfully!');
        print('� Mechanic ID: ${result['mechanic_id']}');
        print('📧 Email: ${result['email']}');
        print('🔑 Temporary password: ${result['temporary_password']}');
      } else {
        final errorMsg = result?['error'] ?? 'Unknown error occurred';
        print('❌ [ADD MECHANIC] RPC failed: $errorMsg');
        throw Exception(errorMsg);
      }
    } catch (e) {
      print('❌ [ADD MECHANIC] Error: $e');
      rethrow;
    }
  }

  String _generateVerificationToken() {
    final random = Random.secure();
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return List.generate(32, (index) => chars[random.nextInt(chars.length)]).join();
  }
}
