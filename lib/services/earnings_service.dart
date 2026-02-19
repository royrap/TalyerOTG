import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/earnings_models.dart';

/// Service to handle Angkas-style earnings calculations and tracking
/// Fee distribution: 75% mechanic, 20% shop, 5% platform
class EarningsService {
  static final EarningsService _instance = EarningsService._internal();
  static EarningsService get instance => _instance;
  EarningsService._internal();

  final _supabase = Supabase.instance.client;

  // Angkas-style fee percentages
  static const double MECHANIC_PERCENTAGE = 75.0;
  static const double SHOP_PERCENTAGE = 20.0;
  static const double PLATFORM_PERCENTAGE = 5.0;

  /// Calculate earnings breakdown from total amount
  EarningsBreakdown calculateEarningsBreakdown(double totalAmount) {
    final mechanicEarnings = (totalAmount * MECHANIC_PERCENTAGE / 100.0);
    final shopEarnings = (totalAmount * SHOP_PERCENTAGE / 100.0);
    final platformFee = (totalAmount * PLATFORM_PERCENTAGE / 100.0);

    return EarningsBreakdown(
      totalAmount: totalAmount,
      mechanicEarnings: double.parse(mechanicEarnings.toStringAsFixed(2)),
      shopEarnings: double.parse(shopEarnings.toStringAsFixed(2)),
      platformFee: double.parse(platformFee.toStringAsFixed(2)),
      mechanicPercentage: MECHANIC_PERCENTAGE,
      shopPercentage: SHOP_PERCENTAGE,
      platformPercentage: PLATFORM_PERCENTAGE,
    );
  }

  /// Get mechanic earnings summary
  Future<MechanicEarningsSummary> getMechanicEarningsSummary({String? mechanicId}) async {
    try {
      final user = _supabase.auth.currentUser;
      final userId = mechanicId ?? user?.id;
      
      if (userId == null) throw Exception('No authenticated user');

      print('💰 EarningsService.getMechanicEarningsSummary() - Loading for mechanic: $userId');

      // Get earnings summary using database function if available, otherwise calculate
      try {
        final result = await _supabase
            .rpc('get_mechanic_earnings_summary', params: {'p_mechanic_id': userId});
        
        if (result.isNotEmpty) {
          final data = result.first;
          return MechanicEarningsSummary(
            totalJobs: data['total_jobs'] ?? 0,
            totalEarnings: (data['total_earnings'] ?? 0.0).toDouble(),
            thisMonthEarnings: (data['this_month_earnings'] ?? 0.0).toDouble(),
            thisWeekEarnings: (data['this_week_earnings'] ?? 0.0).toDouble(),
            todayEarnings: (data['today_earnings'] ?? 0.0).toDouble(),
            averageRating: (data['average_rating'] ?? 0.0).toDouble(),
          );
        }
      } catch (e) {
        print('⚠️ Database function not available, calculating manually: $e');
      }

      // Fallback: Manual calculation from mechanic_job_history
      final jobs = await _supabase
          .from('mechanic_job_history')
          .select('mechanic_earnings, total_amount, rating, completed_at')
          .eq('mechanic_id', userId)
          .eq('job_status', 'completed')
          .not('completed_at', 'is', null);

      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      final startOfDay = DateTime(now.year, now.month, now.day);

      double totalEarnings = 0.0;
      double thisMonthEarnings = 0.0;
      double thisWeekEarnings = 0.0;
      double todayEarnings = 0.0;
      double totalRating = 0.0;
      int ratingCount = 0;

      for (var job in jobs) {
        // Get earnings (prefer mechanic_earnings, fallback to 75% of total_amount)
        final earnings = job['mechanic_earnings']?.toDouble() ?? 
                        (job['total_amount']?.toDouble() ?? 0.0) * 0.75;
        
        totalEarnings += earnings;

        // Get completion date
        final completedAt = job['completed_at'] != null 
            ? DateTime.parse(job['completed_at']) 
            : null;

        if (completedAt != null) {
          if (completedAt.isAfter(startOfMonth)) {
            thisMonthEarnings += earnings;
          }
          if (completedAt.isAfter(startOfWeek)) {
            thisWeekEarnings += earnings;
          }
          if (completedAt.isAfter(startOfDay)) {
            todayEarnings += earnings;
          }
        }

        // Calculate average rating
        final rating = job['rating']?.toDouble();
        if (rating != null) {
          totalRating += rating;
          ratingCount++;
        }
      }

      return MechanicEarningsSummary(
        totalJobs: jobs.length,
        totalEarnings: double.parse(totalEarnings.toStringAsFixed(2)),
        thisMonthEarnings: double.parse(thisMonthEarnings.toStringAsFixed(2)),
        thisWeekEarnings: double.parse(thisWeekEarnings.toStringAsFixed(2)),
        todayEarnings: double.parse(todayEarnings.toStringAsFixed(2)),
        averageRating: ratingCount > 0 
            ? double.parse((totalRating / ratingCount).toStringAsFixed(1)) 
            : 0.0,
      );
    } catch (e) {
      print('❌ Error getting mechanic earnings summary: $e');
      return MechanicEarningsSummary(
        totalJobs: 0,
        totalEarnings: 0.0,
        thisMonthEarnings: 0.0,
        thisWeekEarnings: 0.0,
        todayEarnings: 0.0,
        averageRating: 0.0,
      );
    }
  }

  /// Get shop owner earnings summary
  Future<ShopEarningsSummary> getShopEarningsSummary({String? shopOwnerId}) async {
    try {
      final user = _supabase.auth.currentUser;
      final userId = shopOwnerId ?? user?.id;
      
      if (userId == null) throw Exception('No authenticated user');

      print('🏪 EarningsService.getShopEarningsSummary() - Loading for shop owner: $userId');

      // Try using database function first
      try {
        final result = await _supabase
            .rpc('get_shop_earnings_summary', params: {'p_shop_owner_id': userId});
        
        if (result.isNotEmpty) {
          final data = result.first;
          return ShopEarningsSummary(
            totalJobs: data['total_jobs'] ?? 0,
            totalShopEarnings: (data['total_shop_earnings'] ?? 0.0).toDouble(),
            thisMonthEarnings: (data['this_month_earnings'] ?? 0.0).toDouble(),
            thisWeekEarnings: (data['this_week_earnings'] ?? 0.0).toDouble(),
            todayEarnings: (data['today_earnings'] ?? 0.0).toDouble(),
            numberOfMechanics: data['number_of_mechanics'] ?? 0,
          );
        }
      } catch (e) {
        print('⚠️ Database function not available, calculating manually: $e');
      }

      // Fallback: Manual calculation
      final shops = await _supabase
          .from('shops')
          .select('id, shop_name')
          .eq('owner_id', userId);

      if (shops.isEmpty) {
        return ShopEarningsSummary(
          totalJobs: 0,
          totalShopEarnings: 0.0,
          thisMonthEarnings: 0.0,
          thisWeekEarnings: 0.0,
          todayEarnings: 0.0,
          numberOfMechanics: 0,
        );
      }

      final shopIds = shops.map((shop) => shop['id']).toList();
      
      // Get job history for all shops owned by this user
      final jobs = await _supabase
          .from('mechanic_job_history')
          .select('shop_earnings, total_amount, completed_at, mechanic_id')
          .inFilter('shop_id', shopIds)
          .eq('job_status', 'completed')
          .not('completed_at', 'is', null);

      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      final startOfDay = DateTime(now.year, now.month, now.day);

      double totalShopEarnings = 0.0;
      double thisMonthEarnings = 0.0;
      double thisWeekEarnings = 0.0;
      double todayEarnings = 0.0;
      final uniqueMechanics = <String>{};

      for (var job in jobs) {
        // Get shop earnings (prefer shop_earnings, fallback to 20% of total_amount)
        final shopEarnings = job['shop_earnings']?.toDouble() ?? 
                           (job['total_amount']?.toDouble() ?? 0.0) * 0.20;
        
        totalShopEarnings += shopEarnings;
        uniqueMechanics.add(job['mechanic_id']);

        // Get completion date
        final completedAt = job['completed_at'] != null 
            ? DateTime.parse(job['completed_at']) 
            : null;

        if (completedAt != null) {
          if (completedAt.isAfter(startOfMonth)) {
            thisMonthEarnings += shopEarnings;
          }
          if (completedAt.isAfter(startOfWeek)) {
            thisWeekEarnings += shopEarnings;
          }
          if (completedAt.isAfter(startOfDay)) {
            todayEarnings += shopEarnings;
          }
        }
      }

      return ShopEarningsSummary(
        totalJobs: jobs.length,
        totalShopEarnings: double.parse(totalShopEarnings.toStringAsFixed(2)),
        thisMonthEarnings: double.parse(thisMonthEarnings.toStringAsFixed(2)),
        thisWeekEarnings: double.parse(thisWeekEarnings.toStringAsFixed(2)),
        todayEarnings: double.parse(todayEarnings.toStringAsFixed(2)),
        numberOfMechanics: uniqueMechanics.length,
      );
    } catch (e) {
      print('❌ Error getting shop earnings summary: $e');
      return ShopEarningsSummary(
        totalJobs: 0,
        totalShopEarnings: 0.0,
        thisMonthEarnings: 0.0,
        thisWeekEarnings: 0.0,
        todayEarnings: 0.0,
        numberOfMechanics: 0,
      );
    }
  }

  /// Update job with earnings breakdown when completed
  Future<bool> updateJobEarnings({
    required String jobHistoryId,
    required double totalAmount,
  }) async {
    try {
      print('💰 EarningsService.updateJobEarnings() - Updating job: $jobHistoryId');

      final breakdown = calculateEarningsBreakdown(totalAmount);

      await _supabase
          .from('mechanic_job_history')
          .update({
            'total_amount': totalAmount,
            'mechanic_earnings': breakdown.mechanicEarnings,
            'shop_earnings': breakdown.shopEarnings,
            'platform_fee': breakdown.platformFee,
            'fee_percentage_mechanic': breakdown.mechanicPercentage,
            'fee_percentage_shop': breakdown.shopPercentage,
            'fee_percentage_platform': breakdown.platformPercentage,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', jobHistoryId);

      print('✅ Job earnings updated successfully');
      return true;
    } catch (e) {
      print('❌ Error updating job earnings: $e');
      return false;
    }
  }

  /// Get detailed earnings history for mechanic
  Future<List<EarningsHistoryItem>> getMechanicEarningsHistory({
    String? mechanicId,
    int? limit,
    int? offset,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      final userId = mechanicId ?? user?.id;
      
      if (userId == null) throw Exception('No authenticated user');

      var query = _supabase
          .from('mechanic_job_history')
          .select('''
            id,
            job_title,
            total_amount,
            mechanic_earnings,
            shop_earnings,
            platform_fee,
            completed_at,
            rating,
            service_requests!mechanic_job_history_service_request_id_fkey(
              pickup_address,
              service_type
            ),
            user_profiles!mechanic_job_history_customer_id_fkey(
              first_name,
              last_name
            ),
            shops!mechanic_job_history_shop_id_fkey(
              shop_name
            )
          ''')
          .eq('mechanic_id', userId)
          .eq('job_status', 'completed')
          .not('completed_at', 'is', null)
          .order('completed_at', ascending: false);

      if (limit != null && offset != null) {
        query = query.range(offset, offset + limit - 1);
      } else if (limit != null) {
        query = query.limit(limit);
      }

      final result = await query;

      return result.map<EarningsHistoryItem>((job) {
        // Calculate earnings if not stored (fallback)
        final totalAmount = job['total_amount']?.toDouble() ?? 0.0;
        final storedEarnings = job['mechanic_earnings']?.toDouble();
        final earnings = storedEarnings ?? (totalAmount * 0.75);
        
        return EarningsHistoryItem(
          id: job['id'],
          jobTitle: job['job_title'] ?? '',
          customerName: '${job['user_profiles']?['first_name'] ?? ''} ${job['user_profiles']?['last_name'] ?? ''}',
          shopName: job['shops']?['shop_name'] ?? '',
          location: job['service_requests']?['pickup_address'] ?? '',
          serviceType: job['service_requests']?['service_type'] ?? '',
          totalAmount: totalAmount,
          earnings: double.parse(earnings.toStringAsFixed(2)),
          shopEarnings: job['shop_earnings']?.toDouble() ?? (totalAmount * 0.20),
          platformFee: job['platform_fee']?.toDouble() ?? (totalAmount * 0.05),
          rating: job['rating']?.toDouble(),
          completedAt: job['completed_at'] != null 
              ? DateTime.parse(job['completed_at']) 
              : DateTime.now(),
        );
      }).toList();
    } catch (e) {
      print('❌ Error getting mechanic earnings history: $e');
      return [];
    }
  }

  /// Get detailed earnings history for shop owner
  Future<List<ShopEarningsHistoryItem>> getShopEarningsHistory({
    String? shopOwnerId,
    int? limit,
    int? offset,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      final userId = shopOwnerId ?? user?.id;
      
      if (userId == null) throw Exception('No authenticated user');

      // Get shops owned by this user
      final shops = await _supabase
          .from('shops')
          .select('id, shop_name')
          .eq('owner_id', userId);

      if (shops.isEmpty) return [];

      final shopIds = shops.map((shop) => shop['id']).toList();
      final shopNamesMap = {
        for (var shop in shops) shop['id']: shop['shop_name']
      };

      var query = _supabase
          .from('mechanic_job_history')
          .select('''
            id,
            job_title,
            total_amount,
            mechanic_earnings,
            shop_earnings,
            platform_fee,
            completed_at,
            shop_id,
            mechanic:user_profiles!mechanic_job_history_mechanic_id_fkey(
              first_name,
              last_name
            ),
            customer:user_profiles!mechanic_job_history_customer_id_fkey(
              first_name,
              last_name
            ),
            service_requests!mechanic_job_history_service_request_id_fkey(
              pickup_address,
              service_type
            )
          ''')
          .inFilter('shop_id', shopIds)
          .eq('job_status', 'completed')
          .not('completed_at', 'is', null)
          .order('completed_at', ascending: false);

      if (limit != null && offset != null) {
        query = query.range(offset, offset + limit - 1);
      } else if (limit != null) {
        query = query.limit(limit);
      }

      final result = await query;

      return result.map<ShopEarningsHistoryItem>((job) {
        final totalAmount = job['total_amount']?.toDouble() ?? 0.0;
        final storedShopEarnings = job['shop_earnings']?.toDouble();
        final shopEarnings = storedShopEarnings ?? (totalAmount * 0.20);
        
        return ShopEarningsHistoryItem(
          id: job['id'],
          jobTitle: job['job_title'] ?? '',
          shopName: shopNamesMap[job['shop_id']] ?? '',
          mechanicName: '${job['user_profiles']?['first_name'] ?? ''} ${job['user_profiles']?['last_name'] ?? ''}',
          customerName: job['user_profiles'] != null 
              ? '${job['user_profiles']['first_name'] ?? ''} ${job['user_profiles']['last_name'] ?? ''}'
              : '',
          location: job['service_requests']?['pickup_address'] ?? '',
          serviceType: job['service_requests']?['service_type'] ?? '',
          totalAmount: totalAmount,
          shopEarnings: double.parse(shopEarnings.toStringAsFixed(2)),
          mechanicEarnings: job['mechanic_earnings']?.toDouble() ?? (totalAmount * 0.75),
          platformFee: job['platform_fee']?.toDouble() ?? (totalAmount * 0.05),
          completedAt: job['completed_at'] != null 
              ? DateTime.parse(job['completed_at']) 
              : DateTime.now(),
        );
      }).toList();
    } catch (e) {
      print('❌ Error getting shop earnings history: $e');
      return [];
    }
  }

  /// Format earnings for display
  String formatEarnings(double amount, {String currency = '₱'}) {
    return '$currency${amount.toStringAsFixed(2)}';
  }

  /// Get earnings breakdown text for display
  String getEarningsBreakdownText(double totalAmount) {
    final breakdown = calculateEarningsBreakdown(totalAmount);
    return 'You earned ${formatEarnings(breakdown.mechanicEarnings)} • '
           'Shop: ${formatEarnings(breakdown.shopEarnings)} • '
           'Fee: ${formatEarnings(breakdown.platformFee)}';
  }
}