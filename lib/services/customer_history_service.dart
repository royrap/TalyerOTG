import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/job_history.dart';

class CustomerHistoryService {
  static final CustomerHistoryService _instance = CustomerHistoryService._internal();
  static CustomerHistoryService get instance => _instance;
  CustomerHistoryService._internal();

  final _supabase = Supabase.instance.client;

  // Sync service_requests data to customer_job_history table for better performance
  Future<bool> syncServiceRequestsToHistory({String? customerId}) async {
    try {
      final user = _supabase.auth.currentUser;
      final targetCustomerId = customerId ?? user?.id;
      
      if (targetCustomerId == null) {
        print('❌ No customer ID provided for sync');
        return false;
      }

      print('🔄 Syncing service_requests to customer_job_history for customer: $targetCustomerId');

      // Get all service_requests for this customer that aren't in customer_job_history yet
      final serviceRequests = await _supabase
          .from('service_requests')
          .select('''
            id,
            customer_id,
            title,
            description,
            status,
            pickup_address,
            service_type,
            estimated_price,
            final_price,
            service_completion_time,
            cancelled_at,
            created_at,
            updated_at,
            vehicle_info,
            provider_id,
            shop_id,
            assigned_mechanic_id,
            vehicle_id,
            provider:user_profiles!service_requests_provider_id_fkey(
              first_name,
              last_name,
              phone_number,
              profile_image_url
            ),
            mechanic:user_profiles!service_requests_assigned_mechanic_id_fkey(
              first_name,
              last_name,
              phone_number,
              profile_image_url
            ),
            shop:shops!service_requests_shop_id_fkey(
              shop_name,
              shop_address,
              shop_phone
            ),
            vehicle:vehicles!service_requests_vehicle_id_fkey(
              brand_name,
              model_name,
              year,
              color,
              plate_number,
              vehicle_type
            ),
            category:service_categories!service_requests_category_id_fkey(
              name,
              icon_name
            ),
            reviews:reviews(rating, comment),
            invoices:invoices(total_amount, status)
          ''')
          .eq('customer_id', targetCustomerId)
          .order('created_at', ascending: false);

      print('📊 Found ${serviceRequests.length} service requests to sync');

      // Check which ones are already in customer_job_history
      final existingHistory = await _supabase
          .from('customer_job_history')
          .select('service_request_id')
          .eq('customer_id', targetCustomerId);

      final existingRequestIds = existingHistory.map((h) => h['service_request_id']).toSet();

      // Filter out already synced requests
      final newRequests = serviceRequests.where((req) => !existingRequestIds.contains(req['id'])).toList();

      print('📋 ${newRequests.length} new requests to add to customer_job_history');

      if (newRequests.isEmpty) {
        print('✅ All service requests already synced');
        return true;
      }

      // Convert and insert into customer_job_history
      final historyRecords = <Map<String, dynamic>>[];
      
      for (final req in newRequests) {
        // Extract mechanic info
        String? mechanicName;
        String? mechanicId = req['assigned_mechanic_id'] ?? req['provider_id'];
        
        if (req['mechanic'] != null) {
          final mechanic = req['mechanic'];
          mechanicName = '${mechanic['first_name'] ?? ''} ${mechanic['last_name'] ?? ''}'.trim();
        } else if (req['provider'] != null) {
          final provider = req['provider'];
          mechanicName = '${provider['first_name'] ?? ''} ${provider['last_name'] ?? ''}'.trim();
        }
        
        if (mechanicName != null && mechanicName.isEmpty) mechanicName = null;

        // Extract shop name
        String? shopName = req['shop'] != null ? req['shop']['shop_name'] : null;

        // Extract vehicle info for job description
        String? vehicleInfo;
        if (req['vehicle'] != null) {
          final vehicle = req['vehicle'];
          vehicleInfo = '${vehicle['brand_name'] ?? ''} ${vehicle['model_name'] ?? ''} ${vehicle['year'] ?? ''}'.trim();
          if (vehicleInfo.isEmpty) vehicleInfo = req['vehicle_info'];
        } else {
          vehicleInfo = req['vehicle_info'];
        }

        // Create job title from category or title
        String jobTitle = req['title'] ?? 'Service Request';
        if (req['category'] != null) {
          jobTitle = req['category']['name'] ?? jobTitle;
        }

        // Create enhanced job description
        String? jobDescription = req['description'];
        if (vehicleInfo != null && vehicleInfo.isNotEmpty) {
          jobDescription = jobDescription != null 
              ? '$jobDescription\n\nVehicle: $vehicleInfo'
              : 'Vehicle: $vehicleInfo';
        }

        // Get pricing info from invoices or service_requests
        double? totalAmount;
        double? invoiceAmount;
        
        if (req['invoices'] != null && req['invoices'].isNotEmpty) {
          // 🎯 Invoice total_amount = what mechanic sent
          invoiceAmount = req['invoices'][0]['total_amount']?.toDouble();
          totalAmount = invoiceAmount; // Set total_amount to invoice amount
        } else {
          totalAmount = req['final_price']?.toDouble() ?? req['estimated_price']?.toDouble();
        }
        
        // Note: service_fee will be fetched dynamically via enrichment function

        // Get rating info
        double? rating;
        String? reviewText;
        if (req['reviews'] != null && req['reviews'].isNotEmpty) {
          final review = req['reviews'][0];
          rating = review['rating']?.toDouble();
          reviewText = review['comment'];
        }

        historyRecords.add({
          'customer_id': targetCustomerId,
          'service_request_id': req['id'],
          'mechanic_id': mechanicId,
          'shop_id': req['shop_id'],
          'job_title': jobTitle,
          'job_description': jobDescription,
          'job_status': req['status'] ?? 'unknown',
          'completed_at': req['service_completion_time'],
          'cancelled_at': req['cancelled_at'],
          'total_amount': totalAmount, // 🎯 Invoice total (what mechanic sent)
          'rating': rating,
          'review_text': reviewText,
          'mechanic_name': mechanicName,
          'shop_name': shopName,
          'created_at': req['created_at'],
          'updated_at': req['updated_at'] ?? req['created_at'],
          // Note: service_fee and invoice_amount will be fetched dynamically from service_requests and invoices
          // They are not stored in customer_job_history table, but enriched when displaying
        });
      }

      // Batch insert into customer_job_history
      if (historyRecords.isNotEmpty) {
        await _supabase.from('customer_job_history').insert(historyRecords);
        print('✅ Successfully synced ${historyRecords.length} records to customer_job_history');
      }

      return true;
    } catch (e) {
      print('❌ Error syncing service requests to history: $e');
      return false;
    }
  }

  // Get all job history for the current customer - Auto-sync and query from customer_job_history
  Future<List<CustomerJobHistory>> getCustomerJobHistory({
    int? limit,
    int? offset,
    String? status,
    bool forceSync = false,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        print('❌ CustomerHistoryService: No authenticated user found');
        throw Exception('No authenticated user');
      }

      print('📋 CustomerHistoryService.getCustomerJobHistory() - Loading for customer: ${user.id}');
      
      // First, let's check if there's ANY data in service_requests
      final totalCountResult = await _supabase
          .from('service_requests')
          .select()
          .count();
      print('📊 Total service_requests in database: ${totalCountResult.count}');
      
      // Check if there are any requests for this customer
      final customerCountResult = await _supabase
          .from('service_requests')
          .select()
          .eq('customer_id', user.id)
          .count();
      print('📊 Service requests for customer ${user.id}: ${customerCountResult.count}');

      // Check customer_job_history count
      final historyCountResult = await _supabase
          .from('customer_job_history')
          .select()
          .eq('customer_id', user.id)
          .count();
      print('📊 Customer job history records: ${historyCountResult.count}');

      // Auto-sync if customer_job_history is empty but service_requests exist
      if ((historyCountResult.count == 0 && customerCountResult.count > 0) || forceSync) {
        print('🔄 Auto-syncing service_requests to customer_job_history...');
        await syncServiceRequestsToHistory(customerId: user.id);
      }

      // Now query from customer_job_history (preferred) or fall back to service_requests
      List<Map<String, dynamic>> result;
      bool usingServiceRequests = false;

      try {
        // Try querying customer_job_history first
        var historyQuery = _supabase
            .from('customer_job_history')
            .select('''
              id,
              customer_id,
              service_request_id,
              mechanic_id,
              shop_id,
              job_title,
              job_description,
              job_status,
              completed_at,
              cancelled_at,
              total_amount,
              rating,
              review_text,
              mechanic_name,
              shop_name,
              created_at,
              updated_at
            ''')
            .eq('customer_id', user.id);

        // Apply status filter if provided
        if (status != null) {
          print('📋 Filtering by status: $status');
          historyQuery = historyQuery.eq('job_status', status);
        }

        // Apply ordering and limits
        if (limit != null && offset != null) {
          result = await historyQuery
              .order('created_at', ascending: false)
              .range(offset, offset + limit - 1);
        } else if (limit != null) {
          result = await historyQuery
              .order('created_at', ascending: false)
              .limit(limit);
        } else {
          result = await historyQuery.order('created_at', ascending: false);
        }

        print('📋 Successfully queried customer_job_history. Found ${result.length} records');

      } catch (e) {
        print('⚠️  Error querying customer_job_history, falling back to service_requests: $e');
        usingServiceRequests = true;

        // Fallback to service_requests query
        var serviceQuery = _supabase
            .from('service_requests')
            .select('''
              id,
              customer_id,
              title,
              description,
              status,
              pickup_address,
              service_type,
              estimated_price,
              final_price,
              service_completion_time,
              cancelled_at,
              created_at,
              updated_at,
              vehicle_info,
              provider_id,
              shop_id,
              assigned_mechanic_id,
              vehicle_id,
              provider:user_profiles!service_requests_provider_id_fkey(
                first_name,
                last_name,
                phone_number,
                profile_image_url
              ),
              mechanic:user_profiles!service_requests_assigned_mechanic_id_fkey(
                first_name,
                last_name,
                phone_number,
                profile_image_url
              ),
              shop:shops!service_requests_shop_id_fkey(
                shop_name,
                shop_address,
                shop_phone
              ),
              customer:user_profiles!service_requests_customer_id_fkey(
                first_name,
                last_name,
                phone_number
              ),
              vehicle:vehicles!service_requests_vehicle_id_fkey(
                brand_name,
                model_name,
                year,
                color,
                plate_number,
                vehicle_type
              ),
              category:service_categories!service_requests_category_id_fkey(
                name,
                icon_name
              ),
              reviews:reviews(rating, comment),
              invoices:invoices(total_amount, status)
            ''')
            .eq('customer_id', user.id);

        // Apply status filter if provided
        if (status != null) {
          print('📋 Filtering by status: $status');
          serviceQuery = serviceQuery.eq('status', status);
        }

        // Apply ordering and limits
        if (limit != null && offset != null) {
          result = await serviceQuery
              .order('created_at', ascending: false)
              .range(offset, offset + limit - 1);
        } else if (limit != null) {
          result = await serviceQuery
              .order('created_at', ascending: false)
              .limit(limit);
        } else {
          result = await serviceQuery.order('created_at', ascending: false);
        }

        print('📋 Fallback query to service_requests executed. Found ${result.length} records');
      }
      
      if (result.isEmpty) {
        print('⚠️  No records found for customer ${user.id}');
        print('💡 This could mean:');
        print('   1. Customer has never made any service requests');
        print('   2. Service requests exist but have different customer_id');
        print('   3. Database connection or authentication issue');
        
        // Let's check if this user exists in user_profiles
        final userProfile = await _supabase
            .from('user_profiles')
            .select('id, first_name, last_name, user_type')
            .eq('id', user.id)
            .maybeSingle();
        
        if (userProfile != null) {
          print('✅ User profile found: ${userProfile['first_name']} ${userProfile['last_name']} (${userProfile['user_type']})');
        } else {
          print('❌ No user profile found for user ${user.id}');
        }
      } else {
        print('📋 Records found:');
        for (int i = 0; i < result.length && i < 3; i++) {
          final req = result[i];
          final title = req['job_title'] ?? req['title'] ?? 'Unknown';
          final status = req['job_status'] ?? req['status'] ?? 'Unknown';
          final createdAt = req['created_at'] ?? 'Unknown';
          print('   ${i + 1}. $title ($status) - $createdAt');
        }
      }

      // Convert data to CustomerJobHistory format
      List<CustomerJobHistory> historyList;
      
      if (usingServiceRequests) {
        historyList = result.map((data) => _convertServiceRequestToCustomerHistory(data)).toList();
      } else {
        historyList = result.map((data) => _convertCustomerJobHistoryToModel(data)).toList();
      }
      
      print('✅ Successfully converted ${historyList.length} records to CustomerJobHistory format');
      
      // 🎯 Enrich with service_fee and invoice data
      historyList = await _enrichCustomerHistoryWithPaymentData(historyList);
      
      return historyList;
    } catch (e) {
      print('❌ Error getting customer job history: $e');
      print('🔍 Stack trace: ${StackTrace.current}');
      return [];
    }
  }

  // Get job history by status
  Future<List<CustomerJobHistory>> getJobHistoryByStatus(String status) async {
    return await getCustomerJobHistory(status: status);
  }

  // Get completed jobs count
  Future<int> getCompletedJobsCount() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return 0;

      final result = await _supabase
          .from('customer_job_history')
          .select('id')
          .eq('customer_id', user.id)
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
          .from('customer_job_history')
          .select('id')
          .eq('customer_id', user.id)
          .eq('job_status', 'cancelled');

      return result.length;
    } catch (e) {
      print('❌ Error getting cancelled jobs count: $e');
      return 0;
    }
  }

  // Get total amount spent
  Future<double> getTotalAmountSpent() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return 0.0;

      final result = await _supabase
          .from('customer_job_history')
          .select('total_amount')
          .eq('customer_id', user.id)
          .eq('job_status', 'completed');

      double total = 0.0;
      for (var item in result) {
        final amount = item['total_amount'];
        if (amount != null) {
          total += (amount is num) ? amount.toDouble() : double.tryParse(amount.toString()) ?? 0.0;
        }
      }

      return total;
    } catch (e) {
      print('❌ Error getting total amount spent: $e');
      return 0.0;
    }
  }

  // Get average rating given by customer
  Future<double> getAverageRatingGiven() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return 0.0;

      final result = await _supabase
          .from('customer_job_history')
          .select('rating')
          .eq('customer_id', user.id)
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

  // Get recent job history (last 10)
  Future<List<CustomerJobHistory>> getRecentJobHistory() async {
    return await getCustomerJobHistory(limit: 10);
  }

  // Get job history statistics
  Future<Map<String, dynamic>> getJobHistoryStats() async {
    try {
      final completedCount = await getCompletedJobsCount();
      final cancelledCount = await getCancelledJobsCount();
      final totalSpent = await getTotalAmountSpent();
      final averageRating = await getAverageRatingGiven();

      return {
        'completed_jobs': completedCount,
        'cancelled_jobs': cancelledCount,
        'total_spent': totalSpent,
        'average_rating_given': averageRating,
        'total_jobs': completedCount + cancelledCount,
      };
    } catch (e) {
      print('❌ Error getting job history stats: $e');
      return {
        'completed_jobs': 0,
        'cancelled_jobs': 0,
        'total_spent': 0.0,
        'average_rating_given': 0.0,
        'total_jobs': 0,
      };
    }
  }

  // Search job history
  Future<List<CustomerJobHistory>> searchJobHistory(String query) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('No authenticated user');

      final result = await _supabase
          .from('customer_job_history')
          .select('''
            *,
            service_requests!customer_job_history_service_request_id_fkey(
              title,
              description,
              pickup_address,
              service_type,
              created_at
            ),
            user_profiles!customer_job_history_mechanic_id_fkey(
              first_name,
              last_name,
              phone_number,
              profile_image_url
            ),
            shops!customer_job_history_shop_id_fkey(
              shop_name,
              shop_address,
              shop_phone
            )
          ''')
          .eq('customer_id', user.id)
          .or('job_title.ilike.%$query%,job_description.ilike.%$query%,mechanic_name.ilike.%$query%,shop_name.ilike.%$query%')
          .order('created_at', ascending: false);

      return result.map((data) => CustomerJobHistory.fromJson(data)).toList();
    } catch (e) {
      print('❌ Error searching job history: $e');
      return [];
    }
  }

  // Real-time stream for customer job history updates
  Stream<List<CustomerJobHistory>> getJobHistoryStream() async* {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('No authenticated user');

      // Yield initial data
      yield await getCustomerJobHistory();

      // Listen for real-time changes
      await for (final _ in _supabase
          .from('customer_job_history')
          .stream(primaryKey: ['id'])
          .eq('customer_id', user.id)) {
        
        print('📋 Real-time job history update received');
        
        try {
          final updatedHistory = await getCustomerJobHistory();
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
    required String jobTitle,
    required String jobDescription,
    required String jobStatus,
    String? mechanicId,
    String? shopId,
    double? totalAmount,
    int? rating,
    String? reviewText,
    String? mechanicName,
    String? shopName,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('No authenticated user');

      print('📋 CustomerHistoryService.addJobToHistory() - Adding job to history: $serviceRequestId');

      await _supabase.from('customer_job_history').insert({
        'customer_id': user.id,
        'service_request_id': serviceRequestId,
        'mechanic_id': mechanicId,
        'shop_id': shopId,
        'job_title': jobTitle,
        'job_description': jobDescription,
        'job_status': jobStatus,
        'completed_at': jobStatus == 'completed' ? DateTime.now().toIso8601String() : null,
        'cancelled_at': jobStatus == 'cancelled' ? DateTime.now().toIso8601String() : null,
        'total_amount': totalAmount,
        'rating': rating,
        'review_text': reviewText,
        'mechanic_name': mechanicName,
        'shop_name': shopName,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      print('✅ Job added to customer history successfully');
      return true;
    } catch (e) {
      print('❌ Error adding job to history: $e');
      return false;
    }
  }

  // Update job rating and review
  Future<bool> updateJobRating({
    required String serviceRequestId,
    required int rating,
    String? reviewText,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('No authenticated user');

      print('📋 CustomerHistoryService.updateJobRating() - Updating rating for: $serviceRequestId');

      await _supabase
          .from('customer_job_history')
          .update({
            'rating': rating,
            'review_text': reviewText,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('customer_id', user.id)
          .eq('service_request_id', serviceRequestId);

      print('✅ Job rating updated successfully');
      return true;
    } catch (e) {
      print('❌ Error updating job rating: $e');
      return false;
    }
  }

  // Get job history by date range
  Future<List<CustomerJobHistory>> getJobHistoryByDateRange({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('No authenticated user');

      final result = await _supabase
          .from('customer_job_history')
          .select('''
            *,
            service_requests!customer_job_history_service_request_id_fkey(
              title,
              description,
              pickup_address,
              service_type,
              created_at
            ),
            user_profiles!customer_job_history_mechanic_id_fkey(
              first_name,
              last_name,
              phone_number,
              profile_image_url
            ),
            shops!customer_job_history_shop_id_fkey(
              shop_name,
              shop_address,
              shop_phone
            )
          ''')
          .eq('customer_id', user.id)
          .gte('created_at', startDate.toIso8601String())
          .lte('created_at', endDate.toIso8601String())
          .order('created_at', ascending: false);

      return result.map((data) => CustomerJobHistory.fromJson(data)).toList();
    } catch (e) {
      print('❌ Error getting job history by date range: $e');
      return [];
    }
  }

  // Convert service_requests data to CustomerJobHistory format
  CustomerJobHistory _convertServiceRequestToCustomerHistory(Map<String, dynamic> serviceRequest) {
    // Extract mechanic info - check both provider and assigned_mechanic
    String? mechanicName;
    String? mechanicId = serviceRequest['assigned_mechanic_id'] ?? serviceRequest['provider_id'];
    
    if (serviceRequest['mechanic'] != null) {
      // Use assigned_mechanic if available
      final mechanic = serviceRequest['mechanic'];
      mechanicName = '${mechanic['first_name'] ?? ''} ${mechanic['last_name'] ?? ''}'.trim();
    } else if (serviceRequest['provider'] != null) {
      // Fallback to provider
      final provider = serviceRequest['provider'];
      mechanicName = '${provider['first_name'] ?? ''} ${provider['last_name'] ?? ''}'.trim();
    }
    
    if (mechanicName != null && mechanicName.isEmpty) mechanicName = null;

    // Extract shop info
    String? shopName;
    if (serviceRequest['shop'] != null) {
      shopName = serviceRequest['shop']['shop_name'];
    }

    // Extract vehicle info for better job description
    String? vehicleInfo;
    if (serviceRequest['vehicle'] != null) {
      final vehicle = serviceRequest['vehicle'];
      vehicleInfo = '${vehicle['brand_name'] ?? ''} ${vehicle['model_name'] ?? ''} ${vehicle['year'] ?? ''}'.trim();
      if (vehicleInfo.isEmpty) vehicleInfo = serviceRequest['vehicle_info'];
    } else {
      vehicleInfo = serviceRequest['vehicle_info'];
    }

    // Extract service category for better job title
    String jobTitle = serviceRequest['title'] ?? 'Service Request';
    if (serviceRequest['category'] != null) {
      final category = serviceRequest['category'];
      jobTitle = category['name'] ?? jobTitle;
    }

    // Create enhanced job description
    String? jobDescription = serviceRequest['description'];
    if (vehicleInfo != null && vehicleInfo.isNotEmpty) {
      jobDescription = jobDescription != null 
          ? '$jobDescription\n\nVehicle: $vehicleInfo'
          : 'Vehicle: $vehicleInfo';
    }
    if (serviceRequest['pickup_address'] != null) {
      jobDescription = jobDescription != null 
          ? '$jobDescription\nLocation: ${serviceRequest['pickup_address']}'
          : 'Location: ${serviceRequest['pickup_address']}';
    }

    // Map service_requests status to job_status
    String jobStatus = serviceRequest['status'] ?? 'unknown';
    
    // Map pricing fields - check invoices first, then service_requests
    double? totalAmount;
    if (serviceRequest['invoices'] != null && serviceRequest['invoices'].isNotEmpty) {
      final invoice = serviceRequest['invoices'][0];
      totalAmount = invoice['total_amount']?.toDouble();
    } else {
      totalAmount = serviceRequest['final_price']?.toDouble() ?? serviceRequest['estimated_price']?.toDouble();
    }

    // Extract rating info
    double? rating;
    String? reviewText;
    if (serviceRequest['reviews'] != null && serviceRequest['reviews'].isNotEmpty) {
      final review = serviceRequest['reviews'][0];
      rating = review['rating']?.toDouble();
      reviewText = review['comment'];
    }
    
    return CustomerJobHistory(
      id: serviceRequest['id'] ?? '',
      customerId: serviceRequest['customer_id'] ?? '',
      serviceRequestId: serviceRequest['id'] ?? '',
      mechanicId: mechanicId,
      shopId: serviceRequest['shop_id'],
      jobTitle: jobTitle,
      jobDescription: jobDescription,
      jobStatus: jobStatus,
      completedAt: serviceRequest['service_completion_time'] != null 
          ? DateTime.parse(serviceRequest['service_completion_time']) 
          : (jobStatus == 'completed' && serviceRequest['updated_at'] != null)
              ? DateTime.parse(serviceRequest['updated_at'])
              : null,
      cancelledAt: serviceRequest['cancelled_at'] != null 
          ? DateTime.parse(serviceRequest['cancelled_at']) 
          : null,
      totalAmount: totalAmount,
      rating: rating,
      reviewText: reviewText,
      mechanicName: mechanicName,
      shopName: shopName,
      createdAt: DateTime.parse(serviceRequest['created_at']),
      updatedAt: DateTime.parse(serviceRequest['updated_at'] ?? serviceRequest['created_at']),
      // Store the original service request data for additional info
      serviceRequest: ServiceRequestData.fromJson({
        'title': jobTitle,
        'description': jobDescription ?? serviceRequest['description'] ?? '',
        'pickup_address': serviceRequest['pickup_address'] ?? '',
        'service_type': serviceRequest['service_type'] ?? '',
        'created_at': serviceRequest['created_at'],
        'vehicle_info': vehicleInfo ?? serviceRequest['vehicle_info'] ?? '',
      }),
    );
  }

  // Convert customer_job_history data to CustomerJobHistory model
  CustomerJobHistory _convertCustomerJobHistoryToModel(Map<String, dynamic> historyData) {
    return CustomerJobHistory(
      id: historyData['id'] ?? '',
      customerId: historyData['customer_id'] ?? '',
      serviceRequestId: historyData['service_request_id'] ?? '',
      mechanicId: historyData['mechanic_id'],
      shopId: historyData['shop_id'],
      jobTitle: historyData['job_title'] ?? 'Service Request',
      jobDescription: historyData['job_description'],
      jobStatus: historyData['job_status'] ?? 'unknown',
      completedAt: historyData['completed_at'] != null 
          ? DateTime.parse(historyData['completed_at']) 
          : null,
      cancelledAt: historyData['cancelled_at'] != null 
          ? DateTime.parse(historyData['cancelled_at']) 
          : null,
      totalAmount: historyData['total_amount']?.toDouble(),
      rating: historyData['rating']?.toDouble(),
      reviewText: historyData['review_text'],
      mechanicName: historyData['mechanic_name'],
      shopName: historyData['shop_name'],
      createdAt: DateTime.parse(historyData['created_at']),
      updatedAt: DateTime.parse(historyData['updated_at'] ?? historyData['created_at']),
      // Create basic ServiceRequestData for compatibility
      serviceRequest: ServiceRequestData.fromJson({
        'title': historyData['job_title'] ?? 'Service Request',
        'description': historyData['job_description'] ?? '',
        'pickup_address': '',
        'service_type': '',
        'created_at': historyData['created_at'],
        'vehicle_info': '',
      }),
    );
  }

  // 🎯 Enrich customer history with service_fee and invoice data
  Future<List<CustomerJobHistory>> _enrichCustomerHistoryWithPaymentData(List<CustomerJobHistory> jobs) async {
    try {
      // Get all service request IDs
      final requestIds = jobs.map((job) => job.serviceRequestId).toList();
      
      if (requestIds.isEmpty) return jobs;

      // Get service_requests data for service_fee
      final serviceRequests = <Map<String, dynamic>>[];
      for (final requestId in requestIds) {
        try {
          final result = await _supabase
              .from('service_requests')
              .select('id, service_fee')
              .eq('id', requestId)
              .maybeSingle();
          if (result != null) serviceRequests.add(result);
        } catch (e) {
          print('❌ Error getting service_request for $requestId: $e');
        }
      }

      // Get invoice data for invoice total_amount
      final invoices = <Map<String, dynamic>>[];
      for (final requestId in requestIds) {
        try {
          final result = await _supabase
              .from('invoices')
              .select('request_id, total_amount, status')
              .eq('request_id', requestId);
          invoices.addAll(result);
        } catch (e) {
          print('❌ Error getting invoice for request $requestId: $e');
        }
      }

      // Create maps for quick lookup
      final serviceRequestMap = <String, Map<String, dynamic>>{};
      for (var sr in serviceRequests) {
        serviceRequestMap[sr['id']] = sr;
      }

      final invoiceMap = <String, Map<String, dynamic>>{};
      for (var invoice in invoices) {
        invoiceMap[invoice['request_id']] = invoice;
      }

      // Enrich job history with payment details
      return jobs.map((job) {
        final serviceRequest = serviceRequestMap[job.serviceRequestId];
        final invoice = invoiceMap[job.serviceRequestId];
        
        final serviceFee = serviceRequest?['service_fee']?.toDouble();
        final invoiceAmount = (invoice != null && invoice['status'] == 'paid') 
            ? invoice['total_amount']?.toDouble() 
            : null;

        return CustomerJobHistory(
          id: job.id,
          customerId: job.customerId,
          serviceRequestId: job.serviceRequestId,
          mechanicId: job.mechanicId,
          shopId: job.shopId,
          jobTitle: job.jobTitle,
          jobDescription: job.jobDescription,
          jobStatus: job.jobStatus,
          completedAt: job.completedAt,
          cancelledAt: job.cancelledAt,
          totalAmount: invoiceAmount ?? job.totalAmount, // 🎯 Invoice total if available
          rating: job.rating,
          reviewText: job.reviewText,
          mechanicName: job.mechanicName,
          shopName: job.shopName,
          createdAt: job.createdAt,
          updatedAt: job.updatedAt,
          serviceFee: serviceFee, // 🎯 Service fee from service_requests
          invoiceAmount: invoiceAmount, // 🎯 Invoice total from invoices
          serviceRequest: job.serviceRequest,
          mechanic: job.mechanic,
          shop: job.shop,
        );
      }).toList();
    } catch (e) {
      print('❌ Error enriching customer history with payment data: $e');
      return jobs;
    }
  }
}