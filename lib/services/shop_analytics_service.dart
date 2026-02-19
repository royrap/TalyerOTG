import 'package:supabase_flutter/supabase_flutter.dart';

class ShopAnalyticsService {
  final _supabase = Supabase.instance.client;

  /// Get comprehensive shop analytics data
  Future<Map<String, dynamic>> getShopAnalytics(String shopId) async {
    try {
      // Get shop basic info
      final shopData = await _supabase
          .from('shops')
          .select('*, owner:user_profiles!shops_owner_id_fkey(*)')
          .eq('id', shopId)
          .single();

      // Get today's stats
      final today = DateTime.now();
      final todayStart = DateTime(today.year, today.month, today.day);
      
      // Jobs today
      final jobsToday = await _supabase
          .from('service_requests')
          .select('id')
          .eq('shop_id', shopId)
          .gte('created_at', todayStart.toIso8601String())
          .count();

      // Jobs this week
      final weekStart = todayStart.subtract(Duration(days: today.weekday - 1));
      final jobsWeek = await _supabase
          .from('service_requests')
          .select('id')
          .eq('shop_id', shopId)
          .gte('created_at', weekStart.toIso8601String())
          .count();

      // Jobs this month
      final monthStart = DateTime(today.year, today.month, 1);
      final jobsMonth = await _supabase
          .from('service_requests')
          .select('id')
          .eq('shop_id', shopId)
          .gte('created_at', monthStart.toIso8601String())
          .count();

      // Revenue today
      final revenueToday = await _supabase
          .from('service_history')
          .select('total_amount')
          .eq('shop_id', shopId)
          .gte('service_date', todayStart.toIso8601String());

      double todayRevenue = 0;
      for (var record in revenueToday) {
        todayRevenue += (record['total_amount'] as num?)?.toDouble() ?? 0;
      }

      // Revenue this month
      final revenueMonth = await _supabase
          .from('service_history')
          .select('total_amount')
          .eq('shop_id', shopId)
          .gte('service_date', monthStart.toIso8601String());

      double monthRevenue = 0;
      for (var record in revenueMonth) {
        monthRevenue += (record['total_amount'] as num?)?.toDouble() ?? 0;
      }

      // Active mechanics
      final activeMechanics = await _supabase
          .from('shop_mechanics')
          .select('id')
          .eq('shop_id', shopId)
          .eq('is_active', true)
          .eq('is_available', true)
          .count();

      // Total mechanics
      final totalMechanics = await _supabase
          .from('shop_mechanics')
          .select('id')
          .eq('shop_id', shopId)
          .eq('is_active', true)
          .count();

      // Pending requests
      final pendingRequests = await _supabase
          .from('service_requests')
          .select('id')
          .eq('shop_id', shopId)
          .eq('status', 'pending')
          .count();

      // Completed jobs
      final completedJobs = await _supabase
          .from('service_history')
          .select('id')
          .eq('shop_id', shopId)
          .eq('status', 'completed')
          .count();

      // Average rating
      final ratings = await _supabase
          .from('service_history')
          .select('rating')
          .eq('shop_id', shopId)
          .not('rating', 'is', null);

      double avgRating = 0;
      if (ratings.isNotEmpty) {
        int totalRating = 0;
        for (var record in ratings) {
          totalRating += (record['rating'] as int?) ?? 0;
        }
        avgRating = totalRating / ratings.length;
      }

      return {
        'shop_info': shopData,
        'jobs_today': jobsToday.count,
        'jobs_week': jobsWeek.count,
        'jobs_month': jobsMonth.count,
        'revenue_today': todayRevenue,
        'revenue_month': monthRevenue,
        'active_mechanics': activeMechanics.count,
        'total_mechanics': totalMechanics.count,
        'pending_requests': pendingRequests.count,
        'completed_jobs': completedJobs.count,
        'average_rating': avgRating,
      };
    } catch (e) {
      print('❌ Error fetching shop analytics: $e');
      rethrow;
    }
  }

  /// Get mechanic performance data
  Future<List<Map<String, dynamic>>> getMechanicPerformance(String shopId) async {
    try {
      final mechanics = await _supabase
          .from('shop_mechanics')
          .select('''
            id,
            mechanic_id,
            role,
            is_active,
            is_available,
            mechanic:user_profiles!shop_mechanics_mechanic_id_fkey(
              id,
              first_name,
              last_name,
              profile_image_url,
              rating
            )
          ''')
          .eq('shop_id', shopId)
          .order('is_active', ascending: false);

      List<Map<String, dynamic>> performanceList = [];

      for (var mechanic in mechanics) {
        final mechanicId = mechanic['mechanic_id'];
        
        // Get job statistics
        final jobs = await _supabase
            .from('mechanic_job_history')
            .select('*')
            .eq('mechanic_id', mechanicId)
            .eq('shop_id', shopId);

        int totalJobs = jobs.length;
        int completedJobs = jobs.where((j) => j['job_status'] == 'completed').length;
        double totalEarnings = 0;
        double avgRating = 0;
        int ratingCount = 0;

        for (var job in jobs) {
          totalEarnings += (job['mechanic_earnings'] as num?)?.toDouble() ?? 0;
          if (job['rating'] != null) {
            avgRating += (job['rating'] as num).toDouble();
            ratingCount++;
          }
        }

        if (ratingCount > 0) {
          avgRating = avgRating / ratingCount;
        }

        performanceList.add({
          ...mechanic,
          'total_jobs': totalJobs,
          'completed_jobs': completedJobs,
          'total_earnings': totalEarnings,
          'average_rating': avgRating,
          'rating_count': ratingCount,
        });
      }

      // Sort by completed jobs descending
      performanceList.sort((a, b) => 
          (b['completed_jobs'] as int).compareTo(a['completed_jobs'] as int));

      return performanceList;
    } catch (e) {
      print('❌ Error fetching mechanic performance: $e');
      rethrow;
    }
  }

  /// Get revenue breakdown by service type
  Future<Map<String, dynamic>> getRevenueBreakdown(String shopId, {DateTime? startDate, DateTime? endDate}) async {
    try {
      endDate ??= DateTime.now();
      startDate ??= DateTime(endDate.year, endDate.month, 1); // Default to current month

      final history = await _supabase
          .from('service_history')
          .select('service_type, total_amount, service_date')
          .eq('shop_id', shopId)
          .gte('service_date', startDate.toIso8601String())
          .lte('service_date', endDate.toIso8601String())
          .order('service_date', ascending: true);

      Map<String, double> byServiceType = {};
      Map<String, int> countByServiceType = {};
      List<Map<String, dynamic>> dailyRevenue = [];

      double totalRevenue = 0;

      for (var record in history) {
        final serviceType = record['service_type'] as String? ?? 'Other';
        final amount = (record['total_amount'] as num?)?.toDouble() ?? 0;
        
        totalRevenue += amount;
        byServiceType[serviceType] = (byServiceType[serviceType] ?? 0) + amount;
        countByServiceType[serviceType] = (countByServiceType[serviceType] ?? 0) + 1;
      }

      // Group by date for chart
      Map<String, double> revenueByDate = {};
      for (var record in history) {
        final date = DateTime.parse(record['service_date']);
        final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        final amount = (record['total_amount'] as num?)?.toDouble() ?? 0;
        revenueByDate[dateKey] = (revenueByDate[dateKey] ?? 0) + amount;
      }

      dailyRevenue = revenueByDate.entries.map((e) => {
        'date': e.key,
        'revenue': e.value,
      }).toList();

      return {
        'total_revenue': totalRevenue,
        'by_service_type': byServiceType,
        'count_by_service_type': countByServiceType,
        'daily_revenue': dailyRevenue,
        'start_date': startDate.toIso8601String(),
        'end_date': endDate.toIso8601String(),
      };
    } catch (e) {
      print('❌ Error fetching revenue breakdown: $e');
      rethrow;
    }
  }

  /// Get recent activity logs
  Future<List<Map<String, dynamic>>> getRecentActivity(String shopId, {int limit = 20}) async {
    try {
      // Get request status changes
      final statusChanges = await _supabase
          .from('request_status_history')
          .select('''
            *,
            request:service_requests!request_status_history_request_id_fkey(
              id,
              title,
              customer:user_profiles!service_requests_customer_id_fkey(first_name, last_name)
            ),
            changed_by_user:user_profiles!request_status_history_changed_by_fkey(first_name, last_name)
          ''')
          .eq('request.shop_id', shopId)
          .order('created_at', ascending: false)
          .limit(limit);

      return statusChanges.map((change) => {
        'type': 'status_change',
        'status': change['status'],
        'notes': change['notes'],
        'created_at': change['created_at'],
        'request': change['request'],
        'changed_by': change['changed_by_user'],
      }).toList();
    } catch (e) {
      print('❌ Error fetching recent activity: $e');
      return [];
    }
  }

  /// Get customer reviews for the shop
  Future<List<Map<String, dynamic>>> getShopReviews(String shopId, {int limit = 50}) async {
    try {
      // Get reviews through service_history
      final reviews = await _supabase
          .from('service_history')
          .select('''
            id,
            service_type,
            rating,
            customer_feedback,
            service_date,
            customer:user_profiles!service_history_customer_id_fkey(
              id,
              first_name,
              last_name,
              profile_image_url
            ),
            mechanic:user_profiles!service_history_mechanic_id_fkey(
              first_name,
              last_name
            )
          ''')
          .eq('shop_id', shopId)
          .not('rating', 'is', null)
          .order('service_date', ascending: false)
          .limit(limit);

      return reviews;
    } catch (e) {
      print('❌ Error fetching shop reviews: $e');
      rethrow;
    }
  }

  /// Get payment statistics
  Future<Map<String, dynamic>> getPaymentStats(String shopId) async {
    try {
      final talyerOwnerId = await _getTalyerOwnerIdFromShop(shopId);
      
      if (talyerOwnerId == null) {
        throw Exception('Talyer owner not found for shop');
      }

      // Get all invoices
      final invoices = await _supabase
          .from('invoices')
          .select('status, total_amount, talyer_net_amount, platform_fee, generated_at')
          .eq('talyer_owner_id', talyerOwnerId);

      double totalRevenue = 0;
      double totalPlatformFees = 0;
      double netEarnings = 0;
      int paidInvoices = 0;
      int pendingInvoices = 0;

      for (var invoice in invoices) {
        final status = invoice['status'] as String?;
        final total = (invoice['total_amount'] as num?)?.toDouble() ?? 0;
        final netAmount = (invoice['talyer_net_amount'] as num?)?.toDouble() ?? 0;
        final fee = (invoice['platform_fee'] as num?)?.toDouble() ?? 0;

        if (status == 'paid' || status == 'completed') {
          totalRevenue += total;
          netEarnings += netAmount;
          totalPlatformFees += fee;
          paidInvoices++;
        } else if (status == 'generated' || status == 'sent' || status == 'pending') {
          pendingInvoices++;
        }
      }

      return {
        'total_revenue': totalRevenue,
        'net_earnings': netEarnings,
        'total_platform_fees': totalPlatformFees,
        'paid_invoices': paidInvoices,
        'pending_invoices': pendingInvoices,
        'total_invoices': invoices.length,
      };
    } catch (e) {
      print('❌ Error fetching payment stats: $e');
      rethrow;
    }
  }

  /// Get active jobs count
  Future<int> getActiveJobsCount(String shopId) async {
    try {
      final activeJobs = await _supabase
          .from('service_requests')
          .select('id')
          .eq('shop_id', shopId)
          .inFilter('status', ['accepted', 'in_progress', 'assigned', 'mechanic_assigned'])
          .count();

      return activeJobs.count;
    } catch (e) {
      print('❌ Error fetching active jobs count: $e');
      return 0;
    }
  }

  /// Get activity logs for shop (audit logs, status changes, payments)
  Future<Map<String, dynamic>> getActivityLogs(String shopId, {
    String? filterType,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 50,
  }) async {
    try {
      final talyerOwnerId = await _getTalyerOwnerIdFromShop(shopId);
      if (talyerOwnerId == null) {
        throw Exception('Shop owner not found');
      }
      
      // Get request status history for this shop's service requests
      var statusQuery = _supabase
          .from('request_status_history')
          .select('''
            id,
            status,
            notes,
            created_at,
            changed_by,
            request:service_requests!request_status_history_request_id_fkey(
              id,
              title,
              service_type,
              customer:user_profiles!service_requests_customer_id_fkey(first_name, last_name)
            ),
            changed_by_user:user_profiles!request_status_history_changed_by_fkey(
              first_name,
              last_name,
              user_type
            )
          ''')
          .order('created_at', ascending: false);

      // Get audit logs for talyer owner actions
      var auditQuery = _supabase
          .from('audit_logs')
          .select('''
            id,
            action,
            table_name,
            record_id,
            created_at,
            role,
            success,
            error_message,
            old_values,
            new_values,
            additional_data,
            user:user_profiles!audit_logs_user_id_fkey(
              first_name,
              last_name,
              user_type
            )
          ''')
          .eq('user_id', talyerOwnerId)
          .order('created_at', ascending: false);

      // Get payment activities
      var paymentQuery = _supabase
          .from('payments')
          .select('''
            id,
            amount,
            platform_fee,
            provider_amount,
            payment_method,
            status,
            processed_at,
            created_at,
            request:service_requests!payments_request_id_fkey(
              id,
              title,
              service_type,
              shop_id
            ),
            customer:user_profiles!payments_customer_id_fkey(
              first_name,
              last_name
            )
          ''')
          .eq('request.shop_id', shopId)
          .order('created_at', ascending: false);

      // Execute queries with limits
      final statusHistoryData = await statusQuery.limit(limit * 2);
      final auditLogsData = await auditQuery.limit(limit * 2);
      final paymentsData = await paymentQuery.limit(limit * 2);

      // Convert to lists
      List<Map<String, dynamic>> statusHistory = (statusHistoryData as List).cast<Map<String, dynamic>>();
      List<Map<String, dynamic>> auditLogs = (auditLogsData as List).cast<Map<String, dynamic>>();
      List<Map<String, dynamic>> payments = (paymentsData as List).cast<Map<String, dynamic>>();

      // Apply date filters in Dart
      if (startDate != null) {
        statusHistory = statusHistory.where((item) {
          final createdAt = DateTime.parse(item['created_at']);
          return createdAt.isAfter(startDate) || createdAt.isAtSameMomentAs(startDate);
        }).toList();
        
        auditLogs = auditLogs.where((item) {
          final createdAt = DateTime.parse(item['created_at']);
          return createdAt.isAfter(startDate) || createdAt.isAtSameMomentAs(startDate);
        }).toList();
        
        payments = payments.where((item) {
          final createdAt = DateTime.parse(item['created_at']);
          return createdAt.isAfter(startDate) || createdAt.isAtSameMomentAs(startDate);
        }).toList();
      }

      if (endDate != null) {
        statusHistory = statusHistory.where((item) {
          final createdAt = DateTime.parse(item['created_at']);
          return createdAt.isBefore(endDate) || createdAt.isAtSameMomentAs(endDate);
        }).toList();
        
        auditLogs = auditLogs.where((item) {
          final createdAt = DateTime.parse(item['created_at']);
          return createdAt.isBefore(endDate) || createdAt.isAtSameMomentAs(endDate);
        }).toList();
        
        payments = payments.where((item) {
          final createdAt = DateTime.parse(item['created_at']);
          return createdAt.isBefore(endDate) || createdAt.isAtSameMomentAs(endDate);
        }).toList();
      }

      // Combine and sort all activities by timestamp
      List<Map<String, dynamic>> allActivities = [];

      // Add status changes
      for (var item in statusHistory) {
        allActivities.add({
          'type': 'status_change',
          'id': item['id'],
          'timestamp': DateTime.parse(item['created_at']),
          'status': item['status'],
          'notes': item['notes'],
          'request_id': item['request']?['id'],
          'request_title': item['request']?['title'],
          'service_type': item['request']?['service_type'],
          'customer_name': item['request']?['customer'] != null
              ? '${item['request']['customer']['first_name']} ${item['request']['customer']['last_name']}'
              : 'Unknown',
          'changed_by': item['changed_by_user'] != null
              ? '${item['changed_by_user']['first_name']} ${item['changed_by_user']['last_name']}'
              : 'System',
          'changed_by_type': item['changed_by_user']?['user_type'] ?? 'system',
        });
      }

      // Add audit logs
      for (var item in auditLogs) {
        allActivities.add({
          'type': 'audit_log',
          'id': item['id'],
          'timestamp': DateTime.parse(item['created_at']),
          'action': item['action'],
          'table_name': item['table_name'],
          'record_id': item['record_id'],
          'role': item['role'],
          'success': item['success'],
          'error_message': item['error_message'],
          'old_values': item['old_values'],
          'new_values': item['new_values'],
          'additional_data': item['additional_data'],
          'user_name': item['user'] != null
              ? '${item['user']['first_name']} ${item['user']['last_name']}'
              : 'System',
          'user_type': item['user']?['user_type'] ?? 'system',
        });
      }

      // Add payments
      for (var item in payments) {
        if (item['request']?['shop_id'] == shopId) {
          allActivities.add({
            'type': 'payment',
            'id': item['id'],
            'timestamp': DateTime.parse(item['created_at']),
            'amount': item['amount'],
            'platform_fee': item['platform_fee'],
            'provider_amount': item['provider_amount'],
            'payment_method': item['payment_method'],
            'status': item['status'],
            'processed_at': item['processed_at'],
            'request_id': item['request']?['id'],
            'request_title': item['request']?['title'],
            'service_type': item['request']?['service_type'],
            'customer_name': item['customer'] != null
                ? '${item['customer']['first_name']} ${item['customer']['last_name']}'
                : 'Unknown',
          });
        }
      }

      // Sort by timestamp descending
      allActivities.sort((a, b) => b['timestamp'].compareTo(a['timestamp']));

      // Apply filter type
      if (filterType != null && filterType != 'all') {
        allActivities = allActivities.where((item) => item['type'] == filterType).toList();
      }

      // Get statistics
      final statusChangeCount = allActivities.where((a) => a['type'] == 'status_change').length;
      final auditLogCount = allActivities.where((a) => a['type'] == 'audit_log').length;
      final paymentCount = allActivities.where((a) => a['type'] == 'payment').length;

      return {
        'activities': allActivities,
        'total_count': allActivities.length,
        'status_change_count': statusChangeCount,
        'audit_log_count': auditLogCount,
        'payment_count': paymentCount,
      };
    } catch (e) {
      print('❌ Error fetching activity logs: $e');
      rethrow;
    }
  }

  /// Get activity summary for dashboard widget
  Future<Map<String, dynamic>> getActivitySummary(String shopId, {int days = 7}) async {
    try {
      final startDate = DateTime.now().subtract(Duration(days: days));
      final talyerOwnerId = await _getTalyerOwnerIdFromShop(shopId);
      
      if (talyerOwnerId == null) {
        return {
          'period_days': days,
          'status_changes': 0,
          'audit_actions': 0,
          'payment_activities': 0,
          'total_activities': 0,
        };
      }

      // Count recent status changes
      final statusChangesData = await _supabase
          .from('request_status_history')
          .select('id, request:service_requests!request_status_history_request_id_fkey(shop_id)');
      
      final statusChanges = (statusChangesData as List)
          .where((item) {
            final createdAt = DateTime.parse(item['created_at'] ?? DateTime.now().toIso8601String());
            return createdAt.isAfter(startDate) && item['request']?['shop_id'] == shopId;
          })
          .length;

      // Count audit actions
      final auditActionsData = await _supabase
          .from('audit_logs')
          .select('id, created_at')
          .eq('user_id', talyerOwnerId);
      
      final auditActions = (auditActionsData as List)
          .where((item) {
            final createdAt = DateTime.parse(item['created_at'] ?? DateTime.now().toIso8601String());
            return createdAt.isAfter(startDate);
          })
          .length;

      // Count payment activities
      final paymentActivitiesData = await _supabase
          .from('payments')
          .select('id, created_at, request:service_requests!payments_request_id_fkey(shop_id)')
          .eq('request.shop_id', shopId);
      
      final paymentActivities = (paymentActivitiesData as List)
          .where((item) {
            final createdAt = DateTime.parse(item['created_at'] ?? DateTime.now().toIso8601String());
            return createdAt.isAfter(startDate);
          })
          .length;

      return {
        'period_days': days,
        'status_changes': statusChanges,
        'audit_actions': auditActions,
        'payment_activities': paymentActivities,
        'total_activities': statusChanges + auditActions + paymentActivities,
      };
    } catch (e) {
      print('❌ Error fetching activity summary: $e');
      return {
        'period_days': days,
        'status_changes': 0,
        'audit_actions': 0,
        'payment_activities': 0,
        'total_activities': 0,
      };
    }
  }

  /// Helper: Get talyer owner ID from shop ID
  Future<String?> _getTalyerOwnerIdFromShop(String shopId) async {
    try {
      final shop = await _supabase
          .from('shops')
          .select('owner_id')
          .eq('id', shopId)
          .single();
      
      return shop['owner_id'] as String?;
    } catch (e) {
      print('❌ Error getting talyer owner ID: $e');
      return null;
    }
  }
}
