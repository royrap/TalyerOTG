class CustomerJobHistory {
  final String id;
  final String customerId;
  final String serviceRequestId;
  final String? mechanicId;
  final String? shopId;
  final String jobTitle;
  final String? jobDescription;
  final String jobStatus;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  final double? totalAmount;
  final double? rating;
  final String? reviewText;
  final String? mechanicName;
  final String? shopName;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Payment details from service_requests and invoices
  final double? serviceFee; // From service_requests.service_fee
  final double? invoiceAmount; // From invoices.total_amount

  // Related data
  final ServiceRequestData? serviceRequest;
  final MechanicProfileData? mechanic;
  final ShopData? shop;

  CustomerJobHistory({
    required this.id,
    required this.customerId,
    required this.serviceRequestId,
    this.mechanicId,
    this.shopId,
    required this.jobTitle,
    this.jobDescription,
    required this.jobStatus,
    this.completedAt,
    this.cancelledAt,
    this.totalAmount,
    this.rating,
    this.reviewText,
    this.mechanicName,
    this.shopName,
    required this.createdAt,
    required this.updatedAt,
    this.serviceFee,
    this.invoiceAmount,
    this.serviceRequest,
    this.mechanic,
    this.shop,
  });

  factory CustomerJobHistory.fromJson(Map<String, dynamic> json) {
    return CustomerJobHistory(
      id: json['id'],
      customerId: json['customer_id'],
      serviceRequestId: json['service_request_id'],
      mechanicId: json['mechanic_id'],
      shopId: json['shop_id'],
      jobTitle: json['job_title'],
      jobDescription: json['job_description'],
      jobStatus: json['job_status'],
      completedAt: json['completed_at'] != null ? DateTime.parse(json['completed_at']) : null,
      cancelledAt: json['cancelled_at'] != null ? DateTime.parse(json['cancelled_at']) : null,
      totalAmount: json['total_amount']?.toDouble(),
      rating: json['rating']?.toDouble(),
      reviewText: json['review_text'],
      mechanicName: json['mechanic_name'],
      shopName: json['shop_name'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      serviceFee: json['service_fee']?.toDouble(),
      invoiceAmount: json['invoice_amount']?.toDouble(),
      serviceRequest: json['service_requests'] != null ? ServiceRequestData.fromJson(json['service_requests']) : null,
      mechanic: json['user_profiles'] != null ? MechanicProfileData.fromJson(json['user_profiles']) : null,
      shop: json['shops'] != null ? ShopData.fromJson(json['shops']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'customer_id': customerId,
      'service_request_id': serviceRequestId,
      'mechanic_id': mechanicId,
      'shop_id': shopId,
      'job_title': jobTitle,
      'job_description': jobDescription,
      'job_status': jobStatus,
      'completed_at': completedAt?.toIso8601String(),
      'cancelled_at': cancelledAt?.toIso8601String(),
      'total_amount': totalAmount,
      'rating': rating,
      'review_text': reviewText,
      'mechanic_name': mechanicName,
      'shop_name': shopName,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  String get displayStatus {
    switch (jobStatus) {
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      case 'in_progress':
        return 'In Progress';
      case 'pending':
        return 'Pending';
      default:
        return jobStatus.toUpperCase();
    }
  }

  String get formattedAmount {
    if (totalAmount == null) return 'N/A';
    return '₱${totalAmount!.toStringAsFixed(2)}';
  }

  String get formattedServiceFee {
    if (serviceFee == null) return 'N/A';
    return '₱${serviceFee!.toStringAsFixed(2)}';
  }

  String get formattedInvoiceAmount {
    if (invoiceAmount == null) return 'N/A';
    return '₱${invoiceAmount!.toStringAsFixed(2)}';
  }

  String get mechanicDisplayName {
    if (mechanic != null) {
      return '${mechanic!.firstName} ${mechanic!.lastName}';
    }
    return mechanicName ?? 'Unknown Mechanic';
  }

  String get shopDisplayName {
    if (shop != null) {
      return shop!.shopName;
    }
    return shopName ?? 'Independent Mechanic';
  }

  // Date formatting methods (matches MechanicJobHistory)
  String get formattedJobDate {
    // Use local time (DateTime.parse automatically converts UTC to local)
    final dateToUse = completedAt ?? createdAt;
    
    // For customer history: Always show actual date (no "Today" or "Yesterday")
    return '${dateToUse.day}/${dateToUse.month}/${dateToUse.year}';
  }

  String get fullFormattedJobDate {
    // Database stores UTC, DateTime.parse converts to local automatically
    final dateToUse = completedAt ?? createdAt;
    // Show date only (no time) for customer history
    return '${dateToUse.day}/${dateToUse.month}/${dateToUse.year}';
  }
}

class MechanicJobHistory {
  final String id;
  final String mechanicId;
  final String serviceRequestId;
  final String customerId;
  final String? shopId;
  final String jobTitle;
  final String? jobDescription;
  final String jobStatus;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  final double? totalAmount;
  final double? rating;
  final String? reviewText;
  final int? jobDurationMinutes;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Related data
  final ServiceRequestData? serviceRequest;
  final CustomerProfileData? customer;
  final ShopData? shop;

  // Earnings data (calculated from invoices/payments)
  final double? platformFee;
  final double? netEarnings;
  
  // Payment details from service_requests and invoices
  final double? serviceFee; // From service_requests.service_fee
  final double? invoiceAmount; // From invoices.total_amount

  MechanicJobHistory({
    required this.id,
    required this.mechanicId,
    required this.serviceRequestId,
    required this.customerId,
    this.shopId,
    required this.jobTitle,
    this.jobDescription,
    required this.jobStatus,
    this.completedAt,
    this.cancelledAt,
    this.totalAmount,
    this.rating,
    this.reviewText,
    this.jobDurationMinutes,
    required this.createdAt,
    required this.updatedAt,
    this.serviceRequest,
    this.customer,
    this.shop,
    this.platformFee,
    this.netEarnings,
    this.serviceFee,
    this.invoiceAmount,
  });

  factory MechanicJobHistory.fromJson(Map<String, dynamic> json) {
    return MechanicJobHistory(
      id: json['id'],
      mechanicId: json['mechanic_id'],
      serviceRequestId: json['service_request_id'],
      customerId: json['customer_id'],
      shopId: json['shop_id'],
      jobTitle: json['job_title'],
      jobDescription: json['job_description'],
      jobStatus: json['job_status'],
      completedAt: json['completed_at'] != null ? DateTime.parse(json['completed_at']) : null,
      cancelledAt: json['cancelled_at'] != null ? DateTime.parse(json['cancelled_at']) : null,
      totalAmount: json['total_amount']?.toDouble(),
      rating: json['rating']?.toDouble(),
      reviewText: json['review_text'],
      jobDurationMinutes: json['job_duration_minutes'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      serviceRequest: json['service_requests'] != null ? ServiceRequestData.fromJson(json['service_requests']) : null,
      customer: json['user_profiles'] != null ? CustomerProfileData.fromJson(json['user_profiles']) : null,
      shop: json['shops'] != null ? ShopData.fromJson(json['shops']) : null,
      platformFee: json['platform_fee']?.toDouble(),
      netEarnings: json['net_earnings']?.toDouble(),
      serviceFee: json['service_fee']?.toDouble(),
      invoiceAmount: json['invoice_amount']?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'mechanic_id': mechanicId,
      'service_request_id': serviceRequestId,
      'customer_id': customerId,
      'shop_id': shopId,
      'job_title': jobTitle,
      'job_description': jobDescription,
      'job_status': jobStatus,
      'completed_at': completedAt?.toIso8601String(),
      'cancelled_at': cancelledAt?.toIso8601String(),
      'total_amount': totalAmount,
      'rating': rating,
      'review_text': reviewText,
      'job_duration_minutes': jobDurationMinutes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'platform_fee': platformFee,
      'net_earnings': netEarnings,
    };
  }

  String get displayStatus {
    switch (jobStatus) {
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      case 'in_progress':
        return 'In Progress';
      case 'pending':
        return 'Pending';
      default:
        return jobStatus.toUpperCase();
    }
  }

  String get formattedAmount {
    if (totalAmount == null) return 'N/A';
    return '₱${totalAmount!.toStringAsFixed(2)}';
  }

  String get formattedNetEarnings {
    if (netEarnings == null) return 'N/A';
    return '₱${netEarnings!.toStringAsFixed(2)}';
  }

  String get formattedPlatformFee {
    if (platformFee == null) return 'N/A';
    return '₱${platformFee!.toStringAsFixed(2)}';
  }

  String get formattedServiceFee {
    if (serviceFee == null) return 'N/A';
    return '₱${serviceFee!.toStringAsFixed(2)}';
  }

  String get formattedInvoiceAmount {
    if (invoiceAmount == null) return 'N/A';
    return '₱${invoiceAmount!.toStringAsFixed(2)}';
  }

  String get customerDisplayName {
    if (customer != null) {
      return '${customer!.firstName} ${customer!.lastName}';
    }
    return 'Unknown Customer';
  }

  String get shopDisplayName {
    if (shop != null) {
      return shop!.shopName;
    }
    return 'Independent';
  }

  String get formattedDuration {
    if (jobDurationMinutes == null) return 'N/A';
    if (jobDurationMinutes! < 60) {
      return '${jobDurationMinutes}m';
    }
    final hours = jobDurationMinutes! ~/ 60;
    final minutes = jobDurationMinutes! % 60;
    return '${hours}h ${minutes}m';
  }

  // Enhanced display methods for mechanic history
  String get customerLocation {
    if (serviceRequest?.pickupAddress != null && serviceRequest!.pickupAddress!.isNotEmpty) {
      return serviceRequest!.pickupAddress!;
    }
    return 'Location not specified';
  }

  String get shortCustomerLocation {
    final location = customerLocation;
    if (location == 'Location not specified') return location;
    
    // Truncate if too long
    if (location.length > 40) {
      return '${location.substring(0, 37)}...';
    }
    return location;
  }

  String get formattedJobDate {
    // Use local time (DateTime.parse automatically converts UTC to local)
    final dateToUse = completedAt ?? createdAt;
    final now = DateTime.now();
    
    // Compare dates only (ignore time)
    final dateToUseDay = DateTime(dateToUse.year, dateToUse.month, dateToUse.day);
    final todayDay = DateTime(now.year, now.month, now.day);
    final difference = todayDay.difference(dateToUseDay).inDays;
    
    // Show date only (no time) for mechanic history
    if (difference == 0) {
      return 'Today';
    } else if (difference == 1) {
      return 'Yesterday';
    } else if (difference < 7) {
      return '$difference days ago';
    } else {
      return '${dateToUse.day}/${dateToUse.month}/${dateToUse.year}';
    }
  }

  String get fullFormattedJobDate {
    // Database stores UTC, DateTime.parse converts to local automatically
    final dateToUse = completedAt ?? createdAt;
    // Show date only (no time) for mechanic history
    return '${dateToUse.day}/${dateToUse.month}/${dateToUse.year}';
  }

  String get comprehensivePriceInfo {
    if (totalAmount == null) return 'Amount: N/A';
    
    final total = '₱${totalAmount!.toStringAsFixed(2)}';
    if (netEarnings != null) {
      final net = '₱${netEarnings!.toStringAsFixed(2)}';
      return 'Total: $total • You earned: $net';
    }
    return 'Total: $total';
  }

  String get customerInfo {
    if (customer != null) {
      final name = '${customer!.firstName} ${customer!.lastName}';
      if (customer!.phoneNumber != null && customer!.phoneNumber!.isNotEmpty) {
        return '$name • ${customer!.phoneNumber}';
      }
      return name;
    }
    return 'Unknown Customer';
  }

  bool get hasValidLocation {
    return serviceRequest?.pickupAddress != null && 
           serviceRequest!.pickupAddress!.isNotEmpty;
  }

  Map<String, dynamic> get displaySummary {
    return {
      'customer': customerDisplayName,
      'customerPhone': customer?.phoneNumber ?? '',
      'location': customerLocation,
      'shortLocation': shortCustomerLocation,
      'date': formattedJobDate,
      'fullDate': fullFormattedJobDate,
      'amount': formattedAmount,
      'netEarnings': formattedNetEarnings,
      'priceInfo': comprehensivePriceInfo,
      'duration': formattedDuration,
      'status': displayStatus,
      'hasLocation': hasValidLocation,
    };
  }
}

class ServiceRequestData {
  final String title;
  final String? description;
  final String? pickupAddress;
  final double? pickupLatitude;
  final double? pickupLongitude;
  final String? serviceType;
  final String? status;
  final DateTime createdAt;
  final double? estimatedPrice;
  final double? serviceFee;
  final String? vehicleBrand;
  final String? vehicleModel;
  final String? vehiclePlate;

  ServiceRequestData({
    required this.title,
    this.description,
    this.pickupAddress,
    this.pickupLatitude,
    this.pickupLongitude,
    this.serviceType,
    this.status,
    required this.createdAt,
    this.estimatedPrice,
    this.serviceFee,
    this.vehicleBrand,
    this.vehicleModel,
    this.vehiclePlate,
  });

  factory ServiceRequestData.fromJson(Map<String, dynamic> json) {
    return ServiceRequestData(
      title: json['title'] ?? '',
      description: json['description'],
      pickupAddress: json['pickup_address'],
      pickupLatitude: json['pickup_latitude']?.toDouble(),
      pickupLongitude: json['pickup_longitude']?.toDouble(),
      serviceType: json['service_type'],
      status: json['status'],
      createdAt: DateTime.parse(json['created_at']),
      estimatedPrice: json['estimated_price']?.toDouble(),
      serviceFee: json['service_fee']?.toDouble(),
      vehicleBrand: json['vehicle_brand'],
      vehicleModel: json['vehicle_model'],
      vehiclePlate: json['vehicle_plate'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'pickup_address': pickupAddress,
      'pickup_latitude': pickupLatitude,
      'pickup_longitude': pickupLongitude,
      'service_type': serviceType,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'estimated_price': estimatedPrice,
      'service_fee': serviceFee,
      'vehicle_brand': vehicleBrand,
      'vehicle_model': vehicleModel,
      'vehicle_plate': vehiclePlate,
    };
  }
}

class MechanicProfileData {
  final String firstName;
  final String lastName;
  final String? phoneNumber;
  final String? profileImageUrl;

  MechanicProfileData({
    required this.firstName,
    required this.lastName,
    this.phoneNumber,
    this.profileImageUrl,
  });

  factory MechanicProfileData.fromJson(Map<String, dynamic> json) {
    return MechanicProfileData(
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      phoneNumber: json['phone_number'],
      profileImageUrl: json['profile_image_url'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'first_name': firstName,
      'last_name': lastName,
      'phone_number': phoneNumber,
      'profile_image_url': profileImageUrl,
    };
  }
}

class CustomerProfileData {
  final String firstName;
  final String lastName;
  final String? phoneNumber;
  final String? email;
  final String? profileImageUrl;

  CustomerProfileData({
    required this.firstName,
    required this.lastName,
    this.phoneNumber,
    this.email,
    this.profileImageUrl,
  });

  factory CustomerProfileData.fromJson(Map<String, dynamic> json) {
    return CustomerProfileData(
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      phoneNumber: json['phone_number'],
      email: json['email'],
      profileImageUrl: json['profile_image_url'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'first_name': firstName,
      'last_name': lastName,
      'phone_number': phoneNumber,
      'email': email,
      'profile_image_url': profileImageUrl,
    };
  }
}

class ShopData {
  final String shopName;
  final String? shopAddress;
  final String? shopPhone;

  ShopData({
    required this.shopName,
    this.shopAddress,
    this.shopPhone,
  });

  factory ShopData.fromJson(Map<String, dynamic> json) {
    return ShopData(
      shopName: json['shop_name'] ?? '',
      shopAddress: json['shop_address'],
      shopPhone: json['shop_phone'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'shop_name': shopName,
      'shop_address': shopAddress,
      'shop_phone': shopPhone,
    };
  }
}

// Earnings summary for mechanic
class MechanicEarningsSummary {
  final double totalEarnings;
  final double totalPlatformFees;
  final double netEarnings;
  final int completedJobs;
  final int cancelledJobs;
  final double averageRating;
  final double totalHoursWorked;
  final double earningsThisMonth;
  final double earningsThisWeek;

  MechanicEarningsSummary({
    required this.totalEarnings,
    required this.totalPlatformFees,
    required this.netEarnings,
    required this.completedJobs,
    required this.cancelledJobs,
    required this.averageRating,
    required this.totalHoursWorked,
    required this.earningsThisMonth,
    required this.earningsThisWeek,
  });

  factory MechanicEarningsSummary.fromJson(Map<String, dynamic> json) {
    return MechanicEarningsSummary(
      totalEarnings: json['total_earnings']?.toDouble() ?? 0.0,
      totalPlatformFees: json['total_platform_fees']?.toDouble() ?? 0.0,
      netEarnings: json['net_earnings']?.toDouble() ?? 0.0,
      completedJobs: json['completed_jobs'] ?? 0,
      cancelledJobs: json['cancelled_jobs'] ?? 0,
      averageRating: json['average_rating']?.toDouble() ?? 0.0,
      totalHoursWorked: json['total_hours_worked']?.toDouble() ?? 0.0,
      earningsThisMonth: json['earnings_this_month']?.toDouble() ?? 0.0,
      earningsThisWeek: json['earnings_this_week']?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total_earnings': totalEarnings,
      'total_platform_fees': totalPlatformFees,
      'net_earnings': netEarnings,
      'completed_jobs': completedJobs,
      'cancelled_jobs': cancelledJobs,
      'average_rating': averageRating,
      'total_hours_worked': totalHoursWorked,
      'earnings_this_month': earningsThisMonth,
      'earnings_this_week': earningsThisWeek,
    };
  }

  String get formattedTotalEarnings => '₱${totalEarnings.toStringAsFixed(2)}';
  String get formattedNetEarnings => '₱${netEarnings.toStringAsFixed(2)}';
  String get formattedEarningsThisMonth => '₱${earningsThisMonth.toStringAsFixed(2)}';
  String get formattedEarningsThisWeek => '₱${earningsThisWeek.toStringAsFixed(2)}';
}