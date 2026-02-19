import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'location_service.dart';

class ShopServicesService {
  static final ShopServicesService _instance = ShopServicesService._internal();
  static ShopServicesService get instance => _instance;
  ShopServicesService._internal();

  final _supabase = Supabase.instance.client;
  final _locationService = LocationService();

  // Cache for services to avoid repeated queries
  Map<String, List<Map<String, dynamic>>> _servicesCache = ;
  DateTime? _lastCacheUpdate;
  static const Duration _cacheExpiry = Duration(minutes: 5);

  /// Get all services offered by a specific shop with pricing and distance
  Future<List<Map<String, dynamic>>> getShopServicesWithDistance({
    required String shopId,
    LatLng? customerLocation,
    bool forceRefresh = false,
  }) async {
    try {
      print('🏪 Getting services for shop: $shopId');

      // Check cache first (unless force refresh)
      if (!forceRefresh && _servicesCache.containsKey(shopId) && _lastCacheUpdate != null) {
        final cacheAge = DateTime.now().difference(_lastCacheUpdate!);
        if (cacheAge < _cacheExpiry) {
          print('📦 Using cached services for shop $shopId');
          final cachedServices = _servicesCache[shopId]!;
          return await _addDistanceToServices(cachedServices, customerLocation);
        }
      }

      // Get shop information including location
      final shopData = await _supabase
          .from('shops')
          .select('''
            id,
            shop_name,
            shop_address,
            latitude,
            longitude,
            is_active,
            operating_hours,
            current_status,
            rating,
            total_reviews
          ''')
          .eq('id', shopId)
          .eq('is_active', true)
          .maybeSingle();

      if (shopData == null) {
        throw Exception('Shop not found or inactive');
      }

      // Get services from the new `shop_services` table
      final servicesData = await _supabase
          .from('shop_services')
          .select('''
            id,
            shop_id,
            service_name,
            description,
            base_price,
            custom_price,
            estimated_duration,
            is_active,
            is_default,
            category_id,
            service_categories (
              name,
              description
            )
          ''')
          .eq('shop_id', shopId)
          .eq('is_active', true);

      // Process and format services data
      List<Map<String, dynamic>> processedServices = [];
      
      for (final serviceData in servicesData) {
        final category = serviceData['service_categories'];
        
        // Use custom price if available, otherwise use base price
        final price = serviceData['custom_price']?.toDouble() ?? 
                     serviceData['base_price']?.toDouble() ?? 
                     0.0;

        processedServices.add({
          'service_id': serviceData['id'],
          'shop_id': serviceData['shop_id'],
          'category_id': serviceData['category_id'],
          'service_name': serviceData['service_name'] ?? category?['name'] ?? 'Unknown Service',
          'service_description': serviceData['description'] ?? category?['description'] ?? '',
          'price': price,
          'original_price': serviceData['base_price']?.toDouble(),
          'estimated_duration': serviceData['estimated_duration'] ?? 60,
          'is_default': serviceData['is_default'] ?? false,
          'shop_info': {
            'id': shopData['id'],
            'name': shopData['shop_name'],
            'address': shopData['shop_address'],
            'latitude': shopData['latitude'],
            'longitude': shopData['longitude'],
            'rating': shopData['rating']?.toDouble() ?? 0.0,
            'total_reviews': shopData['total_reviews'] ?? 0,
            'is_open': _isShopCurrentlyOpen(shopData),
            'current_status': shopData['current_status'] ?? 'unknown',
          },
          'created_at': serviceData['created_at'],
          'updated_at': serviceData['updated_at'],
        });
      }

      // Sort services by price (lowest to highest)
      processedServices.sort((a, b) => a['price'].compareTo(b['price']));

      // Cache the results
      _servicesCache[shopId] = processedServices;
      _lastCacheUpdate = DateTime.now();

      print('✅ Found ${processedServices.length} services for shop $shopId');

      // Add distance information if customer location is provided
      return await _addDistanceToServices(processedServices, customerLocation);

    } catch (e) {
      print('❌ Error getting shop services: $e');
      throw Exception('Failed to load shop services: $e');
    }
  }

  /// Add distance information to services
  Future<List<Map<String, dynamic>>> _addDistanceToServices(
    List<Map<String, dynamic>> services,
    LatLng? customerLocation,
  ) async {
    if (customerLocation == null || services.isEmpty) {
      return services;
    }

    List<Map<String, dynamic>> servicesWithDistance = [];

    for (final service in services) {
      final shopInfo = service['shop_info'] as Map<String, dynamic>;
      final shopLat = shopInfo['latitude']?.toDouble();
      final shopLng = shopInfo['longitude']?.toDouble();

      Map<String, dynamic> serviceWithDistance = Map.from(service);

      if (shopLat != null && shopLng != null) {
        // Calculate distance using location service
        final distance = _locationService.calculateDistance(
          customerLocation,
          LatLng(shopLat, shopLng),
        );

        serviceWithDistance['distance'] = {
          'kilometers': distance,
          'formatted': '${distance.toStringAsFixed(1)} km',
          'is_nearby': distance <= 5.0, // Within 5km is considered nearby
        };

        // Calculate estimated travel time (rough estimate: 2 minutes per km in city)
        final estimatedTravelTime = (distance * 2).round();
        serviceWithDistance['estimated_travel_time'] = {
          'minutes': estimatedTravelTime,
          'formatted': estimatedTravelTime < 60 
              ? '$estimatedTravelTime min'
              : '${(estimatedTravelTime / 60).toStringAsFixed(1)} hr',
        };
      } else {
        serviceWithDistance['distance'] = {
          'kilometers': null,
          'formatted': 'Unknown',
          'is_nearby': false,
        };
        serviceWithDistance['estimated_travel_time'] = {
          'minutes': null,
          'formatted': 'Unknown',
        };
      }

      servicesWithDistance.add(serviceWithDistance);
    }

    // Re-sort by distance if available, then by price
    servicesWithDistance.sort((a, b) {
      final aDistance = a['distance']['kilometers'];
      final bDistance = b['distance']['kilometers'];
      
      if (aDistance != null && bDistance != null) {
        final distanceComparison = aDistance.compareTo(bDistance);
        if (distanceComparison != 0) return distanceComparison;
      }
      
      // If distances are equal or unavailable, sort by price
      return a['price'].compareTo(b['price']);
    });

    return servicesWithDistance;
  }

  /// Get services from multiple shops (for comparison)
  Future<List<Map<String, dynamic>>> getServicesFromMultipleShops({
    required List<String> shopIds,
    LatLng? customerLocation,
    String? serviceFilter, // Filter by service name
    double? maxDistance, // Maximum distance in km
    double? maxPrice, // Maximum price filter
  }) async {
    try {
      print('🏪 Getting services from ${shopIds.length} shops');

      List<Map<String, dynamic>> allServices = [];

      // Get services from each shop
      for (final shopId in shopIds) {
        try {
          final shopServices = await getShopServicesWithDistance(
            shopId: shopId,
            customerLocation: customerLocation,
          );
          allServices.addAll(shopServices);
        } catch (e) {
          print('⚠️ Error getting services from shop $shopId: $e');
          // Continue with other shops
        }
      }

      // Apply filters
      List<Map<String, dynamic>> filteredServices = allServices;

      // Filter by service name
      if (serviceFilter != null && serviceFilter.isNotEmpty) {
        filteredServices = filteredServices.where((service) {
          final serviceName = service['service_name'].toString().toLowerCase();
          return serviceName.contains(serviceFilter.toLowerCase());
        }).toList();
      }

      // Filter by distance
      if (maxDistance != null && customerLocation != null) {
        filteredServices = filteredServices.where((service) {
          final distance = service['distance']?['kilometers'];
          return distance != null && distance <= maxDistance;
        }).toList();
      }

      // Filter by price
      if (maxPrice != null) {
        filteredServices = filteredServices.where((service) {
          return service['price'] <= maxPrice;
        }).toList();
      }

      // Sort by distance first, then by price
      filteredServices.sort((a, b) {
        final aDistance = a['distance']?['kilometers'];
        final bDistance = b['distance']?['kilometers'];
        
        if (aDistance != null && bDistance != null) {
          final distanceComparison = aDistance.compareTo(bDistance);
          if (distanceComparison != 0) return distanceComparison;
        }
        
        return a['price'].compareTo(b['price']);
      });

      print('✅ Found ${filteredServices.length} filtered services from ${shopIds.length} shops');
      return filteredServices;

    } catch (e) {
      print('❌ Error getting services from multiple shops: $e');
      throw Exception('Failed to load services: $e');
    }
  }

  /// Get nearby shops with their services
  Future<List<Map<String, dynamic>>> getNearbyShopsWithServices({
    required LatLng customerLocation,
    double radiusKm = 15.0,
    String? serviceFilter,
    int limit = 20,
  }) async {
    try {
      print('🔍 Finding nearby shops with services within ${radiusKm}km');

      // Get nearby shops owned by 'talyer_owner'
      final shopsData = await _supabase
          .from('shops')
          .select('''
            id,
            shop_name,
            shop_address,
            latitude,
            longitude,
            rating,
            total_reviews,
            is_active,
            current_status,
            operating_hours,
            owner:user_profiles!inner(user_type)
          ''')
          .eq('is_active', true)
          .eq('owner.user_type', 'talyer_owner')
          .not('latitude', 'is', null)
          .not('longitude', 'is', null)
          .limit(100); // Get more shops to filter by distance

      List<Map<String, dynamic>> nearbyShops = [];

      for (final shop in shopsData) {
        final shopLat = shop['latitude']?.toDouble();
        final shopLng = shop['longitude']?.toDouble();

        if (shopLat != null && shopLng != null) {
          final distance = _locationService.calculateDistance(
            customerLocation,
            LatLng(shopLat, shopLng),
          );

          if (distance <= radiusKm) {
            // Get services for this shop
            final services = await getShopServicesWithDistance(
              shopId: shop['id'],
              customerLocation: customerLocation,
            );

            // Filter services if needed
            List<Map<String, dynamic>> filteredServices = services;
            if (serviceFilter != null && serviceFilter.isNotEmpty) {
              filteredServices = services.where((service) {
                final serviceName = service['service_name'].toString().toLowerCase();
                return serviceName.contains(serviceFilter.toLowerCase());
              }).toList();
            }

            if (filteredServices.isNotEmpty) {
              nearbyShops.add({
                'shop_info': shop,
                'distance': distance,
                'services': filteredServices,
                'service_count': filteredServices.length,
                'min_price': filteredServices.map((s) => s['price'] as double).reduce((a, b) => a < b ? a : b),
                'max_price': filteredServices.map((s) => s['price'] as double).reduce((a, b) => a > b ? a : b),
                'is_open': _isShopCurrentlyOpen(shop),
              });
            }
          }
        }
      }

      // Sort by distance
      nearbyShops.sort((a, b) => a['distance'].compareTo(b['distance']));

      // Limit results
      if (nearbyShops.length > limit) {
        nearbyShops = nearbyShops.take(limit).toList();
      }

      print('✅ Found ${nearbyShops.length} nearby shops with services');
      return nearbyShops;

    } catch (e) {
      print('❌ Error getting nearby shops with services: $e');
      throw Exception('Failed to load nearby shops: $e');
    }
  }

  /// Check if shop is currently open based on operating hours
  bool _isShopCurrentlyOpen(Map<String, dynamic> shopData) {
    try {
      final operatingHours = shopData['operating_hours'];
      final currentStatus = shopData['current_status'];

      // If status is explicitly set, use it
      if (currentStatus == 'open') return true;
      if (currentStatus == 'closed' || currentStatus == 'maintenance') return false;

      // Check operating hours if available
      if (operatingHours != null && operatingHours is Map) {
        final now = DateTime.now();
        final currentDay = _getDayKey(now.weekday);
        final currentTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

        final dayHours = operatingHours[currentDay];
        if (dayHours != null && dayHours is Map) {
          final isOpen = dayHours['isOpen'] == true;
          final openTime = dayHours['openTime'] ?? '09:00';
          final closeTime = dayHours['closeTime'] ?? '17:00';

          if (!isOpen) return false;

          return currentTime.compareTo(openTime) >= 0 && 
                 currentTime.compareTo(closeTime) < 0;
        }
      }

      return false; // Default to closed if no information
    } catch (e) {
      print('Error checking shop hours: $e');
      return false;
    }
  }

  /// Convert weekday number to day key
  String _getDayKey(int weekday) {
    switch (weekday) {
      case 1: return 'monday';
      case 2: return 'tuesday';
      case 3: return 'wednesday';
      case 4: return 'thursday';
      case 5: return 'friday';
      case 6: return 'saturday';
      case 7: return 'sunday';
      default: return 'monday';
    }
  }

  /// Clear cache (call when user location changes significantly)
  void clearCache() {
    _servicesCache.clear();
    _lastCacheUpdate = null;
    print('🗑️ Shop services cache cleared');
  }

  /// Get service categories for filtering
  Future<List<Map<String, dynamic>>> getServiceCategories() async {
    try {
      final categories = await _supabase
          .from('service_categories')
          .select('*')
          .eq('is_active', true)
          .order('name');

      return List<Map<String, dynamic>>.from(categories);
    } catch (e) {
      print('❌ Error getting service categories: $e');
      return [];
    }
  }

  /// Get customer's current location
  Future<LatLng?> getCurrentLocation() async {
    return await _locationService.getCurrentLocation();
  }

  /// Start real-time location tracking for distance updates
  Stream<LatLng> startLocationTracking() {
    return _locationService.startLocationTracking();
  }
}










