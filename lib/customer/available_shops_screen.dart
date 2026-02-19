import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../services/location_service.dart';
import '../services/shop_service.dart';
import 'request_assistance_screen.dart';

class AvailableShopsScreen extends StatefulWidget {
  final LatLng? userLocation;
  final String? serviceType;

  const AvailableShopsScreen({
    Key? key,
    this.userLocation,
    this.serviceType,
  }) : super(key: key);

  @override
  State<AvailableShopsScreen> createState() => _AvailableShopsScreenState();
}

class _AvailableShopsScreenState extends State<AvailableShopsScreen> {
  GoogleMapController? _mapController;
  List<Map<String, dynamic>> _shops = [];
  Map<String, dynamic>? _selectedShop;
  bool _isLoading = true;
  Set<Marker> _markers = {};
  LatLng? _currentLocation;
  bool _showShopDetails = false;

  @override
  void initState() {
    super.initState();
    _currentLocation = widget.userLocation;
    _loadNearbyShops();
  }

  Future<void> _loadNearbyShops() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Get current location if not provided
      if (_currentLocation == null) {
        final position = await Geolocator.getCurrentPosition();
        _currentLocation = LatLng(position.latitude, position.longitude);
      }

      // Load nearby shops from database
      final shops = await ShopService.instance.getNearbyShops(
        latitude: _currentLocation!.latitude,
        longitude: _currentLocation!.longitude,
        radiusKm: 25.0,
      );

      setState(() {
        _shops = shops;
        _isLoading = false;
      });

      _updateMarkers();
    } catch (e) {
      print('Error loading shops: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _updateMarkers() {
    Set<Marker> markers = {};

    // Add user location marker
    if (_currentLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('user_location'),
          position: _currentLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: const InfoWindow(
            title: 'Your Location',
            snippet: 'Current position',
          ),
        ),
      );
    }

    // Add shop markers
    for (final shop in _shops) {
      final lat = shop['latitude'] as double?;
      final lng = shop['longitude'] as double?;
      
      if (lat != null && lng != null) {
        markers.add(
          Marker(
            markerId: MarkerId('shop_${shop['id']}'),
            position: LatLng(lat, lng),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              _selectedShop?['id'] == shop['id'] 
                  ? BitmapDescriptor.hueRed 
                  : BitmapDescriptor.hueOrange
            ),
            infoWindow: InfoWindow(
              title: shop['shop_name'],
              snippet: 'Tap for details',
            ),
            onTap: () => _selectShop(shop),
          ),
        );
      }
    }

    setState(() {
      _markers = markers;
    });
  }

  void _selectShop(Map<String, dynamic> shop) {
    setState(() {
      _selectedShop = shop;
      _showShopDetails = true;
    });
    _updateMarkers();
  }

  void _proceedWithShop() {
    if (_selectedShop == null) return;

    // Navigate to service request with pre-selected shop
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RequestAssistanceScreen(
          initialServiceType: widget.serviceType,
          preSelectedMechanic: {
            'shop_id': _selectedShop!['id'],
            'shop_name': _selectedShop!['shop_name'],
            'shop_address': _selectedShop!['shop_address'],
            'shop_phone': _selectedShop!['shop_phone'],
            'latitude': _selectedShop!['latitude'],
            'longitude': _selectedShop!['longitude'],
            'distance_km': _selectedShop!['distance_km'],
            'rating': _selectedShop!['rating'],
            'total_mechanics': _selectedShop!['total_mechanics'],
            'available_mechanics': _selectedShop!['available_mechanics'],
          },
        ),
      ),
    );
  }

  Widget _buildShopCard(Map<String, dynamic> shop) {
    final isSelected = _selectedShop?['id'] == shop['id'];
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? const Color.fromARGB(255, 176, 12, 1) : Colors.grey[300]!,
          width: isSelected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isSelected 
                ? const Color.fromARGB(255, 176, 12, 1).withOpacity(0.2)
                : Colors.black.withOpacity(0.05),
            blurRadius: isSelected ? 8 : 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _selectShop(shop),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Shop header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color.fromARGB(255, 176, 12, 1).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.store,
                        color: Color.fromARGB(255, 176, 12, 1),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            shop['shop_name'] ?? 'Unknown Shop',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${(shop['distance_km'] ?? 0.0).toStringAsFixed(1)} km away',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Color.fromARGB(255, 176, 12, 1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // Shop details
                if (shop['shop_address'] != null) ...[
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          shop['shop_address'],
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                
                // Mechanics info
                Row(
                  children: [
                    Icon(Icons.build, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      '${shop['available_mechanics'] ?? 0}/${shop['total_mechanics'] ?? 0} mechanics available',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[700],
                      ),
                    ),
                    const Spacer(),
                    if (shop['rating'] != null) ...[
                      const Icon(Icons.star, size: 14, color: Colors.amber),
                      const SizedBox(width: 2),
                      Text(
                        shop['rating'].toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // Status indicator
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: (shop['current_status'] == 'open' ? Colors.red : Colors.orange).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    shop['current_status'] == 'open' ? 'Open Now' : 'Busy',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: shop['current_status'] == 'open' ? Colors.red[700] : Colors.orange[700],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
          'Choose Service Shop',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: Color.fromARGB(255, 176, 12, 1),
                  ),
                  SizedBox(height: 16),
                  Text('Finding nearby shops...'),
                ],
              ),
            )
          : Column(
              children: [
                // Map section
                Container(
                  height: 300,
                  child: GoogleMap(
                    onMapCreated: (GoogleMapController controller) {
                      _mapController = controller;
                      if (_currentLocation != null) {
                        controller.animateCamera(
                          CameraUpdate.newCameraPosition(
                            CameraPosition(
                              target: _currentLocation!,
                              zoom: 14,
                            ),
                          ),
                        );
                      }
                    },
                    initialCameraPosition: CameraPosition(
                      target: _currentLocation ?? const LatLng(14.5995, 120.9842),
                      zoom: 14,
                    ),
                    markers: _markers,
                    myLocationEnabled: true,
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: true,
                    // Enable all gesture controls for movable map
                    zoomGesturesEnabled: true,
                    scrollGesturesEnabled: true,
                    tiltGesturesEnabled: true,
                    rotateGesturesEnabled: true,
                    compassEnabled: true,
                    mapToolbarEnabled: true,
                    gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{}, // Allow all gestures including pan
                  ),
                ),
                
                // Shops list
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            const Text(
                              'Available Shops',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color.fromARGB(255, 176, 12, 1).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${_shops.length} found',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Color.fromARGB(255, 176, 12, 1),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Shops list
                      Expanded(
                        child: _shops.isEmpty
                            ? const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.store_mall_directory,
                                      size: 64,
                                      color: Colors.grey,
                                    ),
                                    SizedBox(height: 16),
                                    Text(
                                      'No shops found nearby',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'Try expanding your search radius',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.only(bottom: 100),
                                itemCount: _shops.length,
                                itemBuilder: (context, index) {
                                  return _buildShopCard(_shops[index]);
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
      floatingActionButton: _selectedShop != null
          ? Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: FloatingActionButton.extended(
                backgroundColor: const Color.fromARGB(255, 176, 12, 1),
                foregroundColor: Colors.white,
                onPressed: _proceedWithShop,
                icon: const Icon(Icons.arrow_forward),
                label: Text(
                  'Continue with ${_selectedShop!['shop_name']}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}











