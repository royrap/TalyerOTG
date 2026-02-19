class ShopModel {
  final String id;
  final String name;
  final String owner;
  final String address;
  final String distance;
  final double rating;
  final int totalReviews;
  final List<String> specialties;
  final bool isVerified;
  final String priceRange;
  final String responseTime;
  
  ShopModel({
    required this.id,
    required this.name,
    required this.owner,
    required this.address,
    required this.distance,
    required this.rating,
    required this.totalReviews,
    required this.specialties,
    required this.isVerified,
    required this.priceRange,
    required this.responseTime,
  });
  
  factory ShopModel.fromJson(Map<String, dynamic> json) {
    return ShopModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      owner: json['owner'] ?? '',
      address: json['address'] ?? '',
      distance: json['distance'] ?? '0 km',
      rating: (json['rating'] ?? 0.0).toDouble(),
      totalReviews: json['total_reviews'] ?? 0,
      specialties: List<String>.from(json['specialties'] ?? []),
      isVerified: json['is_verified'] ?? false,
      priceRange: json['price_range'] ?? '',
      responseTime: json['response_time'] ?? '',
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'owner': owner,
      'address': address,
      'distance': distance,
      'rating': rating,
      'total_reviews': totalReviews,
      'specialties': specialties,
      'is_verified': isVerified,
      'price_range': priceRange,
      'response_time': responseTime,
    };
  }
}