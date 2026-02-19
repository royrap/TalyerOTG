import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/location_service.dart';
import '../services/shop_services_service.dart';
import 'request_assistance_screen.dart';
import 'shop_selection_screen.dart';

class ServiceTypeSelectionScreen extends StatefulWidget {
  const ServiceTypeSelectionScreen({Key? key}) : super(key: key);

  @override
  State<ServiceTypeSelectionScreen> createState() => _ServiceTypeSelectionScreenState();
}

class _ServiceTypeSelectionScreenState extends State<ServiceTypeSelectionScreen> {
  Position? _currentLocation;
  List<Map<String, dynamic>> _nearbyShops = [];
  bool _isLoadingShops = false;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      final location = await LocationService().getCurrentLocation();
      if (location != null) {
        setState(() {
          _currentLocation = Position(
            latitude: location.latitude,
            longitude: location.longitude,
            timestamp: DateTime.now(),
            accuracy: 0,
            altitude: 0,
            heading: 0,
            speed: 0,
            speedAccuracy: 0,
            altitudeAccuracy: 0,
            headingAccuracy: 0,
          );
        });
        await _loadNearbyShops();
      }
    } catch (e) {
      print('Error getting location: $e');
    }
  }

  Future<void> _loadNearbyShops() async {
    if (_currentLocation == null) return;
    
    setState(() => _isLoadingShops = true);
    
    try {
      final shops = await ShopServicesService.instance.getNearbyShopsWithServices(
        customerLocation: LatLng(_currentLocation!.latitude, _currentLocation!.longitude),
        radiusKm: 25.0,
        limit: 5,
      );
      
      setState(() {
        _nearbyShops = shops;
      });
    } catch (e) {
      print('Error loading nearby shops: $e');
    } finally {
      setState(() => _isLoadingShops = false);
    }
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
          'Choose Service Type',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header section with gradient
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color.fromARGB(255, 176, 12, 1),
                    const Color.fromARGB(255, 176, 12, 1).withOpacity(0.8),
                  ],
                ),
              ),
              child: const Column(
                children: [
                  SizedBox(height: 20),
                  Icon(
                    Icons.build_circle,
                    size: 60,
                    color: Colors.white,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'How would you like to get help?',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Choose your preferred service method',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 30),
                ],
              ),
            ),
            
            // Service type options
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Direct Mechanic Request Option
                  _buildServiceTypeCard(
                    icon: Icons.person_search,
                    title: 'Find Any Available Mechanic',
                    subtitle: 'Get help from the nearest available mechanic',
                    description: 'Request will be sent to all mechanics in your area. First available mechanic can accept.',
                    benefits: [
                      'Fastest response time',
                      'All nearby mechanics notified',
                      'Usually cheaper rates',
                      'Good for urgent repairs',
                    ],
                    color: Colors.blue,
                    onTap: () => _navigateToDirectMechanicRequest(),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Shop Selection Option
                  _buildServiceTypeCard(
                    icon: Icons.store,
                    title: 'Choose a Specific Shop',
                    subtitle: 'Select from nearby auto repair shops',
                    description: 'Browse shops, compare services and prices, then request from your preferred shop.',
                    benefits: [
                      'Compare prices and services',
                      'View shop ratings and reviews',
                      'Professional facilities',
                      'Specialized equipment available',
                    ],
                    color: Colors.orange,
                    shopCount: _nearbyShops.length,
                    isLoading: _isLoadingShops,
                    onTap: () => _navigateToShopSelection(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceTypeCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String description,
    required List<String> benefits,
    required Color color,
    required VoidCallback onTap,
    int? shopCount,
    bool isLoading = false,
  }) {
    return Container(
      width: double.infinity,
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
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        icon,
                        color: color,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (shopCount != null) ...[
                      if (isLoading)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '$shopCount shops',
                            style: TextStyle(
                              color: color,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                    const SizedBox(width: 8),
                    Icon(
                      Icons.arrow_forward_ios,
                      color: color,
                      size: 16,
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Description
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                    height: 1.4,
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Benefits
                ...benefits.map((benefit) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          benefit,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    ],
                  ),
                )).toList(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToDirectMechanicRequest() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const RequestAssistanceScreen(),
      ),
    );
  }

  void _navigateToShopSelection() {
    if (_currentLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enable location services to browse shops'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ShopSelectionScreen(
          customerLocation: LatLng(
            _currentLocation!.latitude,
            _currentLocation!.longitude,
          ),
        ),
      ),
    );
  }
}










