import 'package:supabase_flutter/supabase_flutter.dart';

/// High-Performance Shop-Based Mechanic Management Service
/// Implements ultra-fast mechanic isolation with caching and optimization
class ShopMechanicService {
  static final ShopMechanicService _instance = ShopMechanicService._internal();
  static ShopMechanicService get instance => _instance;
  ShopMechanicService._internal();

  final _supabase = Supabase.instance.client;
  
  // Local cache with TTL
  final Map<String, dynamic> _localCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _cacheTimeout = Duration(minutes: 2);

  /// Clear all caches
  void clearCache() {
    _localCache.clear();
    _cacheTimestamps.clear();
  }

  /// Check if cache entry is valid
  bool _isCacheValid(String key) {
    final timestamp = _cacheTimestamps[key];
    if (timestamp == null) return false;
    return DateTime.now().difference(timestamp) < _cacheTimeout;
  }

  /// Get mechanics for current shop (ultra-fast with caching)
  Future<List<Map<String, dynamic>>> getShopMechanics() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('No authenticated user');
      }

      final cacheKey = 'shop_mechanics_${user.id}';
      
      // Return cached data if valid
      if (_isCacheValid(cacheKey) && _localCache.containsKey(cacheKey)) {
        print('🚀 Returning cached shop mechanics');
        return List<Map<String, dynamic>>.from(_localCache[cacheKey]);
      }

      print('🔍 Fetching shop mechanics from optimized database...');

      // Use ultra-fast database function
      final result = await _supabase.rpc('get_shop_mechanics_fast', 
        params: {'owner_id': user.id}
      );

      List<Map<String, dynamic>> mechanics = [];
      
      if (result != null) {
        for (var row in result) {
          final mechanicData = row['mechanic_data'];
          if (mechanicData != null) {
            mechanics.add(Map<String, dynamic>.from(mechanicData));
          }
        }
      }

      // Cache the result
      _localCache[cacheKey] = mechanics;
      _cacheTimestamps[cacheKey] = DateTime.now();

      print('✅ Loaded ${mechanics.length} mechanics for shop');
      return mechanics;

    } catch (e) {
      print('❌ Error fetching shop mechanics: $e');
      // Return cached data as fallback if available
      final cacheKey = 'shop_mechanics_${_supabase.auth.currentUser?.id}';
      if (_localCache.containsKey(cacheKey)) {
        print('📦 Returning stale cache as fallback');
        return List<Map<String, dynamic>>.from(_localCache[cacheKey]);
      }
      return [];
    }
  }

  /// Get mechanic count (ultra-fast)
  Future<Map<String, int>> getMechanicCount() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return {'total': 0, 'available': 0};

      final cacheKey = 'mechanic_count_${user.id}';
      
      // Return cached count if valid
      if (_isCacheValid(cacheKey) && _localCache.containsKey(cacheKey)) {
        return Map<String, int>.from(_localCache[cacheKey]);
      }

      // Use optimized count function
      final result = await _supabase.rpc('get_shop_mechanic_count',
        params: {'owner_id': user.id}
      );

      Map<String, int> count = {'total': 0, 'available': 0};

      if (result != null) {
        try {
          // result may be a List of rows, a single Map, or a primitive
          if (result is List && result.isNotEmpty) {
            final row = result.first;
            count = {
              'total': (row['total'] ?? 0) as int,
              'available': (row['available'] ?? 0) as int,
            };
          } else if (result is Map) {
            count = {
              'total': (result['total'] ?? 0) as int,
              'available': (result['available'] ?? 0) as int,
            };
          } else if (result is int) {
            count = {'total': result, 'available': 0};
          }
        } catch (_) {
          // keep defaults on parse error
        }
      }

      // Cache the result
      _localCache[cacheKey] = count;
      _cacheTimestamps[cacheKey] = DateTime.now();

      return count;

    } catch (e) {
      print('❌ Error getting mechanic count: $e');
      return {'total': 0, 'available': 0};
    }
  }

  /// Get available mechanics only (filtered)
  Future<List<Map<String, dynamic>>> getAvailableMechanics() async {
    final allMechanics = await getShopMechanics();
    return allMechanics.where((mechanic) => 
      mechanic['is_available'] == true && 
      mechanic['status'] == 'active'
    ).toList();
  }

  /// Assign mechanic to job with shop validation
  Future<bool> assignMechanicToJob(String mechanicId, String jobId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('No authenticated user');

      // First verify mechanic belongs to current shop
      final shopMechanics = await getShopMechanics();
      final mechanic = shopMechanics.firstWhere(
        (m) => m['id'] == mechanicId,
        orElse: () => throw Exception('Mechanic not found in your shop')
      );

      // Update service request
      await _supabase
          .from('service_requests')
          .update({
            'assigned_mechanic_id': mechanic['service_provider']['id'],
            'status': 'assigned',
            'assigned_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', jobId);

      // Update mechanic availability
      await _supabase
          .from('user_profiles')
          .update({'is_available': false})
          .eq('id', mechanicId);

      // Clear cache to force refresh
      clearCache();
      
      print('✅ Successfully assigned mechanic $mechanicId to job $jobId');
      return true;

    } catch (e) {
      print('❌ Error assigning mechanic: $e');
      return false;
    }
  }

  /// Add new mechanic to shop
  Future<bool> addMechanicToShop({
    required String firstName,
    required String lastName,
    required String email,
    required String phoneNumber,
    required String password,
    int yearsExperience = 1,
    double serviceRadius = 50.0,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('No authenticated user');

      // Get shop ID
      final shopResult = await _supabase
          .from('shops')
          .select('id')
          .eq('owner_id', user.id)
          .eq('is_active', true)
          .single();

      final shopId = shopResult['id'];

      // Create auth user for mechanic
      final authResponse = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'first_name': firstName,
          'last_name': lastName,
          'phone_number': phoneNumber,
          'user_type': 'mechanic',
        }
      );

      if (authResponse.user == null) {
        throw Exception('Failed to create mechanic account');
      }

      final mechanicId = authResponse.user!.id;

      // Use the safe assignment function to avoid trigger issues
      final result = await _supabase.rpc('safely_assign_mechanic_to_shop', 
        params: {
          'p_mechanic_id': mechanicId,
          'p_shop_id': shopId,
          'p_assigner_id': user.id,
        }
      );

      if (result['success'] != true) {
        throw Exception(result['error'] ?? 'Failed to assign mechanic to shop');
      }

      // Create user profile with shop assignment
      await _supabase.from('user_profiles').insert({
        'id': mechanicId,
        'first_name': firstName,
        'last_name': lastName,
        'email': email,
        'phone_number': phoneNumber,
        'user_type': 'mechanic',
        'shop_id': shopId,
        'status': 'active',
        'is_available': true,
      });

      // Clear cache to force refresh
      clearCache();

      print('✅ Successfully added mechanic $firstName $lastName to shop');
      return true;

    } catch (e) {
      print('❌ Error adding mechanic to shop: $e');
      return false;
    }
  }

  /// Remove mechanic from shop
  Future<bool> removeMechanicFromShop(String mechanicId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('No authenticated user');

      // Verify mechanic belongs to current shop
      final shopMechanics = await getShopMechanics();
      final mechanic = shopMechanics.firstWhere(
        (m) => m['id'] == mechanicId,
        orElse: () => throw Exception('Mechanic not found in your shop')
      );

      // Check if mechanic has active jobs
      final activeJobs = await _supabase
          .from('service_requests')
          .select('id')
          .eq('assigned_mechanic_id', mechanic['service_provider']['id'])
          .filter('status', 'in', '(assigned,in_progress)');

      if (activeJobs.isNotEmpty) {
        throw Exception('Cannot remove mechanic with active jobs');
      }

      // Remove from shop (set shop_id to null)
      await _supabase
          .from('user_profiles')
          .update({
            'shop_id': null,
            'status': 'inactive',
            'is_available': false,
          })
          .eq('id', mechanicId);

      // Update service provider
      await _supabase
          .from('service_providers')
          .update({
            'shop_id': null,
            'is_available': false,
            'status': 'inactive',
          })
          .eq('user_id', mechanicId);

      // Clear cache
      clearCache();

      print('✅ Successfully removed mechanic from shop');
      return true;

    } catch (e) {
      print('❌ Error removing mechanic from shop: $e');
      return false;
    }
  }

  /// Get shop statistics (fast cached)
  Future<Map<String, dynamic>> getShopStatistics() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return {};

      final cacheKey = 'shop_stats_${user.id}';
      
      // Return cached stats if valid
      if (_isCacheValid(cacheKey) && _localCache.containsKey(cacheKey)) {
        return Map<String, dynamic>.from(_localCache[cacheKey]);
      }

      // Get shop stats from cache table
      final shopResult = await _supabase
          .from('shops')
          .select('id')
          .eq('owner_id', user.id)
          .eq('is_active', true)
          .single();

      final statsResult = await _supabase
          .from('shop_stats_cache')
          .select('*')
          .eq('shop_id', shopResult['id'])
          .maybeSingle();

      Map<String, dynamic> stats = {
        'total_mechanics': 0,
        'available_mechanics': 0,
        'active_jobs': 0,
        'completed_jobs': 0,
        'total_revenue': 0.0,
        'average_rating': 0.0,
      };

      if (statsResult != null) {
        stats = Map<String, dynamic>.from(statsResult);
      }

      // Cache the result
      _localCache[cacheKey] = stats;
      _cacheTimestamps[cacheKey] = DateTime.now();

      return stats;

    } catch (e) {
      print('❌ Error getting shop statistics: $e');
      return {
        'total_mechanics': 0,
        'available_mechanics': 0,
        'active_jobs': 0,
        'completed_jobs': 0,
        'total_revenue': 0.0,
        'average_rating': 0.0,
      };
    }
  }

  /// Refresh all caches (call when needed)
  Future<void> refreshAllCaches() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      // Clear local cache
      clearCache();

      // Refresh database caches
      await _supabase.rpc('refresh_shop_mechanics_cache');
      
      print('✅ All caches refreshed');
    } catch (e) {
      print('❌ Error refreshing caches: $e');
    }
  }

  /// Monitor cache performance
  Future<Map<String, dynamic>> getCachePerformance() async {
    try {
      final result = await _supabase
          .from('cache_performance_stats')
          .select('*');

      return {
        'database_cache': result,
        'local_cache_entries': _localCache.length,
        'local_cache_keys': _localCache.keys.toList(),
      };
    } catch (e) {
      print('❌ Error getting cache performance: $e');
      return {};
    }
  }
}










