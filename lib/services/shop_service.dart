import 'dart:math' as math;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';

class ShopService {
  static final ShopService _instance = ShopService._internal();
  static ShopService get instance => _instance;
  ShopService._internal();

  final _supabase = Supabase.instance.client;

  /// Get nearby shops with availability and distance calculation
  Future<List<Map<String, dynamic>>> getNearbyShops({
    required double latitude,
    required double longitude,
    double radiusKm = 25.0,
  }) async {
    try {
      print('🏪 Getting nearby shops within ${radiusKm}km of ($latitude, $longitude)');

      // Query shops with location, status, and mechanic count
      final results = await _supabase
          .rpc('get_nearby_shops_with_mechanics', params: {
            'user_lat': latitude,
            'user_lng': longitude,
            'radius_km': radiusKm,
          });

      print('✅ Found ${results.length} shops');
      return List<Map<String, dynamic>>.from(results);
    } catch (e) {
      print('❌ Error getting nearby shops: $e');
      
      // Fallback: Get all shops and calculate distance manually
      return await _getFallbackShops(latitude, longitude, radiusKm);
    }
  }

  /// Fallback method to get shops if RPC function doesn't exist
  Future<List<Map<String, dynamic>>> _getFallbackShops(
    double latitude,
    double longitude,
    double radiusKm,
  ) async {
    try {
      // Get all active shops with basic info
      final shops = await _supabase
          .from('shops')
          .select('''
            id,
            shop_name,
            shop_address,
            shop_phone,
            latitude,
            longitude,
            current_status,
            rating,
            total_reviews
          ''')
          .eq('is_active', true)
          .not('latitude', 'is', null)
          .not('longitude', 'is', null);

      // Calculate distances and filter
      final nearbyShops = <Map<String, dynamic>>[];
      
      for (final shop in shops) {
        final shopLat = shop['latitude'] as double?;
        final shopLng = shop['longitude'] as double?;
        
        if (shopLat != null && shopLng != null) {
          final distance = _calculateDistance(
            latitude, longitude,
            shopLat, shopLng,
          );
          
          if (distance <= radiusKm) {
            // Get mechanic counts for this shop
            final mechanicCounts = await _getMechanicCounts(shop['id']);
            
            shop['distance_km'] = distance;
            shop['total_mechanics'] = mechanicCounts['total'];
            shop['available_mechanics'] = mechanicCounts['available'];
            
            nearbyShops.add(shop);
          }
        }
      }

      // Sort by distance
      nearbyShops.sort((a, b) => 
        (a['distance_km'] as double).compareTo(b['distance_km'] as double));

      return nearbyShops;
    } catch (e) {
      print('❌ Error in fallback shop query: $e');
      return [];
    }
  }

  /// Get mechanic counts for a shop
  Future<Map<String, int>> _getMechanicCounts(String shopId) async {
    try {
      // Get total mechanics for this shop
      final totalMechanics = await _supabase
          .from('shop_mechanics')
          .select('id')
          .eq('shop_id', shopId)
          .eq('is_active', true);

      // Get available mechanics (online and not in active jobs)
      final availableMechanics = await _supabase
          .from('shop_mechanics')
          .select('''
            id,
            mechanic_id,
            user_profiles!inner(id, user_type),
            mechanic_availability_status!inner(current_status)
          ''')
          .eq('shop_id', shopId)
          .eq('is_active', true)
          .eq('is_available', true)
          .eq('mechanic_availability_status.current_status', 'available');

      return {
        'total': totalMechanics.length,
        'available': availableMechanics.length,
      };
    } catch (e) {
      print('⚠️ Error getting mechanic counts: $e');
      return {'total': 0, 'available': 0};
    }
  }

  /// Calculate distance between two points using Haversine formula
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // Earth's radius in kilometers
    
    final double dLat = _toRadians(lat2 - lat1);
    final double dLon = _toRadians(lon2 - lon1);
    
    final double a = 
        (math.sin(dLat / 2) * math.sin(dLat / 2)) +
        (math.cos(_toRadians(lat1)) * math.cos(_toRadians(lat2)) *
         math.sin(dLon / 2) * math.sin(dLon / 2));
    
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    
    return earthRadius * c;
  }

  /// Convert degrees to radians
  double _toRadians(double degrees) {
    return degrees * (math.pi / 180);
  }

  /// Get shop details by ID
  Future<Map<String, dynamic>?> getShopDetails(String shopId) async {
    try {
      final shop = await _supabase
          .from('shops')
          .select('''
            *,
            user_profiles!shops_owner_id_fkey(
              first_name,
              last_name,
              email,
              phone_number
            )
          ''')
          .eq('id', shopId)
          .single();

      return shop;
    } catch (e) {
      print('❌ Error getting shop details: $e');
      return null;
    }
  }

  /// Get shops owned by current user
  Future<List<Map<String, dynamic>>> getUserShops() async {
    try {
      final userId = AuthService.instance.userId;
      if (userId == null) return [];

      final shops = await _supabase
          .from('shops')
          .select('''
            *,
            shop_stats_cache(*)
          ''')
          .eq('owner_id', userId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(shops);
    } catch (e) {
      print('❌ Error getting user shops: $e');
      return [];
    }
  }

  /// Create new shop
  Future<String?> createShop({
    required String shopName,
    required String shopAddress,
    required String shopPhone,
    String? shopEmail,
    String? shopDescription,
    required double latitude,
    required double longitude,
  }) async {
    try {
      final userId = AuthService.instance.userId;
      if (userId == null) throw Exception('User not authenticated');

      final shopData = {
        'owner_id': userId,
        'shop_name': shopName,
        'shop_address': shopAddress,
        'shop_phone': shopPhone,
        'shop_email': shopEmail,
        'shop_description': shopDescription,
        'latitude': latitude,
        'longitude': longitude,
        'is_active': true,
        'current_status': 'closed',
        'created_at': DateTime.now().toIso8601String(),
      };

      final result = await _supabase
          .from('shops')
          .insert(shopData)
          .select('id')
          .single();

      print('✅ Shop created successfully: ${result['id']}');
      return result['id'];
    } catch (e) {
      print('❌ Error creating shop: $e');
      return null;
    }
  }

  /// Update shop status (open/closed/busy/maintenance)
  Future<bool> updateShopStatus(String shopId, String status) async {
    try {
      await _supabase
          .from('shops')
          .update({
            'current_status': status,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', shopId);

      print('✅ Shop status updated to: $status');
      return true;
    } catch (e) {
      print('❌ Error updating shop status: $e');
      return false;
    }
  }

  /// Get shop services and availability
  Future<List<Map<String, dynamic>>> getShopServices(String shopId) async {
    try {
      final services = await _supabase
          .from('shop_services')
          .select('''
            *,
            service_categories(name, icon_name, description),
            service_availability_matrix(*)
          ''')
          .eq('shop_id', shopId)
          .eq('is_active', true)
          .order('display_priority', ascending: true);

      return List<Map<String, dynamic>>.from(services);
    } catch (e) {
      print('❌ Error getting shop services: $e');
      return [];
    }
  }
}