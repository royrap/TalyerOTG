import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/supabase_service.dart';
import '../services/ai_description_analysis_service.dart';
import '../theme/roadaid_colors.dart';
import 'vehicle_details_screen.dart';

class ShopServicesScreen extends StatefulWidget {
  final Map<String, dynamic> shopData;
  
  const ShopServicesScreen({
    super.key,
    required this.shopData,
  });

  @override
  State<ShopServicesScreen> createState() => _ShopServicesScreenState();
}

class _ShopServicesScreenState extends State<ShopServicesScreen> {
  List<Map<String, dynamic>> _services = [];
  bool _servicesLoading = true;
  String _shopDistance = 'Calculating...';
  LatLng? _customerLocation;
  LatLng? _shopLocation;

  // Helper method to validate shop data
  bool _validateShopData() {
    final shopId = widget.shopData['id'];
    final shopName = widget.shopData['name'] ?? widget.shopData['shop_name'];
    
    print('🔍 SHOP DATA VALIDATION:');
    print('   - Shop ID: $shopId');
    print('   - Shop Name: $shopName');
    print('   - Full shop data: ${widget.shopData}');
    
    if (shopId == null) {
      print('❌ ERROR: Shop ID is null in widget.shopData');
      return false;
    }
    
    print('✅ Shop validation passed - ID: $shopId, Name: $shopName');
    return true;
  }

  @override
  void initState() {
    super.initState();
    
    // Validate shop data before proceeding
    if (!_validateShopData()) {
      setState(() {
        _servicesLoading = false;
      });
      return;
    }
    
    _loadShopServices();
    _calculateDistance();
  }

  Future<void> _loadShopServices() async {
    try {
      final shopId = widget.shopData['id'];
      print('🔍 Loading services for shop: $shopId');
      
      // Validate shop ID exists
      if (shopId == null) {
        print('❌ Shop ID is null, cannot load services');
        setState(() {
          _servicesLoading = false;
        });
        return;
      }
      
      // 🎯 DIRECT SHOP SERVICES QUERY
      // Query shop_services table directly with proper shop isolation
      print('🔎 Querying shop_services table for shop_id: $shopId');
      
      final servicesResponse = await SupabaseService.client
          .from('shop_services')
          .select('''
            id,
            shop_id,
            service_name,
            description,
            base_price,
            custom_price,
            estimated_duration,
            is_active,
            availability_status,
            service_quality_level,
            requires_appointment,
            special_requirements,
            is_custom,
            custom_name,
            custom_description,
            category_id,
            service_categories!shop_services_category_id_fkey(
              id,
              name,
              description,
              icon_name,
              base_price
            )
          ''')
          .eq('shop_id', shopId)  // 🎯 Filter by specific shop ID
          .eq('is_active', true)  // Only active services
          .or('availability_status.eq.available,availability_status.eq.by_appointment')  // Only available services
          .order('service_name');
      
      print('✅ Direct query response: ${servicesResponse.length} services found for shop $shopId');
      print('📊 Services data: $servicesResponse');

      // If no services found, show empty state
      if (servicesResponse.isEmpty) {
        print('⚠️ No active services available at shop $shopId');
        if (mounted) {
          setState(() {
            _services = [];
            _servicesLoading = false;
          });
        }
        return;
      }

      if (mounted) {
        setState(() {
          _services = servicesResponse.map<Map<String, dynamic>>((item) {
            print('📝 Processing service item: ${item['service_name']} (ID: ${item['id']})');
            
            // Verify shop ownership
            final serviceShopId = item['shop_id'];
            if (serviceShopId != shopId) {
              print('⚠️ SHOP ISOLATION WARNING: Service ${item['id']} belongs to shop $serviceShopId, not $shopId');
            }
            
            // Handle both standard and custom services
            String serviceName;
            String description;
            String categoryName;
            String iconName = 'build';
            
            if (item['is_custom'] == true) {
              // Custom service
              serviceName = item['custom_name'] ?? item['service_name'] ?? 'Custom Service';
              description = item['custom_description'] ?? item['description'] ?? 'Custom automotive service';
              categoryName = 'Custom Service';
              iconName = 'build_circle';
            } else {
              // Standard service with category
              serviceName = item['service_name'] ?? 'Service';
              description = item['description'] ?? 'Professional automotive service';
              
              // Extract category information
              final category = item['service_categories'];
              if (category != null) {
                categoryName = category['name'] ?? 'General Service';
                iconName = category['icon_name'] ?? 'build';
                // Use category description as fallback if service description is empty
                if (description.isEmpty || description == 'Professional automotive service') {
                  description = category['description'] ?? description;
                }
              } else {
                categoryName = 'General Service';
              }
            }
            
            // Calculate effective price (custom_price takes precedence over base_price)
            final effectivePrice = _parsePrice(item['custom_price'] ?? item['base_price'] ?? 500.0);
            
            final serviceData = {
              'id': item['id'],
              'shop_id': serviceShopId,
              'service_name': serviceName,
              'description': description,
              'price': effectivePrice,
              'estimated_duration': item['estimated_duration'] ?? 60,
              'icon_name': iconName,
              'category_name': categoryName,
              'category_id': item['category_id'],
              'quality_level': item['service_quality_level'] ?? 'standard',
              'satisfaction_score': 4.5, // Default rating
              'requires_appointment': item['requires_appointment'] ?? false,
              'special_requirements': item['special_requirements'],
              'is_available': item['is_active'] ?? true,
              'availability_status': item['availability_status'] ?? 'available',
              'is_custom': item['is_custom'] ?? false,
            };
            
            print('✅ Mapped service: $serviceName - ₱${effectivePrice.toStringAsFixed(2)} (Shop: $serviceShopId)');
            return serviceData;
          }).toList();
          _servicesLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error loading shop services: $e');
      if (mounted) {
        setState(() {
          _servicesLoading = false;
        });
      }
    }
  }

  // Helper method to parse price from various data types
  double _parsePrice(dynamic price) {
    if (price == null) return 500.0;
    if (price is double) return price;
    if (price is int) return price.toDouble();
    if (price is String) {
      return double.tryParse(price) ?? 500.0;
    }
    return 500.0;
  }

  Future<void> _calculateDistance() async {
    try {
      // Get customer's current location
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );
      
      _customerLocation = LatLng(position.latitude, position.longitude);
      
      // Get shop location from widget data
      final shopLat = widget.shopData['latitude'];
      final shopLng = widget.shopData['longitude'];
      
      if (shopLat != null && shopLng != null) {
        _shopLocation = LatLng(
          double.parse(shopLat.toString()),
          double.parse(shopLng.toString()),
        );
        
        // Calculate distance
        final distance = _calculateDistanceBetweenPoints(
          _customerLocation!,
          _shopLocation!,
        );
        
        if (mounted) {
          setState(() {
            _shopDistance = '${distance.toStringAsFixed(1)} km';
          });
        }
      }
    } catch (e) {
      print('Error calculating distance: $e');
      if (mounted) {
        setState(() {
          _shopDistance = 'Distance unavailable';
        });
      }
    }
  }

  double _calculateDistanceBetweenPoints(LatLng point1, LatLng point2) {
    return Geolocator.distanceBetween(
      point1.latitude, point1.longitude,
      point2.latitude, point2.longitude,
    ) / 1000; // Convert to kilometers
  }

  Color _getServiceColor(String? iconName) {
    switch (iconName?.toLowerCase()) {
      case 'settings':
        return Colors.blue;
      case 'electrical_services':
        return Colors.orange;
      case 'tire_repair':
        return Colors.purple;
      case 'local_gas_station':
        return Colors.red;
      case 'car_repair':
        return RoadAidColors.warning;
      case 'battery_charging_full':
        return Colors.amber;
      default:
        return const Color.fromARGB(255, 176, 12, 1);
    }
  }

  // Service selection state
  Set<String> _selectedServiceIds = {};
  
  void _toggleServiceSelection(Map<String, dynamic> service) {
    setState(() {
      final serviceId = service['id'].toString();
      if (_selectedServiceIds.contains(serviceId)) {
        _selectedServiceIds.remove(serviceId);
      } else {
        _selectedServiceIds.add(serviceId);
      }
    });
  }
  
  void _requestService() {
    if (_selectedServiceIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one service'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    // Get selected services
    final selectedServices = _services.where((service) => 
        _selectedServiceIds.contains(service['id'].toString())).toList();
    
    // Calculate total price
    final totalPrice = selectedServices.fold<double>(0.0, (sum, service) => sum + service['price']);
    
    // Navigate to Vehicle Details Screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VehicleDetailsScreen(
          issueType: 'repair',
          issueDescription: selectedServices.map((s) => s['service_name']).join(', '),
          issueTitle: selectedServices.length > 1 
              ? 'Multiple Services (${selectedServices.length})' 
              : selectedServices.first['service_name'],
          preSelectedMechanic: {
            'shopData': widget.shopData,
            'selectedServices': selectedServices,
            'shopId': widget.shopData['id'],
            'servicePrice': totalPrice,
            'requiresTowing': false,
            'shopDistance': _shopDistance,
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shopName = widget.shopData['name'] ?? widget.shopData['shop_name'] ?? 'Auto Shop';
    final ownerName = widget.shopData['owner_name'] ?? 'Shop Owner';
    final rating = widget.shopData['rating']?.toDouble() ?? 0.0;
    final isAvailable = widget.shopData['is_available'] ?? false;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: Text(
          '$shopName Services',
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [
          // Shop Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color.fromARGB(255, 176, 12, 1),
                  const Color.fromARGB(255, 200, 50, 20),
                ],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(51),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.store,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            shopName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Owner: $ownerName',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.star_rounded,
                                color: Colors.amber[300],
                                size: 18,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                rating.toStringAsFixed(1),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Icon(
                                Icons.location_on_rounded,
                                color: Colors.white70,
                                size: 18,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _shopDistance,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isAvailable ? Color(0xFFEF5350).withAlpha(51) : Colors.orange.withAlpha(51),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isAvailable ? Color(0xFFEF5350).withAlpha(102) : Colors.orange.withAlpha(102),
                        ),
                      ),
                      child: Text(
                        isAvailable ? 'Open' : 'Closed',
                        style: TextStyle(
                          color: isAvailable ? Colors.red[100] : Colors.orange[100],
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Services List
          Expanded(
            child: _servicesLoading
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color.fromARGB(255, 176, 12, 1),
                          ),
                        ),
                        SizedBox(height: 16),
                        Text('Loading services...'),
                      ],
                    ),
                  )
                : _services.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.construction_outlined,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Services Coming Soon',
                              style: TextStyle(
                                fontSize: 20,
                                color: Colors.grey[700],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${widget.shopData['name'] ?? widget.shopData['shop_name'] ?? 'This shop'} is still setting up their services',
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.blue.withAlpha(26),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.blue.withAlpha(77)),
                              ),
                              child: Column(
                                children: [
                                  Icon(Icons.info_outline, color: Colors.blue[600], size: 20),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Each shop customizes their own services and prices. Please check back later or try another shop.',
                                    style: TextStyle(
                                      color: Colors.blue[700],
                                      fontSize: 13,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _services.length,
                        itemBuilder: (context, index) {
                          final service = _services[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: _buildSelectableServiceCard(service),
                          );
                        },
                      ),
          ),
          
          // Request Service Button (when services selected)
          if (_selectedServiceIds.isNotEmpty)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Price Summary
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(255, 176, 12, 1).withAlpha(26),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color.fromARGB(255, 176, 12, 1).withAlpha(77),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Selected Services (${_selectedServiceIds.length})',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ..._services.where((service) => 
                            _selectedServiceIds.contains(service['id'].toString())).map((service) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    service['service_name'],
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ),
                                Text(
                                  '₱${service['price'].toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        const Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total Amount:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              '₱${_services.where((service) => _selectedServiceIds.contains(service['id'].toString())).fold<double>(0.0, (sum, service) => sum + service['price']).toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: Color.fromARGB(255, 176, 12, 1),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Request Service Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _requestService,
                      icon: const Icon(Icons.build),
                      label: const Text(
                        'Request Service',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromARGB(255, 176, 12, 1),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSelectableServiceCard(Map<String, dynamic> service) {
    final serviceColor = _getServiceColor(service['icon_name']);
    final isSelected = _selectedServiceIds.contains(service['id'].toString());
    final qualityLevel = service['quality_level'] ?? 'standard';
    final requiresAppointment = service['requires_appointment'] ?? false;
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? serviceColor : Colors.grey[200]!,
          width: isSelected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isSelected 
                ? serviceColor.withAlpha(51) 
                : Colors.black.withAlpha(20),
            blurRadius: 12,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _toggleServiceSelection(service),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Service name with quality indicator
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              service['service_name'],
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? serviceColor : Colors.black87,
                              ),
                            ),
                          ),
                          if (qualityLevel != 'standard') ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _getQualityColor(qualityLevel).withAlpha(26),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _getQualityColor(qualityLevel).withAlpha(77),
                                ),
                              ),
                              child: Text(
                                qualityLevel.toUpperCase(),
                                style: TextStyle(
                                  color: _getQualityColor(qualityLevel),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      
                      // Service description
                      Text(
                        service['description'] ?? 'Professional automotive service',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      
                      // Price only
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Color(0xFFEF5350).withAlpha(26),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '₱${service['price'].toStringAsFixed(2)}',
                          style: TextStyle(
                            color: Colors.red[700],
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      
                      // Special indicators
                      if (requiresAppointment || service['special_requirements'] != null) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            if (requiresAppointment) ...[
                              Text(
                                'Appointment Required',
                                style: TextStyle(
                                  color: Colors.orange[600],
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                            if (service['special_requirements'] != null) ...[
                              if (requiresAppointment) const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  service['special_requirements'],
                                  style: TextStyle(
                                    color: Colors.blue[600],
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                // Selection indicator
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isSelected ? serviceColor : Colors.transparent,
                    border: Border.all(
                      color: isSelected ? serviceColor : Colors.grey[400]!,
                      width: 2,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: isSelected
                      ? const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 16,
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Helper method to get quality level colors
  Color _getQualityColor(String qualityLevel) {
    switch (qualityLevel.toLowerCase()) {
      case 'premium':
        return Colors.purple;
      case 'specialized':
        return Colors.blue;
      case 'basic':
        return Colors.grey;
      default:
        return Colors.red;
    }
  }

}

// 🎯 Unified Service Request Page - Everything in One Screen
class UnifiedServiceRequestPage extends StatefulWidget {
  final Map<String, dynamic> shopData;
  final String shopDistance;
  
  const UnifiedServiceRequestPage({
    super.key,
    required this.shopData,
    required this.shopDistance,
  });

  @override
  State<UnifiedServiceRequestPage> createState() => _UnifiedServiceRequestPageState();
}

class _UnifiedServiceRequestPageState extends State<UnifiedServiceRequestPage> {
  final TextEditingController _issueController = TextEditingController();
  final TextEditingController _vehicleModelController = TextEditingController();
  final TextEditingController _vehicleYearController = TextEditingController();
  final TextEditingController _vehiclePlateController = TextEditingController();
  final TextEditingController _customerNameController = TextEditingController();
  final TextEditingController _customerPhoneController = TextEditingController();
  final TextEditingController _pickupLocationController = TextEditingController();
  
  // Service Selection
  Set<String> _selectedServices = {};
  
  // AI Analysis
  bool _requiresTowing = false;
  String _towingReason = '';
  AIAnalysisResult? _aiAnalysis;
  
  // UI State
  int _currentStep = 0;
  bool _isAnalyzing = false;
  
  // Available services (simplified)
  final List<Map<String, dynamic>> _availableServices = [
    {
      'id': 'inspection',
      'name': 'Vehicle Inspection',
      'description': 'Comprehensive diagnostic check',
      'icon': Icons.search,
      'color': Colors.blue,
    },
    {
      'id': 'mechanical',
      'name': 'Mechanical Repair',
      'description': 'Engine and mechanical issues',
      'icon': Icons.build,
      'color': Colors.orange,
    },
    {
      'id': 'electrical',
      'name': 'Electrical Service',
      'description': 'Battery and electrical systems',
      'icon': Icons.electrical_services,
      'color': Colors.amber,
    },
    {
      'id': 'tire',
      'name': 'Tire Service',
      'description': 'Tire repair and replacement',
      'icon': Icons.tire_repair,
      'color': Colors.purple,
    },
    {
      'id': 'fuel',
      'name': 'Fuel Service',
      'description': 'Fuel delivery and system repair',
      'icon': Icons.local_gas_station,
      'color': Colors.red,
    },
  ];

  @override
  void initState() {
    super.initState();
    // Auto-select inspection as default
    _selectedServices.add('inspection');
    _loadUserData();
  }

  @override
  void dispose() {
    _issueController.dispose();
    _vehicleModelController.dispose();
    _vehicleYearController.dispose();
    _vehiclePlateController.dispose();
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _pickupLocationController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final user = SupabaseService.client.auth.currentUser;
      if (user != null) {
        final response = await SupabaseService.client
            .from('user_profiles')
            .select('first_name, last_name, phone_number')
            .eq('id', user.id)
            .single();
        
        if (mounted) {
          setState(() {
            _customerNameController.text = '${response['first_name'] ?? ''} ${response['last_name'] ?? ''}'.trim();
            _customerPhoneController.text = response['phone_number'] ?? '';
          });
        }
      }
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  // 🤖 AI Analysis with Towing Detection
  Future<void> _performAIAnalysis() async {
    final description = _issueController.text.trim();
    if (description.isEmpty) return;

    setState(() {
      _isAnalyzing = true;
    });

    try {
      // Simulate AI analysis
      await Future.delayed(const Duration(milliseconds: 1500));
      
      final analysis = AIDescriptionAnalysisService.analyzeDescription(description);
      final requiresTowing = AIDescriptionAnalysisService.requiresTowing(description);
      final towingReason = AIDescriptionAnalysisService.getTowingReason(description);

      setState(() {
        _aiAnalysis = analysis;
        _requiresTowing = requiresTowing;
        _towingReason = towingReason;
        _isAnalyzing = false;
      });

      // Auto-suggest services based on analysis
      if (requiresTowing) {
        _showTowingRequiredDialog();
      } else {
        _autoSuggestServices(analysis);
      }
      
    } catch (e) {
      setState(() {
        _isAnalyzing = false;
      });
      print('AI analysis error: $e');
    }
  }

  void _autoSuggestServices(AIAnalysisResult analysis) {
    setState(() {
      // Clear current selection except inspection
      _selectedServices = {'inspection'};
      
      // Add relevant services based on analysis
      switch (analysis.category.toLowerCase()) {
        case 'engine':
        case 'mechanical':
          _selectedServices.add('mechanical');
          break;
        case 'electrical':
        case 'battery':
          _selectedServices.add('electrical');
          break;
        case 'tire':
        case 'wheel':
          _selectedServices.add('tire');
          break;
        case 'fuel':
          _selectedServices.add('fuel');
          break;
      }
    });

    // Show suggestion message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('AI suggested services based on your description'),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showTowingRequiredDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.car_repair, color: RoadAidColors.warning, size: 24),
            const SizedBox(width: 8),
            const Text('Towing Required'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withAlpha(26),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withAlpha(77)),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, color: Colors.red[600], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Vehicle needs to be towed to shop',
                      style: TextStyle(
                        color: Colors.red[700],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text('Reason:', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(_towingReason.isNotEmpty ? _towingReason : 'Issue requires shop facilities'),
            const SizedBox(height: 16),
            Text('What happens next:', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.local_shipping, 'Vehicle towed to shop'),
            _buildInfoRow(Icons.build, 'Professional inspection'),
            _buildInfoRow(Icons.phone, 'Shop contacts you with estimate'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                _selectedServices = {'inspection'}; // Only inspection for towing
                _currentStep = 2; // Skip to vehicle details
              });
            },
            child: const Text('Continue with Towing'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: TextStyle(color: Colors.grey[700], fontSize: 14)),
          ),
        ],
      ),
    );
  }

  void _submitRequest() async {
    // Validate form
    if (_selectedServices.isEmpty) {
      _showErrorSnackBar('Please select at least one service');
      return;
    }
    
    if (_vehicleModelController.text.trim().isEmpty) {
      _showErrorSnackBar('Please enter vehicle model');
      return;
    }

    if (_customerNameController.text.trim().isEmpty) {
      _showErrorSnackBar('Please enter your name');
      return;
    }

    if (_customerPhoneController.text.trim().isEmpty) {
      _showErrorSnackBar('Please enter your phone number');
      return;
    }

    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Get current user
      final user = SupabaseService.client.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Get customer location for distance calculation
      final position = await Geolocator.getCurrentPosition();
      
      // Create service request with proper targeting
      final requestData = {
        'customer_id': user.id,
        'shop_id': widget.shopData['id'], // Specific shop ID - only this shop will see the request
  // Routing fields for fan-out: mark as shop-based and set preferred shop
  'request_type': 'shop_based',
  'preferred_shop_id': widget.shopData['id'],
        'title': _selectedServices.length > 1 
            ? 'Multiple Services (${_selectedServices.length})' 
            : _selectedServices.first,
        'description': _issueController.text.trim(),
        'pickup_latitude': position.latitude,
        'pickup_longitude': position.longitude,
        'pickup_address': _pickupLocationController.text.trim().isNotEmpty 
            ? _pickupLocationController.text.trim() 
            : 'Current location',
        'status': 'pending',
        'payment_status': 'pending',
        'service_type': 'repair',
        'priority': _requiresTowing ? 'high' : 'normal',
        'is_emergency': _requiresTowing,
        'vehicle_info': {
          'model': _vehicleModelController.text.trim(),
          'year': _vehicleYearController.text.trim(),
          'plate': _vehiclePlateController.text.trim(),
        },
        'additional_details': {
          'customer_name': _customerNameController.text.trim(),
          'customer_phone': _customerPhoneController.text.trim(),
          'selected_services': _selectedServices.toList(),
          'requires_towing': _requiresTowing,
          'towing_reason': _towingReason,
          'request_source': 'specific_shop', // Flag to indicate this was sent to a specific shop
          'shop_selected': true, // Indicates customer chose this specific shop
        },
        'created_at': DateTime.now().toIso8601String(),
      };

      // Submit to database
      await SupabaseService.client.from('service_requests').insert(requestData);

      // Close loading dialog
      Navigator.of(context).pop();

      // Show success and navigate back
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 24),
              const SizedBox(width: 8),
              const Text('Request Sent!'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Your service request has been sent to ${widget.shopData['name'] ?? widget.shopData['shop_name'] ?? 'the shop'}.'),
              const SizedBox(height: 12),
              if (_requiresTowing) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withAlpha(26),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info, color: Colors.orange[700], size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Towing service included in request',
                          style: TextStyle(color: Colors.orange[700]),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Text('Services: ${_selectedServices.join(', ')}'),
              const SizedBox(height: 8),
              Text('The shop will contact you shortly at ${_customerPhoneController.text}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(context).pop(); // Go back to main screen
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );

    } catch (e) {
      Navigator.of(context).pop(); // Close loading dialog
      _showErrorSnackBar('Error submitting request: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: RoadAidColors.warning,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text(
          'Request Service',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          // Shop Header
          Container(
            width: double.infinity,
            color: Colors.white,
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(255, 176, 12, 1).withAlpha(26),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.store,
                    color: Color.fromARGB(255, 176, 12, 1),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.shopData['name'] ?? widget.shopData['shop_name'] ?? 'Auto Shop',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${widget.shopDistance} • ${widget.shopData['owner_name'] ?? 'Shop Owner'}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Progress Indicator
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                _buildStepIndicator(0, 'Issue', _currentStep >= 0),
                Expanded(child: Container(height: 2, color: _currentStep >= 1 ? Colors.red : Colors.grey[300])),
                _buildStepIndicator(1, 'Services', _currentStep >= 1),
                Expanded(child: Container(height: 2, color: _currentStep >= 2 ? Colors.red : Colors.grey[300])),
                _buildStepIndicator(2, 'Vehicle', _currentStep >= 2),
              ],
            ),
          ),

          // Main Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Step 1: Issue Description
                  if (_currentStep >= 0) ...[
                    _buildSectionCard(
                      title: '1. Describe Your Issue',
                      child: Column(
                        children: [
                          TextField(
                            controller: _issueController,
                            maxLines: 4,
                            decoration: const InputDecoration(
                              hintText: 'e.g., Car won\'t start, strange noise, flat tire...',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.all(16),
                            ),
                            onChanged: (value) {
                              if (value.length > 10) {
                                Future.delayed(const Duration(milliseconds: 2000), () {
                                  if (_issueController.text == value) {
                                    _performAIAnalysis();
                                  }
                                });
                              }
                            },
                          ),
                          if (_isAnalyzing) ...[
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                                const SizedBox(width: 8),
                                Text('AI analyzing...', style: TextStyle(color: Colors.grey[600])),
                              ],
                            ),
                          ],
                          if (_aiAnalysis != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue.withAlpha(26),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.blue.withAlpha(77)),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.psychology, color: Colors.blue[700], size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'AI detected: ${_aiAnalysis!.category} issue',
                                      style: TextStyle(color: Colors.blue[700], fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () => setState(() => _currentStep = 1),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color.fromARGB(255, 176, 12, 1),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: const Text('Next: Select Services'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Step 2: Service Selection
                  if (_currentStep >= 1) ...[
                    _buildSectionCard(
                      title: '2. Select Services',
                      child: Column(
                        children: [
                          if (_requiresTowing) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.red.withAlpha(26),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.red.withAlpha(77)),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.car_repair, color: Colors.red[600], size: 20),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                    child: Text(
                                      'Towing Required - Vehicle needs shop repair',
                                      style: TextStyle(fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: _availableServices.map((service) {
                              final isSelected = _selectedServices.contains(service['id']);
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    if (isSelected) {
                                      _selectedServices.remove(service['id']);
                                    } else {
                                      _selectedServices.add(service['id']);
                                    }
                                  });
                                },
                                child: Container(
                                  width: (MediaQuery.of(context).size.width - 64) / 2,
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: isSelected ? service['color'].withAlpha(26) : Colors.white,
                                    border: Border.all(
                                      color: isSelected ? service['color'] : Colors.grey[300]!,
                                      width: isSelected ? 2 : 1,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(
                                        service['icon'],
                                        size: 32,
                                        color: isSelected ? service['color'] : Colors.grey[600],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        service['name'],
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: isSelected ? service['color'] : Colors.black87,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        service['description'],
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _selectedServices.isNotEmpty 
                                  ? () => setState(() => _currentStep = 2)
                                  : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color.fromARGB(255, 176, 12, 1),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: Text('Next: Vehicle Details (${_selectedServices.length} services)'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Step 3: Vehicle Details
                  if (_currentStep >= 2) ...[
                    _buildSectionCard(
                      title: '3. Vehicle & Contact Details',
                      child: Column(
                        children: [
                          // Vehicle Info
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _vehicleModelController,
                                  decoration: const InputDecoration(
                                    labelText: 'Vehicle Model *',
                                    hintText: 'e.g., Toyota Camry',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: _vehicleYearController,
                                  decoration: const InputDecoration(
                                    labelText: 'Year',
                                    hintText: '2020',
                                    border: OutlineInputBorder(),
                                  ),
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _vehiclePlateController,
                            decoration: const InputDecoration(
                              labelText: 'License Plate',
                              hintText: 'ABC-1234',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // Contact Info
                          TextField(
                            controller: _customerNameController,
                            decoration: const InputDecoration(
                              labelText: 'Your Name *',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _customerPhoneController,
                            decoration: const InputDecoration(
                              labelText: 'Phone Number *',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.phone,
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _pickupLocationController,
                            decoration: const InputDecoration(
                              labelText: 'Pickup Location',
                              hintText: 'Current location or specific address',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
      
      // Submit Button
      bottomNavigationBar: _currentStep >= 2 ? Container(
        color: Colors.white,
        padding: const EdgeInsets.all(20),
        child: SafeArea(
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _submitRequest,
              icon: _requiresTowing ? const Icon(Icons.car_repair) : const Icon(Icons.send),
              label: Text(
                _requiresTowing ? 'Request Service with Towing' : 'Submit Service Request',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _requiresTowing ? RoadAidColors.warning : RoadAidColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ),
      ) : null,
    );
  }

  Widget _buildStepIndicator(int step, String label, bool isActive) {
    return Column(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: isActive ? Colors.red : Colors.grey[300],
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              (step + 1).toString(),
              style: TextStyle(
                color: isActive ? Colors.white : Colors.grey[600],
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isActive ? Colors.red : Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(20),
            blurRadius: 12,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}





















