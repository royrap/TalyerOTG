import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for fetching mechanic dashboard statistics and reviews
/// Used by profile screen and dashboard to sync data
class MechanicDashboardService {
  final _supabase = Supabase.instance.client;

  /// Get comprehensive dashboard statistics for a mechanic
  /// Returns: Map with today's jobs, earnings, rating, active jobs, total jobs
  Future<Map<String, dynamic>> getDashboardStats(String mechanicId) async {
    try {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final todayEnd = todayStart.add(const Duration(days: 1));

      // Get today's earnings from completed jobs
      final todayEarnings = await _getTodayEarnings(mechanicId, todayStart, todayEnd);

      // Get today's job count (completed today)
      final todayJobsCount = await _getTodayJobsCount(mechanicId, todayStart, todayEnd);

      // Get active jobs count (in_progress, on_the_way, accepted)
      final activeJobsCount = await _getActiveJobsCount(mechanicId);

      // Get mechanic rating from user_profiles
      final rating = await _getMechanicRating(mechanicId);

      // Get total completed jobs
      final totalJobs = await _getTotalCompletedJobs(mechanicId);

      // Get total earnings (all-time)
      final totalEarnings = await _getTotalEarnings(mechanicId);

      return {
        'today_jobs': todayJobsCount,
        'today_earnings': todayEarnings,
        'active_jobs': activeJobsCount,
        'rating': rating,
        'total_jobs': totalJobs,
        'total_earnings': totalEarnings,
      };
    } catch (e) {
      print('❌ Error getting dashboard stats: $e');
      // Return default values on error
      return {
        'today_jobs': 0,
        'today_earnings': 0.0,
        'active_jobs': 0,
        'rating': 0.0,
        'total_jobs': 0,
      };
    }
  }

  /// Get today's earnings for mechanic
  Future<double> _getTodayEarnings(
    String mechanicId,
    DateTime todayStart,
    DateTime todayEnd,
  ) async {
    try {
      // Convert to UTC for database query
      final startOfDayUTC = todayStart.toUtc();
      final endOfDayUTC = todayEnd.toUtc();

      // Sum all paid invoices for today directly from invoices table
      // This matches MechanicHistoryService.getEarningsToday() logic
      final result = await _supabase
          .from('invoices')
          .select('total_amount')
          .eq('mechanic_id', mechanicId)
          .eq('status', 'paid')
          .gte('paid_at', startOfDayUTC.toIso8601String())
          .lte('paid_at', endOfDayUTC.toIso8601String());

      double total = 0.0;
      for (var invoice in result) {
        final amount = invoice['total_amount'];
        if (amount != null) {
          total += (amount is int) ? amount.toDouble() : amount as double;
        }
      }

      return total;
    } catch (e) {
      print('❌ Error getting today earnings: $e');
      return 0.0;
    }
  }

  /// Get count of jobs completed today
  Future<int> _getTodayJobsCount(
    String mechanicId,
    DateTime todayStart,
    DateTime todayEnd,
  ) async {
    try {
      // Convert to UTC for database query
      final startOfDayUTC = todayStart.toUtc();
      final endOfDayUTC = todayEnd.toUtc();

      // Query mechanic_job_history table for completed jobs today
      // This matches MechanicHistoryService.getCompletedJobsTodayCount() logic
      final jobs = await _supabase
          .from('mechanic_job_history')
          .select('id')
          .eq('mechanic_id', mechanicId)
          .eq('job_status', 'completed')
          .gte('completed_at', startOfDayUTC.toIso8601String())
          .lte('completed_at', endOfDayUTC.toIso8601String());

      return jobs.length;
    } catch (e) {
      print('❌ Error getting today jobs count: $e');
      return 0;
    }
  }

  /// Get count of active jobs (in progress, on the way, accepted)
  Future<int> _getActiveJobsCount(String mechanicId) async {
    try {
      final activeJobs = await _supabase
          .from('service_requests')
          .select('id')
          .eq('provider_id', mechanicId)
          .inFilter('status', ['accepted', 'in_progress', 'on_the_way']);

      return activeJobs.length;
    } catch (e) {
      print('❌ Error getting active jobs count: $e');
      return 0;
    }
  }

  /// Get mechanic's average rating from user_profiles
  Future<double> _getMechanicRating(String mechanicId) async {
    try {
      final profile = await _supabase
          .from('user_profiles')
          .select('rating')
          .eq('id', mechanicId)
          .maybeSingle();

      return profile != null ? (profile['rating'] ?? 0.0).toDouble() : 0.0;
    } catch (e) {
      print('❌ Error getting mechanic rating: $e');
      return 0.0;
    }
  }

  /// Get total completed jobs count
  Future<int> _getTotalCompletedJobs(String mechanicId) async {
    try {
      // Query mechanic_job_history table for all completed jobs
      // This matches MechanicHistoryService.getCompletedJobsCount() logic
      final jobs = await _supabase
          .from('mechanic_job_history')
          .select('id')
          .eq('mechanic_id', mechanicId)
          .eq('job_status', 'completed');

      return jobs.length;
    } catch (e) {
      print('❌ Error getting total jobs: $e');
      return 0;
    }
  }

  /// Get total all-time earnings for mechanic
  Future<double> _getTotalEarnings(String mechanicId) async {
    try {
      // Sum all paid invoices from invoices table
      // This matches MechanicHistoryService.getTotalEarnings() logic
      final result = await _supabase
          .from('invoices')
          .select('total_amount')
          .eq('mechanic_id', mechanicId)
          .eq('status', 'paid');

      double total = 0.0;
      for (var invoice in result) {
        final amount = invoice['total_amount'];
        if (amount != null) {
          total += (amount is int) ? amount.toDouble() : amount as double;
        }
      }

      return total;
    } catch (e) {
      print('❌ Error getting total earnings: $e');
      return 0.0;
    }
  }

  /// Get reviews for a mechanic
  /// Returns list of reviews with customer details
  Future<List<Map<String, dynamic>>> getMechanicReviews(String mechanicId) async {
    try {
      final reviews = await _supabase
          .from('reviews')
          .select('''
            id,
            rating,
            comment,
            created_at,
            customer_id,
            request_id
          ''')
          .eq('provider_id', mechanicId)
          .order('created_at', ascending: false)
          .limit(50);

      // reviews is always a List from Supabase query

      // Fetch customer details for each review
      final reviewsWithCustomer = <Map<String, dynamic>>[];
      for (var review in reviews) {
        try {
          final customerId = review['customer_id'];
          final customerProfile = await _supabase
              .from('user_profiles')
              .select('first_name, last_name, profile_image_url')
              .eq('id', customerId)
              .maybeSingle();

          reviewsWithCustomer.add({
            'id': review['id'],
            'rating': review['rating'],
            'comment': review['comment'] ?? '',
            'created_at': review['created_at'],
            'customer_name': customerProfile != null
                ? '${customerProfile['first_name'] ?? ''} ${customerProfile['last_name'] ?? ''}'.trim()
                : 'Customer',
            'customer_image': customerProfile?['profile_image_url'],
            'request_id': review['request_id'],
          });
        } catch (e) {
          print('⚠️ Error fetching customer for review: $e');
          // Add review without customer details
          reviewsWithCustomer.add({
            'id': review['id'],
            'rating': review['rating'],
            'comment': review['comment'] ?? '',
            'created_at': review['created_at'],
            'customer_name': 'Customer',
            'customer_image': null,
            'request_id': review['request_id'],
          });
        }
      }

      return reviewsWithCustomer;
    } catch (e) {
      print('❌ Error getting mechanic reviews: $e');
      return [];
    }
  }

  /// Get review count for a mechanic
  Future<int> getReviewCount(String mechanicId) async {
    try {
      final reviews = await _supabase
          .from('reviews')
          .select('id')
          .eq('provider_id', mechanicId);

      return reviews.length;
    } catch (e) {
      print('❌ Error getting review count: $e');
      return 0;
    }
  }

  /// Get rating distribution (how many 1-star, 2-star, etc.)
  Future<Map<int, int>> getRatingDistribution(String mechanicId) async {
    try {
      final reviews = await _supabase
          .from('reviews')
          .select('rating')
          .eq('provider_id', mechanicId);

      Map<int, int> distribution = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};

      for (var review in reviews) {
          final rating = review['rating'] as int?;
          if (rating != null && rating >= 1 && rating <= 5) {
            distribution[rating] = (distribution[rating] ?? 0) + 1;
          }
        }

      return distribution;
    } catch (e) {
      print('❌ Error getting rating distribution: $e');
      return {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
    }
  }

  /// Get quick stats summary for mechanic
  /// Convenience method for profile header
  Future<Map<String, dynamic>> getQuickStats(String mechanicId) async {
    try {
      final stats = await getDashboardStats(mechanicId);
      final reviewCount = await getReviewCount(mechanicId);

      return {
        'rating': stats['rating'],
        'total_reviews': reviewCount,
        'total_jobs': stats['total_jobs'],
        'today_earnings': stats['today_earnings'],
      };
    } catch (e) {
      print('❌ Error getting quick stats: $e');
      return {
        'rating': 0.0,
        'total_reviews': 0,
        'total_jobs': 0,
        'today_earnings': 0.0,
      };
    }
  }
}
