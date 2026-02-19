import 'package:supabase_flutter/supabase_flutter.dart';

class MarketplaceService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Find nearby shops with their services and pricing
  Future<List<ShopWithServices>> findNearbyShops({
    required double customerLat,
    required double customerLng,
    double maxDistanceKm = 50.0,
    String? serviceCategoryId,
  }) async {
    try {
      final response = await _supabase.rpc('find_nearby_shops', params: {
        'p_customer_lat': customerLat,
        'p_customer_lng': customerLng,
        'p_max_distance_km': maxDistanceKm,
        'p_service_category_id': serviceCategoryId,
      });

      if (response == null) {
        return [];
      }

      final List<dynamic> shops = response as List<dynamic>;
      return shops
          .map((shop) => ShopWithServices.fromJson(shop))
          .toList();
    } catch (e) {
      print('Error finding nearby shops: $e');
      throw Exception('Failed to find nearby shops: $e');
    }
  }

  /// Create a service request from customer
  Future<ServiceRequestResult> createServiceRequest({
    required String customerId,
    required String shopId,
    required String serviceId,
    required String vehicleId,
    required double pickupLatitude,
    required double pickupLongitude,
    required String pickupAddress,
    String? description,
    bool isEmergency = false,
    DateTime? preferredTime,
  }) async {
    try {
      final response = await _supabase.rpc('create_customer_service_request', params: {
        'p_customer_id': customerId,
        'p_shop_id': shopId,
        'p_service_id': serviceId,
        'p_vehicle_id': vehicleId,
        'p_pickup_latitude': pickupLatitude,
        'p_pickup_longitude': pickupLongitude,
        'p_pickup_address': pickupAddress,
        'p_description': description,
        'p_is_emergency': isEmergency,
        'p_preferred_time': preferredTime?.toIso8601String(),
      });

      if (response == null) {
        throw Exception('No response from server');
      }

      return ServiceRequestResult.fromJson(response);
    } catch (e) {
      print('Error creating service request: $e');
      throw Exception('Failed to create service request: $e');
    }
  }

  /// Get pending requests for shop owner
  Future<List<PendingServiceRequest>> getShopPendingRequests(String shopOwnerId) async {
    try {
      final response = await _supabase.rpc('get_shop_pending_requests', params: {
        'p_shop_owner_id': shopOwnerId,
      });

      if (response == null) {
        return [];
      }

      final List<dynamic> requests = response as List<dynamic>;
      return requests
          .map((request) => PendingServiceRequest.fromJson(request))
          .toList();
    } catch (e) {
      print('Error getting pending requests: $e');
      throw Exception('Failed to get pending requests: $e');
    }
  }

  /// Respond to service request (accept/reject)
  Future<RequestResponseResult> respondToServiceRequest({
    required String requestId,
    required String shopOwnerId,
    required String action, // 'accept' or 'reject'
    String? notes,
    DateTime? estimatedArrivalTime,
  }) async {
    try {
      final response = await _supabase.rpc('respond_to_service_request', params: {
        'p_request_id': requestId,
        'p_shop_owner_id': shopOwnerId,
        'p_action': action,
        'p_notes': notes,
        'p_estimated_arrival_time': estimatedArrivalTime?.toIso8601String(),
      });

      if (response == null) {
        throw Exception('No response from server');
      }

      return RequestResponseResult.fromJson(response);
    } catch (e) {
      print('Error responding to service request: $e');
      throw Exception('Failed to respond to service request: $e');
    }
  }

  /// Get service categories
  Future<List<ServiceCategory>> getServiceCategories() async {
    try {
      final response = await _supabase
          .from('service_categories')
          .select('*')
          .eq('is_active', true)
          .order('display_order');

      return (response as List)
          .map((category) => ServiceCategory.fromJson(category))
          .toList();
    } catch (e) {
      print('Error getting service categories: $e');
      throw Exception('Failed to get service categories: $e');
    }
  }

  /// Get customer's vehicles
  Future<List<Vehicle>> getCustomerVehicles(String customerId) async {
    try {
      final response = await _supabase
          .from('vehicles')
          .select('*')
          .eq('user_id', customerId)
          .order('is_primary', ascending: false);

      return (response as List)
          .map((vehicle) => Vehicle.fromJson(vehicle))
          .toList();
    } catch (e) {
      print('Error getting customer vehicles: $e');
      throw Exception('Failed to get customer vehicles: $e');
    }
  }

  /// Get customer's service request history
  Future<List<ServiceRequestHistory>> getCustomerRequestHistory(String customerId) async {
    try {
      final response = await _supabase
          .from('service_requests')
          .select('''
            *,
            shops:shop_id(shop_name, shop_address, contact_phone),
            service_categories:category_id(name),
            vehicles:vehicle_id(brand_name, model_name, year)
          ''')
          .eq('customer_id', customerId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((request) => ServiceRequestHistory.fromJson(request))
          .toList();
    } catch (e) {
      print('Error getting request history: $e');
      throw Exception('Failed to get request history: $e');
    }
  }
}

// Data Models

class ShopWithServices {
  final String shopId;
  final String shopName;
  final String? shopAddress;
  final double? shopLatitude;
  final double? shopLongitude;
  final String? contactPhone;
  final String? contactEmail;
  final Map<String, dynamic>? businessHours;
  final String? shopDescription;
  final String? shopImageUrl;
  final double averageRating;
  final int totalReviews;
  final double distanceKm;
  final double minServiceFee;
  final bool emergencyAvailable;
  final bool nightServiceAvailable;
  final List<ShopService> availableServices;
  final bool isCurrentlyOpen;

  ShopWithServices({
    required this.shopId,
    required this.shopName,
    this.shopAddress,
    this.shopLatitude,
    this.shopLongitude,
    this.contactPhone,
    this.contactEmail,
    this.businessHours,
    this.shopDescription,
    this.shopImageUrl,
    required this.averageRating,
    required this.totalReviews,
    required this.distanceKm,
    required this.minServiceFee,
    required this.emergencyAvailable,
    required this.nightServiceAvailable,
    required this.availableServices,
    required this.isCurrentlyOpen,
  });

  factory ShopWithServices.fromJson(Map<String, dynamic> json) {
    return ShopWithServices(
      shopId: json['shop_id'],
      shopName: json['shop_name'],
      shopAddress: json['shop_address'],
      shopLatitude: json['shop_latitude']?.toDouble(),
      shopLongitude: json['shop_longitude']?.toDouble(),
      contactPhone: json['contact_phone'],
      contactEmail: json['contact_email'],
      businessHours: json['business_hours'],
      shopDescription: json['shop_description'],
      shopImageUrl: json['shop_image_url'],
      averageRating: (json['average_rating'] ?? 0.0).toDouble(),
      totalReviews: json['total_reviews'] ?? 0,
      distanceKm: (json['distance_km'] ?? 0.0).toDouble(),
      minServiceFee: (json['min_service_fee'] ?? 0.0).toDouble(),
      emergencyAvailable: json['emergency_available'] ?? false,
      nightServiceAvailable: json['night_service_available'] ?? false,
      availableServices: (json['available_services'] as List?)
              ?.map((service) => ShopService.fromJson(service))
              .toList() ??
          [],
      isCurrentlyOpen: json['is_currently_open'] ?? false,
    );
  }
}

class ShopService {
  final String serviceId;
  final String serviceName;
  final String? description;
  final double price;
  final int? estimatedDuration;
  final String availabilityStatus;
  final String serviceQualityLevel;
  final bool isFeatured;
  final String? categoryName;
  final String? categoryId;

  ShopService({
    required this.serviceId,
    required this.serviceName,
    this.description,
    required this.price,
    this.estimatedDuration,
    required this.availabilityStatus,
    required this.serviceQualityLevel,
    required this.isFeatured,
    this.categoryName,
    this.categoryId,
  });

  factory ShopService.fromJson(Map<String, dynamic> json) {
    return ShopService(
      serviceId: json['service_id'],
      serviceName: json['service_name'],
      description: json['description'],
      price: (json['price'] ?? 0.0).toDouble(),
      estimatedDuration: json['estimated_duration'],
      availabilityStatus: json['availability_status'] ?? 'available',
      serviceQualityLevel: json['service_quality_level'] ?? 'standard',
      isFeatured: json['is_featured'] ?? false,
      categoryName: json['category_name'],
      categoryId: json['category_id'],
    );
  }
}

class ServiceRequestResult {
  final bool success;
  final String? requestId;
  final String? shopName;
  final String? serviceName;
  final double? estimatedPrice;
  final double? serviceFee;
  final double? distanceKm;
  final String status;
  final String message;
  final String? error;

  ServiceRequestResult({
    required this.success,
    this.requestId,
    this.shopName,
    this.serviceName,
    this.estimatedPrice,
    this.serviceFee,
    this.distanceKm,
    required this.status,
    required this.message,
    this.error,
  });

  factory ServiceRequestResult.fromJson(Map<String, dynamic> json) {
    return ServiceRequestResult(
      success: json['success'] ?? false,
      requestId: json['request_id'],
      shopName: json['shop_name'],
      serviceName: json['service_name'],
      estimatedPrice: json['estimated_price']?.toDouble(),
      serviceFee: json['service_fee']?.toDouble(),
      distanceKm: json['distance_km']?.toDouble(),
      status: json['status'] ?? 'pending',
      message: json['message'] ?? '',
      error: json['error'],
    );
  }
}

class PendingServiceRequest {
  final String requestId;
  final String customerName;
  final String? customerPhone;
  final String serviceName;
  final String? description;
  final String pickupAddress;
  final double pickupLatitude;
  final double pickupLongitude;
  final double estimatedPrice;
  final double serviceFee;
  final double distanceKm;
  final bool isEmergency;
  final DateTime createdAt;
  final VehicleInfo vehicleInfo;
  final Map<String, dynamic>? pricingBreakdown;

  PendingServiceRequest({
    required this.requestId,
    required this.customerName,
    this.customerPhone,
    required this.serviceName,
    this.description,
    required this.pickupAddress,
    required this.pickupLatitude,
    required this.pickupLongitude,
    required this.estimatedPrice,
    required this.serviceFee,
    required this.distanceKm,
    required this.isEmergency,
    required this.createdAt,
    required this.vehicleInfo,
    this.pricingBreakdown,
  });

  factory PendingServiceRequest.fromJson(Map<String, dynamic> json) {
    return PendingServiceRequest(
      requestId: json['request_id'],
      customerName: json['customer_name'],
      customerPhone: json['customer_phone'],
      serviceName: json['service_name'],
      description: json['description'],
      pickupAddress: json['pickup_address'],
      pickupLatitude: json['pickup_latitude'].toDouble(),
      pickupLongitude: json['pickup_longitude'].toDouble(),
      estimatedPrice: json['estimated_price'].toDouble(),
      serviceFee: json['service_fee'].toDouble(),
      distanceKm: json['distance_km'].toDouble(),
      isEmergency: json['is_emergency'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
      vehicleInfo: VehicleInfo.fromJson(json['vehicle_info']),
      pricingBreakdown: json['pricing_breakdown'],
    );
  }
}

class VehicleInfo {
  final String? brand;
  final String? model;
  final int? year;
  final String? color;
  final String? plateNumber;

  VehicleInfo({
    this.brand,
    this.model,
    this.year,
    this.color,
    this.plateNumber,
  });

  factory VehicleInfo.fromJson(Map<String, dynamic> json) {
    return VehicleInfo(
      brand: json['brand'],
      model: json['model'],
      year: json['year'],
      color: json['color'],
      plateNumber: json['plate_number'],
    );
  }
}

class RequestResponseResult {
  final bool success;
  final String action;
  final String requestId;
  final String customerName;
  final String message;
  final String? error;

  RequestResponseResult({
    required this.success,
    required this.action,
    required this.requestId,
    required this.customerName,
    required this.message,
    this.error,
  });

  factory RequestResponseResult.fromJson(Map<String, dynamic> json) {
    return RequestResponseResult(
      success: json['success'] ?? false,
      action: json['action'] ?? '',
      requestId: json['request_id'] ?? '',
      customerName: json['customer_name'] ?? '',
      message: json['message'] ?? '',
      error: json['error'],
    );
  }
}

class ServiceCategory {
  final String id;
  final String name;
  final String? description;
  final String? iconName;
  final double? basePrice;
  final int? estimatedDuration;
  final bool isActive;

  ServiceCategory({
    required this.id,
    required this.name,
    this.description,
    this.iconName,
    this.basePrice,
    this.estimatedDuration,
    required this.isActive,
  });

  factory ServiceCategory.fromJson(Map<String, dynamic> json) {
    return ServiceCategory(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      iconName: json['icon_name'],
      basePrice: json['base_price']?.toDouble(),
      estimatedDuration: json['estimated_duration'],
      isActive: json['is_active'] ?? true,
    );
  }
}

class Vehicle {
  final String id;
  final String userId;
  final String brandName;
  final String modelName;
  final int year;
  final String? color;
  final String? plateNumber;
  final bool isPrimary;

  Vehicle({
    required this.id,
    required this.userId,
    required this.brandName,
    required this.modelName,
    required this.year,
    this.color,
    this.plateNumber,
    required this.isPrimary,
  });

  factory Vehicle.fromJson(Map<String, dynamic> json) {
    return Vehicle(
      id: json['id'],
      userId: json['user_id'],
      brandName: json['brand_name'],
      modelName: json['model_name'],
      year: json['year'],
      color: json['color'],
      plateNumber: json['plate_number'],
      isPrimary: json['is_primary'] ?? false,
    );
  }
}

class ServiceRequestHistory {
  final String id;
  final String status;
  final String title;
  final DateTime createdAt;
  final double? estimatedPrice;
  final double? finalPrice;
  final String? shopName;
  final String? serviceName;
  final String? vehicleInfo;

  ServiceRequestHistory({
    required this.id,
    required this.status,
    required this.title,
    required this.createdAt,
    this.estimatedPrice,
    this.finalPrice,
    this.shopName,
    this.serviceName,
    this.vehicleInfo,
  });

  factory ServiceRequestHistory.fromJson(Map<String, dynamic> json) {
    return ServiceRequestHistory(
      id: json['id'],
      status: json['status'],
      title: json['title'],
      createdAt: DateTime.parse(json['created_at']),
      estimatedPrice: json['estimated_price']?.toDouble(),
      finalPrice: json['final_price']?.toDouble(),
      shopName: json['shops']?['shop_name'],
      serviceName: json['service_categories']?['name'],
      vehicleInfo: json['vehicles'] != null 
          ? '${json['vehicles']['brand_name']} ${json['vehicles']['model_name']} ${json['vehicles']['year']}'
          : null,
    );
  }
}










