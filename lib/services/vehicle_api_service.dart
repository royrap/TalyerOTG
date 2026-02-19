
class VehicleBrand {
  final String id;
  final String name;
  final String logoUrl;
  final List<VehicleModel> models;

  VehicleBrand({
    required this.id,
    required this.name,
    required this.logoUrl,
    required this.models,
  });

  factory VehicleBrand.fromJson(Map<String, dynamic> json) {
    return VehicleBrand(
      id: json['id'].toString(),
      name: json['name'],
      logoUrl: json['logoUrl'] ?? '',
      models: (json['models'] as List?)
          ?.map((model) => VehicleModel.fromJson(model))
          .toList() ?? [],
    );
  }
}

class VehicleModel {
  final String id;
  final String name;
  final String brandId;
  final int startYear;
  final int? endYear;
  final String type; // car, motorcycle, truck, van, suv

  VehicleModel({
    required this.id,
    required this.name,
    required this.brandId,
    required this.startYear,
    this.endYear,
    required this.type,
  });

  factory VehicleModel.fromJson(Map<String, dynamic> json) {
    return VehicleModel(
      id: json['id'].toString(),
      name: json['name'],
      brandId: json['brandId'].toString(),
      startYear: json['startYear'] ?? 2000,
      endYear: json['endYear'],
      type: json['type'] ?? 'car',
    );
  }
}

class VehicleApiService {
  static const String _baseUrl = 'https://vpic.nhtsa.dot.gov/api';
  
  // Static data for popular Filipino car brands and models
  static final List<VehicleBrand> _philippineVehicles = [
    VehicleBrand(
      id: '1',
      name: 'Toyota',
      logoUrl: 'https://logos-world.net/wp-content/uploads/2020/04/Toyota-Logo.png',
      models: [
        VehicleModel(id: '1', name: 'Vios', brandId: '1', startYear: 2003, type: 'car'),
        VehicleModel(id: '2', name: 'Camry', brandId: '1', startYear: 1982, type: 'car'),
        VehicleModel(id: '3', name: 'Corolla', brandId: '1', startYear: 1966, type: 'car'),
        VehicleModel(id: '4', name: 'Fortuner', brandId: '1', startYear: 2004, type: 'suv'),
        VehicleModel(id: '5', name: 'Innova', brandId: '1', startYear: 2004, type: 'van'),
        VehicleModel(id: '6', name: 'Hiace', brandId: '1', startYear: 1967, type: 'van'),
        VehicleModel(id: '7', name: 'Hilux', brandId: '1', startYear: 1968, type: 'truck'),
        VehicleModel(id: '8', name: 'RAV4', brandId: '1', startYear: 1994, type: 'suv'),
        VehicleModel(id: '9', name: 'Prius', brandId: '1', startYear: 1997, type: 'car'),
        VehicleModel(id: '10', name: 'Wigo', brandId: '1', startYear: 2014, type: 'car'),
      ],
    ),
    VehicleBrand(
      id: '2',
      name: 'Honda',
      logoUrl: 'https://logos-world.net/wp-content/uploads/2021/03/Honda-Logo.png',
      models: [
        VehicleModel(id: '11', name: 'Civic', brandId: '2', startYear: 1972, type: 'car'),
        VehicleModel(id: '12', name: 'Accord', brandId: '2', startYear: 1976, type: 'car'),
        VehicleModel(id: '13', name: 'CR-V', brandId: '2', startYear: 1995, type: 'suv'),
        VehicleModel(id: '14', name: 'HR-V', brandId: '2', startYear: 1998, type: 'suv'),
        VehicleModel(id: '15', name: 'City', brandId: '2', startYear: 1996, type: 'car'),
        VehicleModel(id: '16', name: 'Brio', brandId: '2', startYear: 2011, type: 'car'),
        VehicleModel(id: '17', name: 'Jazz', brandId: '2', startYear: 2001, type: 'car'),
        VehicleModel(id: '18', name: 'Pilot', brandId: '2', startYear: 2003, type: 'suv'),
        VehicleModel(id: '19', name: 'Click 125i', brandId: '2', startYear: 2006, type: 'motorcycle'),
        VehicleModel(id: '20', name: 'Beat', brandId: '2', startYear: 2008, type: 'motorcycle'),
      ],
    ),
    VehicleBrand(
      id: '3',
      name: 'Mitsubishi',
      logoUrl: 'https://logos-world.net/wp-content/uploads/2021/03/Mitsubishi-Logo.png',
      models: [
        VehicleModel(id: '21', name: 'Lancer', brandId: '3', startYear: 1973, type: 'car'),
        VehicleModel(id: '22', name: 'Montero Sport', brandId: '3', startYear: 1996, type: 'suv'),
        VehicleModel(id: '23', name: 'Pajero', brandId: '3', startYear: 1982, type: 'suv'),
        VehicleModel(id: '24', name: 'Strada', brandId: '3', startYear: 2006, type: 'truck'),
        VehicleModel(id: '25', name: 'Mirage', brandId: '3', startYear: 1978, type: 'car'),
        VehicleModel(id: '26', name: 'Outlander', brandId: '3', startYear: 2001, type: 'suv'),
        VehicleModel(id: '27', name: 'ASX', brandId: '3', startYear: 2010, type: 'suv'),
        VehicleModel(id: '28', name: 'Xpander', brandId: '3', startYear: 2017, type: 'van'),
      ],
    ),
    VehicleBrand(
      id: '4',
      name: 'Nissan',
      logoUrl: 'https://logos-world.net/wp-content/uploads/2021/03/Nissan-Logo.png',
      models: [
        VehicleModel(id: '29', name: 'Almera', brandId: '4', startYear: 1995, type: 'car'),
        VehicleModel(id: '30', name: 'Sentra', brandId: '4', startYear: 1982, type: 'car'),
        VehicleModel(id: '31', name: 'X-Trail', brandId: '4', startYear: 2000, type: 'suv'),
        VehicleModel(id: '32', name: 'Patrol', brandId: '4', startYear: 1951, type: 'suv'),
        VehicleModel(id: '33', name: 'Navara', brandId: '4', startYear: 1997, type: 'truck'),
        VehicleModel(id: '34', name: 'Juke', brandId: '4', startYear: 2010, type: 'suv'),
        VehicleModel(id: '35', name: 'Terra', brandId: '4', startYear: 2018, type: 'suv'),
        VehicleModel(id: '36', name: 'Livina', brandId: '4', startYear: 2006, type: 'van'),
      ],
    ),
    VehicleBrand(
      id: '5',
      name: 'Ford',
      logoUrl: 'https://logos-world.net/wp-content/uploads/2021/03/Ford-Logo.png',
      models: [
        VehicleModel(id: '37', name: 'Focus', brandId: '5', startYear: 1998, type: 'car'),
        VehicleModel(id: '38', name: 'Fiesta', brandId: '5', startYear: 1976, type: 'car'),
        VehicleModel(id: '39', name: 'Mustang', brandId: '5', startYear: 1964, type: 'car'),
        VehicleModel(id: '40', name: 'Explorer', brandId: '5', startYear: 1990, type: 'suv'),
        VehicleModel(id: '41', name: 'Ranger', brandId: '5', startYear: 1983, type: 'truck'),
        VehicleModel(id: '42', name: 'EcoSport', brandId: '5', startYear: 2003, type: 'suv'),
        VehicleModel(id: '43', name: 'Territory', brandId: '5', startYear: 2004, type: 'suv'),
        VehicleModel(id: '44', name: 'Everest', brandId: '5', startYear: 2003, type: 'suv'),
      ],
    ),
    VehicleBrand(
      id: '6',
      name: 'Hyundai',
      logoUrl: 'https://logos-world.net/wp-content/uploads/2021/03/Hyundai-Logo.png',
      models: [
        VehicleModel(id: '45', name: 'Accent', brandId: '6', startYear: 1994, type: 'car'),
        VehicleModel(id: '46', name: 'Elantra', brandId: '6', startYear: 1990, type: 'car'),
        VehicleModel(id: '47', name: 'Tucson', brandId: '6', startYear: 2004, type: 'suv'),
        VehicleModel(id: '48', name: 'Santa Fe', brandId: '6', startYear: 2000, type: 'suv'),
        VehicleModel(id: '49', name: 'Kona', brandId: '6', startYear: 2017, type: 'suv'),
        VehicleModel(id: '50', name: 'Starex', brandId: '6', startYear: 1997, type: 'van'),
        VehicleModel(id: '51', name: 'Reina', brandId: '6', startYear: 2017, type: 'car'),
        VehicleModel(id: '52', name: 'Creta', brandId: '6', startYear: 2014, type: 'suv'),
      ],
    ),
    VehicleBrand(
      id: '7',
      name: 'Suzuki',
      logoUrl: 'https://logos-world.net/wp-content/uploads/2021/03/Suzuki-Logo.png',
      models: [
        VehicleModel(id: '53', name: 'Swift', brandId: '7', startYear: 1983, type: 'car'),
        VehicleModel(id: '54', name: 'Vitara', brandId: '7', startYear: 1988, type: 'suv'),
        VehicleModel(id: '55', name: 'Jimny', brandId: '7', startYear: 1970, type: 'suv'),
        VehicleModel(id: '56', name: 'Ertiga', brandId: '7', startYear: 2012, type: 'van'),
        VehicleModel(id: '57', name: 'Celerio', brandId: '7', startYear: 2008, type: 'car'),
        VehicleModel(id: '58', name: 'Alto', brandId: '7', startYear: 1979, type: 'car'),
        VehicleModel(id: '59', name: 'XL7', brandId: '7', startYear: 1998, type: 'suv'),
        VehicleModel(id: '60', name: 'Raider J 110', brandId: '7', startYear: 2001, type: 'motorcycle'),
      ],
    ),
    VehicleBrand(
      id: '8',
      name: 'Yamaha',
      logoUrl: 'https://logos-world.net/wp-content/uploads/2021/03/Yamaha-Logo.png',
      models: [
        VehicleModel(id: '61', name: 'Mio', brandId: '8', startYear: 2003, type: 'motorcycle'),
        VehicleModel(id: '62', name: 'NMAX', brandId: '8', startYear: 2015, type: 'motorcycle'),
        VehicleModel(id: '63', name: 'Aerox', brandId: '8', startYear: 1997, type: 'motorcycle'),
        VehicleModel(id: '64', name: 'Sight', brandId: '8', startYear: 2020, type: 'motorcycle'),
        VehicleModel(id: '65', name: 'Sniper', brandId: '8', startYear: 2006, type: 'motorcycle'),
        VehicleModel(id: '66', name: 'YZF-R15', brandId: '8', startYear: 2008, type: 'motorcycle'),
        VehicleModel(id: '67', name: 'MT-03', brandId: '8', startYear: 2016, type: 'motorcycle'),
        VehicleModel(id: '68', name: 'Vega Force', brandId: '8', startYear: 2005, type: 'motorcycle'),
      ],
    ),
  ];

  /// Get all vehicle brands
  static Future<List<VehicleBrand>> getAllBrands() async {
    try {
      // Simulate API delay
      await Future.delayed(const Duration(milliseconds: 500));
      return _philippineVehicles;
    } catch (e) {
      print('Error fetching vehicle brands: $e');
      return [];
    }
  }

  /// Get models for a specific brand
  static Future<List<VehicleModel>> getModelsByBrand(String brandId) async {
    try {
      await Future.delayed(const Duration(milliseconds: 300));
      final brand = _philippineVehicles.firstWhere(
        (brand) => brand.id == brandId,
        orElse: () => VehicleBrand(id: '', name: '', logoUrl: '', models: []),
      );
      return brand.models;
    } catch (e) {
      print('Error fetching vehicle models: $e');
      return [];
    }
  }

  /// Search vehicles by name
  static Future<List<VehicleModel>> searchVehicles(String query) async {
    try {
      await Future.delayed(const Duration(milliseconds: 300));
      final allModels = _philippineVehicles
          .expand((brand) => brand.models)
          .where((model) => 
              model.name.toLowerCase().contains(query.toLowerCase()) ||
              _philippineVehicles
                  .firstWhere((brand) => brand.id == model.brandId)
                  .name
                  .toLowerCase()
                  .contains(query.toLowerCase()))
          .toList();
      return allModels;
    } catch (e) {
      print('Error searching vehicles: $e');
      return [];
    }
  }

  /// Get vehicle years for a specific model
  static List<int> getAvailableYears(VehicleModel model) {
    final currentYear = DateTime.now().year;
    final endYear = model.endYear ?? currentYear;
    final years = <int>[];
    
    for (int year = model.startYear; year <= endYear; year++) {
      years.add(year);
    }
    
    return years.reversed.toList(); // Most recent years first
  }

  /// Get vehicles by type
  static Future<List<VehicleModel>> getVehiclesByType(String type) async {
    try {
      await Future.delayed(const Duration(milliseconds: 300));
      final models = _philippineVehicles
          .expand((brand) => brand.models)
          .where((model) => model.type.toLowerCase() == type.toLowerCase())
          .toList();
      return models;
    } catch (e) {
      print('Error fetching vehicles by type: $e');
      return [];
    }
  }

  /// Get brand by ID
  static VehicleBrand? getBrandById(String brandId) {
    try {
      return _philippineVehicles.firstWhere((brand) => brand.id == brandId);
    } catch (e) {
      return null;
    }
  }

  /// Get model by ID
  static VehicleModel? getModelById(String modelId) {
    try {
      return _philippineVehicles
          .expand((brand) => brand.models)
          .firstWhere((model) => model.id == modelId);
    } catch (e) {
      return null;
    }
  }
}










