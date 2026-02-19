import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'location_service.dart';

class PricingService {
  static final PricingService _instance = PricingService._internal();
  factory PricingService() => _instance;
  PricingService._internal();  // Tiered service fee structure
  static const double _tier1Fee = 500.0;   // Up to 10km
  static const double _tier2Fee = 1000.0;  // Up to 20km  
  static const double _tier3Fee = 1500.0;  // Up to 30km
  static const double _additionalFeePerKm = 100.0; // Beyond 30km
  
  // Minimum distance charge
  static const double _minimumFee = 500.0;
  
  // Fixed processing fee
  static const double _processingFee = 15.0;  /// Calculate distance-based service fee
  /// Formula: ₱500 (≤10km), ₱1000 (≤20km), ₱1500 (≤30km), then ₱100/km
  double calculateServiceFee({
    required LatLng customerLocation,
    required LatLng mechanicLocation,
  }) {
    // Calculate distance using existing location service
    final LocationService locationService = LocationService();
    final double distanceKm = locationService.calculateDistance(
      customerLocation, 
      mechanicLocation
    );

    double serviceFee;
    
    if (distanceKm <= 10) {
      // Up to 10km: ₱500
      serviceFee = _tier1Fee;
    } else if (distanceKm <= 20) {
      // Up to 20km: ₱1,000
      serviceFee = _tier2Fee;
    } else if (distanceKm <= 30) {
      // Up to 30km: ₱1,500
      serviceFee = _tier3Fee;
    } else {
      // Beyond 30km: ₱1,500 + ₱100 per additional km
      final double additionalKm = distanceKm - 30;
      serviceFee = _tier3Fee + (additionalKm * _additionalFeePerKm);
    }
    
    print('🧮 Pricing Calculation:');
    print('   Distance: ${distanceKm.toStringAsFixed(2)} km');
    if (distanceKm <= 10) {
      print('   Tier 1 (≤10km): ₱${_tier1Fee.toStringAsFixed(2)}');
    } else if (distanceKm <= 20) {
      print('   Tier 2 (≤20km): ₱${_tier2Fee.toStringAsFixed(2)}');
    } else if (distanceKm <= 30) {
      print('   Tier 3 (≤30km): ₱${_tier3Fee.toStringAsFixed(2)}');
    } else {
      final double additionalKm = distanceKm - 30;
      print('   Tier 3 (30km): ₱${_tier3Fee.toStringAsFixed(2)}');
      print('   Additional ${additionalKm.toStringAsFixed(2)}km × ₱$_additionalFeePerKm: ₱${(additionalKm * _additionalFeePerKm).toStringAsFixed(2)}');
    }
    print('   Service Fee: ₱${serviceFee.toStringAsFixed(2)}');
    
    return serviceFee;
  }

  /// Calculate total amount including processing fee
  double calculateTotalAmount({
    required LatLng customerLocation,
    required LatLng mechanicLocation,
  }) {
    final double serviceFee = calculateServiceFee(
      customerLocation: customerLocation,
      mechanicLocation: mechanicLocation,
    );
    
    final double totalAmount = serviceFee + _processingFee;
    
    print('💰 Total Calculation:');
    print('   Service Fee: ₱${serviceFee.toStringAsFixed(2)}');
    print('   Processing Fee: ₱${_processingFee.toStringAsFixed(2)}');
    print('   Total Amount: ₱${totalAmount.toStringAsFixed(2)}');
    
    return totalAmount;
  }  /// Get pricing breakdown for display
  Map<String, dynamic> getPricingBreakdown({
    required LatLng customerLocation,
    required LatLng mechanicLocation,
  }) {
    final LocationService locationService = LocationService();
    final double distanceKm = locationService.calculateDistance(
      customerLocation, 
      mechanicLocation
    );

    double serviceFee;
    double additionalKm = 0;
    String tier = '';
    
    if (distanceKm <= 10) {
      serviceFee = _tier1Fee;
      tier = 'Tier 1 (≤10km)';
    } else if (distanceKm <= 20) {
      serviceFee = _tier2Fee;
      tier = 'Tier 2 (≤20km)';
    } else if (distanceKm <= 30) {
      serviceFee = _tier3Fee;
      tier = 'Tier 3 (≤30km)';
    } else {
      additionalKm = distanceKm - 30;
      serviceFee = _tier3Fee + (additionalKm * _additionalFeePerKm);
      tier = 'Tier 3 + Additional';
    }
    
    final double totalAmount = serviceFee + _processingFee;

    return {
      'distance_km': distanceKm,
      'additional_km': additionalKm,
      'service_fee': serviceFee,
      'processing_fee': _processingFee,
      'total_amount': totalAmount,
      'tier': tier,
      'tier1_fee': _tier1Fee,
      'tier2_fee': _tier2Fee,
      'tier3_fee': _tier3Fee,
      'additional_fee_per_km': _additionalFeePerKm,
    };
  }  /// Calculate service fee from distance (helper method)
  double calculateServiceFeeFromDistance(double distanceKm) {
    if (distanceKm <= 10) {
      return _tier1Fee;
    } else if (distanceKm <= 20) {
      return _tier2Fee;
    } else if (distanceKm <= 30) {
      return _tier3Fee;
    } else {
      final double additionalKm = distanceKm - 30;
      return _tier3Fee + (additionalKm * _additionalFeePerKm);
    }
  }

  /// Get formatted pricing display text
  String getFormattedPricing({
    required LatLng customerLocation,
    required LatLng mechanicLocation,
  }) {
    final breakdown = getPricingBreakdown(
      customerLocation: customerLocation,
      mechanicLocation: mechanicLocation,
    );

    return 'Distance: ${breakdown['distance_km'].toStringAsFixed(1)}km\n'
           'Service Fee: ₱${breakdown['service_fee'].toStringAsFixed(2)}\n'
           'Processing Fee: ₱${breakdown['processing_fee'].toStringAsFixed(2)}\n'
           'Total: ₱${breakdown['total_amount'].toStringAsFixed(2)}';
  }  /// Constants for external access
  static double get processingFee => _processingFee;
  static double get tier1Fee => _tier1Fee;
  static double get tier2Fee => _tier2Fee;
  static double get tier3Fee => _tier3Fee;
  static double get additionalFeePerKm => _additionalFeePerKm;
  static double get minimumFee => _minimumFee;
}










