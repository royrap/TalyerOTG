import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/marketplace_service.dart';
import '../services/location_service.dart';
import 'shop_details_screen.dart';
import 'service_request_screen.dart';

class CustomerMarketplaceScreen extends StatefulWidget {
  const CustomerMarketplaceScreen({super.key});

  @override
  State<CustomerMarketplaceScreen> createState() => _CustomerMarketplaceScreenState();
}

class _CustomerMarketplaceScreenState extends State<CustomerMarketplaceScreen> {
  final MarketplaceService _marketplaceService = MarketplaceService();
  final LocationService _locationService = LocationService();

  List<ShopWithServices> _shops = [];
  List<ServiceCategory> _categories = [];
  ServiceCategory? _selectedCategory;
  bool _isLoading = true;
  String _errorMessage = '';
  LatLng? _currentPosition;
  double _searchRadius = 25.0; // km

  @override
  void initState() {
    super.initState();
    _initializeMarketplace();
  }

  Future<void> _initializeMarketplace() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      // Get current location
      _currentPosition = await _locationService.getCurrentLocation();
      
      // Load service categories
      _categories = await _marketplaceService.getServiceCategories();
      
      // Load nearby shops
      await _loadNearbyShops();

    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load marketplace: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadNearbyShops() async {
    if (_currentPosition == null) return;

    try {
      final shops = await _marketplaceService.findNearbyShops(
        customerLat: _currentPosition!.latitude,
        customerLng: _currentPosition!.longitude,
        maxDistanceKm: _searchRadius,
        serviceCategoryId: _selectedCategory?.id,
      );

      setState(() {
        _shops = shops;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load shops: $e';
      });
    }
  }

  void _onCategorySelected(ServiceCategory? category) {
    setState(() {
      _selectedCategory = category;
    });
    _loadNearbyShops();
  }

  void _onRadiusChanged(double radius) {
    setState(() {
      _searchRadius = radius;
    });
    _loadNearbyShops();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Auto Shops'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _initializeMarketplace,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterSection(),
          Expanded(
            child: _buildShopsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(51),
            spreadRadius: 1,
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Service Category Filter
          const Text(
            'Service Type',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildCategoryChip(null, 'All Services'),
                ..._categories.map((category) => 
                  _buildCategoryChip(category, category.name)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // Search Radius
          Row(
            children: [
              const Text(
                'Search Radius: ',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('${_searchRadius.toInt()} km'),
              const SizedBox(width: 16),
              Expanded(
                child: Slider(
                  value: _searchRadius,
                  min: 5.0,
                  max: 100.0,
                  divisions: 19,
                  onChanged: _onRadiusChanged,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(ServiceCategory? category, String label) {
    final isSelected = _selectedCategory == category;
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => _onCategorySelected(category),
        backgroundColor: Colors.white,
        selectedColor: Colors.blue.withAlpha(51),
        checkmarkColor: Colors.blue,
      ),
    );
  }

  Widget _buildShopsList() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Finding nearby auto shops...'),
          ],
        ),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _initializeMarketplace,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_shops.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.car_repair, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No auto shops found within ${_searchRadius.toInt()} km',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text(
              'Try increasing the search radius or check back later.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _shops.length,
      itemBuilder: (context, index) {
        final shop = _shops[index];
        return _buildShopCard(shop);
      },
    );
  }

  Widget _buildShopCard(ShopWithServices shop) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: InkWell(
        onTap: () => _navigateToShopDetails(shop),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Shop Header
              Row(
                children: [
                  // Shop Image or Icon
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.blue.withAlpha(26),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: shop.shopImageUrl != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              shop.shopImageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(Icons.car_repair, size: 30, color: Colors.blue),
                            ),
                          )
                        : const Icon(Icons.car_repair, size: 30, color: Colors.blue),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          shop.shopName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (shop.shopAddress != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            shop.shopAddress!,
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Distance
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withAlpha(26),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${shop.distanceKm.toStringAsFixed(1)} km',
                          style: const TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Rating
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 16),
                          const SizedBox(width: 2),
                          Text(
                            shop.averageRating.toStringAsFixed(1),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            ' (${shop.totalReviews})',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              
              // Shop Status
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildStatusChip(
                    shop.isCurrentlyOpen ? 'Open' : 'Closed',
                    shop.isCurrentlyOpen ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 8),
                  if (shop.emergencyAvailable)
                    _buildStatusChip('Emergency', Colors.orange),
                  if (shop.nightServiceAvailable) ...[
                    const SizedBox(width: 8),
                    _buildStatusChip('24/7', Colors.blue),
                  ],
                ],
              ),
              
              // Services Preview
              if (shop.availableServices.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  'Available Services:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: shop.availableServices
                      .take(3)
                      .map((service) => _buildServiceChip(service))
                      .toList(),
                ),
                if (shop.availableServices.length > 3)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '+${shop.availableServices.length - 3} more services',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
              
              // Action Buttons
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _navigateToShopDetails(shop),
                      icon: const Icon(Icons.info_outline, size: 18),
                      label: const Text('View Details'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _navigateToServiceRequest(shop),
                      icon: const Icon(Icons.build, size: 18),
                      label: const Text('Request Service'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
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
    );
  }

  Widget _buildStatusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(26),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(77)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildServiceChip(ShopService service) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.blue.withAlpha(26),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '${service.serviceName} - ₱${service.price.toStringAsFixed(0)}',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  void _navigateToShopDetails(ShopWithServices shop) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ShopDetailsScreen(shop: shop),
      ),
    );
  }

  void _navigateToServiceRequest(ShopWithServices shop) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ServiceRequestScreen(
          shop: shop,
          customerLocation: _currentPosition,
        ),
      ),
    );
  }
}










