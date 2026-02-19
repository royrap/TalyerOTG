/// Comprehensive model for service history detail view
/// Contains all related data: mechanic, shop, vehicle, payment, etc.
class ServiceHistoryDetail {
  // Service Request Info
  final String requestId;
  final String title;
  final String description;
  final String status;
  final DateTime createdAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;

  // Mechanic Info
  final String? mechanicId;
  final String? mechanicFirstName;
  final String? mechanicLastName;
  final String? mechanicPhone;
  final String? mechanicEmail;
  final String? mechanicProfileImage;

  // Shop Info
  final String? shopId;
  final String? shopName;
  final String? shopAddress;
  final String? shopPhone;
  final String? shopEmail;

  // Vehicle Info
  final String? vehicleBrand;
  final String? vehicleModel;
  final String? vehiclePlate;
  final int? vehicleYear;
  final String? vehicleColor;

  // Service Details
  final String? serviceCategory;
  final String? serviceCategoryIcon;
  final double? estimatedPrice;
  final double? finalPrice;
  final DateTime? serviceStartTime;
  final DateTime? serviceCompletionTime;

  // Payment Info
  final String? invoiceId;
  final String? invoiceNumber;
  final double? subtotal;
  final double? platformFee;
  final double? totalAmount;
  final String? paymentStatus;
  final String? paymentMethod;
  final DateTime? paidAt;
  final String? paymentProofUrl;

  // Location Info
  final double? pickupLatitude;
  final double? pickupLongitude;
  final String? pickupAddress;
  final double? distanceKm;

  // Review Info
  final double? rating;
  final String? reviewComment;
  final DateTime? reviewDate;

  // Additional Info
  final String? rejectionReason;
  final String? mechanicReport;
  final Map<String, dynamic>? inspectionReport;
  final Map<String, dynamic>? additionalDetails;

  ServiceHistoryDetail({
    required this.requestId,
    required this.title,
    required this.description,
    required this.status,
    required this.createdAt,
    this.completedAt,
    this.cancelledAt,
    this.mechanicId,
    this.mechanicFirstName,
    this.mechanicLastName,
    this.mechanicPhone,
    this.mechanicEmail,
    this.mechanicProfileImage,
    this.shopId,
    this.shopName,
    this.shopAddress,
    this.shopPhone,
    this.shopEmail,
    this.vehicleBrand,
    this.vehicleModel,
    this.vehiclePlate,
    this.vehicleYear,
    this.vehicleColor,
    this.serviceCategory,
    this.serviceCategoryIcon,
    this.estimatedPrice,
    this.finalPrice,
    this.serviceStartTime,
    this.serviceCompletionTime,
    this.invoiceId,
    this.invoiceNumber,
    this.subtotal,
    this.platformFee,
    this.totalAmount,
    this.paymentStatus,
    this.paymentMethod,
    this.paidAt,
    this.paymentProofUrl,
    this.pickupLatitude,
    this.pickupLongitude,
    this.pickupAddress,
    this.distanceKm,
    this.rating,
    this.reviewComment,
    this.reviewDate,
    this.rejectionReason,
    this.mechanicReport,
    this.inspectionReport,
    this.additionalDetails,
  });

  factory ServiceHistoryDetail.fromJson(Map<String, dynamic> json) {
    // Extract nested data safely
    final mechanic = json['assigned_mechanic'] ?? json['mechanic'];
    final shop = json['shop'] ?? json['shops'];
    final vehicle = json['vehicle'] ?? json['vehicles'];
    final category = json['category'] ?? json['service_categories'];
    final invoices = json['invoices'] as List?;
    final invoice = invoices?.isNotEmpty == true ? invoices!.first : null;
    final reviews = json['reviews'] as List?;
    final review = reviews?.isNotEmpty == true ? reviews!.first : null;

    return ServiceHistoryDetail(
      requestId: json['id'] ?? '',
      title: json['title'] ?? 'Service Request',
      description: json['description'] ?? '',
      status: json['status'] ?? 'pending',
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      completedAt: json['completed_at'] != null ? DateTime.parse(json['completed_at']) : null,
      cancelledAt: json['cancelled_at'] != null ? DateTime.parse(json['cancelled_at']) : null,
      
      // Mechanic info
      mechanicId: mechanic?['id'],
      mechanicFirstName: mechanic?['first_name'],
      mechanicLastName: mechanic?['last_name'],
      mechanicPhone: mechanic?['phone_number'],
      mechanicEmail: mechanic?['email'],
      mechanicProfileImage: mechanic?['profile_image_url'],
      
      // Shop info
      shopId: shop?['id'],
      shopName: shop?['shop_name'],
      shopAddress: shop?['shop_address'],
      shopPhone: shop?['shop_phone'],
      shopEmail: shop?['shop_email'],
      
      // Vehicle info
      vehicleBrand: vehicle?['brand_name'],
      vehicleModel: vehicle?['model_name'],
      vehiclePlate: vehicle?['plate_number'],
      vehicleYear: vehicle?['year'],
      vehicleColor: vehicle?['color'],
      
      // Service details
      serviceCategory: category?['name'],
      serviceCategoryIcon: category?['icon_name'],
      estimatedPrice: json['estimated_price'] != null ? double.tryParse(json['estimated_price'].toString()) : null,
      finalPrice: json['final_price'] != null ? double.tryParse(json['final_price'].toString()) : null,
      serviceStartTime: json['service_start_time'] != null ? DateTime.parse(json['service_start_time']) : null,
      serviceCompletionTime: json['service_completion_time'] != null ? DateTime.parse(json['service_completion_time']) : null,
      
      // Payment info
      invoiceId: invoice?['id'],
      invoiceNumber: invoice?['invoice_number'],
      subtotal: invoice?['subtotal'] != null ? double.tryParse(invoice['subtotal'].toString()) : null,
      platformFee: invoice?['platform_fee'] != null ? double.tryParse(invoice['platform_fee'].toString()) : null,
      totalAmount: invoice?['total_amount'] != null ? double.tryParse(invoice['total_amount'].toString()) : null,
      paymentStatus: json['payment_status'],
      paymentMethod: json['payment_method'] ?? invoice?['selected_payment_method'],
      paidAt: invoice?['paid_at'] != null ? DateTime.parse(invoice['paid_at']) : null,
      // Extract proof_url from payment_details JSONB
      paymentProofUrl: invoice?['payment_details'] != null && invoice['payment_details'] is Map
          ? invoice['payment_details']['proof_url']
          : null,
      
      // Location info
      pickupLatitude: json['pickup_latitude'] != null ? double.tryParse(json['pickup_latitude'].toString()) : null,
      pickupLongitude: json['pickup_longitude'] != null ? double.tryParse(json['pickup_longitude'].toString()) : null,
      pickupAddress: json['pickup_address'],
      distanceKm: json['distance_km'] != null ? double.tryParse(json['distance_km'].toString()) : null,
      
      // Review info
      rating: review?['rating'] != null ? double.tryParse(review['rating'].toString()) : null,
      reviewComment: review?['comment'],
      reviewDate: review?['created_at'] != null ? DateTime.parse(review['created_at']) : null,
      
      // Additional info
      rejectionReason: json['rejection_reason'],
      mechanicReport: json['mechanic_report'],
      inspectionReport: json['inspection_report'],
      additionalDetails: json['additional_details'],
    );
  }

  String get mechanicFullName {
    if (mechanicFirstName != null && mechanicLastName != null) {
      return '$mechanicFirstName $mechanicLastName';
    }
    return 'No mechanic assigned';
  }

  String get vehicleFullName {
    if (vehicleBrand != null && vehicleModel != null) {
      return '$vehicleBrand $vehicleModel';
    }
    return 'No vehicle info';
  }

  String get formattedTotalAmount {
    if (totalAmount != null) {
      return '₱${totalAmount!.toStringAsFixed(2)}';
    }
    return '₱0.00';
  }

  String get statusDisplay {
    return status.split('_').map((word) => word[0].toUpperCase() + word.substring(1)).join(' ');
  }

  bool get hasReview => rating != null && rating! > 0;
  bool get hasMechanic => mechanicId != null;
  bool get hasShop => shopId != null;
  bool get hasVehicle => vehicleBrand != null && vehicleModel != null;
  bool get hasInvoice => invoiceId != null;
  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';
}
