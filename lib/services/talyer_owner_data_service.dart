import 'package:supabase_flutter/supabase_flutter.dart';

/// 🏪 Comprehensive Talyer Owner Data Service
/// Fetches ALL relevant data from the complete database schema
class TalyerOwnerDataService {
  static final TalyerOwnerDataService _instance = TalyerOwnerDataService._internal();
  static TalyerOwnerDataService get instance => _instance;
  TalyerOwnerDataService._internal();

  final _supabase = Supabase.instance.client;

  /// ===== SHOP INFORMATION =====
  
  /// Get shop details with all related data
  Future<Map<String, dynamic>?> getShopDetails(String shopId) async {
    try {
      final response = await _supabase
          .from('shops')
          .select('''
            *,
            owner:user_profiles!shops_owner_id_fkey(
              id,
              first_name,
              last_name,
              email,
              phone_number,
              profile_image_url,
              rating,
              total_reviews
            )
          ''')
          .eq('id', shopId)
          .single();
      
      return response;
    } catch (e) {
      print('❌ Error getting shop details: $e');
      return null;
    }
  }

  /// Get shop statistics from cache table
  Future<Map<String, dynamic>?> getShopStatsCache(String shopId) async {
    try {
      final response = await _supabase
          .from('shop_stats_cache')
          .select('*')
          .eq('shop_id', shopId)
          .maybeSingle();
      
      return response;
    } catch (e) {
      print('❌ Error getting shop stats cache: $e');
      return null;
    }
  }

  /// ===== SERVICE REQUESTS =====
  
  /// Get service requests with comprehensive filtering
  Future<List<Map<String, dynamic>>> getServiceRequests({
    required String shopId,
    List<String>? statuses,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  }) async {
    try {
      var query = _supabase
          .from('service_requests')
          .select('''
            *,
            customer:user_profiles!service_requests_customer_id_fkey(
              id,
              first_name,
              last_name,
              email,
              phone_number,
              profile_image_url,
              rating
            ),
            mechanic:user_profiles!service_requests_assigned_mechanic_id_fkey(
              id,
              first_name,
              last_name,
              profile_image_url,
              rating
            ),
            vehicle:vehicles(
              id,
              brand_name,
              model_name,
              year,
              plate_number,
              color
            ),
            category:service_categories(
              id,
              name,
              description,
              icon_name
            ),
            invoice:invoices(
              id,
              invoice_number,
              total_amount,
              status,
              payment_details
            )
          ''')
          .eq('shop_id', shopId);

      if (statuses != null && statuses.isNotEmpty) {
        query = query.inFilter('status', statuses);
      }

      if (startDate != null) {
        query = query.gte('created_at', startDate.toIso8601String());
      }

      if (endDate != null) {
        query = query.lte('created_at', endDate.toIso8601String());
      }

      final response = await (limit != null 
          ? query.limit(limit).order('created_at', ascending: false)
          : query.order('created_at', ascending: false));
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('❌ Error getting service requests: $e');
      return [];
    }
  }

  /// Get jobs statistics by period
  Future<Map<String, dynamic>> getJobsStatistics({
    required String shopId,
    required DateTime startDate,
    DateTime? endDate,
  }) async {
    try {
      var query = _supabase
          .from('service_requests')
          .select('id, status, final_price, shop_earnings, mechanic_earnings, platform_fee')
          .eq('shop_id', shopId)
          .gte('created_at', startDate.toIso8601String());

      if (endDate != null) {
        query = query.lte('created_at', endDate.toIso8601String());
      }

      final jobs = await query;

      // Calculate statistics
      final total = jobs.length;
      final completed = jobs.where((j) => j['status'] == 'completed').length;
      final cancelled = jobs.where((j) => j['status'] == 'cancelled').length;
      final pending = jobs.where((j) => j['status'] == 'pending').length;
      final active = jobs.where((j) => 
        ['accepted', 'in_progress', 'assigned', 'inspection_started'].contains(j['status'])
      ).length;

      double totalRevenue = 0.0;
      double shopEarnings = 0.0;
      double mechanicEarnings = 0.0;
      double platformFees = 0.0;

      for (var job in jobs) {
        if (job['status'] == 'completed') {
          totalRevenue += (job['final_price'] ?? 0.0).toDouble();
          shopEarnings += (job['shop_earnings'] ?? 0.0).toDouble();
          mechanicEarnings += (job['mechanic_earnings'] ?? 0.0).toDouble();
          platformFees += (job['platform_fee'] ?? 0.0).toDouble();
        }
      }

      return {
        'total_jobs': total,
        'completed_jobs': completed,
        'cancelled_jobs': cancelled,
        'pending_jobs': pending,
        'active_jobs': active,
        'completion_rate': total > 0 ? (completed / total * 100) : 0.0,
        'total_revenue': totalRevenue,
        'shop_earnings': shopEarnings,
        'mechanic_earnings': mechanicEarnings,
        'platform_fees': platformFees,
        'average_job_value': completed > 0 ? (totalRevenue / completed) : 0.0,
      };
    } catch (e) {
      print('❌ Error getting jobs statistics: $e');
      return {};
    }
  }

  /// ===== MECHANICS MANAGEMENT =====
  
  /// Get all shop mechanics with comprehensive data
  Future<List<Map<String, dynamic>>> getShopMechanics(String shopId) async {
    try {
      // Use RPC function to bypass RLS recursion
      final mechanics = await _supabase.rpc('get_shop_mechanics_for_owner') as List;

      // Get all mechanic IDs
      final mechanicIds = mechanics
          .map((m) => m['mechanic_id'] as String)
          .toList();

      // Get availability status separately
      final availabilities = mechanicIds.isEmpty ? [] : await _supabase
          .from('mechanic_availability_status')
          .select('*')
          .inFilter('mechanic_id', mechanicIds);

      // Map availability by mechanic_id
      final availabilityMap = {
        for (var av in availabilities) av['mechanic_id']: av
      };

      // Transform RPC result to match expected structure
      final result = mechanics.map((m) {
        final mechanicId = m['mechanic_id'];
        return {
          'mechanic_id': mechanicId,
          'shop_id': m['shop_id'],
          'specialties': m['specialties'],
          'hourly_rate': m['hourly_rate'],
          'is_active': m['is_active'],
          'is_available': m['is_available'],
          'mechanic': {
            'id': mechanicId,
            'first_name': m['first_name'],
            'last_name': m['last_name'],
            'email': m['email'],
            'phone_number': m['phone_number'],
            'profile_image_url': m['profile_image_url'], // Now returned from RPC
            'rating': m['rating'], // Now returned from RPC
            'total_reviews': m['total_reviews'], // Now returned from RPC
            'status': null,
            'is_available': m['is_available'],
          },
          'availability': availabilityMap[mechanicId],
        };
      }).toList();

      return List<Map<String, dynamic>>.from(result);
    } catch (e) {
      print('❌ Error getting shop mechanics: $e');
      return [];
    }
  }

  /// Get mechanic job history and performance
  Future<Map<String, dynamic>> getMechanicPerformance({
    required String mechanicId,
    DateTime? startDate,
  }) async {
    try {
      var query = _supabase
          .from('mechanic_job_history')
          .select('*')
          .eq('mechanic_id', mechanicId);

      if (startDate != null) {
        query = query.gte('created_at', startDate.toIso8601String());
      }

      final jobs = await query;

      final totalJobs = jobs.length;
      final completedJobs = jobs.where((j) => j['job_status'] == 'completed').length;
      
      double totalEarnings = 0.0;
      double totalRating = 0.0;
      int ratedJobs = 0;
      int totalDuration = 0;

      for (var job in jobs) {
        if (job['mechanic_earnings'] != null) {
          totalEarnings += (job['mechanic_earnings'] as num).toDouble();
        }
        if (job['rating'] != null) {
          totalRating += (job['rating'] as num).toDouble();
          ratedJobs++;
        }
        if (job['job_duration_minutes'] != null) {
          totalDuration += (job['job_duration_minutes'] as int);
        }
      }

      return {
        'total_jobs': totalJobs,
        'completed_jobs': completedJobs,
        'total_earnings': totalEarnings,
        'average_rating': ratedJobs > 0 ? (totalRating / ratedJobs) : 0.0,
        'average_duration_minutes': totalJobs > 0 ? (totalDuration / totalJobs) : 0,
        'completion_rate': totalJobs > 0 ? (completedJobs / totalJobs * 100) : 0.0,
      };
    } catch (e) {
      print('❌ Error getting mechanic performance: $e');
      return {};
    }
  }

  /// ===== FINANCIAL OVERVIEW =====
  
  /// Get invoices for shop
  Future<List<Map<String, dynamic>>> getInvoices({
    required String shopId,
    List<String>? statuses,
    DateTime? startDate,
    int? limit,
  }) async {
    try {
      var query = _supabase
          .from('invoices')
          .select('''
            *,
            request:service_requests(
              id,
              title,
              service_type
            ),
            customer:user_profiles!invoices_customer_id_fkey(
              id,
              first_name,
              last_name,
              email,
              phone_number
            ),
            mechanic:user_profiles!invoices_mechanic_id_fkey(
              id,
              first_name,
              last_name
            ),
            payment:payments(
              id,
              payment_method,
              status,
              processed_at
            )
          ''')
          .eq('request_id.shop_id', shopId);

      if (statuses != null && statuses.isNotEmpty) {
        query = query.inFilter('status', statuses);
      }

      if (startDate != null) {
        query = query.gte('generated_at', startDate.toIso8601String());
      }

      final response = await (limit != null
          ? query.limit(limit).order('generated_at', ascending: false)
          : query.order('generated_at', ascending: false));
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('❌ Error getting invoices: $e');
      return [];
    }
  }

  /// Get payments with cash verification details
  Future<List<Map<String, dynamic>>> getPayments({
    required String shopId,
    DateTime? startDate,
    int? limit,
  }) async {
    try {
      // First get service requests for this shop
      var requestQuery = _supabase
          .from('service_requests')
          .select('id')
          .eq('shop_id', shopId);

      if (startDate != null) {
        requestQuery = requestQuery.gte('created_at', startDate.toIso8601String());
      }

      final requests = await requestQuery;
      final requestIds = requests.map((r) => r['id'] as String).toList();

      if (requestIds.isEmpty) return [];

      // Get payments for these requests
      var query = _supabase
          .from('payments')
          .select('''
            *,
            request:service_requests(
              id,
              title,
              service_type
            ),
            customer:user_profiles!payments_customer_id_fkey(
              id,
              first_name,
              last_name,
              phone_number
            ),
            cash_verification:cash_payment_verifications(
              id,
              receipt_photo_url,
              cash_photo_url,
              verification_status,
              verified_at
            )
          ''')
          .inFilter('request_id', requestIds);

      final response = await (limit != null
          ? query.limit(limit).order('created_at', ascending: false)
          : query.order('created_at', ascending: false));
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('❌ Error getting payments: $e');
      return [];
    }
  }

  /// Get earnings summary by period
  Future<Map<String, dynamic>> getEarningsSummary({
    required String shopId,
    required String period, // 'today', 'week', 'month', 'year'
  }) async {
    try {
      final now = DateTime.now();
      DateTime startDate;

      switch (period) {
        case 'today':
          startDate = DateTime(now.year, now.month, now.day);
          break;
        case 'week':
          startDate = now.subtract(Duration(days: now.weekday - 1));
          startDate = DateTime(startDate.year, startDate.month, startDate.day);
          break;
        case 'month':
          startDate = DateTime(now.year, now.month, 1);
          break;
        case 'year':
          startDate = DateTime(now.year, 1, 1);
          break;
        default:
          startDate = DateTime(now.year, now.month, now.day);
      }

      final jobs = await _supabase
          .from('service_requests')
          .select('shop_earnings, mechanic_earnings, platform_fee, final_price, completed_at')
          .eq('shop_id', shopId)
          .eq('status', 'completed')
          .gte('completed_at', startDate.toIso8601String());

      double shopTotal = 0.0;
      double mechanicTotal = 0.0;
      double platformTotal = 0.0;
      double revenueTotal = 0.0;

      for (var job in jobs) {
        shopTotal += (job['shop_earnings'] ?? 0.0).toDouble();
        mechanicTotal += (job['mechanic_earnings'] ?? 0.0).toDouble();
        platformTotal += (job['platform_fee'] ?? 0.0).toDouble();
        revenueTotal += (job['final_price'] ?? 0.0).toDouble();
      }

      return {
        'period': period,
        'start_date': startDate.toIso8601String(),
        'shop_earnings': shopTotal,
        'mechanic_earnings': mechanicTotal,
        'platform_fees': platformTotal,
        'total_revenue': revenueTotal,
        'completed_jobs': jobs.length,
      };
    } catch (e) {
      print('❌ Error getting earnings summary: $e');
      return {};
    }
  }

  /// ===== NOTIFICATIONS =====
  
  /// Get shop notifications
  Future<List<Map<String, dynamic>>> getShopNotifications({
    required String shopId,
    bool? unreadOnly,
    int? limit,
  }) async {
    try {
      var query = _supabase
          .from('shop_notifications')
          .select('''
            *,
            related_request:service_requests(
              id,
              title,
              status
            )
          ''')
          .eq('shop_id', shopId);

      if (unreadOnly == true) {
        query = query.eq('is_read', false);
      }

      final response = await (limit != null
          ? query.limit(limit).order('created_at', ascending: false)
          : query.order('created_at', ascending: false));
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('❌ Error getting shop notifications: $e');
      return [];
    }
  }

  /// Mark notification as read
  Future<bool> markNotificationAsRead(String notificationId) async {
    try {
      await _supabase
          .from('shop_notifications')
          .update({'is_read': true})
          .eq('id', notificationId);
      
      return true;
    } catch (e) {
      print('❌ Error marking notification as read: $e');
      return false;
    }
  }

  /// ===== REVIEWS =====
  
  /// Get shop reviews
  Future<List<Map<String, dynamic>>> getShopReviews({
    required String shopId,
    int? limit,
  }) async {
    try {
      // Get service requests for this shop first
      final requests = await _supabase
          .from('service_requests')
          .select('id')
          .eq('shop_id', shopId);

      final requestIds = requests.map((r) => r['id'] as String).toList();

      if (requestIds.isEmpty) return [];

      var query = _supabase
          .from('reviews')
          .select('''
            *,
            customer:user_profiles!reviews_customer_id_fkey(
              id,
              first_name,
              last_name,
              profile_image_url
            ),
            request:service_requests(
              id,
              title,
              service_type
            )
          ''')
          .inFilter('request_id', requestIds);

      final response = await (limit != null
          ? query.limit(limit).order('created_at', ascending: false)
          : query.order('created_at', ascending: false));
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('❌ Error getting shop reviews: $e');
      return [];
    }
  }

  /// ===== CUSTOMERS =====
  
  /// Get shop customers history
  Future<List<Map<String, dynamic>>> getShopCustomers({
    required String shopId,
    int? limit,
  }) async {
    try {
      final response = await _supabase
          .from('service_requests')
          .select('''
            customer_id,
            customer:user_profiles!service_requests_customer_id_fkey(
              id,
              first_name,
              last_name,
              email,
              phone_number,
              profile_image_url,
              rating
            ),
            created_at,
            status
          ''')
          .eq('shop_id', shopId)
          .order('created_at', ascending: false);

      // Group by customer to get unique customers
      final Map<String, Map<String, dynamic>> customersMap = {};
      
      for (var request in response) {
        final customerId = request['customer_id'];
        if (customerId != null && !customersMap.containsKey(customerId)) {
          customersMap[customerId] = {
            ...request['customer'],
            'first_visit': request['created_at'],
            'total_requests': 1,
          };
        } else if (customerId != null) {
          customersMap[customerId]!['total_requests'] += 1;
        }
      }

      return customersMap.values.toList();
    } catch (e) {
      print('❌ Error getting shop customers: $e');
      return [];
    }
  }

  /// ===== SHOP SERVICES =====
  
  /// Get shop services
  Future<List<Map<String, dynamic>>> getShopServices(String shopId) async {
    try {
      final response = await _supabase
          .from('shop_services')
          .select('''
            *,
            category:service_categories(
              id,
              name,
              description,
              icon_name
            )
          ''')
          .eq('shop_id', shopId)
          .eq('is_active', true)
          .order('display_priority', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('❌ Error getting shop services: $e');
      return [];
    }
  }

  /// ===== COMPLETED JOBS & HISTORY =====
  
  /// Get ALL completed jobs with full details (from mechanic_job_history)
  Future<List<Map<String, dynamic>>> getAllCompletedJobs({
    required String shopId,
    DateTime? startDate,
    DateTime? endDate,
    String? mechanicId,
    int? limit,
  }) async {
    try {
      var query = _supabase
          .from('mechanic_job_history')
          .select('''
            *,
            mechanic:user_profiles!mechanic_job_history_mechanic_id_fkey(
              id,
              first_name,
              last_name,
              profile_image_url,
              rating
            ),
            customer:user_profiles!mechanic_job_history_customer_id_fkey(
              id,
              first_name,
              last_name,
              phone_number
            ),
            service_request:service_requests(
              id,
              title,
              service_type,
              category:service_categories(
                name,
                icon_name
              )
            )
          ''')
          .eq('shop_id', shopId)
          .eq('job_status', 'completed');

      if (mechanicId != null) {
        query = query.eq('mechanic_id', mechanicId);
      }

      if (startDate != null) {
        query = query.gte('completed_at', startDate.toIso8601String());
      }

      if (endDate != null) {
        query = query.lte('completed_at', endDate.toIso8601String());
      }

      final response = await (limit != null
          ? query.limit(limit).order('completed_at', ascending: false)
          : query.order('completed_at', ascending: false));
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('❌ Error getting all completed jobs: $e');
      return [];
    }
  }

  /// Get mechanic-wise job completion statistics
  Future<List<Map<String, dynamic>>> getMechanicsJobStats({
    required String shopId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      // First get all mechanics for this shop
      final mechanics = await getShopMechanics(shopId);
      
      List<Map<String, dynamic>> mechanicStats = [];
      
      for (var mechanic in mechanics) {
        final mechanicId = mechanic['mechanic_id'];
        
        // Get job history for this mechanic
        var query = _supabase
            .from('mechanic_job_history')
            .select('*')
            .eq('mechanic_id', mechanicId)
            .eq('shop_id', shopId);

        if (startDate != null) {
          query = query.gte('created_at', startDate.toIso8601String());
        }

        if (endDate != null) {
          query = query.lte('created_at', endDate.toIso8601String());
        }

        final jobs = await query;
        
        final completedJobs = jobs.where((j) => j['job_status'] == 'completed').toList();
        final cancelledJobs = jobs.where((j) => j['job_status'] == 'cancelled').length;
        
        double totalEarnings = 0.0;
        double totalShopEarnings = 0.0;
        double totalMechanicEarnings = 0.0;
        double totalPlatformFees = 0.0;
        double totalRating = 0.0;
        int ratedJobs = 0;
        int totalDuration = 0;

        for (var job in completedJobs) {
          totalEarnings += (job['total_amount'] ?? 0.0).toDouble();
          totalMechanicEarnings += (job['mechanic_earnings'] ?? 0.0).toDouble();
          totalShopEarnings += (job['shop_earnings'] ?? 0.0).toDouble();
          totalPlatformFees += (job['platform_fee'] ?? 0.0).toDouble();
          
          if (job['rating'] != null) {
            totalRating += (job['rating'] as num).toDouble();
            ratedJobs++;
          }
          
          if (job['job_duration_minutes'] != null) {
            totalDuration += (job['job_duration_minutes'] as int);
          }
        }

        // Get overall mechanic rating from user_profiles as fallback
        double overallRating = 0.0;
        try {
          final profileData = await _supabase
              .from('user_profiles')
              .select('rating, total_reviews')
              .eq('id', mechanicId)
              .maybeSingle();
          if (profileData != null && profileData['rating'] != null) {
            overallRating = (profileData['rating'] as num).toDouble();
          }
        } catch (e) {
          print('Error fetching mechanic rating: $e');
        }

        mechanicStats.add({
          'mechanic': mechanic['mechanic'],
          'mechanic_id': mechanicId,
          'total_jobs': jobs.length,
          'completed_jobs': completedJobs.length,
          'cancelled_jobs': cancelledJobs,
          'completion_rate': jobs.isNotEmpty ? (completedJobs.length / jobs.length * 100) : 0.0,
          'total_revenue': totalEarnings,
          'mechanic_earnings': totalMechanicEarnings,
          'shop_earnings': totalShopEarnings,
          'platform_fees': totalPlatformFees,
          'average_rating': ratedJobs > 0 ? (totalRating / ratedJobs) : overallRating,
          'overall_rating': overallRating,
          'average_duration_minutes': completedJobs.isNotEmpty ? (totalDuration / completedJobs.length) : 0,
          'is_available': mechanic['is_available'],
        });
      }
      
      // Sort by completed jobs descending
      mechanicStats.sort((a, b) => (b['completed_jobs'] as int).compareTo(a['completed_jobs'] as int));
      
      return mechanicStats;
    } catch (e) {
      print('❌ Error getting mechanics job stats: $e');
      return [];
    }
  }

  /// Get comprehensive earnings breakdown for shop owner
  Future<Map<String, dynamic>> getComprehensiveEarningsBreakdown({
    required String shopId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      // Query from both service_requests and mechanic_job_history
      var requestQuery = _supabase
          .from('service_requests')
          .select('final_price, shop_earnings, mechanic_earnings, platform_fee, completed_at')
          .eq('shop_id', shopId)
          .eq('status', 'completed');

      if (startDate != null) {
        requestQuery = requestQuery.gte('completed_at', startDate.toIso8601String());
      }

      if (endDate != null) {
        requestQuery = requestQuery.lte('completed_at', endDate.toIso8601String());
      }

      final serviceRequests = await requestQuery;

      // Also get from mechanic_job_history for cross-verification
      var historyQuery = _supabase
          .from('mechanic_job_history')
          .select('total_amount, mechanic_earnings, shop_earnings, platform_fee, completed_at')
          .eq('shop_id', shopId)
          .eq('job_status', 'completed');

      if (startDate != null) {
        historyQuery = historyQuery.gte('completed_at', startDate.toIso8601String());
      }

      if (endDate != null) {
        historyQuery = historyQuery.lte('completed_at', endDate.toIso8601String());
      }

      final jobHistory = await historyQuery;

      // Calculate from service_requests (primary source)
      double totalRevenue = 0.0;
      double shopEarnings = 0.0;
      double mechanicEarnings = 0.0;
      double platformFees = 0.0;
      int completedJobs = 0;

      for (var request in serviceRequests) {
        totalRevenue += (request['final_price'] ?? 0.0).toDouble();
        shopEarnings += (request['shop_earnings'] ?? 0.0).toDouble();
        mechanicEarnings += (request['mechanic_earnings'] ?? 0.0).toDouble();
        platformFees += (request['platform_fee'] ?? 0.0).toDouble();
        completedJobs++;
      }

      // Calculate from job history (for verification)
      double historyTotalRevenue = 0.0;
      double historyShopEarnings = 0.0;
      double historyMechanicEarnings = 0.0;
      double historyPlatformFees = 0.0;

      for (var job in jobHistory) {
        historyTotalRevenue += (job['total_amount'] ?? 0.0).toDouble();
        historyShopEarnings += (job['shop_earnings'] ?? 0.0).toDouble();
        historyMechanicEarnings += (job['mechanic_earnings'] ?? 0.0).toDouble();
        historyPlatformFees += (job['platform_fee'] ?? 0.0).toDouble();
      }

      return {
        'total_revenue': totalRevenue,
        'shop_earnings': shopEarnings,
        'mechanic_earnings': mechanicEarnings,
        'platform_fees': platformFees,
        'completed_jobs_count': completedJobs,
        'average_job_value': completedJobs > 0 ? (totalRevenue / completedJobs) : 0.0,
        'shop_percentage': totalRevenue > 0 ? (shopEarnings / totalRevenue * 100) : 0.0,
        'mechanic_percentage': totalRevenue > 0 ? (mechanicEarnings / totalRevenue * 100) : 0.0,
        'platform_percentage': totalRevenue > 0 ? (platformFees / totalRevenue * 100) : 0.0,
        // History data for cross-reference
        'history_total_jobs': jobHistory.length,
        'history_total_revenue': historyTotalRevenue,
        'history_shop_earnings': historyShopEarnings,
        'history_mechanic_earnings': historyMechanicEarnings,
        'history_platform_fees': historyPlatformFees,
      };
    } catch (e) {
      print('❌ Error getting comprehensive earnings breakdown: $e');
      return {};
    }
  }

  /// Get recent job activity (last N jobs)
  Future<List<Map<String, dynamic>>> getRecentJobActivity({
    required String shopId,
    int limit = 20,
  }) async {
    try {
      final response = await _supabase
          .from('mechanic_job_history')
          .select('''
            *,
            mechanic:user_profiles!mechanic_job_history_mechanic_id_fkey(
              first_name,
              last_name,
              profile_image_url
            ),
            customer:user_profiles!mechanic_job_history_customer_id_fkey(
              first_name,
              last_name
            )
          ''')
          .eq('shop_id', shopId)
          .order('created_at', ascending: false)
          .limit(limit);
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('❌ Error getting recent job activity: $e');
      return [];
    }
  }

  /// ===== DASHBOARD OVERVIEW =====
  
  /// Get complete dashboard data using RPC (bypasses RLS)
  Future<Map<String, dynamic>> getDashboardOverview({
    required String shopId,
    required String ownerId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      // Use RPC functions that bypass RLS
      final results = await Future.wait([
        // Get dashboard stats via RPC
        _supabase.rpc('get_talyer_owner_dashboard_stats').select(),
        // Get recent requests via RPC
        _supabase.rpc('get_talyer_owner_recent_requests', params: {'limit_count': 10}).select(),
        // Get mechanic stats via RPC
        _supabase.rpc('get_talyer_owner_mechanic_stats').select(),
        // Get earnings breakdown via RPC
        _supabase.rpc('get_talyer_owner_earnings_breakdown').select(),
        // Get mechanics with availability (this one works)
        getShopMechanics(shopId),
        // Get notifications (this one works)
        getShopNotifications(shopId: shopId, unreadOnly: true, limit: 5),
      ]);

      final dashboardStats = (results[0] as List).isNotEmpty ? (results[0] as List)[0] : {};
      final recentRequests = results[1] as List;
      final mechanicStats = results[2] as List;
      final earningsBreakdown = results[3] as List;
      final mechanics = results[4] as List;
      final notifications = results[5] as List;

      return {
        // Dashboard stats from RPC
        'shop_id': dashboardStats['shop_id'],
        'shop_name': dashboardStats['shop_name'],
        'shop_address': dashboardStats['shop_address'],
        'shop_phone': dashboardStats['shop_phone'],
        'shop_status': dashboardStats['shop_status'],
        
        // Mechanic counts
        'total_mechanics': dashboardStats['total_mechanics'] ?? 0,
        'available_mechanics': dashboardStats['available_mechanics'] ?? 0,
        'busy_mechanics': dashboardStats['busy_mechanics'] ?? 0,
        
        // Job counts
        'total_jobs': dashboardStats['total_jobs'] ?? 0,
        'active_jobs': dashboardStats['active_jobs'] ?? 0,
        'completed_jobs': dashboardStats['completed_jobs'] ?? 0,
        'pending_requests': dashboardStats['pending_requests'] ?? 0,
        
        // Earnings
        'total_earnings': dashboardStats['total_earnings'] ?? 0.0,
        'today_earnings': dashboardStats['today_earnings'] ?? 0.0,
        'this_week_earnings': dashboardStats['this_week_earnings'] ?? 0.0,
        'this_month_earnings': dashboardStats['this_month_earnings'] ?? 0.0,
        
        // Customer stats
        'total_customers': dashboardStats['total_customers'] ?? 0,
        'active_customers_today': dashboardStats['active_customers_today'] ?? 0,
        
        // Rating
        'average_shop_rating': dashboardStats['average_shop_rating'] ?? 0.0,
        'total_shop_reviews': dashboardStats['total_shop_reviews'] ?? 0,
        
        // Lists
        'active_requests': recentRequests,
        'mechanics': mechanics,
        'mechanics_performance': mechanicStats,
        'earnings_breakdown': earningsBreakdown,
        'unread_notifications': notifications,
        
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      print('❌ Error getting dashboard overview: $e');
      print('Full error: ${e.toString()}');
      rethrow;
    }
  }
}
