import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

class MechanicService {
  static final MechanicService _instance = MechanicService._internal();
  static MechanicService get instance => _instance;
  MechanicService._internal();

  final _supabase = Supabase.instance.client;

  // Update mechanic basic profile fields (first_name, last_name, phone_number)
  Future<bool> updateMechanicProfile({
    String? firstName,
    String? lastName,
    String? phoneNumber,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('No authenticated user');
      if ([firstName, lastName, phoneNumber].every((e) => e == null)) {
        return false; // nothing to update
      }

      final updateData = <String, dynamic>{};
      if (firstName != null) updateData['first_name'] = firstName.trim();
      if (lastName != null) updateData['last_name'] = lastName.trim();
      if (phoneNumber != null) updateData['phone_number'] = phoneNumber.trim();
      updateData['updated_at'] = DateTime.now().toIso8601String();

      await _supabase
          .from('user_profiles')
          .update(updateData)
          .eq('id', user.id);
      return true;
    } catch (e) {
      print('❌ Error updating mechanic profile: $e');
      return false;
    }
  }

  // Get mechanic profile information
  Future<Map<String, dynamic>?> getMechanicProfile() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('No authenticated user');

      // Get profile row (do NOT hard require user_type='mechanic' because some rows might have been inserted initially as another type)
      Map<String, dynamic>? profile;
      try {
        profile = await _supabase
            .from('user_profiles')
            .select('*')
            .eq('id', user.id)
            .maybeSingle();
      } catch (e) {
        print('⚠️ Primary profile fetch failed: $e');
      }

      if (profile == null) {
        // Last attempt with explicit mechanic filter (legacy behavior)
        try {
          profile = await _supabase
              .from('user_profiles')
              .select('*')
              .eq('id', user.id)
              .eq('user_type', 'mechanic')
              .maybeSingle();
        } catch (e) {
          print('⚠️ Secondary profile fetch (mechanic filter) failed: $e');
        }
      }

      if (profile == null) {
        print('❌ No user_profiles row found for user ${user.id}');
        return null;
      }

      // Get service provider info if exists (defensive: take first row if duplicates exist)
      try {
        final spResp = await _supabase
            .from('service_providers')
            .select('id, user_id, image_url, avatar_url, profile_image_url, logo_url')
            .eq('user_id', user.id)
            .maybeSingle();

        Map<String, dynamic>? serviceProvider;
        if (spResp != null) {
          if (spResp is List && spResp.isNotEmpty) {
            serviceProvider = Map<String, dynamic>.from(spResp[0]);
          } else if (spResp is Map) {
            serviceProvider = Map<String, dynamic>.from(spResp as Map);
          }
        }

        String? resolvedImage = profile['profile_image_url'];
        if (resolvedImage == null || (resolvedImage is String && resolvedImage.trim().isEmpty)) {
          // Fallback order from service_providers columns if available
            final candidates = [
              serviceProvider?['profile_image_url'],
              serviceProvider?['avatar_url'],
              serviceProvider?['image_url'],
              serviceProvider?['logo_url'],
            ];
            for (final c in candidates) {
              if (c is String && c.trim().isNotEmpty) {
                resolvedImage = c;
                break;
              }
            }
        }

        final merged = {
          ...profile,
          if (resolvedImage != null) 'profile_image_url': resolvedImage,
          if (serviceProvider != null) 'service_provider': serviceProvider,
        };
        return merged;
      } catch (e) {
        // Service provider entry doesn't exist yet or query failed; just return profile as-is
        return profile;
      }
    } catch (e) {
      print('Error fetching mechanic profile: $e');
      return null;
    }
  }

  // Get mechanic statistics using direct queries
  Future<Map<String, dynamic>> getMechanicStats() async {
    try {
      print('🔧 MechanicService.getMechanicStats() - Starting...');
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('No authenticated user');

      print('🔧 User authenticated: ${user.id}');

      // Get or create service provider
      Map<String, dynamic>? serviceProvider;
      try {
        print('🔧 Querying service_providers table...');
        final spResp = await _supabase
            .from('service_providers')
            .select('id, rating, total_reviews, is_verified, is_available, status')
            .eq('user_id', user.id)
            .maybeSingle();

        if (spResp != null) {
          if (spResp is List && spResp.isNotEmpty) {
            serviceProvider = Map<String, dynamic>.from(spResp[0]);
          } else {
            serviceProvider = Map<String, dynamic>.from(spResp as Map);
          }
          print('🔧 Found service provider: ${serviceProvider['id']}');
        }
      } catch (e) {
        // ignore here and fallback to creation below
      }

      // If service provider still null, create one and return default stats
      if (serviceProvider == null) {
        print('🔧 Service provider not found, creating new one...');
        await _supabase.from('service_providers').insert({
          'user_id': user.id,
          'is_verified': false,
          'is_available': true,
          'status': 'offline',
          'rating': 0.0,
          'total_reviews': 0,
          'created_at': DateTime.now().toIso8601String(),
        });

        print('🔧 Created new service provider, returning default stats');
        return {
          'activeJobs': 0,
          'completedToday': 0,
          'totalCompleted': 0,
          'earningsToday': 0.0,
          'totalEarnings': 0.0,
          'averageRating': 0.0,
          'totalReviews': 0,
          'isVerified': false,
          'isAvailable': true,
          'status': 'offline',
        };
      }

      final providerId = serviceProvider['id'];
      print('🔧 Using provider ID: $providerId');

      // Get active jobs count
      print('🔧 Querying active jobs...');
      final activeJobsResponse = await _supabase
          .from('service_requests')
          .select('id')
          .eq('provider_id', providerId)
          .inFilter('status', ['accepted', 'in_progress']);

      // Get today's completed jobs
      print('🔧 Querying completed jobs today...');
      final today = DateTime.now();
      final todayStart = DateTime(today.year, today.month, today.day);
      final completedTodayResponse = await _supabase
          .from('service_requests')
          .select('id, final_price')
          .eq('provider_id', providerId)
          .eq('status', 'completed')
          .gte('service_completion_time', todayStart.toIso8601String());

      // Get total completed jobs
      print('🔧 Querying total completed jobs...');
      final totalCompletedResponse = await _supabase
          .from('service_requests')
          .select('id, final_price')
          .eq('provider_id', providerId)
          .eq('status', 'completed');

      // Calculate earnings
      print('🔧 Calculating earnings...');
      double earningsToday = 0.0;
      if (completedTodayResponse.isNotEmpty) {
        earningsToday = completedTodayResponse
            .map((e) => (e['final_price'] as num?)?.toDouble() ?? 0.0)
            .fold(0.0, (a, b) => a + b);
      }

      double totalEarnings = 0.0;
      if (totalCompletedResponse.isNotEmpty) {
        totalEarnings = totalCompletedResponse
            .map((e) => (e['final_price'] as num?)?.toDouble() ?? 0.0)
            .fold(0.0, (a, b) => a + b);
      }

      final stats = {
        'activeJobs': activeJobsResponse.length,
        'completedToday': completedTodayResponse.length,
        'totalCompleted': totalCompletedResponse.length,
        'earningsToday': earningsToday,
        'totalEarnings': totalEarnings,
        'averageRating': serviceProvider['rating']?.toDouble() ?? 0.0,
        'totalReviews': serviceProvider['total_reviews'] ?? 0,
        'isVerified': serviceProvider['is_verified'] ?? false,
        'isAvailable': serviceProvider['is_available'] ?? true,
        'status': serviceProvider['status'] ?? 'offline',
      };

      print('🔧 Stats calculated successfully: $stats');
      return stats;
    } catch (e) {
      print('❌ Error fetching mechanic stats: $e');
      print('❌ Stack trace: ${StackTrace.current}');
      return {
        'activeJobs': 0,
        'completedToday': 0,
        'totalCompleted': 0,
        'earningsToday': 0.0,
        'totalEarnings': 0.0,
        'averageRating': 0.0,
        'totalReviews': 0,
        'isVerified': false,
        'isAvailable': true,
        'status': 'offline',
      };
    }
  }

  // Get assigned jobs using separate queries to avoid column name issues
  Future<List<Map<String, dynamic>>> getAssignedJobs() async {
    try {
      print('🔧 MechanicService.getAssignedJobs() - Starting...');
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('No authenticated user');

      print('🔧 Getting service provider...');
      // Get service provider (defensive: limit to 1)
      final spResp = await _supabase
          .from('service_providers')
          .select('id')
          .eq('user_id', user.id)
          .limit(1)
          .maybeSingle();

      if (spResp == null) {
        print('🔧 No service provider found for user ${user.id}');
        return [];
      }

      Map<String, dynamic>? serviceProvider;
      if (spResp is List && spResp.isNotEmpty) {
        serviceProvider = Map<String, dynamic>.from(spResp[0]);
      } else {
        serviceProvider = Map<String, dynamic>.from(spResp as Map);
      }
  // serviceProvider extracted above; proceed to fetch assigned jobs

      print('🔧 Fetching assigned service requests...');
      // Get assigned service requests (active jobs only - completed jobs go to history)
      // IMPORTANT: Include ALL statuses that keep the job visible to the mechanic
      // Also check by assigned_mechanic_id to catch jobs assigned directly to the mechanic
      final currentUser = _supabase.auth.currentUser!;
      print('🔧 Current user ID: ${currentUser.id}');
      print('🔧 Service provider ID: ${serviceProvider['id']}');
      
      final serviceRequests = await _supabase
          .from('service_requests')
          .select('*')
          .or('provider_id.eq.${serviceProvider['id']},assigned_mechanic_id.eq.${currentUser.id}')
          .inFilter('status', [
            'assigned', 
            'accepted', 
            'awaiting_payment', 
            'paid', 
            'ready_to_assign', 
            'in_progress', 
            'inspection_started',
            'inspection_completed', 
            'estimate_provided',
            'estimate_approved',
            'invoice_sent', 
            'invoice_accepted',
            'invoice_paid',
            'work_started',
            'work_completed',
            'awaiting_completion'
          ])
          .order('created_at', ascending: false);

      print('🔧 Found ${serviceRequests.length} assigned jobs');
      for (final job in serviceRequests) {
        print('🔧 Job ${job['id']}: status=${job['status']}, provider_id=${job['provider_id']}, assigned_mechanic_id=${job['assigned_mechanic_id']}');
      }

      // Also get recently completed jobs (last 24 hours) so they don't disappear immediately
      final yesterday = DateTime.now().subtract(const Duration(hours: 24));
      final recentlyCompleted = await _supabase
          .from('service_requests')
          .select('*')
          .eq('provider_id', serviceProvider['id'])
          .eq('status', 'completed')
          .gte('completed_at', yesterday.toIso8601String())
          .order('completed_at', ascending: false);

      // Combine active jobs and recently completed jobs
      final allRequests = [...serviceRequests, ...recentlyCompleted];

      print('🔧 Found ${allRequests.length} total jobs (${serviceRequests.length} active + ${recentlyCompleted.length} recently completed), enriching with customer and vehicle data...');

      // Enrich each service request with customer and vehicle data
      List<Map<String, dynamic>> enrichedJobs = [];
      
      for (final request in allRequests) {
        final enrichedJob = Map<String, dynamic>.from(request);
        
        // Get customer data
        if (request['customer_id'] != null) {
          try {
            final customer = await _supabase
                .from('user_profiles')
                .select('id, first_name, last_name, phone_number, email')
                .eq('id', request['customer_id'])
                .single();
            enrichedJob['customer'] = customer;
          } catch (e) {
            print('Warning: Could not fetch customer for request ${request['id']}: $e');
            enrichedJob['customer'] = null;
          }
        }
        
        // Get vehicle data
        if (request['vehicle_id'] != null) {
          try {
            final vehicle = await _supabase
                .from('vehicles')
                .select('brand_name, model_name, year, color, plate_number')
                .eq('id', request['vehicle_id'])
                .single();
            enrichedJob['vehicle'] = vehicle;
          } catch (e) {
            print('Warning: Could not fetch vehicle for request ${request['id']}: $e');
            enrichedJob['vehicle'] = null;
          }
        }
        
        enrichedJobs.add(enrichedJob);
      }

      print('🔧 Successfully enriched ${enrichedJobs.length} jobs');
      return enrichedJobs;
    } catch (e) {
      print('❌ Error fetching assigned jobs: $e');
      print('❌ Stack trace: ${StackTrace.current}');
      return [];
    }
  }

  // Accept assigned job
  Future<bool> acceptJob(String requestId) async {
    try {
      print('🔧 MechanicService.acceptJob() - Accepting job: $requestId');
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('No authenticated user');

      // Verify this job is assigned to this mechanic
    final spResp = await _supabase
      .from('service_providers')
      .select('id')
      .eq('user_id', user.id)
      .limit(1)
      .maybeSingle();
    if (spResp == null) throw Exception('No service provider found');
    Map<String, dynamic>? serviceProvider;
    if (spResp is List && spResp.isNotEmpty) {
      serviceProvider = Map<String, dynamic>.from(spResp[0]);
    } else {
      serviceProvider = Map<String, dynamic>.from(spResp as Map);
    }
  // serviceProvider extracted above; proceed

      final serviceRequest = await _supabase
          .from('service_requests')
          .select('id, status, provider_id')
          .eq('id', requestId)
          .eq('provider_id', serviceProvider['id'])
          .single();

      if (serviceRequest['status'] != 'in_progress') {
        throw Exception('Job is not in assignable status');
      }

      await _supabase
          .from('service_requests')
          .update({
            'status': 'accepted',
            'mechanic_accepted_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', requestId);

      print('✅ Job accepted successfully');
      return true;
    } catch (e) {
      print('❌ Error accepting job: $e');
      return false;
    }
  }

  // Decline assigned job
  Future<bool> declineJob(String requestId, String reason) async {
    try {
      print('🔧 MechanicService.declineJob() - Declining job: $requestId');
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('No authenticated user');

      // Verify this job is assigned to this mechanic
    final spResp = await _supabase
      .from('service_providers')
      .select('id')
      .eq('user_id', user.id)
      .limit(1)
      .maybeSingle();
    if (spResp == null) throw Exception('No service provider found');
    Map<String, dynamic>? serviceProvider;
    if (spResp is List && spResp.isNotEmpty) {
      serviceProvider = Map<String, dynamic>.from(spResp[0]);
    } else {
      serviceProvider = Map<String, dynamic>.from(spResp as Map);
    }
  // serviceProvider extracted above; proceed

      final serviceRequest = await _supabase
          .from('service_requests')
          .select('id, status, provider_id')
          .eq('id', requestId)
          .eq('provider_id', serviceProvider['id'])
          .single();

      if (serviceRequest['status'] != 'in_progress') {
        throw Exception('Job is not in assignable status');
      }

      await _supabase
          .from('service_requests')
          .update({
            'status': 'declined_by_mechanic',
            'provider_id': null, // Clear assignment
            'mechanic_decline_reason': reason,
            'mechanic_declined_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', requestId);

      print('✅ Job declined successfully');
      return true;
    } catch (e) {
      print('❌ Error declining job: $e');
      return false;
    }
  }

  // Update job status
  Future<bool> updateJobStatus(String requestId, String newStatus) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('No authenticated user');

      await _supabase
          .from('service_requests')
          .update({
            'status': newStatus,
            'updated_at': DateTime.now().toIso8601String(),
            if (newStatus == 'in_progress') 
              'service_start_time': DateTime.now().toIso8601String(),
            if (newStatus == 'completed')
              'service_completion_time': DateTime.now().toIso8601String(),
          })
          .eq('id', requestId);

      return true;
    } catch (e) {
      print('Error updating job status: $e');
      return false;
    }
  }  // Update mechanic location
  Future<bool> updateLocation(double latitude, double longitude) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('No authenticated user');

      await _supabase
          .from('service_providers')
          .update({
            'latitude': latitude,
            'longitude': longitude,
            'last_location_update': DateTime.now().toIso8601String(),
          })
          .eq('user_id', user.id);

      return true;
    } catch (e) {
      print('Error updating location: $e');
      return false;
    }
  }

  // Update availability status
  Future<bool> updateAvailability(bool isAvailable) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('No authenticated user');

      await _supabase
          .from('service_providers')
          .update({
            'is_available': isAvailable,
            'status': isAvailable ? 'online' : 'offline',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', user.id);

      return true;
    } catch (e) {
      print('Error updating availability: $e');
      return false;
    }
  }

  // Get job details
  Future<Map<String, dynamic>?> getJobDetails(String requestId) async {
    try {
      print('🔧 MechanicService.getJobDetails() - Starting for request: $requestId');
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('No authenticated user');

      print('🔧 Executing basic service request query first...');
      final serviceRequest = await _supabase
          .from('service_requests')
          .select('*')
          .eq('id', requestId)
          .single();

      print('🔧 Service request found, fetching customer data...');
      Map<String, dynamic>? customer;
      if (serviceRequest['customer_id'] != null) {
        try {
          customer = await _supabase
              .from('user_profiles')
              .select('id, first_name, last_name, phone_number, email')
              .eq('id', serviceRequest['customer_id'])
              .single();
        } catch (e) {
          print('Warning: Could not fetch customer data: $e');
        }
      }

      print('🔧 Fetching vehicle data...');
      Map<String, dynamic>? vehicle;
      if (serviceRequest['vehicle_id'] != null) {
        try {
          vehicle = await _supabase
              .from('vehicles')
              .select('brand_name, model_name, year, color, plate_number')
              .eq('id', serviceRequest['vehicle_id'])
              .single();
        } catch (e) {
          print('Warning: Could not fetch vehicle data: $e');
        }
      }

      // Combine the data
      final jobData = {
        ...serviceRequest,
        'customer': customer,
        'vehicle': vehicle,
      };

      print('🔧 Job details retrieved successfully');
      return jobData;
    } catch (e) {
      print('❌ Error fetching job details: $e');
      print('❌ Stack trace: ${StackTrace.current}');
      return null;
    }
  }

  // Get earnings summary for mechanic
  Future<Map<String, dynamic>> getEarningsSummary() async {
    try {
      print('🔧 MechanicService.getEarningsSummary() - Starting...');
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('No authenticated user');

      print('🔧 Getting service provider...');
      // Get service provider
    final spResp = await _supabase
      .from('service_providers')
      .select('id')
      .eq('user_id', user.id)
      .limit(1)
      .maybeSingle();
    if (spResp == null) throw Exception('No service provider found');
    Map<String, dynamic>? serviceProvider;
    if (spResp is List && spResp.isNotEmpty) {
      serviceProvider = Map<String, dynamic>.from(spResp[0]);
    } else {
      serviceProvider = Map<String, dynamic>.from(spResp as Map);
    }

    final providerId = serviceProvider['id'];
      print('🔧 Using provider ID: $providerId');

      // Get current date boundaries
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final weekStart = todayStart.subtract(Duration(days: now.weekday - 1));
      final monthStart = DateTime(now.year, now.month, 1);
      final yearStart = DateTime(now.year, 1, 1);

      print('🔧 Calculating earnings for different periods...');

      // Get completed jobs with final_price
      final completedJobs = await _supabase
          .from('service_requests')
          .select('final_price, service_completion_time')
          .eq('provider_id', providerId)
          .eq('status', 'completed')
          .not('final_price', 'is', null);

      // Calculate earnings by period
      double todayEarnings = 0.0;
      double weekEarnings = 0.0;
      double monthEarnings = 0.0;
      double yearEarnings = 0.0;
      double totalEarnings = 0.0;

      int todayJobs = 0;
      int weekJobs = 0;
      int monthJobs = 0;
      int yearJobs = 0;
      int totalJobs = completedJobs.length;

      for (final job in completedJobs) {
        final price = (job['final_price'] as num?)?.toDouble() ?? 0.0;
        totalEarnings += price;

        if (job['service_completion_time'] != null) {
          final completionTime = DateTime.parse(job['service_completion_time']);
          
          if (completionTime.isAfter(todayStart)) {
            todayEarnings += price;
            todayJobs++;
          }
          
          if (completionTime.isAfter(weekStart)) {
            weekEarnings += price;
            weekJobs++;
          }
          
          if (completionTime.isAfter(monthStart)) {
            monthEarnings += price;
            monthJobs++;
          }
          
          if (completionTime.isAfter(yearStart)) {
            yearEarnings += price;
            yearJobs++;
          }
        }
      }

      final earnings = {
        'today': {
          'earnings': todayEarnings,
          'jobs': todayJobs,
        },
        'week': {
          'earnings': weekEarnings,
          'jobs': weekJobs,
        },
        'month': {
          'earnings': monthEarnings,
          'jobs': monthJobs,
        },
        'year': {
          'earnings': yearEarnings,
          'jobs': yearJobs,
        },
        'total': {
          'earnings': totalEarnings,
          'jobs': totalJobs,
        },
        'average_per_job': totalJobs > 0 ? totalEarnings / totalJobs : 0.0,
      };

      print('🔧 Earnings summary calculated successfully');
      return earnings;
    } catch (e) {
      print('❌ Error fetching earnings summary: $e');
      print('❌ Stack trace: ${StackTrace.current}');
      return {
        'today': {'earnings': 0.0, 'jobs': 0},
        'week': {'earnings': 0.0, 'jobs': 0},
        'month': {'earnings': 0.0, 'jobs': 0},
        'year': {'earnings': 0.0, 'jobs': 0},
        'total': {'earnings': 0.0, 'jobs': 0},
        'average_per_job': 0.0,
      };
    }
  }

  // Get job history for the mechanic
  Future<List<Map<String, dynamic>>> getJobHistory() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('No authenticated user');

      print('🔧 MechanicService.getJobHistory() - Fetching job history for mechanic: ${user.id}');

      // Get service provider (defensive: limit to 1)
      final spResp = await _supabase
          .from('service_providers')
          .select('id')
          .eq('user_id', user.id)
          .limit(1)
          .maybeSingle();

      if (spResp == null) {
        print('🔧 No service provider found for user ${user.id}');
        return [];
      }

      Map<String, dynamic>? serviceProvider;
      if (spResp is List && spResp.isNotEmpty) {
        serviceProvider = Map<String, dynamic>.from(spResp[0]);
      } else {
        serviceProvider = Map<String, dynamic>.from(spResp as Map);
      }

      // Get completed/cancelled jobs using provider_id (consistent with getAssignedJobs)
      final jobs = await _supabase
          .from('service_requests')
          .select('*')
          .eq('provider_id', serviceProvider['id'])
          .inFilter('status', ['completed', 'cancelled'])
          .order('created_at', ascending: false);

      print('🔧 Found ${jobs.length} historical jobs');
      return jobs;
    } catch (e) {
      print('❌ Error fetching job history: $e');
      return [];
    }
  }

  // Submit inspection report
  Future<bool> submitInspectionReport(String jobId, Map<String, dynamic> report) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('No authenticated user');

      print('🔧 MechanicService.submitInspectionReport() - Submitting report for job: $jobId');

      // Create inspection report entry
      await _supabase.from('inspection_reports').insert({
        'request_id': jobId,
        'mechanic_id': user.id,
        'report_data': report,
        'created_at': DateTime.now().toIso8601String(),
      });

      // Update service request status to invoice_sent - mechanic sends invoice directly after inspection
      await _supabase
          .from('service_requests')
          .update({'status': 'invoice_sent'})
          .eq('id', jobId);

      print('🔧 Inspection report submitted successfully');
      return true;
    } catch (e) {
      print('❌ Error submitting inspection report: $e');
      return false;
    }
  }

  // Enhanced real-time stream for assigned jobs with retry logic and fallback
  Stream<List<Map<String, dynamic>>> getAssignedJobsStream() async* {
    int retryCount = 0;
    const maxRetries = 3;
    const retryDelay = Duration(seconds: 5);
    
    while (retryCount <= maxRetries) {
      try {
        final user = _supabase.auth.currentUser;
        if (user == null) throw Exception('No authenticated user');

        // Get service provider ID (for potential filtering, but we use getAssignedJobs() instead)
        final serviceProviders = await _supabase
            .from('service_providers')
            .select('id')
            .eq('user_id', user.id)
            .limit(1);

        if (serviceProviders.isEmpty) {
          print('🔧 No service provider found for user');
          yield [];
          continue;
        }
        
        // Yield initial data
        print('🔧 Loading initial assigned jobs data...');
        yield await getAssignedJobs();

        // Reset retry count on successful connection
        retryCount = 0;

        try {
          // Listen for real-time changes with timeout handling
          // Note: We listen for all changes and filter on client side since Supabase streams
          // don't support OR conditions. We filter by status to reduce noise.
          await for (final _ in _supabase
              .from('service_requests')
              .stream(primaryKey: ['id'])
              .inFilter('status', ['assigned', 'accepted', 'awaiting_payment', 'paid', 'ready_to_assign', 'in_progress', 'inspection_completed', 'invoice_sent', 'invoice_paid'])
              .timeout(Duration(seconds: 30))) {
            
            print('🔧 Real-time update received for assigned jobs');
            
            // Fetch fresh data when changes occur
            try {
              final updatedJobs = await getAssignedJobs();
              yield updatedJobs;
            } catch (e) {
              print('❌ Error fetching updated jobs: $e');
              // Continue with stream, don't break it
            }
          }
        } on TimeoutException catch (e) {
          print('⏰ Real-time stream timeout for assigned jobs: $e');
          throw e; // This will trigger retry logic
        } on PostgrestException catch (e) {
          print('📡 Database connection error for assigned jobs: $e');
          throw e; // This will trigger retry logic
        } on RealtimeSubscribeException catch (e) {
          print('📡 Realtime subscription error for assigned jobs: $e');
          throw e; // This will trigger retry logic
        }
      } catch (e) {
        retryCount++;
        print('❌ Error in assigned jobs stream (attempt $retryCount/$maxRetries): $e');
        
        if (retryCount <= maxRetries) {
          print('🔄 Retrying assigned jobs stream in ${retryDelay.inSeconds} seconds...');
          await Future.delayed(retryDelay);
          
          // Yield fresh data during retry
          try {
            final fallbackJobs = await getAssignedJobs();
            yield fallbackJobs;
          } catch (fallbackError) {
            print('❌ Fallback data fetch failed: $fallbackError');
          }
        } else {
          print('❌ Max retries exceeded for assigned jobs stream');
          rethrow;
        }
      }
    }
  }

  // Enhanced real-time stream for specific job details with retry logic and fallback
  Stream<Map<String, dynamic>?> getJobDetailsStream(String jobId) async* {
    int retryCount = 0;
    const maxRetries = 3;
    const retryDelay = Duration(seconds: 5);
    
    while (retryCount <= maxRetries) {
      try {
        final user = _supabase.auth.currentUser;
        if (user == null) throw Exception('No authenticated user');

        // Get service provider ID
        final serviceProvider = await _supabase
            .from('service_providers')
            .select('id')
            .eq('user_id', user.id)
            .single();

        final providerId = serviceProvider['id'];
        
        // Yield initial data
        print('🔧 Loading initial job details for $jobId...');
        yield await getJobDetails(jobId);

        // Reset retry count on successful connection
        retryCount = 0;

        try {
          // Listen for real-time changes to this specific job with timeout
          await for (final _ in _supabase
              .from('service_requests')
              .stream(primaryKey: ['id'])
              .eq('id', jobId)
              .timeout(Duration(seconds: 30))) {
            
            print('🔧 Real-time update received for job $jobId');
            
            // Verify this job belongs to this provider
            try {
              final jobCheck = await _supabase
                  .from('service_requests')
                  .select('provider_id')
                  .eq('id', jobId)
                  .eq('provider_id', providerId)
                  .maybeSingle();
              
              if (jobCheck != null) {
                final updatedJob = await getJobDetails(jobId);
                yield updatedJob;
              }
            } catch (e) {
              print('❌ Error fetching updated job details: $e');
              // Continue with stream, don't break it
            }
          }
        } on TimeoutException catch (e) {
          print('⏰ Real-time stream timeout for job $jobId: $e');
          throw e; // This will trigger retry logic
        } on PostgrestException catch (e) {
          print('📡 Database connection error for job $jobId: $e');
          throw e; // This will trigger retry logic
        } on RealtimeSubscribeException catch (e) {
          print('📡 Realtime subscription error for job $jobId: $e');
          throw e; // This will trigger retry logic
        }
      } catch (e) {
        retryCount++;
        print('❌ Error in job details stream (attempt $retryCount/$maxRetries): $e');
        
        if (retryCount <= maxRetries) {
          print('🔄 Retrying job details stream for $jobId in ${retryDelay.inSeconds} seconds...');
          await Future.delayed(retryDelay);
          
          // Yield fresh data during retry
          try {
            final fallbackJob = await getJobDetails(jobId);
            yield fallbackJob;
          } catch (fallbackError) {
            print('❌ Fallback job details fetch failed: $fallbackError');
          }
        } else {
          print('❌ Max retries exceeded for job details stream');
          rethrow;
        }
      }
    }
  }

  /// Ensure mechanic has availability status record
  Future<bool> ensureMechanicAvailabilityStatus() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return false;

      print('🔧 Ensuring mechanic availability status for user: ${user.id}');

      // Check if user is a mechanic
      final userProfile = await _supabase
          .from('user_profiles')
          .select('user_type')
          .eq('id', user.id)
          .maybeSingle();

      if (userProfile == null || userProfile['user_type'] != 'mechanic') {
        print('❌ User is not a mechanic or profile not found');
        return false;
      }

      // Check if availability status already exists
      final existingStatus = await _supabase
          .from('mechanic_availability_status')
          .select('id')
          .eq('mechanic_id', user.id)
          .maybeSingle();

      if (existingStatus != null) {
        print('✅ Mechanic availability status already exists');
        return true;
      }

      // Create availability status record
      await _supabase
          .from('mechanic_availability_status')
          .insert({
            'mechanic_id': user.id,
            'current_status': 'available',
            'is_accepting_requests': true,
            'last_status_update': DateTime.now().toIso8601String(),
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          });

      print('✅ Created mechanic availability status record');
      return true;

    } catch (e) {
      print('❌ Error ensuring mechanic availability status: $e');
      return false;
    }
  }

  /// Update mechanic availability status
  Future<bool> updateMechanicAvailabilityStatus({
    required String status,
    required bool isAcceptingRequests,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return false;

      await _supabase
          .from('mechanic_availability_status')
          .upsert({
            'mechanic_id': user.id,
            'current_status': status,
            'is_accepting_requests': isAcceptingRequests,
            'last_status_update': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('mechanic_id', user.id);

      print('✅ Updated mechanic availability status: $status (accepting: $isAcceptingRequests)');
      return true;

    } catch (e) {
      print('❌ Error updating mechanic availability status: $e');
      return false;
    }
  }

  // Get current active job for mechanic (for bottom sheet restoration)
  Future<Map<String, dynamic>?> getCurrentActiveJob() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return null;

      print('🔧 Checking for current active job...');
      print('🔍 User ID: ${user.id}');
      
      // Get the service provider info first (if exists)
      final serviceProviderResponse = await _supabase
          .from('service_providers')
          .select('id')
          .eq('user_id', user.id)
          .limit(1);

      print('🔧 Service provider response: ${serviceProviderResponse.length} records found');

      if (serviceProviderResponse.isEmpty) {
        print('❌ No service provider found for user');
        // Still try to find jobs assigned directly to mechanic
      } else {
        print('✅ Service provider found: ${serviceProviderResponse.first['id']}');
      }

      // Check for active jobs with multiple relevant statuses
      // These are jobs that have been started and should show the persistent bottom sheet
      print('🔍 Searching for active jobs with statuses: ready_to_assign, assigned, in_progress, awaiting_payment, paid, invoice_sent, invoice_paid');
      final activeJobResponse = await _supabase
          .from('service_requests')
          .select('''
            *,
            customer:user_profiles!service_requests_customer_id_fkey(
              first_name,
              last_name,
              phone_number,
              profile_image_url
            )
          ''')
          .eq('assigned_mechanic_id', user.id)
          .inFilter('status', ['ready_to_assign', 'assigned', 'in_progress', 'awaiting_payment', 'paid', 'invoice_sent', 'invoice_paid'])
          .order('created_at', ascending: false)
          .limit(1);

      print('🔍 Active job query returned ${activeJobResponse.length} results');
      
      if (activeJobResponse.isEmpty) {
        print('✅ No active job found');
        return null;
      }

      final jobData = activeJobResponse.first;
      print('✅ Active job found: ${jobData['id']} with status: ${jobData['status']}');
      print('📍 Job details: provider_id=${jobData['provider_id']}, assigned_mechanic_id=${jobData['assigned_mechanic_id']}');
      
      // Format the job data for the bottom sheet
      final customer = jobData['customer'] as Map<String, dynamic>?;
      return {
        'request_id': jobData['id'],
        'customer_id': jobData['customer_id'],
        'customer_name': customer != null 
            ? '${customer['first_name'] ?? ''} ${customer['last_name'] ?? ''}'.trim()
            : 'Unknown Customer',
        'customer_phone': customer?['phone_number'] ?? '',
        'profile_image_url': customer?['profile_image_url'],
        'pickup_latitude': jobData['pickup_latitude'],
        'pickup_longitude': jobData['pickup_longitude'],
        'pickup_address': jobData['pickup_address'],
        'service_type': jobData['service_type'],
        'description': jobData['description'],
        'job_status': jobData['status'], // IMPORTANT: Include status so dashboard can check if job is completed
      };

    } catch (e) {
      print('❌ Error getting current active job: $e');
      return null;
    }
  }
}
