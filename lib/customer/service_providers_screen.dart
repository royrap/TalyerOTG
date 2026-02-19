import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/user_data_service.dart';
import '../shared/services/google_maps_service.dart';

class ServiceProvidersScreen extends StatefulWidget {
  @override
  _ServiceProvidersScreenState createState() => _ServiceProvidersScreenState();
}

class _ServiceProvidersScreenState extends State<ServiceProvidersScreen> {
  List<Map<String, dynamic>> serviceProviders = [];
  bool isLoading = true;
  Position? currentLocation;
  final GoogleMapsService mapsService = GoogleMapsService();
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadServiceProviders();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        currentLocation = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        if (mounted) setState(() {});
      }
    } catch (e) {
      // Get current location silently
    }
  }

  Future<void> _loadServiceProviders() async {
    try {
      final providers = await UserDataService.getNearbyServiceProviders(
        latitude: currentLocation?.latitude,
        longitude: currentLocation?.longitude,
        radiusKm: 50.0, // 50km radius
      );
      
      if (mounted) {
        setState(() {
          serviceProviders = providers.map((provider) {
            // Calculate distance if we have current location
            double? distance;
            if (currentLocation != null && 
                provider['current_latitude'] != null && 
                provider['current_longitude'] != null) {
              distance = Geolocator.distanceBetween(
                currentLocation!.latitude,
                currentLocation!.longitude,
                provider['current_latitude'].toDouble(),
                provider['current_longitude'].toDouble(),
              ) / 1000; // Convert to kilometers
            }
            
            return {
              ...provider,
              'distance': distance,
            };
          }).toList();
          
          // Sort by distance if available
          serviceProviders.sort((a, b) {
            if (a['distance'] == null && b['distance'] == null) return 0;
            if (a['distance'] == null) return 1;
            if (b['distance'] == null) return -1;
            return a['distance'].compareTo(b['distance']);
          });
          
          isLoading = false;
        });
      }
    } catch (e) {
      // Error loading service providers
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> get filteredProviders {
    if (searchQuery.isEmpty) return serviceProviders;
    
    return serviceProviders.where((provider) {
      final shopName = (provider['shop_name'] ?? 
                      provider['business_name'] ?? 
                      provider['name'] ?? '').toString().toLowerCase();
      final address = (provider['address'] ?? 
                      provider['location'] ?? '').toString().toLowerCase();
      final services = (provider['services'] ?? 
                       provider['service_types'] ?? 
                       provider['specialization'] ?? '').toString().toLowerCase();
      final query = searchQuery.toLowerCase();
      
      return shopName.contains(query) || 
             address.contains(query) || 
             services.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Service Providers'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  searchQuery = value;
                });
              },
              decoration: InputDecoration(
                hintText: 'Search by shop name, location, or services...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
            ),
          ),
          
          // Providers List
          Expanded(
            child: isLoading
                ? Center(child: CircularProgressIndicator())
                : filteredProviders.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            SizedBox(height: 16),
                            Text(
                              searchQuery.isEmpty 
                                  ? 'No service providers available'
                                  : 'No providers found matching your search',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadServiceProviders,
                        child: ListView.builder(
                          padding: EdgeInsets.all(16),
                          itemCount: filteredProviders.length,
                          itemBuilder: (context, index) {
                            final provider = filteredProviders[index];
                            return _buildProviderCard(provider);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildProviderCard(Map<String, dynamic> provider) {
    // Handle different possible field names from the database
    final shopName = provider['shop_name'] ?? 
                    provider['business_name'] ?? 
                    provider['name'] ?? 
                    'Unknown Shop';
    final address = provider['address'] ?? 
                   provider['location'] ?? 
                   'Address not available';
    final services = provider['services'] ?? 
                    provider['service_types'] ?? 
                    provider['specialization'] ?? 
                    'Services not specified';
    final phone = provider['phone_number'] ?? 
                 provider['user_profiles']?['phone_number'] ?? 
                 '';
    final distance = provider['distance'];
    final isOnline = provider['current_latitude'] != null && 
                     provider['current_longitude'] != null;
    
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _showProviderDetails(provider),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with shop name and status
              Row(
                children: [
                  Expanded(
                    child: Text(
                      shopName,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isOnline ? Colors.red : Colors.grey,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isOnline ? 'Online' : 'Offline',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              
              SizedBox(height: 8),
              
              // Address
              Row(
                children: [
                  Icon(Icons.location_on, color: Colors.red, size: 16),
                  SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      address,
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
              
              SizedBox(height: 8),
              
              // Services
              Row(
                children: [
                  Icon(Icons.build, color: Colors.blue, size: 16),
                  SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      services,
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
              
              if (distance != null) ...[
                SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.directions, color: Colors.red, size: 16),
                    SizedBox(width: 4),
                    Text(
                      '${distance.toStringAsFixed(1)} km away',
                      style: TextStyle(
                        color: Colors.red[700],
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
              
              if (phone.isNotEmpty) ...[
                SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.phone, color: Colors.orange, size: 16),
                    SizedBox(width: 4),
                    Text(
                      phone,
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
              
              SizedBox(height: 12),
              
              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showProviderDetails(provider),
                      icon: Icon(Icons.info, size: 16),
                      label: Text('View Details'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  if (isOnline) ...[
                    SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _showOnMap(provider),
                        icon: Icon(Icons.map, size: 16),
                        label: Text('View on Map'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showProviderDetails(Map<String, dynamic> provider) {
    final shopName = provider['shop_name'] ?? 
                    provider['business_name'] ?? 
                    provider['name'] ?? 
                    'Unknown Shop';
    final address = provider['address'] ?? 
                   provider['location'] ?? 
                   'Address not available';
    final services = provider['services'] ?? 
                    provider['service_types'] ?? 
                    provider['specialization'] ?? 
                    'Services not specified';
    final phone = provider['phone_number'] ?? 
                 provider['user_profiles']?['phone_number'] ?? 
                 '';
                 
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: EdgeInsets.symmetric(vertical: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Shop name
                      Text(
                        shopName,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      
                      SizedBox(height: 16),
                      
                      // Location info
                      _buildDetailRow(
                        Icons.location_on, 
                        'Address', 
                        address
                      ),
                      
                      _buildDetailRow(
                        Icons.build, 
                        'Services', 
                        services
                      ),
                      
                      if (phone.isNotEmpty)
                        _buildDetailRow(
                          Icons.phone, 
                          'Phone', 
                          phone
                        ),
                      
                      if (provider['distance'] != null)
                        _buildDetailRow(
                          Icons.directions, 
                          'Distance', 
                          '${provider['distance'].toStringAsFixed(1)} km away'
                        ),
                      
                      if (provider['current_latitude'] != null && provider['current_longitude'] != null) ...[
                        SizedBox(height: 20),
                        
                        Container(
                          width: double.infinity,
                          height: 200,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: GoogleMap(
                              initialCameraPosition: CameraPosition(
                                target: LatLng(
                                  provider['current_latitude'].toDouble(),
                                  provider['current_longitude'].toDouble(),
                                ),
                                zoom: 15,
                              ),
                              markers: {
                                Marker(
                                  markerId: MarkerId('shop_location'),
                                  position: LatLng(
                                    provider['current_latitude'].toDouble(),
                                    provider['current_longitude'].toDouble(),
                                  ),
                                  infoWindow: InfoWindow(
                                    title: shopName,
                                  ),
                                ),
                              },
                              // Enable all gesture controls for movable map
                              zoomControlsEnabled: true,
                              zoomGesturesEnabled: true,
                              scrollGesturesEnabled: true,
                              tiltGesturesEnabled: true,
                              rotateGesturesEnabled: true,
                              compassEnabled: true,
                              mapToolbarEnabled: true,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.grey[600], size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showOnMap(Map<String, dynamic> provider) {
    if (provider['current_latitude'] == null || provider['current_longitude'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Location not available for this provider')),
      );
      return;
    }

    final shopName = provider['shop_name'] ?? 
                    provider['business_name'] ?? 
                    provider['name'] ?? 
                    'Shop';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ShopMapView(
          shopLocation: LatLng(
            provider['current_latitude'].toDouble(),
            provider['current_longitude'].toDouble(),
          ),
          shopName: shopName,
          userLocation: currentLocation != null 
              ? LatLng(currentLocation!.latitude, currentLocation!.longitude)
              : null,
        ),
      ),
    );
  }
}

class ShopMapView extends StatelessWidget {
  final LatLng shopLocation;
  final String shopName;
  final LatLng? userLocation;

  const ShopMapView({
    super.key,
    required this.shopLocation,
    required this.shopName,
    this.userLocation,
  });

  @override
  Widget build(BuildContext context) {
    Set<Marker> markers = {
      Marker(
        markerId: MarkerId('shop'),
        position: shopLocation,
        infoWindow: InfoWindow(title: shopName),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      ),
    };

    if (userLocation != null) {
      markers.add(
        Marker(
          markerId: MarkerId('user'),
          position: userLocation!,
          infoWindow: InfoWindow(title: 'Your Location'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(shopName),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: shopLocation,
          zoom: 15,
        ),
        markers: markers,
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
        // Enable all gesture controls for movable map
        zoomControlsEnabled: true,
        zoomGesturesEnabled: true,
        scrollGesturesEnabled: true,
        tiltGesturesEnabled: true,
        rotateGesturesEnabled: true,
        compassEnabled: true,
        mapToolbarEnabled: true,
      ),
    );
  }
}





















