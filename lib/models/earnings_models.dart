/// Models for the Angkas-style earnings tracking system
/// Fee distribution: 75% mechanic, 20% shop, 5% platform

class EarningsBreakdown {
  final double totalAmount;
  final double mechanicEarnings;
  final double shopEarnings;
  final double platformFee;
  final double mechanicPercentage;
  final double shopPercentage;
  final double platformPercentage;

  EarningsBreakdown({
    required this.totalAmount,
    required this.mechanicEarnings,
    required this.shopEarnings,
    required this.platformFee,
    required this.mechanicPercentage,
    required this.shopPercentage,
    required this.platformPercentage,
  });

  /// Create from JSON
  factory EarningsBreakdown.fromJson(Map<String, dynamic> json) {
    return EarningsBreakdown(
      totalAmount: (json['total_amount'] ?? 0.0).toDouble(),
      mechanicEarnings: (json['mechanic_earnings'] ?? 0.0).toDouble(),
      shopEarnings: (json['shop_earnings'] ?? 0.0).toDouble(),
      platformFee: (json['platform_fee'] ?? 0.0).toDouble(),
      mechanicPercentage: (json['mechanic_percentage'] ?? 75.0).toDouble(),
      shopPercentage: (json['shop_percentage'] ?? 20.0).toDouble(),
      platformPercentage: (json['platform_percentage'] ?? 5.0).toDouble(),
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'total_amount': totalAmount,
      'mechanic_earnings': mechanicEarnings,
      'shop_earnings': shopEarnings,
      'platform_fee': platformFee,
      'mechanic_percentage': mechanicPercentage,
      'shop_percentage': shopPercentage,
      'platform_percentage': platformPercentage,
    };
  }

  /// Check if earnings add up correctly
  bool get isValid {
    final sum = mechanicEarnings + shopEarnings + platformFee;
    return (sum - totalAmount).abs() < 0.01; // Allow small floating point differences
  }
}

class MechanicEarningsSummary {
  final int totalJobs;
  final double totalEarnings;
  final double thisMonthEarnings;
  final double thisWeekEarnings;
  final double todayEarnings;
  final double averageRating;

  MechanicEarningsSummary({
    required this.totalJobs,
    required this.totalEarnings,
    required this.thisMonthEarnings,
    required this.thisWeekEarnings,
    required this.todayEarnings,
    required this.averageRating,
  });

  /// Create from JSON
  factory MechanicEarningsSummary.fromJson(Map<String, dynamic> json) {
    return MechanicEarningsSummary(
      totalJobs: json['total_jobs'] ?? 0,
      totalEarnings: (json['total_earnings'] ?? 0.0).toDouble(),
      thisMonthEarnings: (json['this_month_earnings'] ?? 0.0).toDouble(),
      thisWeekEarnings: (json['this_week_earnings'] ?? 0.0).toDouble(),
      todayEarnings: (json['today_earnings'] ?? 0.0).toDouble(),
      averageRating: (json['average_rating'] ?? 0.0).toDouble(),
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'total_jobs': totalJobs,
      'total_earnings': totalEarnings,
      'this_month_earnings': thisMonthEarnings,
      'this_week_earnings': thisWeekEarnings,
      'today_earnings': todayEarnings,
      'average_rating': averageRating,
    };
  }
}

class ShopEarningsSummary {
  final int totalJobs;
  final double totalShopEarnings;
  final double thisMonthEarnings;
  final double thisWeekEarnings;
  final double todayEarnings;
  final int numberOfMechanics;

  ShopEarningsSummary({
    required this.totalJobs,
    required this.totalShopEarnings,
    required this.thisMonthEarnings,
    required this.thisWeekEarnings,
    required this.todayEarnings,
    required this.numberOfMechanics,
  });

  /// Create from JSON
  factory ShopEarningsSummary.fromJson(Map<String, dynamic> json) {
    return ShopEarningsSummary(
      totalJobs: json['total_jobs'] ?? 0,
      totalShopEarnings: (json['total_shop_earnings'] ?? 0.0).toDouble(),
      thisMonthEarnings: (json['this_month_earnings'] ?? 0.0).toDouble(),
      thisWeekEarnings: (json['this_week_earnings'] ?? 0.0).toDouble(),
      todayEarnings: (json['today_earnings'] ?? 0.0).toDouble(),
      numberOfMechanics: json['number_of_mechanics'] ?? 0,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'total_jobs': totalJobs,
      'total_shop_earnings': totalShopEarnings,
      'this_month_earnings': thisMonthEarnings,
      'this_week_earnings': thisWeekEarnings,
      'today_earnings': todayEarnings,
      'number_of_mechanics': numberOfMechanics,
    };
  }
}

class EarningsHistoryItem {
  final String id;
  final String jobTitle;
  final String customerName;
  final String shopName;
  final String location;
  final String serviceType;
  final double totalAmount;
  final double earnings;
  final double shopEarnings;
  final double platformFee;
  final double? rating;
  final DateTime completedAt;

  EarningsHistoryItem({
    required this.id,
    required this.jobTitle,
    required this.customerName,
    required this.shopName,
    required this.location,
    required this.serviceType,
    required this.totalAmount,
    required this.earnings,
    required this.shopEarnings,
    required this.platformFee,
    this.rating,
    required this.completedAt,
  });

  /// Create from JSON
  factory EarningsHistoryItem.fromJson(Map<String, dynamic> json) {
    return EarningsHistoryItem(
      id: json['id'] ?? '',
      jobTitle: json['job_title'] ?? '',
      customerName: json['customer_name'] ?? '',
      shopName: json['shop_name'] ?? '',
      location: json['location'] ?? '',
      serviceType: json['service_type'] ?? '',
      totalAmount: (json['total_amount'] ?? 0.0).toDouble(),
      earnings: (json['earnings'] ?? 0.0).toDouble(),
      shopEarnings: (json['shop_earnings'] ?? 0.0).toDouble(),
      platformFee: (json['platform_fee'] ?? 0.0).toDouble(),
      rating: json['rating']?.toDouble(),
      completedAt: json['completed_at'] != null 
          ? DateTime.parse(json['completed_at'])
          : DateTime.now(),
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'job_title': jobTitle,
      'customer_name': customerName,
      'shop_name': shopName,
      'location': location,
      'service_type': serviceType,
      'total_amount': totalAmount,
      'earnings': earnings,
      'shop_earnings': shopEarnings,
      'platform_fee': platformFee,
      'rating': rating,
      'completed_at': completedAt.toIso8601String(),
    };
  }

  /// Get earnings breakdown for display
  EarningsBreakdown get breakdown {
    return EarningsBreakdown(
      totalAmount: totalAmount,
      mechanicEarnings: earnings,
      shopEarnings: shopEarnings,
      platformFee: platformFee,
      mechanicPercentage: 75.0,
      shopPercentage: 20.0,
      platformPercentage: 5.0,
    );
  }
}

class ShopEarningsHistoryItem {
  final String id;
  final String jobTitle;
  final String shopName;
  final String mechanicName;
  final String customerName;
  final String location;
  final String serviceType;
  final double totalAmount;
  final double shopEarnings;
  final double mechanicEarnings;
  final double platformFee;
  final DateTime completedAt;

  ShopEarningsHistoryItem({
    required this.id,
    required this.jobTitle,
    required this.shopName,
    required this.mechanicName,
    required this.customerName,
    required this.location,
    required this.serviceType,
    required this.totalAmount,
    required this.shopEarnings,
    required this.mechanicEarnings,
    required this.platformFee,
    required this.completedAt,
  });

  /// Create from JSON
  factory ShopEarningsHistoryItem.fromJson(Map<String, dynamic> json) {
    return ShopEarningsHistoryItem(
      id: json['id'] ?? '',
      jobTitle: json['job_title'] ?? '',
      shopName: json['shop_name'] ?? '',
      mechanicName: json['mechanic_name'] ?? '',
      customerName: json['customer_name'] ?? '',
      location: json['location'] ?? '',
      serviceType: json['service_type'] ?? '',
      totalAmount: (json['total_amount'] ?? 0.0).toDouble(),
      shopEarnings: (json['shop_earnings'] ?? 0.0).toDouble(),
      mechanicEarnings: (json['mechanic_earnings'] ?? 0.0).toDouble(),
      platformFee: (json['platform_fee'] ?? 0.0).toDouble(),
      completedAt: json['completed_at'] != null 
          ? DateTime.parse(json['completed_at'])
          : DateTime.now(),
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'job_title': jobTitle,
      'shop_name': shopName,
      'mechanic_name': mechanicName,
      'customer_name': customerName,
      'location': location,
      'service_type': serviceType,
      'total_amount': totalAmount,
      'shop_earnings': shopEarnings,
      'mechanic_earnings': mechanicEarnings,
      'platform_fee': platformFee,
      'completed_at': completedAt.toIso8601String(),
    };
  }

  /// Get earnings breakdown for display
  EarningsBreakdown get breakdown {
    return EarningsBreakdown(
      totalAmount: totalAmount,
      mechanicEarnings: mechanicEarnings,
      shopEarnings: shopEarnings,
      platformFee: platformFee,
      mechanicPercentage: 75.0,
      shopPercentage: 20.0,
      platformPercentage: 5.0,
    );
  }
}

/// Legacy model for backwards compatibility
class MechanicEarningsSummaryLegacy {
  final double totalEarnings;
  final double totalPlatformFees;
  final double netEarnings;
  final int completedJobs;
  final int cancelledJobs;
  final double averageRating;
  final double totalHoursWorked;
  final double earningsThisMonth;
  final double earningsThisWeek;

  MechanicEarningsSummaryLegacy({
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
}