import 'package:supabase_flutter/supabase_flutter.dart';

/// Comprehensive service for RoadAid system integration
/// Connects all system components for unified tracking and analytics
class SystemIntegrationService {
  static final SystemIntegrationService _instance = SystemIntegrationService._internal();
  static SystemIntegrationService get instance => _instance;
  SystemIntegrationService._internal();

  final _supabase = Supabase.instance.client;

  // ==========================================================================
  // SERVICE REQUEST LIFECYCLE MANAGEMENT
  // ==========================================================================

  /// Get complete service request lifecycle data
  Future<Map<String, dynamic>?> getServiceRequestLifecycle(String requestId) async {
    try {
      final response = await _supabase
          .from('service_request_lifecycle')
          .select('''
            *,
            service_requests(title, description, status),
            user_profiles!customer_id(first_name, last_name, email),
            service_providers!provider_id(company_name, rating, years_experience),
            service_categories(name, description),
            vehicles(brand_name, model_name, plate_number)
          ''')
          .eq('request_id', requestId)
          .single();

      return response;
    } catch (e) {
      print('Error fetching service request lifecycle: $e');
      return null;
    }
  }

  /// Get lifecycle analytics for a specific provider
  Future<Map<String, dynamic>> getProviderLifecycleAnalytics(String providerId) async {
    try {
      final response = await _supabase
          .from('service_request_lifecycle')
          .select('*')
          .eq('provider_id', providerId)
          .order('request_created_at', ascending: false);

      final lifecycles = List<Map<String, dynamic>>.from(response);
      
      // Calculate analytics
      int totalJobs = lifecycles.length;
      int completedJobs = lifecycles.where((l) => l['current_status'] == 'completed').length;
      double avgRating = 0.0;
      double avgDuration = 0.0;
      int totalDurationMinutes = 0;
      int ratedJobs = 0;

      for (final lifecycle in lifecycles) {
        if (lifecycle['customer_satisfaction_rating'] != null) {
          avgRating += lifecycle['customer_satisfaction_rating'];
          ratedJobs++;
        }
        if (lifecycle['actual_duration_minutes'] != null) {
          totalDurationMinutes += lifecycle['actual_duration_minutes'] as int;
        }
      }

      avgRating = ratedJobs > 0 ? avgRating / ratedJobs : 0.0;
      avgDuration = completedJobs > 0 ? totalDurationMinutes / completedJobs : 0.0;

      return {
        'total_jobs': totalJobs,
        'completed_jobs': completedJobs,
        'completion_rate': totalJobs > 0 ? (completedJobs / totalJobs) * 100 : 0.0,
        'average_rating': avgRating,
        'average_duration_minutes': avgDuration,
        'recent_jobs': lifecycles.take(10).toList(),
      };
    } catch (e) {
      print('Error fetching provider lifecycle analytics: $e');
      return ;
    }
  }

  // ==========================================================================
  // SYSTEM ACTIVITY TRACKING
  // ==========================================================================

  /// Log system activity with comprehensive context
  Future<String?> logActivity({
    required String activityType,
    required String primaryEntityType,
    required String primaryEntityId,
    String? actorUserId,
    String? targetUserId,
    String? activityDescription,
    Map<String, dynamic>? activityMetadata,
    String? platform,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final response = await _supabase
          .from('system_activity_tracker')
          .insert({
            'activity_type': activityType,
            'primary_entity_type': primaryEntityType,
            'primary_entity_id': primaryEntityId,
            'actor_user_id': actorUserId,
            'target_user_id': targetUserId,
            'activity_description': activityDescription ?? '',
            'activity_metadata': activityMetadata ?? {},
            'platform': platform,
            'activity_latitude': latitude,
            'activity_longitude': longitude,
          })
          .select('id')
          .single();

      return response['id'];
    } catch (e) {
      print('Error logging system activity: $e');
      return null;
    }
  }

  /// Get recent activities for a user
  Future<List<Map<String, dynamic>>> getUserActivities(
    String userId, {
    int limit = 50,
    List<String>? activityTypes,
  }) async {
    try {
      var query = _supabase
          .from('system_activity_tracker')
          .select('*')
          .or('actor_user_id.eq.$userId,target_user_id.eq.$userId')
          .order('activity_timestamp', ascending: false)
          .limit(limit);

      final response = await query;
      var activities = List<Map<String, dynamic>>.from(response);

      // Filter by activity types if specified
      if (activityTypes != null && activityTypes.isNotEmpty) {
        activities = activities.where((activity) => 
          activityTypes.contains(activity['activity_type'])).toList();
      }

      return activities;
    } catch (e) {
      print('Error fetching user activities: $e');
      return [];
    }
  }

  /// Get system-wide activity statistics
  Future<Map<String, dynamic>> getSystemActivityStats({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      var query = _supabase
          .from('system_activity_tracker')
          .select('activity_type, activity_result, platform');

      if (startDate != null) {
        query = query.gte('activity_timestamp', startDate.toIso8601String());
      }
      if (endDate != null) {
        query = query.lte('activity_timestamp', endDate.toIso8601String());
      }

      final response = await query;
      final activities = List<Map<String, dynamic>>.from(response);

      // Analyze activity patterns
      Map<String, int> activityTypeCounts = ;
      Map<String, int> platformCounts = ;
      Map<String, int> resultCounts = ;

      for (final activity in activities) {
        final type = activity['activity_type']?.toString() ?? 'unknown';
        final platform = activity['platform']?.toString();
        final result = activity['activity_result']?.toString();

        activityTypeCounts[type] = (activityTypeCounts[type] ?? 0) + 1;
        if (platform != null && platform.isNotEmpty) {
          platformCounts[platform] = (platformCounts[platform] ?? 0) + 1;
        }
        if (result != null && result.isNotEmpty) {
          resultCounts[result] = (resultCounts[result] ?? 0) + 1;
        }
      }

      return {
        'total_activities': activities.length,
        'activity_type_breakdown': activityTypeCounts,
        'platform_breakdown': platformCounts,
        'result_breakdown': resultCounts,
        'success_rate': activities.isNotEmpty ? 
          (resultCounts['success'] ?? 0) / activities.length * 100 : 0.0,
      };
    } catch (e) {
      print('Error fetching system activity stats: $e');
      return ;
    }
  }

  // ==========================================================================
  // ENTITY RELATIONSHIP MANAGEMENT
  // ==========================================================================

  /// Create or update relationship between entities
  Future<String?> createEntityRelationship({
    required String relationshipType,
    required String entityAType,
    required String entityAId,
    required String entityBType,
    required String entityBId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final response = await _supabase
          .rpc('create_entity_relationship', params: {
            'p_relationship_type': relationshipType,
            'p_entity_a_type': entityAType,
            'p_entity_a_id': entityAId,
            'p_entity_b_type': entityBType,
            'p_entity_b_id': entityBId,
            'p_relationship_metadata': metadata ?? {},
          });

      return response;
    } catch (e) {
      print('Error creating entity relationship: $e');
      return null;
    }
  }

  /// Get all relationships for an entity
  Future<List<Map<String, dynamic>>> getEntityRelationships(
    String entityType,
    String entityId, {
    List<String>? relationshipTypes,
    String? status,
  }) async {
    try {
      var query = _supabase
          .from('entity_relationships')
          .select('*')
          .or('and(entity_a_type.eq.$entityType,entity_a_id.eq.$entityId),and(entity_b_type.eq.$entityType,entity_b_id.eq.$entityId)');

      if (relationshipTypes != null && relationshipTypes.isNotEmpty) {
        query = query.inFilter('relationship_type', relationshipTypes);
      }

      if (status != null) {
        query = query.eq('relationship_status', status);
      }

      final response = await query.order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching entity relationships: $e');
      return [];
    }
  }

  // ==========================================================================
  // PERFORMANCE METRICS & ANALYTICS
  // ==========================================================================

  /// Get current system performance metrics
  Future<Map<String, dynamic>?> getCurrentSystemMetrics() async {
    try {
      final response = await _supabase
          .from('system_performance_metrics')
          .select('*')
          .order('metric_timestamp', ascending: false)
          .limit(1)
          .single();

      return response;
    } catch (e) {
      print('Error fetching current system metrics: $e');
      return null;
    }
  }

  /// Get performance metrics over time
  Future<List<Map<String, dynamic>>> getPerformanceMetricsHistory({
    required String metricType,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 100,
  }) async {
    try {
      var query = _supabase
          .from('system_performance_metrics')
          .select('*')
          .eq('metric_type', metricType)
          .order('metric_timestamp', ascending: false)
          .limit(limit);

      final response = await query;
      var metrics = List<Map<String, dynamic>>.from(response);

      // Filter by date range if specified
      if (startDate != null || endDate != null) {
        metrics = metrics.where((metric) {
          final timestamp = DateTime.parse(metric['metric_timestamp']);
          if (startDate != null && timestamp.isBefore(startDate)) return false;
          if (endDate != null && timestamp.isAfter(endDate)) return false;
          return true;
        }).toList();
      }

      return metrics;
    } catch (e) {
      print('Error fetching performance metrics history: $e');
      return [];
    }
  }

  /// Generate comprehensive system analytics
  Future<Map<String, dynamic>> generateSystemAnalytics() async {
    try {
      // Get various analytics in parallel
      final results = await Future.wait([
        _getRequestAnalytics(),
        _getProviderAnalytics(),
        _getCustomerAnalytics(),
        _getFinancialAnalytics(),
        _getGeographicAnalytics(),
      ]);

      return {
        'request_analytics': results[0],
        'provider_analytics': results[1],
        'customer_analytics': results[2],
        'financial_analytics': results[3],
        'geographic_analytics': results[4],
        'generated_at': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      print('Error generating system analytics: $e');
      return ;
    }
  }

  // ==========================================================================
  // DASHBOARD DATA CACHING
  // ==========================================================================

  /// Get cached dashboard data
  Future<Map<String, dynamic>?> getCachedDashboardData({
    required String cacheType,
    String? targetUserId,
    String? targetEntityType,
    String? targetEntityId,
  }) async {
    try {
      String cacheKey = '$cacheType';
      if (targetUserId != null) cacheKey += '_$targetUserId';
      if (targetEntityType != null && targetEntityId != null) {
        cacheKey += '_${targetEntityType}_$targetEntityId';
      }

      final response = await _supabase
          .from('dashboard_data_cache')
          .select('cached_data, cache_expires_at')
          .eq('cache_key', cacheKey)
          .eq('is_valid', true)
          .gte('cache_expires_at', DateTime.now().toIso8601String())
          .maybeSingle();

      return response?['cached_data'];
    } catch (e) {
      print('Error fetching cached dashboard data: $e');
      return null;
    }
  }

  /// Cache dashboard data
  Future<bool> cacheDashboardData({
    required String cacheType,
    required Map<String, dynamic> data,
    String? targetUserId,
    String? targetEntityType,
    String? targetEntityId,
    Duration? expirationDuration,
  }) async {
    try {
      String cacheKey = '$cacheType';
      if (targetUserId != null) cacheKey += '_$targetUserId';
      if (targetEntityType != null && targetEntityId != null) {
        cacheKey += '_${targetEntityType}_$targetEntityId';
      }

      final expiresAt = DateTime.now().add(expirationDuration ?? const Duration(hours: 1));

      await _supabase
          .from('dashboard_data_cache')
          .upsert({
            'cache_key': cacheKey,
            'cache_type': cacheType,
            'target_user_id': targetUserId,
            'target_entity_type': targetEntityType,
            'target_entity_id': targetEntityId,
            'cached_data': data,
            'cache_expires_at': expiresAt.toIso8601String(),
            'is_valid': true,
          });

      return true;
    } catch (e) {
      print('Error caching dashboard data: $e');
      return false;
    }
  }

  // ==========================================================================
  // PRIVATE HELPER METHODS
  // ==========================================================================

  Future<Map<String, dynamic>> _getRequestAnalytics() async {
    final response = await _supabase
        .from('service_request_lifecycle')
        .select('current_status, request_created_at, actual_duration_minutes, customer_satisfaction_rating');

    final requests = List<Map<String, dynamic>>.from(response);
    
    Map<String, int> statusCounts = ;
    double totalRating = 0;
    int ratedCount = 0;
    int totalDuration = 0;
    int durationCount = 0;

    for (final request in requests) {
      final status = request['current_status']?.toString() ?? 'unknown';
      statusCounts[status] = (statusCounts[status] ?? 0) + 1;

      if (request['customer_satisfaction_rating'] != null) {
        totalRating += request['customer_satisfaction_rating'];
        ratedCount++;
      }

      if (request['actual_duration_minutes'] != null) {
        totalDuration += request['actual_duration_minutes'] as int;
        durationCount++;
      }
    }

    return {
      'total_requests': requests.length,
      'status_breakdown': statusCounts,
      'average_rating': ratedCount > 0 ? totalRating / ratedCount : 0.0,
      'average_duration_minutes': durationCount > 0 ? totalDuration / durationCount : 0.0,
    };
  }

  Future<Map<String, dynamic>> _getProviderAnalytics() async {
    final response = await _supabase
        .from('service_providers')
        .select('rating, total_reviews, is_verified, is_available, status');

    final providers = List<Map<String, dynamic>>.from(response);
    
    int totalProviders = providers.length;
    int verifiedProviders = providers.where((p) => p['is_verified'] == true).length;
    int availableProviders = providers.where((p) => p['is_available'] == true).length;
    double avgRating = 0;

    if (providers.isNotEmpty) {
      avgRating = providers
          .map((p) => (p['rating'] as num?)?.toDouble() ?? 0.0)
          .reduce((a, b) => a + b) / providers.length;
    }

    return {
      'total_providers': totalProviders,
      'verified_providers': verifiedProviders,
      'available_providers': availableProviders,
      'verification_rate': totalProviders > 0 ? (verifiedProviders / totalProviders) * 100 : 0.0,
      'average_rating': avgRating,
    };
  }

  Future<Map<String, dynamic>> _getCustomerAnalytics() async {
    final response = await _supabase
        .from('user_profiles')
        .select('user_type, created_at, last_login_at')
        .eq('user_type', 'customer');

    final customers = List<Map<String, dynamic>>.from(response);
    
    final now = DateTime.now();
    final lastWeek = now.subtract(const Duration(days: 7));
    final lastMonth = now.subtract(const Duration(days: 30));

    int activeLastWeek = 0;
    int activeLastMonth = 0;
    int newThisMonth = 0;

    for (final customer in customers) {
      final lastLogin = customer['last_login_at'] != null 
          ? DateTime.parse(customer['last_login_at']) 
          : null;
      final createdAt = DateTime.parse(customer['created_at']);

      if (lastLogin != null && lastLogin.isAfter(lastWeek)) {
        activeLastWeek++;
      }
      if (lastLogin != null && lastLogin.isAfter(lastMonth)) {
        activeLastMonth++;
      }
      if (createdAt.isAfter(lastMonth)) {
        newThisMonth++;
      }
    }

    return {
      'total_customers': customers.length,
      'active_last_week': activeLastWeek,
      'active_last_month': activeLastMonth,
      'new_this_month': newThisMonth,
    };
  }

  Future<Map<String, dynamic>> _getFinancialAnalytics() async {
    final paymentsResponse = await _supabase
        .from('payments')
        .select('amount, platform_fee, provider_amount, status, created_at');

    final payments = List<Map<String, dynamic>>.from(paymentsResponse);
    
    double totalRevenue = 0;
    double totalPlatformFees = 0;
    double totalProviderPayouts = 0;
    
    final now = DateTime.now();
    final thisMonth = DateTime(now.year, now.month, 1);
    
    double monthlyRevenue = 0;
    double monthlyFees = 0;

    for (final payment in payments) {
      if (payment['status'] == 'completed' || payment['status'] == 'paid') {
        final amount = (payment['amount'] as num?)?.toDouble() ?? 0.0;
        final fee = (payment['platform_fee'] as num?)?.toDouble() ?? 0.0;
        final providerAmount = (payment['provider_amount'] as num?)?.toDouble() ?? 0.0;
        
        totalRevenue += amount;
        totalPlatformFees += fee;
        totalProviderPayouts += providerAmount;

        final createdAt = DateTime.parse(payment['created_at']);
        if (createdAt.isAfter(thisMonth)) {
          monthlyRevenue += amount;
          monthlyFees += fee;
        }
      }
    }

    return {
      'total_revenue': totalRevenue,
      'total_platform_fees': totalPlatformFees,
      'total_provider_payouts': totalProviderPayouts,
      'monthly_revenue': monthlyRevenue,
      'monthly_platform_fees': monthlyFees,
      'total_transactions': payments.length,
    };
  }

  Future<Map<String, dynamic>> _getGeographicAnalytics() async {
    final response = await _supabase
        .from('service_request_lifecycle')
        .select('pickup_latitude, pickup_longitude, pickup_address')
        .not('pickup_latitude', 'is', null)
        .not('pickup_longitude', 'is', null);

    final requests = List<Map<String, dynamic>>.from(response);
    
    // Simple geographic analysis
    Map<String, int> areaCounts = ;
    
    for (final request in requests) {
      final address = request['pickup_address']?.toString();
      if (address != null && address.isNotEmpty) {
        // Extract city/area from address (simplified)
        final parts = address.split(',');
        if (parts.isNotEmpty) {
          final area = parts.last.trim();
          areaCounts[area] = (areaCounts[area] ?? 0) + 1;
        }
      }
    }

    return {
      'total_service_locations': requests.length,
      'coverage_areas': areaCounts.keys.length,
      'top_service_areas': areaCounts,
    };
  }
}










