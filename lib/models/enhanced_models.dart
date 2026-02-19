class VehicleModel {
  final String id;
  final String userId;
  final String brandName;
  final String modelName;
  final int year;
  final String? color;
  final String? plateNumber;
  final bool isPrimary;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String vehicleType;

  VehicleModel({
    required this.id,
    required this.userId,
    required this.brandName,
    required this.modelName,
    required this.year,
    this.color,
    this.plateNumber,
    this.isPrimary = false,
    required this.createdAt,
    required this.updatedAt,
    this.vehicleType = 'car',
  });

  factory VehicleModel.fromJson(Map<String, dynamic> json) {
    return VehicleModel(
      id: json['id'],
      userId: json['user_id'],
      brandName: json['brand_name'],
      modelName: json['model_name'],
      year: json['year'],
      color: json['color'],
      plateNumber: json['plate_number'],
      isPrimary: json['is_primary'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      vehicleType: json['vehicle_type'] ?? 'car',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'brand_name': brandName,
      'model_name': modelName,
      'year': year,
      'color': color,
      'plate_number': plateNumber,
      'is_primary': isPrimary,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'vehicle_type': vehicleType,
    };
  }

  String get displayName => '$brandName $modelName ($year)';
  String get fullDescription => '$brandName $modelName $year${color != null ? ' - $color' : ''}';
}

class ServiceProvider {
  final String id;
  final String userId;
  final String? companyName;
  final String? licenseNumber;
  final String? insurancePolicyNumber;
  final double rating;
  final int totalReviews;
  final int? yearsExperience;
  final double serviceRadius;
  final bool isVerified;
  final bool isAvailable;
  final double? currentLatitude;
  final double? currentLongitude;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? talyerOwnerId;
  final String? shopId;

  ServiceProvider({
    required this.id,
    required this.userId,
    this.companyName,
    this.licenseNumber,
    this.insurancePolicyNumber,
    this.rating = 0.00,
    this.totalReviews = 0,
    this.yearsExperience,
    this.serviceRadius = 50.0,
    this.isVerified = false,
    this.isAvailable = true,
    this.currentLatitude,
    this.currentLongitude,
    this.status = 'offline',
    required this.createdAt,
    required this.updatedAt,
    this.talyerOwnerId,
    this.shopId,
  });

  factory ServiceProvider.fromJson(Map<String, dynamic> json) {
    return ServiceProvider(
      id: json['id'],
      userId: json['user_id'],
      companyName: json['company_name'],
      licenseNumber: json['license_number'],
      insurancePolicyNumber: json['insurance_policy_number'],
      rating: json['rating'] != null ? (json['rating'] as num).toDouble() : 0.00,
      totalReviews: json['total_reviews'] ?? 0,
      yearsExperience: json['years_experience'],
      serviceRadius: json['service_radius'] != null 
          ? (json['service_radius'] as num).toDouble() 
          : 50.0,
      isVerified: json['is_verified'] ?? false,
      isAvailable: json['is_available'] ?? true,
      currentLatitude: json['current_latitude'] != null 
          ? (json['current_latitude'] as num).toDouble() 
          : null,
      currentLongitude: json['current_longitude'] != null 
          ? (json['current_longitude'] as num).toDouble() 
          : null,
      status: json['status'] ?? 'offline',
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      talyerOwnerId: json['talyer_owner_id'],
      shopId: json['shop_id'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'company_name': companyName,
      'license_number': licenseNumber,
      'insurance_policy_number': insurancePolicyNumber,
      'rating': rating,
      'total_reviews': totalReviews,
      'years_experience': yearsExperience,
      'service_radius': serviceRadius,
      'is_verified': isVerified,
      'is_available': isAvailable,
      'current_latitude': currentLatitude,
      'current_longitude': currentLongitude,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'talyer_owner_id': talyerOwnerId,
      'shop_id': shopId,
    };
  }

  bool get isOnline => status == 'online';
  bool get isActive => isAvailable && isVerified;
  bool get hasLocation => currentLatitude != null && currentLongitude != null;
}

class Shop {
  final String id;
  final String ownerId;
  final String shopName;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  Shop({
    required this.id,
    required this.ownerId,
    required this.shopName,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Shop.fromJson(Map<String, dynamic> json) {
    return Shop(
      id: json['id'],
      ownerId: json['owner_id'],
      shopName: json['shop_name'],
      isActive: json['is_active'] ?? true,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'owner_id': ownerId,
      'shop_name': shopName,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
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
  final DateTime createdAt;

  ServiceCategory({
    required this.id,
    required this.name,
    this.description,
    this.iconName,
    this.basePrice,
    this.estimatedDuration,
    this.isActive = true,
    required this.createdAt,
  });

  factory ServiceCategory.fromJson(Map<String, dynamic> json) {
    return ServiceCategory(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      iconName: json['icon_name'],
      basePrice: json['base_price'] != null 
          ? (json['base_price'] as num).toDouble() 
          : null,
      estimatedDuration: json['estimated_duration'],
      isActive: json['is_active'] ?? true,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'icon_name': iconName,
      'base_price': basePrice,
      'estimated_duration': estimatedDuration,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
    };
  }

  String get estimatedDurationText {
    if (estimatedDuration == null) return 'Duration varies';
    if (estimatedDuration! < 60) return '${estimatedDuration} minutes';
    final hours = estimatedDuration! / 60;
    return '${hours.toStringAsFixed(1)} hours';
  }
}

class Message {
  final String id;
  final String requestId;
  final String senderId;
  final String receiverId;
  final String message;
  final DateTime sentAt;
  final bool isRead;

  Message({
    required this.id,
    required this.requestId,
    required this.senderId,
    required this.receiverId,
    required this.message,
    required this.sentAt,
    this.isRead = false,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'],
      requestId: json['request_id'],
      senderId: json['sender_id'],
      receiverId: json['receiver_id'],
      message: json['message'],
      sentAt: DateTime.parse(json['sent_at']),
      isRead: json['is_read'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'request_id': requestId,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'message': message,
      'sent_at': sentAt.toIso8601String(),
      'is_read': isRead,
    };
  }

  bool isFromUser(String userId) => senderId == userId;
}

class Review {
  final String id;
  final String requestId;
  final String customerId;
  final String providerId;
  final int rating;
  final String? comment;
  final String? response;
  final bool isVerified;
  final DateTime createdAt;
  final DateTime updatedAt;

  Review({
    required this.id,
    required this.requestId,
    required this.customerId,
    required this.providerId,
    required this.rating,
    this.comment,
    this.response,
    this.isVerified = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      id: json['id'],
      requestId: json['request_id'],
      customerId: json['customer_id'],
      providerId: json['provider_id'],
      rating: json['rating'],
      comment: json['comment'],
      response: json['response'],
      isVerified: json['is_verified'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'request_id': requestId,
      'customer_id': customerId,
      'provider_id': providerId,
      'rating': rating,
      'comment': comment,
      'response': response,
      'is_verified': isVerified,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  String get ratingText {
    switch (rating) {
      case 5: return 'Excellent';
      case 4: return 'Good';
      case 3: return 'Average';
      case 2: return 'Poor';
      case 1: return 'Very Poor';
      default: return 'No Rating';
    }
  }
}

class JobCompletionCode {
  final String id;
  final String requestId;
  final String customerId;
  final String completionCode;
  final bool isUsed;
  final DateTime createdAt;
  final DateTime expiresAt;
  final DateTime? usedAt;
  final String? usedByProviderId;
  final String verificationStatus;
  final double? scanLatitude;
  final double? scanLongitude;
  final double? scanDistanceMeters;
  final String? scanIpAddress;
  final String? deviceFingerprint;

  JobCompletionCode({
    required this.id,
    required this.requestId,
    required this.customerId,
    required this.completionCode,
    this.isUsed = false,
    required this.createdAt,
    required this.expiresAt,
    this.usedAt,
    this.usedByProviderId,
    this.verificationStatus = 'pending',
    this.scanLatitude,
    this.scanLongitude,
    this.scanDistanceMeters,
    this.scanIpAddress,
    this.deviceFingerprint,
  });

  factory JobCompletionCode.fromJson(Map<String, dynamic> json) {
    return JobCompletionCode(
      id: json['id'],
      requestId: json['request_id'],
      customerId: json['customer_id'],
      completionCode: json['completion_code'],
      isUsed: json['is_used'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
      expiresAt: DateTime.parse(json['expires_at']),
      usedAt: json['used_at'] != null ? DateTime.parse(json['used_at']) : null,
      usedByProviderId: json['used_by_provider_id'],
      verificationStatus: json['verification_status'] ?? 'pending',
      scanLatitude: json['scan_latitude'] != null 
          ? (json['scan_latitude'] as num).toDouble() 
          : null,
      scanLongitude: json['scan_longitude'] != null 
          ? (json['scan_longitude'] as num).toDouble() 
          : null,
      scanDistanceMeters: json['scan_distance_meters'] != null 
          ? (json['scan_distance_meters'] as num).toDouble() 
          : null,
      scanIpAddress: json['scan_ip_address'],
      deviceFingerprint: json['device_fingerprint'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'request_id': requestId,
      'customer_id': customerId,
      'completion_code': completionCode,
      'is_used': isUsed,
      'created_at': createdAt.toIso8601String(),
      'expires_at': expiresAt.toIso8601String(),
      'used_at': usedAt?.toIso8601String(),
      'used_by_provider_id': usedByProviderId,
      'verification_status': verificationStatus,
      'scan_latitude': scanLatitude,
      'scan_longitude': scanLongitude,
      'scan_distance_meters': scanDistanceMeters,
      'scan_ip_address': scanIpAddress,
      'device_fingerprint': deviceFingerprint,
    };
  }

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get isValid => !isUsed && !isExpired && verificationStatus != 'invalid';
  
  String get statusText {
    if (isExpired) return 'Expired';
    if (isUsed) return 'Used';
    return verificationStatus.toUpperCase();
  }
}










