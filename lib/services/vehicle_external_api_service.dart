import 'dart:convert';
import 'package:http/http.dart' as http;

/// Service class for fetching vehicle data from external APIs
/// 
/// Supports:
/// - Cars, SUVs, Trucks, Vans via NHTSA API (no key required)
/// - Motorcycles via API Ninjas (requires API key)
class VehicleExternalApiService {
  // NHTSA API Base URL (free, no API key required)
  static const String _nhtsaBaseUrl = 'https://vpic.nhtsa.dot.gov/api/vehicles';
  
  // API Ninjas Base URL (requires API key)
  static const String _apiNinjasBaseUrl = 'https://api.api-ninjas.com/v1/motorcycles';
  
  /// Fetch all vehicle makes from NHTSA API
  /// 
  /// Returns a list of make names like ["Honda", "Toyota", "Ford", ...]
  /// Throws exception on error
  Future<List<String>> fetchAllMakes() async {
    try {
      final response = await http.get(
        Uri.parse('$_nhtsaBaseUrl/getallmakes?format=json'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['Results'] != null && data['Results'] is List) {
          final makes = (data['Results'] as List)
              .map((item) => item['Make_Name'] as String)
              .where((name) => name.isNotEmpty)
              .toList();
          
          makes.sort(); // Sort alphabetically
          return makes;
        } else {
          throw Exception('Invalid response format from NHTSA API');
        }
      } else {
        throw Exception('Failed to fetch makes: HTTP ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching vehicle makes: $e');
    }
  }

  /// Fetch car/truck/SUV models for a specific make from NHTSA API
  /// 
  /// [make] - The vehicle make (e.g., "Honda", "Toyota")
  /// 
  /// Returns a list of model objects with name and type information
  /// Throws exception on error
  Future<List<NHTSAVehicleModel>> fetchCarModels(String make) async {
    if (make.isEmpty) {
      throw ArgumentError('Make cannot be empty');
    }

    try {
      final encodedMake = Uri.encodeComponent(make);
      final response = await http.get(
        Uri.parse('$_nhtsaBaseUrl/getmodelsformake/$encodedMake?format=json'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['Results'] != null && data['Results'] is List) {
          final models = (data['Results'] as List)
              .map((item) => NHTSAVehicleModel(
                    name: item['Model_Name'] as String? ?? '',
                    makeId: item['Make_ID'] as int? ?? 0,
                    makeName: item['Make_Name'] as String? ?? make,
                    modelId: item['Model_ID'] as int? ?? 0,
                  ))
              .where((model) => model.name.isNotEmpty)
              .toList();
          
          models.sort((a, b) => a.name.compareTo(b.name)); // Sort alphabetically
          return models;
        } else {
          throw Exception('Invalid response format from NHTSA API');
        }
      } else if (response.statusCode == 404) {
        // No models found for this make
        return [];
      } else {
        throw Exception('Failed to fetch models: HTTP ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching car models for "$make": $e');
    }
  }

  /// Fetch vehicle types for a specific make from NHTSA API
  /// 
  /// [make] - The vehicle make (e.g., "Honda", "Toyota")
  /// 
  /// Returns a list of vehicle type names (e.g., "Passenger Car", "Truck", "SUV")
  /// Throws exception on error
  Future<List<String>> fetchVehicleTypes(String make) async {
    if (make.isEmpty) {
      throw ArgumentError('Make cannot be empty');
    }

    try {
      final encodedMake = Uri.encodeComponent(make);
      final response = await http.get(
        Uri.parse('$_nhtsaBaseUrl/GetVehicleTypesForMake/$encodedMake?format=json'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['Results'] != null && data['Results'] is List) {
          final types = (data['Results'] as List)
              .map((item) => item['VehicleTypeName'] as String? ?? '')
              .where((name) => name.isNotEmpty)
              .toList();
          
          types.sort(); // Sort alphabetically
          return types;
        } else {
          throw Exception('Invalid response format from NHTSA API');
        }
      } else if (response.statusCode == 404) {
        // No types found for this make
        return [];
      } else {
        throw Exception('Failed to fetch vehicle types: HTTP ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching vehicle types for "$make": $e');
    }
  }

  /// Fetch motorcycles for a specific make from API Ninjas
  /// 
  /// [make] - The motorcycle make (e.g., "Honda", "Yamaha", "Kawasaki")
  /// [apiKey] - Your API Ninjas API key (get free key at https://api-ninjas.com/)
  /// 
  /// Returns a list of motorcycle model objects with detailed information
  /// Throws exception on error
  Future<List<MotorcycleModel>> fetchMotorcycles(String make, String apiKey) async {
    if (make.isEmpty) {
      throw ArgumentError('Make cannot be empty');
    }
    
    if (apiKey.isEmpty) {
      throw ArgumentError('API key is required for motorcycle data');
    }

    try {
      final encodedMake = Uri.encodeComponent(make);
      final response = await http.get(
        Uri.parse('$_apiNinjasBaseUrl?make=$encodedMake'),
        headers: {
          'X-Api-Key': apiKey,
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data is List) {
          final motorcycles = data
              .map((item) => MotorcycleModel(
                    make: item['make'] as String? ?? make,
                    model: item['model'] as String? ?? '',
                    year: item['year'] as String? ?? '',
                    type: item['type'] as String? ?? '',
                    displacement: item['displacement'] as String? ?? '',
                    engine: item['engine'] as String? ?? '',
                    power: item['power'] as String? ?? '',
                    torque: item['torque'] as String? ?? '',
                    compression: item['compression'] as String? ?? '',
                    boreStroke: item['bore_stroke'] as String? ?? '',
                    valvesPerCylinder: item['valves_per_cylinder'] as String? ?? '',
                    fuelSystem: item['fuel_system'] as String? ?? '',
                    fuelControl: item['fuel_control'] as String? ?? '',
                    cooling: item['cooling'] as String? ?? '',
                    gearbox: item['gearbox'] as String? ?? '',
                    transmission: item['transmission'] as String? ?? '',
                    clutch: item['clutch'] as String? ?? '',
                    frame: item['frame'] as String? ?? '',
                    frontSuspension: item['front_suspension'] as String? ?? '',
                    rearSuspension: item['rear_suspension'] as String? ?? '',
                    frontBrakes: item['front_brakes'] as String? ?? '',
                    rearBrakes: item['rear_brakes'] as String? ?? '',
                    frontTire: item['front_tire'] as String? ?? '',
                    rearTire: item['rear_tire'] as String? ?? '',
                    seatHeight: item['seat_height'] as String? ?? '',
                    dryWeight: item['dry_weight'] as String? ?? '',
                    wetWeight: item['wet_weight'] as String? ?? '',
                    wheelbase: item['wheelbase'] as String? ?? '',
                    fuelCapacity: item['fuel_capacity'] as String? ?? '',
                    starterType: item['starter'] as String? ?? '',
                  ))
              .where((moto) => moto.model.isNotEmpty)
              .toList();
          
          motorcycles.sort((a, b) => a.model.compareTo(b.model)); // Sort by model
          return motorcycles;
        } else {
          throw Exception('Invalid response format from API Ninjas');
        }
      } else if (response.statusCode == 400) {
        throw Exception('Invalid request to API Ninjas. Check make name.');
      } else if (response.statusCode == 401) {
        throw Exception('Invalid API key. Please check your API Ninjas key.');
      } else if (response.statusCode == 404) {
        // No motorcycles found for this make
        return [];
      } else {
        throw Exception('Failed to fetch motorcycles: HTTP ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching motorcycles for "$make": $e');
    }
  }

  /// Unified method to fetch models based on vehicle type
  /// 
  /// [make] - The vehicle make
  /// [vehicleType] - Either 'car' or 'motorcycle'
  /// [apiKey] - Required only for motorcycles, optional for cars
  /// 
  /// Returns a list of model names as strings
  /// Throws exception on error
  Future<List<String>> fetchModels({
    required String make,
    required String vehicleType,
    String? apiKey,
  }) async {
    if (vehicleType.toLowerCase() == 'motorcycle') {
      if (apiKey == null || apiKey.isEmpty) {
        throw ArgumentError('API key is required for motorcycle data');
      }
      final motorcycles = await fetchMotorcycles(make, apiKey);
      return motorcycles.map((m) => m.model).toList();
    } else {
      // Default to car/truck/SUV/van
      final models = await fetchCarModels(make);
      return models.map((m) => m.name).toList();
    }
  }
}

/// Model class for car/truck/SUV data from NHTSA API
class NHTSAVehicleModel {
  final String name;
  final int makeId;
  final String makeName;
  final int modelId;

  NHTSAVehicleModel({
    required this.name,
    required this.makeId,
    required this.makeName,
    required this.modelId,
  });

  @override
  String toString() => name;

  Map<String, dynamic> toJson() => {
        'name': name,
        'makeId': makeId,
        'makeName': makeName,
        'modelId': modelId,
      };
}

/// Model class for motorcycle data from API Ninjas
class MotorcycleModel {
  final String make;
  final String model;
  final String year;
  final String type;
  final String displacement;
  final String engine;
  final String power;
  final String torque;
  final String compression;
  final String boreStroke;
  final String valvesPerCylinder;
  final String fuelSystem;
  final String fuelControl;
  final String cooling;
  final String gearbox;
  final String transmission;
  final String clutch;
  final String frame;
  final String frontSuspension;
  final String rearSuspension;
  final String frontBrakes;
  final String rearBrakes;
  final String frontTire;
  final String rearTire;
  final String seatHeight;
  final String dryWeight;
  final String wetWeight;
  final String wheelbase;
  final String fuelCapacity;
  final String starterType;

  MotorcycleModel({
    required this.make,
    required this.model,
    required this.year,
    required this.type,
    required this.displacement,
    required this.engine,
    required this.power,
    required this.torque,
    required this.compression,
    required this.boreStroke,
    required this.valvesPerCylinder,
    required this.fuelSystem,
    required this.fuelControl,
    required this.cooling,
    required this.gearbox,
    required this.transmission,
    required this.clutch,
    required this.frame,
    required this.frontSuspension,
    required this.rearSuspension,
    required this.frontBrakes,
    required this.rearBrakes,
    required this.frontTire,
    required this.rearTire,
    required this.seatHeight,
    required this.dryWeight,
    required this.wetWeight,
    required this.wheelbase,
    required this.fuelCapacity,
    required this.starterType,
  });

  @override
  String toString() => '$make $model ($year)';

  Map<String, dynamic> toJson() => {
        'make': make,
        'model': model,
        'year': year,
        'type': type,
        'displacement': displacement,
        'engine': engine,
        'power': power,
        'torque': torque,
        'compression': compression,
        'boreStroke': boreStroke,
        'valvesPerCylinder': valvesPerCylinder,
        'fuelSystem': fuelSystem,
        'fuelControl': fuelControl,
        'cooling': cooling,
        'gearbox': gearbox,
        'transmission': transmission,
        'clutch': clutch,
        'frame': frame,
        'frontSuspension': frontSuspension,
        'rearSuspension': rearSuspension,
        'frontBrakes': frontBrakes,
        'rearBrakes': rearBrakes,
        'frontTire': frontTire,
        'rearTire': rearTire,
        'seatHeight': seatHeight,
        'dryWeight': dryWeight,
        'wetWeight': wetWeight,
        'wheelbase': wheelbase,
        'fuelCapacity': fuelCapacity,
        'starterType': starterType,
      };
}
