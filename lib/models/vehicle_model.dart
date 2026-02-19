import 'package:flutter/material.dart';

class Vehicle {
  final String id;
  final String name;
  final String plateNumber;
  final IconData icon;
  bool isPrimary;
  
  // Additional fields to match database
  final int? year;
  final String? color;
  final String? vehicleType;
  final String? make;
  final String? model;
  final String? vin;
  final String? fuelType;
  
  // Legacy fields for backward compatibility
  final String? brandId;
  final String? brandName;
  final String? modelId;
  final String? modelName;

  Vehicle({
    required this.id,
    required this.name,
    required this.plateNumber,
    required this.icon,
    this.isPrimary = false,
    this.year,
    this.color,
    this.vehicleType,
    this.make,
    this.model,
    this.vin,
    this.fuelType,
    // Legacy fields
    this.brandId,
    this.brandName,
    this.modelId,
    this.modelName,
  });

  // Helper getter for display name
  String get displayName {
    if (name.isNotEmpty) return name;
    if (make != null && model != null) {
      return '$make $model${year != null ? ' $year' : ''}';
    }
    if (brandName != null && modelName != null) {
      return '$brandName $modelName${year != null ? ' $year' : ''}';
    }
    return 'Unknown Vehicle';
  }

  // Static method to get icon from vehicle type
  static IconData getIconFromType(String? type) {
    switch (type?.toLowerCase()) {
      case 'motorcycle':
        return Icons.motorcycle;
      case 'truck':
        return Icons.local_shipping;
      case 'van':
        return Icons.airport_shuttle;
      case 'suv':
        return Icons.directions_car;
      default:
        return Icons.directions_car;
    }
  }

  // Factory constructor from database data
  factory Vehicle.fromMap(Map<String, dynamic> map) {
    return Vehicle(
      id: map['id'].toString(),
      name: '${map['make'] ?? ''} ${map['model'] ?? ''}'.trim(),
      plateNumber: map['license_plate'] ?? '',
      icon: getIconFromType(map['vehicle_type']),
      isPrimary: map['is_primary'] ?? false,
      year: map['year'],
      color: map['color'],
      vehicleType: map['vehicle_type'],
      make: map['make'],
      model: map['model'],
      vin: map['vin'],
      fuelType: map['fuel_type'],
    );
  }

  // Convert to map for database operations
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'make': make,
      'model': model,
      'year': year,
      'color': color,
      'license_plate': plateNumber,
      'vin': vin,
      'fuel_type': fuelType,
      'vehicle_type': vehicleType,
      'is_primary': isPrimary,
    };
  }

  // Copy with method for updates
  Vehicle copyWith({
    String? id,
    String? name,
    String? plateNumber,
    IconData? icon,
    bool? isPrimary,
    int? year,
    String? color,
    String? vehicleType,
    String? make,
    String? model,
    String? vin,
    String? fuelType,
  }) {
    return Vehicle(
      id: id ?? this.id,
      name: name ?? this.name,
      plateNumber: plateNumber ?? this.plateNumber,
      icon: icon ?? this.icon,
      isPrimary: isPrimary ?? this.isPrimary,
      year: year ?? this.year,
      color: color ?? this.color,
      vehicleType: vehicleType ?? this.vehicleType,
      make: make ?? this.make,
      model: model ?? this.model,
      vin: vin ?? this.vin,
      fuelType: fuelType ?? this.fuelType,
    );
  }
}










