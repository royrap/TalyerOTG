import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/shop_services_service.dart';
import '../services/location_service.dart';
import 'dart:async';

class ShopServicesDisplayScreen extends StatefulWidget {
  final String shopId;
  final String shopName;
  final LatLng? customerLocation;

  const ShopServicesDisplayScreen({
    super.key,
    required this.shopId,
    required this.shopName,
    this.customerLocation,
  });

  @override
  State<ShopServicesDisplayScreen> createState() => _ShopServicesDisplayScreenState();
}

class _ShopServicesDisplayScreenState extends State<ShopServicesDisplayScreen> {
  final ShopServicesService _shopServicesService = ShopServicesService.instance;
  final LocationService _locationService = LocationService();
  
  List<Map<String, dynamic>> _services = [];
  Map<String, dynamic>? _shopInfo;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  LatLng? _currentLocation;
  
  StreamSubscription<LatLng>? _locationSubscription;
  Timer? _refreshTimer;

  // Filter options
  String _sortBy = 'price'; // 'price', 'distance', 'name'
  double? _maxPrice;
  bool _showOnlyNearby = false;

  @override
  void initState() {
    super.initState();
    _initializeLocation();
    _loadShopServices();
    _startRealTimeUpdates();
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeLocation() async {
    try {
      if (widget.customerLocation != null) {
        _currentLocation = widget.customerLocation;
      } else {
        _currentLocation = await _locationService.getCurrentLocation();
      }
      
      // Start location tracking for real-time updates
      _locationSubscription = _locationService.startLocationTracking().listen(
        (newLocation) {
          if (mounted) {
            setState(() {
              _currentLocation = newLocation;
            });
            _refreshDistances();
          }
        },
        onError: (error) {
          print('Location tracking error: $error');
        },
      );
    } catch (e) {
      print('Error initializing location: $e');
    }
  }

  void _startRealTimeUpdates() {
    // Refresh services every 30 seconds for real-time updates
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        _refreshDistances();
      }
    });
  }

  Future<void> _loadShopServices({bool forceRefresh = false}) async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });

      final services = await _shopServicesService.getShopServicesWithDistance(
        shopId: widget.shopId,
        customerLocation: _currentLocation,
        forceRefresh: forceRefresh,
      );

      if (mounted) {
        setState(() {
          _services = services;
          if (services.isNotEmpty) {
            _shopInfo = services.first['shop_info'];
          }
          _isLoading = false;
        });
        
        _applySorting();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  Future<void> _refreshDistances() async {
    if (_currentLocation != null && _services.isNotEmpty) {
      try {
        final updatedServices = await _shopServicesService.getShopServicesWithDistance(
          shopId: widget.shopId,
          customerLocation: _currentLocation,
          forceRefresh: true,
        );

        if (mounted) {
          setState(() {
            _services = updatedServices;
          });
          _applySorting();
        }
      } catch (e) {
        print('Error refreshing distances: $e');
      }
    }
  }

  void _applySorting() {
    setState(() {
      switch (_sortBy) {
        case 'price':
          _services.sort((a, b) => a['price'].compareTo(b['price']));
          break;
        case 'distance':
          _services.sort((a, b) {
            final aDistance = a['distance']?['kilometers'] ?? double.infinity;
            final bDistance = b['distance']?['kilometers'] ?? double.infinity;
            return aDistance.compareTo(bDistance);
          });
          break;
        case 'name':
          _services.sort((a, b) => a['service_name'].compareTo(b['service_name']));
          break;
      }
    });
  }

  List<Map<String, dynamic>> get _filteredServices {
    List<Map<String, dynamic>> filtered = _services;

    // Filter by max price
    if (_maxPrice != null) {
      filtered = filtered.where((service) => service['price'] <= _maxPrice!).toList();
    }

    // Filter by nearby only
    if (_showOnlyNearby) {
      filtered = filtered.where((service) {
        final distance = service['distance']?['kilometers'];
        return distance != null && distance <= 5.0; // Within 5km
      }).toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.shopName),
        backgroundColor: Colors.orange[700],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadShopServices(forceRefresh: true),
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterOptions,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _hasError
              ? _buildErrorWidget()
              : _buildServicesContent(),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red[300],
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load services',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _loadShopServices(forceRefresh: true),
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange[700],
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServicesContent() {
    final filteredServices = _filteredServices;

    return Column(
      children: [
        // Shop info header
        if (_shopInfo != null) _buildShopInfoHeader(),
        
        // Sort and filter bar
        _buildSortFilterBar(),

        // Services list
        Expanded(
          child: filteredServices.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: () => _loadShopServices(forceRefresh: true),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredServices.length,
                    itemBuilder: (context, index) {
                      return _buildServiceCard(filteredServices[index]);
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildShopInfoHeader() {
    final shop = _shopInfo!;
    final isOpen = shop['is_open'] ?? false;
    final rating = shop['rating']?.toDouble() ?? 0.0;
    final totalReviews = shop['total_reviews'] ?? 0;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange[700]!, Colors.orange[500]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        shop['name'] ?? 'Unknown Shop',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        shop['address'] ?? 'No address available',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isOpen ? Colors.green : Colors.red,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isOpen ? 'OPEN' : 'CLOSED',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (rating > 0) ...[
                  Icon(
                    Icons.star,
                    color: Colors.yellow[300],
                    size: 20,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${rating.toStringAsFixed(1)} ($totalReviews reviews)',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ],
                const Spacer(),
                Text(
                  '${_services.length} services available',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSortFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border(
          bottom: BorderSide(color: Colors.grey[300]!),
        ),
      ),
      child: Row(
        children: [
          Text(
            'Sort by:',
            style: TextStyle(
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          DropdownButton<String>(
            value: _sortBy,
            underline: Container(),
            onChanged: (String? newValue) {
              if (newValue != null) {
                setState(() {
                  _sortBy = newValue;
                });
                _applySorting();
              }
            },
            items: const [
              DropdownMenuItem(value: 'price', child: Text('Price')),
              DropdownMenuItem(value: 'distance', child: Text('Distance')),
              DropdownMenuItem(value: 'name', child: Text('Name')),
            ],
          ),
          const Spacer(),
          Text(
            '${_filteredServices.length} results',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceCard(Map<String, dynamic> service) {
    final serviceName = service['service_name'] ?? 'Unknown Service';
    final description = service['service_description'] ?? '';
    final price = service['price']?.toDouble() ?? 0.0;
    final originalPrice = service['original_price']?.toDouble();
    final distance = service['distance'];
    final estimatedDuration = service['estimated_duration'] ?? 60;
    final travelTime = service['estimated_travel_time'];
    final isDefault = service['is_default'] ?? false;
    final serviceNotes = service['service_notes'];

    final hasDiscount = originalPrice != null && originalPrice > price;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showServiceDetails(service),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Service header
              Row(
                children: [
                  // Service icon
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getServiceIcon(service['icon_name']),
                      color: Colors.orange[700],
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  
                  // Service name and badges
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                serviceName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (isDefault)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue[100],
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  'Popular',
                                  style: TextStyle(
                                    color: Colors.blue[700],
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        if (description.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            description,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Price and details
              Row(
                children: [
                  // Price section
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '₱${price.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                            if (hasDiscount) ...[
                              const SizedBox(width: 8),
                              Text(
                                '₱${originalPrice!.toStringAsFixed(0)}',
                                style: TextStyle(
                                  fontSize: 14,
                                  decoration: TextDecoration.lineThrough,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          'Est. ${estimatedDuration} min',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Distance and travel time
                  if (distance != null) ...[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.location_on,
                              size: 16,
                              color: distance['is_nearby'] 
                                  ? Colors.green 
                                  : Colors.orange,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              distance['formatted'] ?? 'Unknown',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: distance['is_nearby'] 
                                    ? Colors.green 
                                    : Colors.orange[700],
                              ),
                            ),
                          ],
                        ),
                        if (travelTime != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            '${travelTime['formatted']} travel',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),

              // Service notes
              if (serviceNotes != null && serviceNotes.toString().isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: Colors.blue[700],
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          serviceNotes.toString(),
                          style: TextStyle(
                            color: Colors.blue[700],
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.build_circle_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No Services Available',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This shop doesn\'t have any services available at the moment.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _loadShopServices(forceRefresh: true),
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange[700],
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showServiceDetails(Map<String, dynamic> service) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => ServiceDetailsBottomSheet(service: service),
    );
  }

  void _showFilterOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => FilterOptionsBottomSheet(
        maxPrice: _maxPrice,
        showOnlyNearby: _showOnlyNearby,
        onFiltersChanged: (double? maxPrice, bool showOnlyNearby) {
          setState(() {
            _maxPrice = maxPrice;
            _showOnlyNearby = showOnlyNearby;
          });
        },
      ),
    );
  }

  IconData _getServiceIcon(String? iconName) {
    switch (iconName) {
      case 'oil_change':
        return Icons.local_gas_station;
      case 'tire_repair':
        return Icons.tire_repair;
      case 'battery_service':
        return Icons.battery_charging_full;
      case 'brake_service':
        return Icons.directions_car;
      case 'engine_diagnostic':
        return Icons.settings;
      case 'car_wash':
        return Icons.local_car_wash;
      case 'towing':
        return Icons.local_shipping;
      default:
        return Icons.build;
    }
  }
}

// Service Details Bottom Sheet
class ServiceDetailsBottomSheet extends StatelessWidget {
  final Map<String, dynamic> service;

  const ServiceDetailsBottomSheet({
    super.key,
    required this.service,
  });

  @override
  Widget build(BuildContext context) {
    final serviceName = service['service_name'] ?? 'Unknown Service';
    final description = service['service_description'] ?? '';
    final price = service['price']?.toDouble() ?? 0.0;
    final originalPrice = service['original_price']?.toDouble();
    final estimatedDuration = service['estimated_duration'] ?? 60;
    final distance = service['distance'];
    final travelTime = service['estimated_travel_time'];
    final shopInfo = service['shop_info'] as Map<String, dynamic>?;
    final providerInfo = service['provider_info'] as Map<String, dynamic>?;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      minChildSize: 0.5,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Service title
                      Text(
                        serviceName,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      
                      const SizedBox(height: 8),
                      
                      // Description
                      if (description.isNotEmpty) ...[
                        Text(
                          description,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      
                      // Price details
                      _buildDetailRow(
                        'Price',
                        '₱${price.toStringAsFixed(0)}',
                        originalPrice != null && originalPrice > price
                            ? '₱${originalPrice.toStringAsFixed(0)}'
                            : null,
                      ),
                      
                      _buildDetailRow(
                        'Estimated Duration',
                        '${estimatedDuration} minutes',
                      ),
                      
                      if (distance != null) ...[
                        _buildDetailRow(
                          'Distance',
                          distance['formatted'] ?? 'Unknown',
                        ),
                        
                        if (travelTime != null)
                          _buildDetailRow(
                            'Travel Time',
                            travelTime['formatted'] ?? 'Unknown',
                          ),
                      ],
                      
                      // Shop information
                      if (shopInfo != null) ...[
                        const SizedBox(height: 24),
                        Text(
                          'Shop Information',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        
                        _buildDetailRow(
                          'Shop Name',
                          shopInfo['name'] ?? 'Unknown',
                        ),
                        
                        _buildDetailRow(
                          'Address',
                          shopInfo['address'] ?? 'No address',
                        ),
                        
                        if (shopInfo['rating'] != null && shopInfo['rating'] > 0)
                          _buildDetailRow(
                            'Rating',
                            '${shopInfo['rating'].toStringAsFixed(1)} ⭐ (${shopInfo['total_reviews']} reviews)',
                          ),
                      ],
                      
                      // Provider information
                      if (providerInfo != null) ...[
                        const SizedBox(height: 24),
                        Text(
                          'Service Provider',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        
                        _buildDetailRow(
                          'Company',
                          providerInfo['company_name'] ?? 'Unknown',
                        ),
                        
                        if (providerInfo['rating'] != null && providerInfo['rating'] > 0)
                          _buildDetailRow(
                            'Provider Rating',
                            '${providerInfo['rating'].toStringAsFixed(1)} ⭐ (${providerInfo['total_reviews']} reviews)',
                          ),
                      ],
                      
                      const SizedBox(height: 32),
                      
                      // Action buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                // TODO: Implement contact shop functionality
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Contact shop feature coming soon!'),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.phone),
                              label: const Text('Contact Shop'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.orange[700],
                                side: BorderSide(color: Colors.orange[700]!),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                // TODO: Implement book service functionality
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Book service feature coming soon!'),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.calendar_today),
                              label: const Text('Book Service'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange[700],
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, [String? strikethroughValue]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (strikethroughValue != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    strikethroughValue,
                    style: const TextStyle(
                      decoration: TextDecoration.lineThrough,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Filter Options Bottom Sheet
class FilterOptionsBottomSheet extends StatefulWidget {
  final double? maxPrice;
  final bool showOnlyNearby;
  final Function(double? maxPrice, bool showOnlyNearby) onFiltersChanged;

  const FilterOptionsBottomSheet({
    super.key,
    required this.maxPrice,
    required this.showOnlyNearby,
    required this.onFiltersChanged,
  });

  @override
  State<FilterOptionsBottomSheet> createState() => _FilterOptionsBottomSheetState();
}

class _FilterOptionsBottomSheetState extends State<FilterOptionsBottomSheet> {
  late double? _maxPrice;
  late bool _showOnlyNearby;
  final TextEditingController _priceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _maxPrice = widget.maxPrice;
    _showOnlyNearby = widget.showOnlyNearby;
    
    if (_maxPrice != null) {
      _priceController.text = _maxPrice!.toStringAsFixed(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          Text(
            'Filter Services',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Max price filter
          Text(
            'Maximum Price',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _priceController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: 'Enter maximum price',
              prefixText: '₱',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              suffixIcon: _maxPrice != null
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          _maxPrice = null;
                          _priceController.clear();
                        });
                      },
                    )
                  : null,
            ),
            onChanged: (value) {
              final price = double.tryParse(value);
              setState(() {
                _maxPrice = price;
              });
            },
          ),
          
          const SizedBox(height: 24),
          
          // Nearby filter
          SwitchListTile(
            title: const Text('Show only nearby services'),
            subtitle: const Text('Within 5km of your location'),
            value: _showOnlyNearby,
            onChanged: (value) {
              setState(() {
                _showOnlyNearby = value;
              });
            },
            activeColor: Colors.orange[700],
          ),
          
          const SizedBox(height: 32),
          
          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _maxPrice = null;
                      _showOnlyNearby = false;
                      _priceController.clear();
                    });
                  },
                  child: const Text('Clear All'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey[600],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    widget.onFiltersChanged(_maxPrice, _showOnlyNearby);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[700],
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Apply Filters'),
                ),
              ),
            ],
          ),
          
          // Add bottom padding for safe area
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }
}










