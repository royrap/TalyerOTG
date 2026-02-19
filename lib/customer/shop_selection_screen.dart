import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/shop_services_service.dart';
import 'shop_service_selection_screen.dart';

class ShopSelectionScreen extends StatefulWidget {
  final LatLng customerLocation;
  
  const ShopSelectionScreen({
    Key? key,
    required this.customerLocation,
  }) : super(key: key);

  @override
  State<ShopSelectionScreen> createState() => _ShopSelectionScreenState();
}

class _ShopSelectionScreenState extends State<ShopSelectionScreen> {
  List<Map<String, dynamic>> _shops = [];
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  String _searchQuery = '';
  String _selectedFilter = 'all';
  double _selectedRadius = 15.0;

  final List<Map<String, String>> _filterOptions = [
    {'value': 'all', 'label': 'All Shops'},
    {'value': 'open', 'label': 'Open Now'},
    {'value': 'rated', 'label': 'Highly Rated'},
    {'value': 'nearby', 'label': 'Nearest First'},
  ];

  @override
  void initState() {
    super.initState();
    _loadShops();
  }

  Future<void> _loadShops() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final shops = await ShopServicesService.instance.getNearbyShopsWithServices(
        customerLocation: widget.customerLocation,
        radiusKm: _selectedRadius,
        limit: 20,
      );

      setState(() {
        _shops = shops;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = e.toString();
      });
    }
  }

  List<Map<String, dynamic>> get _filteredShops {
    var filtered = _shops.where((shopData) {
      final shop = shopData['shop_info'] as Map<String, dynamic>? ?? {};
      final shopName = shop['shop_name']?.toString().toLowerCase() ?? '';
      final shopAddress = shop['shop_address']?.toString().toLowerCase() ?? '';
      
      // Search filter
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        if (!shopName.contains(query) && !shopAddress.contains(query)) {
          return false;
        }
      }
      
      // Additional filters
      switch (_selectedFilter) {
        case 'open':
          return shopData['is_open'] == true;
        case 'rated':
          final rating = shop['rating']?.toDouble() ?? 0.0;
          return rating >= 4.0;
        case 'nearby':
          final distance = shopData['distance']?.toDouble() ?? double.infinity;
          return distance <= 10.0;
        default:
          return true;
      }
    }).toList();

    // Sort based on filter
    if (_selectedFilter == 'nearby') {
      filtered.sort((a, b) {
        final distanceA = a['distance']?.toDouble() ?? double.infinity;
        final distanceB = b['distance']?.toDouble() ?? double.infinity;
        return distanceA.compareTo(distanceB);
      });
    } else if (_selectedFilter == 'rated') {
      filtered.sort((a, b) {
        final shopA = a['shop_info'] as Map<String, dynamic>? ?? {};
        final shopB = b['shop_info'] as Map<String, dynamic>? ?? {};
        final ratingA = shopA['rating']?.toDouble() ?? 0.0;
        final ratingB = shopB['rating']?.toDouble() ?? 0.0;
        return ratingB.compareTo(ratingA);
      });
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 176, 12, 1),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Choose a Shop',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Search and Filter Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Search Bar
                TextField(
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search shops by name or location...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Filter Options
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ..._filterOptions.map((option) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(option['label']!),
                          selected: _selectedFilter == option['value'],
                          onSelected: (selected) {
                            setState(() {
                              _selectedFilter = selected ? option['value']! : 'all';
                            });
                          },
                          selectedColor: const Color.fromARGB(255, 176, 12, 1).withOpacity(0.2),
                          checkmarkColor: const Color.fromARGB(255, 176, 12, 1),
                        ),
                      )).toList(),
                      
                      // Radius Filter
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: DropdownButton<double>(
                          value: _selectedRadius,
                          underline: const SizedBox(),
                          items: [5.0, 10.0, 15.0, 25.0, 50.0].map((radius) {
                            return DropdownMenuItem<double>(
                              value: radius,
                              child: Text('${radius.toInt()}km'),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _selectedRadius = value;
                              });
                              _loadShops();
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Results Count
          if (!_isLoading)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text(
                '${_filteredShops.length} shop${_filteredShops.length != 1 ? 's' : ''} found',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          
          // Shops List
          Expanded(
            child: _buildShopsList(),
          ),
        ],
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
            Text('Loading nearby shops...'),
          ],
        ),
      );
    }

    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            const Text(
              'Unable to load shops',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage,
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadShops,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 176, 12, 1),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    if (_filteredShops.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.store_mall_directory_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty ? 'No shops found' : 'No shops available',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isNotEmpty 
                  ? 'Try adjusting your search or filters'
                  : 'Try expanding your search radius',
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadShops,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _filteredShops.length,
        itemBuilder: (context, index) {
          return _buildShopCard(_filteredShops[index]);
        },
      ),
    );
  }

  Widget _buildShopCard(Map<String, dynamic> shopData) {
    final shop = shopData['shop_info'] as Map<String, dynamic>? ?? {};
    final services = shopData['services'] as List<dynamic>? ?? [];
    final distance = shopData['distance']?.toDouble() ?? 0.0;
    final minPrice = shopData['min_price']?.toDouble() ?? 0.0;
    final serviceCount = shopData['service_count'] ?? 0;
    final isOpen = shopData['is_open'] ?? false;
    
    final shopName = shop['shop_name']?.toString() ?? 'Unknown Shop';
    final shopAddress = shop['shop_address']?.toString() ?? 'No address';
    final rating = shop['rating']?.toDouble() ?? 0.0;
    final totalReviews = shop['total_reviews'] ?? 0;
    final shopId = shop['id']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _selectShop(shopId, shopName, shop),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Shop Header
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  shopName,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: isOpen ? Colors.red : Colors.red,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  isOpen ? 'OPEN' : 'CLOSED',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            shopAddress,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // Shop Stats
                Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      color: Colors.grey[600],
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${distance.toStringAsFixed(1)} km away',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 16),
                    
                    if (rating > 0) ...[
                      Icon(
                        Icons.star,
                        color: Colors.orange,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${rating.toStringAsFixed(1)} ($totalReviews)',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 16),
                    ],
                    
                    Icon(
                      Icons.build_circle,
                      color: Colors.grey[600],
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$serviceCount services',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // Price Range
                Row(
                  children: [
                    Text(
                      'Starting from ₱${minPrice.toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // Popular Services Preview
                if (services.isNotEmpty) ...[
                  Text(
                    'Popular Services:',
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: services.take(3).map((service) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color.fromARGB(255, 176, 12, 1).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          service['service_name'] ?? 'Unknown',
                          style: const TextStyle(
                            color: Color.fromARGB(255, 176, 12, 1),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
                
                const SizedBox(height: 16),
                
                // Action Button
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(255, 176, 12, 1).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.touch_app,
                        color: const Color.fromARGB(255, 176, 12, 1),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Tap to select this shop',
                        style: TextStyle(
                          color: Color.fromARGB(255, 176, 12, 1),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _selectShop(String shopId, String shopName, Map<String, dynamic> shopData) {
    if (shopId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid shop selection. Please try another shop.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ShopServiceSelectionScreen(
          shopId: shopId,
          shopName: shopName,
          shopData: shopData,
          customerLocation: widget.customerLocation,
        ),
      ),
    );
  }
}











