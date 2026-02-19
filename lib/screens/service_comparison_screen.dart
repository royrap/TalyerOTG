import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/shop_services_service.dart';
import '../services/location_service.dart';
import 'shop_services_display_screen.dart';
import 'dart:async';

class ServiceComparisonScreen extends StatefulWidget {
  final List<String> shopIds;
  final String? serviceFilter;
  final LatLng? customerLocation;

  const ServiceComparisonScreen({
    super.key,
    required this.shopIds,
    this.serviceFilter,
    this.customerLocation,
  });

  @override
  State<ServiceComparisonScreen> createState() => _ServiceComparisonScreenState();
}

class _ServiceComparisonScreenState extends State<ServiceComparisonScreen> {
  final ShopServicesService _shopServicesService = ShopServicesService.instance;
  final LocationService _locationService = LocationService();
  
  List<Map<String, dynamic>> _allServices = [];
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  LatLng? _currentLocation;
  
  StreamSubscription<LatLng>? _locationSubscription;
  
  // Filter options
  String _sortBy = 'price'; // 'price', 'distance', 'shop'
  double? _maxPrice;
  double? _maxDistance;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _initializeLocation();
    _loadAllServices();
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeLocation() async {
    try {
      if (widget.customerLocation != null) {
        _currentLocation = widget.customerLocation;
      } else {
        _currentLocation = await _locationService.getCurrentLocation();
      }
      
      _locationSubscription = _locationService.startLocationTracking().listen(
        (newLocation) {
          if (mounted) {
            setState(() {
              _currentLocation = newLocation;
            });
            _refreshServices();
          }
        },
      );
    } catch (e) {
      print('Error initializing location: $e');
    }
  }

  Future<void> _loadAllServices() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });

      final services = await _shopServicesService.getServicesFromMultipleShops(
        shopIds: widget.shopIds,
        customerLocation: _currentLocation,
        serviceFilter: widget.serviceFilter,
      );

      if (mounted) {
        setState(() {
          _allServices = services;
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

  Future<void> _refreshServices() async {
    if (_currentLocation != null) {
      try {
        final services = await _shopServicesService.getServicesFromMultipleShops(
          shopIds: widget.shopIds,
          customerLocation: _currentLocation,
          serviceFilter: widget.serviceFilter,
        );

        if (mounted) {
          setState(() {
            _allServices = services;
          });
          _applySorting();
        }
      } catch (e) {
        print('Error refreshing services: $e');
      }
    }
  }

  void _applySorting() {
    setState(() {
      switch (_sortBy) {
        case 'price':
          _allServices.sort((a, b) => a['price'].compareTo(b['price']));
          break;
        case 'distance':
          _allServices.sort((a, b) {
            final aDistance = a['distance']?['kilometers'] ?? double.infinity;
            final bDistance = b['distance']?['kilometers'] ?? double.infinity;
            return aDistance.compareTo(bDistance);
          });
          break;
        case 'shop':
          _allServices.sort((a, b) {
            final aShop = a['shop_info']['name'] ?? '';
            final bShop = b['shop_info']['name'] ?? '';
            return aShop.compareTo(bShop);
          });
          break;
      }
    });
  }

  List<Map<String, dynamic>> get _filteredServices {
    List<Map<String, dynamic>> filtered = _allServices;

    // Search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((service) {
        final serviceName = service['service_name'].toString().toLowerCase();
        final shopName = service['shop_info']['name'].toString().toLowerCase();
        final query = _searchQuery.toLowerCase();
        return serviceName.contains(query) || shopName.contains(query);
      }).toList();
    }

    // Price filter
    if (_maxPrice != null) {
      filtered = filtered.where((service) => service['price'] <= _maxPrice!).toList();
    }

    // Distance filter
    if (_maxDistance != null) {
      filtered = filtered.where((service) {
        final distance = service['distance']?['kilometers'];
        return distance != null && distance <= _maxDistance!;
      }).toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Compare Services'),
        backgroundColor: Colors.orange[700],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAllServices,
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterOptions,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          _buildSearchBar(),
          
          // Sort bar
          _buildSortBar(),
          
          // Services list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _hasError
                    ? _buildErrorWidget()
                    : _buildServicesContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(26),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: TextField(
        decoration: InputDecoration(
          hintText: 'Search services or shops...',
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(25),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.grey[100],
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
      ),
    );
  }

  Widget _buildSortBar() {
    final filteredCount = _filteredServices.length;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(
          bottom: BorderSide(color: Colors.grey[200]!),
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
              DropdownMenuItem(value: 'shop', child: Text('Shop')),
            ],
          ),
          const Spacer(),
          Text(
            '$filteredCount result${filteredCount != 1 ? 's' : ''}',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServicesContent() {
    final filteredServices = _filteredServices;

    if (filteredServices.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _loadAllServices,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: filteredServices.length,
        itemBuilder: (context, index) {
          return _buildComparisonServiceCard(filteredServices[index]);
        },
      ),
    );
  }

  Widget _buildComparisonServiceCard(Map<String, dynamic> service) {
    final serviceName = service['service_name'] ?? 'Unknown Service';
    final price = service['price']?.toDouble() ?? 0.0;
    final distance = service['distance'];
    final shopInfo = service['shop_info'] as Map<String, dynamic>;
    final shopName = shopInfo['name'] ?? 'Unknown Shop';
    final isOpen = shopInfo['is_open'] ?? false;
    final rating = shopInfo['rating']?.toDouble() ?? 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ShopServicesDisplayScreen(
                shopId: shopInfo['id'],
                shopName: shopName,
                customerLocation: _currentLocation,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Service and shop header
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          serviceName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.store,
                              size: 16,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              shopName,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: isOpen ? Colors.green[100] : Colors.red[100],
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                isOpen ? 'OPEN' : 'CLOSED',
                                style: TextStyle(
                                  color: isOpen ? Colors.green[700] : Colors.red[700],
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Price
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₱${price.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      if (rating > 0)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.star,
                              size: 14,
                              color: Colors.orange[400],
                            ),
                            const SizedBox(width: 2),
                            Text(
                              rating.toStringAsFixed(1),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Distance and travel info
              Row(
                children: [
                  if (distance != null) ...[
                    Icon(
                      Icons.location_on,
                      size: 16,
                      color: distance['is_nearby'] ? Colors.green : Colors.orange,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      distance['formatted'] ?? 'Unknown',
                      style: TextStyle(
                        color: distance['is_nearby'] ? Colors.green : Colors.orange[700],
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                  
                  Icon(
                    Icons.access_time,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${service['estimated_duration'] ?? 60} min',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                  
                  const Spacer(),
                  
                  // Quick action button
                  TextButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ShopServicesDisplayScreen(
                            shopId: shopInfo['id'],
                            shopName: shopName,
                            customerLocation: _currentLocation,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.arrow_forward, size: 16),
                    label: const Text('View Shop'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.orange[700],
                    ),
                  ),
                ],
              ),
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
              Icons.search_off,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No Services Found',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isNotEmpty
                  ? 'Try adjusting your search or filters'
                  : 'No services available from selected shops',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _searchQuery = '';
                  _maxPrice = null;
                  _maxDistance = null;
                });
                _loadAllServices();
              },
              icon: const Icon(Icons.clear_all),
              label: const Text('Clear Filters'),
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

  Widget _buildErrorWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
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
              onPressed: _loadAllServices,
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

  void _showFilterOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => ComparisonFilterBottomSheet(
        maxPrice: _maxPrice,
        maxDistance: _maxDistance,
        onFiltersChanged: (double? maxPrice, double? maxDistance) {
          setState(() {
            _maxPrice = maxPrice;
            _maxDistance = maxDistance;
          });
        },
      ),
    );
  }
}

// Comparison Filter Bottom Sheet
class ComparisonFilterBottomSheet extends StatefulWidget {
  final double? maxPrice;
  final double? maxDistance;
  final Function(double? maxPrice, double? maxDistance) onFiltersChanged;

  const ComparisonFilterBottomSheet({
    super.key,
    required this.maxPrice,
    required this.maxDistance,
    required this.onFiltersChanged,
  });

  @override
  State<ComparisonFilterBottomSheet> createState() => _ComparisonFilterBottomSheetState();
}

class _ComparisonFilterBottomSheetState extends State<ComparisonFilterBottomSheet> {
  late double? _maxPrice;
  late double? _maxDistance;
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _distanceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _maxPrice = widget.maxPrice;
    _maxDistance = widget.maxDistance;
    
    if (_maxPrice != null) {
      _priceController.text = _maxPrice!.toStringAsFixed(0);
    }
    if (_maxDistance != null) {
      _distanceController.text = _maxDistance!.toStringAsFixed(1);
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
          
          // Max distance filter
          Text(
            'Maximum Distance',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _distanceController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: 'Enter maximum distance',
              suffixText: 'km',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              suffixIcon: _maxDistance != null
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          _maxDistance = null;
                          _distanceController.clear();
                        });
                      },
                    )
                  : null,
            ),
            onChanged: (value) {
              final distance = double.tryParse(value);
              setState(() {
                _maxDistance = distance;
              });
            },
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
                      _maxDistance = null;
                      _priceController.clear();
                      _distanceController.clear();
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
                    widget.onFiltersChanged(_maxPrice, _maxDistance);
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
    _distanceController.dispose();
    super.dispose();
  }
}










