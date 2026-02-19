import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/shop_services_service.dart';
import '../customer/shop_services_screen.dart';
import '../screens/service_comparison_screen.dart';
import 'dart:async';

class NearbyShopsWidget extends StatefulWidget {
  final LatLng? customerLocation;
  final double radiusKm;
  final String? serviceFilter;
  final VoidCallback? onLocationError;

  const NearbyShopsWidget({
    super.key,
    this.customerLocation,
    this.radiusKm = 10.0,
    this.serviceFilter,
    this.onLocationError,
  });

  @override
  State<NearbyShopsWidget> createState() => _NearbyShopsWidgetState();
}

class _NearbyShopsWidgetState extends State<NearbyShopsWidget> {
  final ShopServicesService _shopServicesService = ShopServicesService.instance;
  
  List<Map<String, dynamic>> _nearbyShops = [];
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  LatLng? _currentLocation;

  @override
  void initState() {
    super.initState();
    _currentLocation = widget.customerLocation;
    _loadNearbyShops();
  }

  @override
  void didUpdateWidget(NearbyShopsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.customerLocation != oldWidget.customerLocation ||
        widget.radiusKm != oldWidget.radiusKm ||
        widget.serviceFilter != oldWidget.serviceFilter) {
      _currentLocation = widget.customerLocation;
      _loadNearbyShops();
    }
  }

  Future<void> _loadNearbyShops() async {
    if (_currentLocation == null) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'Location not available';
      });
      widget.onLocationError?.call();
      return;
    }

    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });

      final shops = await _shopServicesService.getNearbyShopsWithServices(
        customerLocation: _currentLocation!,
        radiusKm: widget.radiusKm,
        serviceFilter: widget.serviceFilter,
        limit: 10,
      );

      if (mounted) {
        setState(() {
          _nearbyShops = shops;
          _isLoading = false;
        });
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingWidget();
    }

    if (_hasError) {
      return _buildErrorWidget();
    }

    if (_nearbyShops.isEmpty) {
      return _buildEmptyWidget();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        const SizedBox(height: 12),
        _buildShopsList(),
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Text(
            'Nearby Shops',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.orange[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${_nearbyShops.length}',
              style: TextStyle(
                color: Colors.orange[700],
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Spacer(),
          if (_nearbyShops.length > 1)
            TextButton.icon(
              onPressed: _showComparisonScreen,
              icon: const Icon(Icons.compare_arrows, size: 16),
              label: const Text('Compare'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.orange[700],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildShopsList() {
    return SizedBox(
      height: 280,
      child: RefreshIndicator(
        onRefresh: _loadNearbyShops,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: _nearbyShops.length,
          itemBuilder: (context, index) {
            return _buildShopCard(_nearbyShops[index]);
          },
        ),
      ),
    );
  }

  Widget _buildShopCard(Map<String, dynamic> shopData) {
  final shop = (shopData['shop_info'] as Map<String, dynamic>?) ?? <String, dynamic>{};
  final services = (shopData['services'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? <Map<String, dynamic>>[];
    final distance = shopData['distance']?.toDouble() ?? 0.0;
    final minPrice = shopData['min_price']?.toDouble() ?? 0.0;
    final serviceCount = shopData['service_count'] ?? 0;
    final isOpen = shopData['is_open'] ?? false;
  final shopName = shop['shop_name']?.toString() ?? 'Unknown Shop';
  final shopAddress = shop['shop_address']?.toString() ?? 'No address';
    final rating = shop['rating']?.toDouble() ?? 0.0;
    final totalReviews = shop['total_reviews'] ?? 0;

    return Container(
      width: 280,
      margin: const EdgeInsets.only(right: 12),
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _navigateToShopServices(shop),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Shop header with status
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.orange[600]!,
                      Colors.orange[400]!,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            shopName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isOpen ? Colors.green : Colors.red,
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
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          color: Colors.white70,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${distance.toStringAsFixed(1)} km away',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        if (rating > 0) ...[
                          Icon(
                            Icons.star,
                            color: Colors.yellow[300],
                            size: 16,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '${rating.toStringAsFixed(1)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Business hours
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          color: Colors.white70,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatBusinessHours(shop),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Services info
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.build_circle,
                            color: Colors.grey[600],
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '$serviceCount service${serviceCount != 1 ? 's' : ''}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      
                      // Price range
                      Row(
                        children: [
                          Text(
                            'From ₱${minPrice.toStringAsFixed(0)}',
                            style: const TextStyle(
                              color: Colors.green,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // Top services preview
                      Text(
                        'Popular Services:',
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: services.take(3).map((service) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 2),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.arrow_right,
                                      size: 14,
                                      color: Colors.grey[400],
                                    ),
                                    Expanded(
                                      child: Text(
                                        service['service_name'] ?? 'Unknown',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 11,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Text(
                                      '₱${(service['price']?.toDouble() ?? 0.0).toStringAsFixed(0)}',
                                      style: TextStyle(
                                        color: Colors.grey[500],
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Action footer
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Tap to view all services',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward,
                      color: Colors.orange[700],
                      size: 16,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return Container(
      height: 200,
      padding: const EdgeInsets.all(32),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Finding nearby shops...'),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      height: 200,
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Colors.red[300],
            ),
            const SizedBox(height: 16),
            Text(
              'Unable to load nearby shops',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage.contains('Location') 
                  ? 'Please enable location services'
                  : 'Check your internet connection',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadNearbyShops,
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

  Widget _buildEmptyWidget() {
    return Container(
      height: 200,
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.store_mall_directory_outlined,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No shops nearby',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try expanding your search radius or check back later',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadNearbyShops,
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

  void _navigateToShopServices(Map<String, dynamic> shop) {
    // Build complete shop data structure expected by ShopServicesScreen
    final shopData = {
      'id': shop['id'],
      'shop_name': shop['shop_name'] ?? 'Unknown Shop',
      'name': shop['shop_name'] ?? 'Unknown Shop', // alias
      'shop_address': shop['shop_address'],
      'rating': shop['rating'] ?? 0.0,
      'total_reviews': shop['total_reviews'] ?? 0,
      'owner_name': shop['owner_name'] ?? '',
      'is_available': shop['is_available'] ?? true,
      'phone_number': shop['phone_number'] ?? '',
      'latitude': shop['latitude'],
      'longitude': shop['longitude'],
    };
    
    print('🏪 Navigating to ShopServicesScreen with shopData:');
    print('   - Shop ID: ${shopData['id']}');
    print('   - Shop Name: ${shopData['shop_name']}');
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ShopServicesScreen(
          shopData: shopData,
        ),
      ),
    );
  }

  void _showComparisonScreen() {
  final shopIds = _nearbyShops
    .map((shop) => shop['shop_info']?['id']?.toString() ?? '')
    .where((id) => id.isNotEmpty)
    .toList();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ServiceComparisonScreen(
          shopIds: shopIds,
          serviceFilter: widget.serviceFilter,
          customerLocation: _currentLocation,
        ),
      ),
    );
  }

  /// Format business hours from shop data (e.g., "8:00 AM - 5:00 PM")
  String _formatBusinessHours(Map<String, dynamic> shop) {
    try {
      // Get business_hours from shop data
      final businessHours = shop['business_hours'];
      
      if (businessHours == null) {
        return '24/7'; // Default if no hours specified
      }

      // Get current day of week (lowercase)
      final now = DateTime.now();
      final dayNames = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
      final currentDay = dayNames[now.weekday - 1];

      // Get today's hours
      final todayHours = businessHours[currentDay];
      
      if (todayHours == null) {
        return 'Hours not set';
      }

      // Check if closed today
      final openTime = todayHours['open'];
      final closeTime = todayHours['close'];
      
      if (openTime == null || closeTime == null) {
        return 'Closed today';
      }

      // Format times (convert from 24-hour to 12-hour format)
      final formattedOpen = _formatTime(openTime);
      final formattedClose = _formatTime(closeTime);

      return '$formattedOpen - $formattedClose';
    } catch (e) {
      print('Error formatting business hours: $e');
      return '24/7';
    }
  }

  /// Convert 24-hour time (e.g., "18:00") to 12-hour format (e.g., "6:00 PM")
  String _formatTime(String time24) {
    try {
      final parts = time24.split(':');
      if (parts.length != 2) return time24;
      
      int hour = int.parse(parts[0]);
      final minute = parts[1];
      
      final period = hour >= 12 ? 'PM' : 'AM';
      
      if (hour == 0) {
        hour = 12;
      } else if (hour > 12) {
        hour = hour - 12;
      }
      
      return '$hour:$minute $period';
    } catch (e) {
      return time24;
    }
  }
}

// Quick Service Search Widget
class QuickServiceSearchWidget extends StatefulWidget {
  final LatLng? customerLocation;
  final Function(String service) onServiceSelected;

  const QuickServiceSearchWidget({
    super.key,
    this.customerLocation,
    required this.onServiceSelected,
  });

  @override
  State<QuickServiceSearchWidget> createState() => _QuickServiceSearchWidgetState();
}

class _QuickServiceSearchWidgetState extends State<QuickServiceSearchWidget> {
  final List<Map<String, dynamic>> _popularServices = [
    {'name': 'Oil Change', 'icon': Icons.local_gas_station, 'query': 'oil change'},
    {'name': 'Tire Repair', 'icon': Icons.tire_repair, 'query': 'tire repair'},
    {'name': 'Battery Service', 'icon': Icons.battery_charging_full, 'query': 'battery'},
    {'name': 'Brake Service', 'icon': Icons.directions_car, 'query': 'brake'},
    {'name': 'Car Wash', 'icon': Icons.local_car_wash, 'query': 'car wash'},
    {'name': 'Lockout Service', 'icon': Icons.lock_open, 'query': 'lockout'},
    {'name': 'Towing', 'icon': Icons.local_shipping, 'query': 'towing'},
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Quick Service Search',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _popularServices.length,
            itemBuilder: (context, index) {
              final service = _popularServices[index];
              return Container(
                width: 100,
                margin: const EdgeInsets.only(right: 12),
                child: InkWell(
                  onTap: () => widget.onServiceSelected(service['query']),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[200]!),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withAlpha(26),
                          spreadRadius: 1,
                          blurRadius: 2,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          service['icon'],
                          size: 32,
                          color: Colors.orange[700],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          service['name'],
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}










