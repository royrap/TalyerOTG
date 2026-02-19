import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/job_history.dart';
import 'earnings_service.dart';

class MechanicHistoryService {
  static final MechanicHistoryService _instance = MechanicHistoryService._internal();
  static MechanicHistoryService get instance => _instance;
  MechanicHistoryService._internal();

  final _supabase = Supabase.instance.client;

  // Get all job history for the current mechanic
  Future<List<MechanicJobHistory>> getMechanicJobHistory({
    int? limit,
    int? offset,
    String? status,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('No authenticated user');

      // Get user profile to show who is logged in
      final userProfile = await _supabase
          .from('user_profiles')
          .select('first_name, last_name, email, user_type')
          .eq('id', user.id)
          .maybeSingle();

      print('🔧 MechanicHistoryService.getMechanicJobHistory()');
      print('   📝 Logged in as: ${userProfile?['first_name']} ${userProfile?['last_name']} (${userProfile?['email']})');
      print('   👤 User ID: ${user.id}');
      print('   🎭 User Type: ${userProfile?['user_type']}');

      // Use RPC to bypass RLS and get customer data
      final result = await _supabase.rpc('get_mechanic_job_history');
      
      print('✅ RPC returned ${result.length} job history entries');

      // Map RPC result to expected structure
      final mappedResults = (result as List).map((mjh) {
        // Debug: Check if vehicle data exists in RPC result
        if (mjh['sr_vehicle_brand'] != null) {
          print('🚗 Vehicle data from RPC: ${mjh['sr_vehicle_brand']} ${mjh['sr_vehicle_model']} - ${mjh['sr_vehicle_plate']}');
        } else {
          print('⚠️ No vehicle data in RPC for job: ${mjh['job_title']} (sr_vehicle_brand is null)');
        }
        
        return {
          'id': mjh['id'],
          'mechanic_id': mjh['mechanic_id'],
          'service_request_id': mjh['service_request_id'],
          'customer_id': mjh['customer_id'],
          'shop_id': mjh['shop_id'],
          'job_title': mjh['job_title'],
          'job_description': mjh['job_description'],
          'job_status': mjh['job_status'],
          'completed_at': mjh['completed_at'],
          'cancelled_at': mjh['cancelled_at'],
          'total_amount': mjh['total_amount'],
          'rating': mjh['rating'],
          'review_text': mjh['review_text'],
          'job_duration_minutes': mjh['job_duration_minutes'],
          'created_at': mjh['created_at'],
          'updated_at': mjh['updated_at'],
          
          // Customer details (nested structure)
          'user_profiles': {
            'first_name': mjh['customer_first_name'],
            'last_name': mjh['customer_last_name'],
            'phone_number': mjh['customer_phone_number'],
            'profile_image_url': mjh['customer_profile_image_url'],
            'email': mjh['customer_email'],
          },
          
          // Service request details (nested structure)
          'service_requests': {
            'title': mjh['sr_title'],
            'description': mjh['sr_description'],
            'pickup_address': mjh['sr_pickup_address'],
            'pickup_latitude': mjh['sr_pickup_latitude'],
            'pickup_longitude': mjh['sr_pickup_longitude'],
            'service_type': mjh['sr_service_type'],
            'created_at': mjh['sr_created_at'],
            'status': mjh['sr_status'],
            'estimated_price': mjh['sr_estimated_price'],
            'service_fee': mjh['sr_service_fee'],
            'vehicle_brand': mjh['sr_vehicle_brand'],
            'vehicle_model': mjh['sr_vehicle_model'],
            'vehicle_plate': mjh['sr_vehicle_plate'],
          },
          
          // Shop details (nested structure)
          'shops': {
            'shop_name': mjh['shop_name'],
            'shop_address': mjh['shop_address'],
            'shop_phone': mjh['shop_phone'],
          },
        };
      }).toList();

      // Apply status filter if provided (filter in memory since RPC can't take params yet)
      var filteredResults = mappedResults;
      if (status != null) {
        filteredResults = mappedResults.where((job) => job['job_status'] == status).toList();
      }

      // Apply limit/offset if provided
      if (limit != null && offset != null) {
        final endIndex = (offset + limit).clamp(0, filteredResults.length);
        filteredResults = filteredResults.sublist(offset, endIndex);
      } else if (limit != null) {
        filteredResults = filteredResults.take(limit).toList();
      }

      return await _enrichWithEarningsData(
        filteredResults.map((data) => MechanicJobHistory.fromJson(data)).toList()
      );
    } catch (e) {
      print('❌ Error getting mechanic job history: $e');
      return [];
    }
  }

  // Enrich job history with earnings data from invoices
  Future<List<MechanicJobHistory>> _enrichWithEarningsData(List<MechanicJobHistory> jobs) async {
    try {
      // Get all service request IDs
      final requestIds = jobs.map((job) => job.serviceRequestId).toList();
      
      if (requestIds.isEmpty) return jobs;

      // Get invoice data for these service requests - using individual queries for now
      final invoices = <Map<String, dynamic>>[];
      for (final requestId in requestIds) {
        try {
          final result = await _supabase
              .from('invoices')
              .select('request_id, total_amount, platform_fee, provider_net_amount, status')
              .eq('request_id', requestId);
          invoices.addAll(result);
        } catch (e) {
          print('❌ Error getting invoice for request $requestId: $e');
        }
      }

      // Create a map for quick lookup
      final invoiceMap = <String, Map<String, dynamic>>{};
      for (var invoice in invoices) {
        invoiceMap[invoice['request_id']] = invoice;
      }

      // Enrich job history with earnings data and payment details
      return jobs.map((job) {
        final invoice = invoiceMap[job.serviceRequestId];
        
        // Get service_fee from service_requests
        final serviceFee = job.serviceRequest?.serviceFee;
        
        if (invoice != null && invoice['status'] == 'paid') {
          return MechanicJobHistory(
            id: job.id,
            mechanicId: job.mechanicId,
            serviceRequestId: job.serviceRequestId,
            customerId: job.customerId,
            shopId: job.shopId,
            jobTitle: job.jobTitle,
            jobDescription: job.jobDescription,
            jobStatus: job.jobStatus,
            completedAt: job.completedAt,
            cancelledAt: job.cancelledAt,
            totalAmount: invoice['total_amount']?.toDouble(), // 🎯 Invoice total (what mechanic sent)
            rating: job.rating,
            reviewText: job.reviewText,
            jobDurationMinutes: job.jobDurationMinutes,
            createdAt: job.createdAt,
            updatedAt: job.updatedAt,
            serviceRequest: job.serviceRequest,
            customer: job.customer,
            shop: job.shop,
            platformFee: invoice['platform_fee']?.toDouble(),
            netEarnings: invoice['provider_net_amount']?.toDouble(),
            serviceFee: serviceFee, // 🎯 Service fee from service_requests
            invoiceAmount: invoice['total_amount']?.toDouble(), // 🎯 Same as totalAmount for clarity
          );
        }
        
        // If no paid invoice yet, still show service fee if available
        return MechanicJobHistory(
          id: job.id,
          mechanicId: job.mechanicId,
          serviceRequestId: job.serviceRequestId,
          customerId: job.customerId,
          shopId: job.shopId,
          jobTitle: job.jobTitle,
          jobDescription: job.jobDescription,
          jobStatus: job.jobStatus,
          completedAt: job.completedAt,
          cancelledAt: job.cancelledAt,
          totalAmount: job.totalAmount,
          rating: job.rating,
          reviewText: job.reviewText,
          jobDurationMinutes: job.jobDurationMinutes,
          createdAt: job.createdAt,
          updatedAt: job.updatedAt,
          serviceRequest: job.serviceRequest,
          customer: job.customer,
          shop: job.shop,
          platformFee: job.platformFee,
          netEarnings: job.netEarnings,
          serviceFee: serviceFee, // 🎯 Service fee from service_requests
          invoiceAmount: job.totalAmount,
        );
      }).toList();
    } catch (e) {
      print('❌ Error enriching with earnings data: $e');
      return jobs;
    }
  }

  // Get job history by status
  Future<List<MechanicJobHistory>> getJobHistoryByStatus(String status) async {
    return await getMechanicJobHistory(status: status);
  }

  // Get completed jobs count
  Future<int> getCompletedJobsCount() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return 0;

      final result = await _supabase
          .from('mechanic_job_history')
          .select('id')
          .eq('mechanic_id', user.id)
          .eq('job_status', 'completed');

      return result.length;
    } catch (e) {
      print('❌ Error getting completed jobs count: $e');
      return 0;
    }
  }

  // Get cancelled jobs count
  Future<int> getCancelledJobsCount() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return 0;

      final result = await _supabase
          .from('mechanic_job_history')
          .select('id')
          .eq('mechanic_id', user.id)
          .eq('job_status', 'cancelled');

      return result.length;
    } catch (e) {
      print('❌ Error getting cancelled jobs count: $e');
      return 0;
    }
  }

  // Get total earnings (from completed jobs) - updated to sum all paid invoice amounts
  Future<double> getTotalEarnings() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return 0.0;

      // Sum all paid invoice amounts for this mechanic from database
      final response = await _supabase
          .from('invoices')
          .select('total_amount')
          .eq('mechanic_id', user.id)
          .eq('status', 'paid');

      if (response.isEmpty) {
        return 0.0;
      }

      double total = 0.0;
      for (var invoice in response) {
        if (invoice['total_amount'] != null) {
          total += (invoice['total_amount'] as num).toDouble();
        }
      }

      return total;
    } catch (e) {
      print('❌ Error getting total earnings: $e');
      return 0.0;
    }
  }

  // Get earnings this month - updated for Angkas-style
  Future<double> getEarningsThisMonth() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return 0.0;

      // Try using new earnings service first
      try {
        final summary = await EarningsService.instance.getMechanicEarningsSummary();
        return summary.thisMonthEarnings;
      } catch (e) {
        print('⚠️ New earnings service not available, using fallback: $e');
      }

      // Fallback: Manual calculation
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

      final jobs = await getJobHistoryByDateRange(
        startDate: startOfMonth,
        endDate: endOfMonth,
        status: 'completed',
      );

      double total = 0.0;
      for (var job in jobs) {
        if (job.totalAmount != null) {
          // Use Angkas-style calculation: 75% to mechanic
          total += job.totalAmount! * 0.75;
        } else if (job.netEarnings != null) {
          total += job.netEarnings!;
        }
      }

      return total;
    } catch (e) {
      print('❌ Error getting earnings this month: $e');
      return 0.0;
    }
  }

  // Get earnings this week - updated for Angkas-style
  Future<double> getEarningsThisWeek() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return 0.0;

      // Try using new earnings service first
      try {
        final summary = await EarningsService.instance.getMechanicEarningsSummary();
        return summary.thisWeekEarnings;
      } catch (e) {
        print('⚠️ New earnings service not available, using fallback: $e');
      }

      // Fallback: Manual calculation
      final now = DateTime.now();
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      final endOfWeek = startOfWeek.add(Duration(days: 6, hours: 23, minutes: 59, seconds: 59));

      final jobs = await getJobHistoryByDateRange(
        startDate: startOfWeek,
        endDate: endOfWeek,
        status: 'completed',
      );

      double total = 0.0;
      for (var job in jobs) {
        if (job.totalAmount != null) {
          // Use Angkas-style calculation: 75% to mechanic
          total += job.totalAmount! * 0.75;
        } else if (job.netEarnings != null) {
          total += job.netEarnings!;
        }
      }

      return total;
    } catch (e) {
      print('❌ Error getting earnings this week: $e');
      return 0.0;
    }
  }

  // Get earnings today - updated for Angkas-style
  Future<double> getEarningsToday() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return 0.0;

      // Calculate today's date range in local time then convert to UTC
      final now = DateTime.now();
      final localStartOfDay = DateTime(now.year, now.month, now.day);
      final localEndOfDay = localStartOfDay.add(Duration(hours: 23, minutes: 59, seconds: 59));
      
      // Convert to UTC for database query
      final startOfDayUTC = localStartOfDay.toUtc();
      final endOfDayUTC = localEndOfDay.toUtc();

      print('💰 Querying earnings for today: ${localStartOfDay} to ${localEndOfDay} (local)');
      print('💰 UTC range: ${startOfDayUTC} to ${endOfDayUTC}');

      // Sum all paid invoices for today directly from invoices table
      final result = await _supabase
          .from('invoices')
          .select('total_amount')
          .eq('mechanic_id', user.id)
          .eq('status', 'paid')
          .gte('paid_at', startOfDayUTC.toIso8601String())
          .lte('paid_at', endOfDayUTC.toIso8601String());

      double total = 0.0;
      for (var invoice in result) {
        final amount = invoice['total_amount'];
        if (amount != null) {
          total += (amount is int) ? amount.toDouble() : amount;
        }
      }

      print('💰 Today\'s earnings calculated: ₱$total from ${result.length} paid invoices');
      return total;
    } catch (e) {
      print('❌ Error getting earnings today: $e');
      return 0.0;
    }
  }

  // Get completed jobs count today
  Future<int> getCompletedJobsTodayCount() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return 0;

      // Get current local time and convert to UTC for database query
      final now = DateTime.now();
      final localStartOfDay = DateTime(now.year, now.month, now.day);
      final localEndOfDay = localStartOfDay.add(Duration(hours: 23, minutes: 59, seconds: 59));
      
      // Convert to UTC for database query
      final startOfDayUTC = localStartOfDay.toUtc();
      final endOfDayUTC = localEndOfDay.toUtc();

      print('🕐 Querying jobs for today: ${localStartOfDay} to ${localEndOfDay} (local)');
      print('🕐 UTC range: ${startOfDayUTC} to ${endOfDayUTC}');

      final jobs = await getJobHistoryByDateRange(
        startDate: startOfDayUTC,
        endDate: endOfDayUTC,
        status: 'completed',
      );

      print('✅ Found ${jobs.length} jobs completed today');
      return jobs.length;
    } catch (e) {
      print('❌ Error getting completed jobs today count: $e');
      return 0;
    }
  }

  // Get active jobs count
  Future<int> getActiveJobsCount() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return 0;

      // Query service_requests table for active jobs
      final result = await _supabase
          .from('service_requests')
          .select('id')
          .eq('provider_id', user.id)
          .inFilter('status', ['accepted', 'in_progress', 'provider_en_route', 'work_in_progress']);

      return result.length;
    } catch (e) {
      print('❌ Error getting active jobs count: $e');
      return 0;
    }
  }

  // Get average rating received from customers
  Future<double> getAverageRating() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return 0.0;

      final result = await _supabase
          .from('mechanic_job_history')
          .select('rating')
          .eq('mechanic_id', user.id)
          .not('rating', 'is', null);

      if (result.isEmpty) return 0.0;

      double totalRating = 0.0;
      int count = 0;

      for (var item in result) {
        final rating = item['rating'];
        if (rating != null) {
          totalRating += (rating is num) ? rating.toDouble() : double.tryParse(rating.toString()) ?? 0.0;
          count++;
        }
      }

      return count > 0 ? totalRating / count : 0.0;
    } catch (e) {
      print('❌ Error getting average rating: $e');
      return 0.0;
    }
  }

  // Get total hours worked
  Future<double> getTotalHoursWorked() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return 0.0;

      final result = await _supabase
          .from('mechanic_job_history')
          .select('job_duration_minutes')
          .eq('mechanic_id', user.id)
          .eq('job_status', 'completed')
          .not('job_duration_minutes', 'is', null);

      int totalMinutes = 0;
      for (var item in result) {
        final minutes = item['job_duration_minutes'];
        if (minutes != null) {
          totalMinutes += (minutes is int) ? minutes : int.tryParse(minutes.toString()) ?? 0;
        }
      }

      return totalMinutes / 60.0; // Convert to hours
    } catch (e) {
      print('❌ Error getting total hours worked: $e');
      return 0.0;
    }
  }

  // Get comprehensive earnings summary
  Future<MechanicEarningsSummary> getEarningsSummary() async {
    try {
      final completedJobs = await getCompletedJobsCount();
      final cancelledJobs = await getCancelledJobsCount();
      final totalEarnings = await getTotalEarnings();
      final averageRating = await getAverageRating();
      final totalHours = await getTotalHoursWorked();
      final earningsThisMonth = await getEarningsThisMonth();
      final earningsThisWeek = await getEarningsThisWeek();
      
      // Calculate platform fees (estimated)
      final platformFees = totalEarnings * 0.1111; // If net is 90%, gross is 111.11% of net
      
      return MechanicEarningsSummary(
        totalEarnings: totalEarnings / 0.9, // Convert net back to gross
        totalPlatformFees: platformFees,
        netEarnings: totalEarnings,
        completedJobs: completedJobs,
        cancelledJobs: cancelledJobs,
        averageRating: averageRating,
        totalHoursWorked: totalHours,
        earningsThisMonth: earningsThisMonth,
        earningsThisWeek: earningsThisWeek,
      );
    } catch (e) {
      print('❌ Error getting earnings summary: $e');
      return MechanicEarningsSummary(
        totalEarnings: 0.0,
        totalPlatformFees: 0.0,
        netEarnings: 0.0,
        completedJobs: 0,
        cancelledJobs: 0,
        averageRating: 0.0,
        totalHoursWorked: 0.0,
        earningsThisMonth: 0.0,
        earningsThisWeek: 0.0,
      );
    }
  }

  // Get recent job history (last 10)
  Future<List<MechanicJobHistory>> getRecentJobHistory() async {
    return await getMechanicJobHistory(limit: 10);
  }

  // Get dashboard statistics
  Future<Map<String, dynamic>> getDashboardStats() async {
    try {
      print('🔧 MechanicHistoryService.getDashboardStats() - Starting...');
      
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('No authenticated user');

      // Get all the stats in parallel for better performance
      final futures = [
        getActiveJobsCount(),
        getCompletedJobsTodayCount(), 
        getEarningsToday(),
        getAverageRating(),
        getCompletedJobsCount(),
        getTotalEarnings(),
      ];

      final results = await Future.wait(futures);
      
      final stats = {
        'activeJobs': results[0], // int
        'completedToday': results[1], // int
        'earningsToday': results[2], // double
        'averageRating': results[3], // double
        'totalCompleted': results[4], // int
        'totalEarnings': results[5], // double
        'isVerified': true, // TODO: get from service_providers table
        'isAvailable': true, // TODO: get from service_providers table 
        'status': 'online', // TODO: get from service_providers table
      };

      print('🔧 Dashboard stats calculated: $stats');
      return stats;
    } catch (e) {
      print('❌ Error getting dashboard stats: $e');
      return {
        'activeJobs': 0,
        'completedToday': 0,
        'earningsToday': 0.0,
        'averageRating': 0.0,
        'totalCompleted': 0,
        'totalEarnings': 0.0,
        'isVerified': false,
        'isAvailable': true,
        'status': 'offline',
      };
    }
  }

  // Search job history
  Future<List<MechanicJobHistory>> searchJobHistory(String query) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('No authenticated user');

      final result = await _supabase
          .from('mechanic_job_history')
          .select('''
            *,
            service_requests!mechanic_job_history_service_request_id_fkey(
              title,
              description,
              pickup_address,
              pickup_latitude,
              pickup_longitude,
              service_type,
              created_at,
              status,
              estimated_price
            ),
            user_profiles!mechanic_job_history_customer_id_fkey(
              first_name,
              last_name,
              phone_number,
              profile_image_url,
              email
            ),
            shops!mechanic_job_history_shop_id_fkey(
              shop_name,
              shop_address,
              shop_phone
            )
          ''')
          .eq('mechanic_id', user.id)
          .or('job_title.ilike.%$query%,job_description.ilike.%$query%')
          .order('created_at', ascending: false);

      return await _enrichWithEarningsData(result.map((data) => MechanicJobHistory.fromJson(data)).toList());
    } catch (e) {
      print('❌ Error searching job history: $e');
      return [];
    }
  }

  // Real-time stream for mechanic job history updates
  Stream<List<MechanicJobHistory>> getJobHistoryStream() async* {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('No authenticated user');

      // Yield initial data
      yield await getMechanicJobHistory();

      // Listen for real-time changes
      await for (final _ in _supabase
          .from('mechanic_job_history')
          .stream(primaryKey: ['id'])
          .eq('mechanic_id', user.id)) {
        
        print('🔧 Real-time job history update received');
        
        try {
          final updatedHistory = await getMechanicJobHistory();
          yield updatedHistory;
        } catch (e) {
          print('❌ Error fetching updated job history: $e');
        }
      }
    } catch (e) {
      print('❌ Error in job history stream: $e');
      rethrow;
    }
  }

  // Add a job to history (called when job is completed/cancelled)
  Future<bool> addJobToHistory({
    required String serviceRequestId,
    required String customerId,
    required String jobTitle,
    required String jobDescription,
    required String jobStatus,
    String? shopId,
    double? totalAmount,
    int? rating,
    String? reviewText,
    int? jobDurationMinutes,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('No authenticated user');

      print('🔧 MechanicHistoryService.addJobToHistory() - Adding job to history: $serviceRequestId');

      await _supabase.from('mechanic_job_history').insert({
        'mechanic_id': user.id,
        'service_request_id': serviceRequestId,
        'customer_id': customerId,
        'shop_id': shopId,
        'job_title': jobTitle,
        'job_description': jobDescription,
        'job_status': jobStatus,
        'completed_at': jobStatus == 'completed' ? DateTime.now().toIso8601String() : null,
        'cancelled_at': jobStatus == 'cancelled' ? DateTime.now().toIso8601String() : null,
        'total_amount': totalAmount,
        'rating': rating,
        'review_text': reviewText,
        'job_duration_minutes': jobDurationMinutes,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      print('✅ Job added to mechanic history successfully');
      return true;
    } catch (e) {
      print('❌ Error adding job to history: $e');
      return false;
    }
  }

  // Get job history by date range
  Future<List<MechanicJobHistory>> getJobHistoryByDateRange({
    required DateTime startDate,
    required DateTime endDate,
    String? status,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('No authenticated user');

      var query = _supabase
          .from('mechanic_job_history')
          .select('''
            *,
            service_requests!mechanic_job_history_service_request_id_fkey(
              title,
              description,
              pickup_address,
              pickup_latitude,
              pickup_longitude,
              service_type,
              created_at,
              status,
              estimated_price
            ),
            user_profiles!mechanic_job_history_customer_id_fkey(
              first_name,
              last_name,
              phone_number,
              profile_image_url,
              email
            ),
            shops!mechanic_job_history_shop_id_fkey(
              shop_name,
              shop_address,
              shop_phone
            )
          ''')
          .eq('mechanic_id', user.id)
          .gte('created_at', startDate.toIso8601String())
          .lte('created_at', endDate.toIso8601String());

      if (status != null) {
        query = query.eq('job_status', status);
      }

      final result = await query.order('created_at', ascending: false);

      return await _enrichWithEarningsData(result.map((data) => MechanicJobHistory.fromJson(data)).toList());
    } catch (e) {
      print('❌ Error getting job history by date range: $e');
      return [];
    }
  }
}