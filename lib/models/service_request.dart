class ServiceRequest {
  final String id;
  final String customerId;
  final String? providerId;
  final String? vehicleId;
  final String? categoryId;
  final String title;
  final String? description;
  final String status;
  final double pickupLatitude;
  final double pickupLongitude;
  final double? estimatedPrice;
  final double? finalPrice;
  final DateTime? serviceStartTime;
  final DateTime? serviceCompletionTime;
  final String paymentStatus;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? serviceType;
  final String priority;
  final String? pickupAddress;
  final DateTime? assignedAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  final String? paymentMethod;
  final String serviceClassification;
  final DateTime? estimatedArrivalTime;
  final double? distanceToCustomer;

  ServiceRequest({
    required this.id,
    required this.customerId,
    this.providerId,
    this.vehicleId,
    this.categoryId,
    required this.title,
    this.description,
    required this.status,
    required this.pickupLatitude,
    required this.pickupLongitude,
    this.estimatedPrice,
    this.finalPrice,
    this.serviceStartTime,
    this.serviceCompletionTime,
    required this.paymentStatus,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.serviceType,
    this.priority = 'normal',
    this.pickupAddress,
    this.assignedAt,
    this.completedAt,
    this.cancelledAt,
    this.paymentMethod,
    this.serviceClassification = 'minor',
    this.estimatedArrivalTime,
    this.distanceToCustomer,
  });

  factory ServiceRequest.fromJson(Map<String, dynamic> json) {
    return ServiceRequest(
      id: json['id'],
      customerId: json['customer_id'],
      providerId: json['provider_id'],
      vehicleId: json['vehicle_id'],
      categoryId: json['category_id'],
      title: json['title'],
      description: json['description'],
      status: json['status'] ?? 'pending',
      pickupLatitude: (json['pickup_latitude'] as num).toDouble(),
      pickupLongitude: (json['pickup_longitude'] as num).toDouble(),
      estimatedPrice: json['estimated_price'] != null 
          ? (json['estimated_price'] as num).toDouble() 
          : null,
      finalPrice: json['final_price'] != null 
          ? (json['final_price'] as num).toDouble() 
          : null,
      serviceStartTime: json['service_start_time'] != null 
          ? DateTime.parse(json['service_start_time']) 
          : null,
      serviceCompletionTime: json['service_completion_time'] != null 
          ? DateTime.parse(json['service_completion_time']) 
          : null,
      paymentStatus: json['payment_status'] ?? 'pending',
      notes: json['notes'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      serviceType: json['service_type'],
      priority: json['priority'] ?? 'normal',
      pickupAddress: json['pickup_address'],
      assignedAt: json['assigned_at'] != null 
          ? DateTime.parse(json['assigned_at']) 
          : null,
      completedAt: json['completed_at'] != null 
          ? DateTime.parse(json['completed_at']) 
          : null,
      cancelledAt: json['cancelled_at'] != null 
          ? DateTime.parse(json['cancelled_at']) 
          : null,
      paymentMethod: json['payment_method'],
      serviceClassification: json['service_classification'] ?? 'minor',
      estimatedArrivalTime: json['estimated_arrival_time'] != null 
          ? DateTime.parse(json['estimated_arrival_time']) 
          : null,
      distanceToCustomer: json['distance_to_customer'] != null 
          ? (json['distance_to_customer'] as num).toDouble() 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'customer_id': customerId,
      'provider_id': providerId,
      'vehicle_id': vehicleId,
      'category_id': categoryId,
      'title': title,
      'description': description,
      'status': status,
      'pickup_latitude': pickupLatitude,
      'pickup_longitude': pickupLongitude,
      'estimated_price': estimatedPrice,
      'final_price': finalPrice,
      'service_start_time': serviceStartTime?.toIso8601String(),
      'service_completion_time': serviceCompletionTime?.toIso8601String(),
      'payment_status': paymentStatus,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'service_type': serviceType,
      'priority': priority,
      'pickup_address': pickupAddress,
      'assigned_at': assignedAt?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'cancelled_at': cancelledAt?.toIso8601String(),
      'payment_method': paymentMethod,
      'service_classification': serviceClassification,
      'estimated_arrival_time': estimatedArrivalTime?.toIso8601String(),
      'distance_to_customer': distanceToCustomer,
    };
  }

  ServiceRequest copyWith({
    String? id,
    String? customerId,
    String? providerId,
    String? vehicleId,
    String? categoryId,
    String? title,
    String? description,
    String? status,
    double? pickupLatitude,
    double? pickupLongitude,
    double? estimatedPrice,
    double? finalPrice,
    DateTime? serviceStartTime,
    DateTime? serviceCompletionTime,
    String? paymentStatus,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? serviceType,
    String? priority,
    String? pickupAddress,
    DateTime? assignedAt,
    DateTime? completedAt,
    DateTime? cancelledAt,
    String? paymentMethod,
    String? serviceClassification,
    DateTime? estimatedArrivalTime,
    double? distanceToCustomer,
  }) {
    return ServiceRequest(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      providerId: providerId ?? this.providerId,
      vehicleId: vehicleId ?? this.vehicleId,
      categoryId: categoryId ?? this.categoryId,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      pickupLatitude: pickupLatitude ?? this.pickupLatitude,
      pickupLongitude: pickupLongitude ?? this.pickupLongitude,
      estimatedPrice: estimatedPrice ?? this.estimatedPrice,
      finalPrice: finalPrice ?? this.finalPrice,
      serviceStartTime: serviceStartTime ?? this.serviceStartTime,
      serviceCompletionTime: serviceCompletionTime ?? this.serviceCompletionTime,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      serviceType: serviceType ?? this.serviceType,
      priority: priority ?? this.priority,
      pickupAddress: pickupAddress ?? this.pickupAddress,
      assignedAt: assignedAt ?? this.assignedAt,
      completedAt: completedAt ?? this.completedAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      serviceClassification: serviceClassification ?? this.serviceClassification,
      estimatedArrivalTime: estimatedArrivalTime ?? this.estimatedArrivalTime,
      distanceToCustomer: distanceToCustomer ?? this.distanceToCustomer,
    );
  }

  // Helper getters
  bool get isCompleted => status == 'completed';
  bool get isInProgress => status == 'in_progress';
  bool get isPending => status == 'pending';
  bool get isCancelled => status == 'cancelled' || status == 'canceled';
  bool get isAssigned => providerId != null && status != 'pending';
  bool get isPaid => paymentStatus == 'completed' || paymentStatus == 'paid';
  bool get isMajorService => serviceClassification == 'major';
  bool get isHighPriority => priority == 'high' || priority == 'urgent';
}

class Payment {
  final String id;
  final String requestId;
  final String customerId;
  final String providerId;
  final double amount;
  final double platformFee;
  final double providerAmount;
  final String? paymentMethod;
  final String? paymentGateway;
  final String? transactionId;
  final String status;
  final DateTime? processedAt;
  final DateTime createdAt;

  Payment({
    required this.id,
    required this.requestId,
    required this.customerId,
    required this.providerId,
    required this.amount,
    this.platformFee = 0.00,
    required this.providerAmount,
    this.paymentMethod,
    this.paymentGateway,
    this.transactionId,
    this.status = 'pending',
    this.processedAt,
    required this.createdAt,
  });

  factory Payment.fromJson(Map<String, dynamic> json) {
    return Payment(
      id: json['id'],
      requestId: json['request_id'],
      customerId: json['customer_id'],
      providerId: json['provider_id'],
      amount: (json['amount'] as num).toDouble(),
      platformFee: json['platform_fee'] != null 
          ? (json['platform_fee'] as num).toDouble() 
          : 0.00,
      providerAmount: (json['provider_amount'] as num).toDouble(),
      paymentMethod: json['payment_method'],
      paymentGateway: json['payment_gateway'],
      transactionId: json['transaction_id'],
      status: json['status'] ?? 'pending',
      processedAt: json['processed_at'] != null 
          ? DateTime.parse(json['processed_at']) 
          : null,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'request_id': requestId,
      'customer_id': customerId,
      'provider_id': providerId,
      'amount': amount,
      'platform_fee': platformFee,
      'provider_amount': providerAmount,
      'payment_method': paymentMethod,
      'payment_gateway': paymentGateway,
      'transaction_id': transactionId,
      'status': status,
      'processed_at': processedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  bool get isCompleted => status == 'completed' || status == 'paid';
  bool get isPending => status == 'pending';
  bool get isFailed => status == 'failed' || status == 'error';
}










