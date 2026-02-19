import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/maps_service.dart';
import '../services/location_service.dart';
import '../services/user_data_service.dart';

class MechanicNavigationScreen extends StatefulWidget {
  final String serviceRequestId;
  final String customerId;
  final String customerName;
  final String customerPhone;
  final LatLng customerLocation;
  final String serviceType;

  const MechanicNavigationScreen({
    super.key,
    required this.serviceRequestId,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    required this.customerLocation,
    required this.serviceType,
  });

  @override
  State<MechanicNavigationScreen> createState() => _MechanicNavigationScreenState();
}

class _MechanicNavigationScreenState extends State<MechanicNavigationScreen> {
  GoogleMapController? _mapController;
  final MapsService _mapsService = MapsService();
  final LocationService _locationService = LocationService();
  
  // Map data
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  LatLng? _currentLocation;
  List<LatLng> _routePoints = [];
    // Navigation data
  String _distance = '';
  String _duration = '';
  bool _hasArrived = false;
  bool _isNavigating = true;
  
  // Timers
  Timer? _locationTimer;
  Timer? _routeTimer;

  @override
  void initState() {
    super.initState();
    _initializeNavigation();
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _routeTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeNavigation() async {
    try {
      // Get current location
      await _updateCurrentLocation();
      
      // Calculate initial route
      await _calculateRoute();
      
      // Start location tracking
      _startLocationTracking();
      
      // Start route updates
      _startRouteUpdates();
      
    } catch (e) {
      print('❌ Error initializing navigation: $e');
    }
  }

  Future<void> _updateCurrentLocation() async {
    try {
      final location = await _locationService.getCurrentLocation();
      if (location != null) {
        setState(() {
          _currentLocation = location;
        });
        _updateMarkers();
      }
    } catch (e) {
      print('❌ Error updating location: $e');
    }
  }

  Future<void> _calculateRoute() async {
    if (_currentLocation == null) return;
    
    try {
      final directions = await _mapsService.getDirections(
        origin: _currentLocation!,
        destination: widget.customerLocation,
      );
      
      if (directions['success'] == true) {
        setState(() {
          _routePoints = directions['route_points'];
          _distance = directions['distance'] ?? '';
          _duration = directions['duration'] ?? '';
          _polylines = {_mapsService.createRoutePolyline(_routePoints)};
        });
        
        // Check if arrived (within 50 meters)
        final distanceToCustomer = _mapsService.calculateDistance(
          _currentLocation!,
          widget.customerLocation,
        );
        
        if (distanceToCustomer <= 0.05) { // 50 meters
          _handleArrival();
        }
        
        _updateCamera();
      }
    } catch (e) {
      print('❌ Error calculating route: $e');
    }
  }

  void _startLocationTracking() {
    _locationTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_isNavigating) {
        _updateCurrentLocation();
      }
    });
  }

  void _startRouteUpdates() {
    _routeTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (_isNavigating && !_hasArrived) {
        _calculateRoute();
      }
    });
  }

  void _updateMarkers() {
    _markers = _mapsService.createTrackingMarkers(
      mechanicLocation: _currentLocation,
      customerLocation: widget.customerLocation,
      onMechanicMarkerTap: () => _showCurrentLocationInfo(),
      onCustomerMarkerTap: () => _showCustomerInfo(),
    );
  }

  void _updateCamera() {
    if (_mapController != null && _currentLocation != null) {
      final cameraUpdate = _mapsService.calculateCameraBounds(
        _currentLocation!,
        widget.customerLocation,
      );
      _mapController!.animateCamera(cameraUpdate);
    }
  }

  void _handleArrival() {
    if (!_hasArrived) {
      setState(() {
        _hasArrived = true;
        _isNavigating = false;
      });
      
      _showArrivalDialog();
    }
  }

  void _showArrivalDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('🎉 You have arrived!'),
        content: Text(
          'You are now at ${widget.customerName}\'s location. Please start the service when ready.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _startService();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color.fromARGB(255, 176, 12, 1),
              foregroundColor: Colors.white,
            ),
            child: const Text('Start Service'),
          ),
        ],
      ),
    );
  }

  Future<void> _startService() async {
    try {
      // Update service request status to in_progress
      final success = await UserDataService.updateServiceRequestStatus(
        widget.serviceRequestId,
        'in_progress',
      );
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Service started successfully!'),
            backgroundColor: Color.fromARGB(255, 176, 12, 1),
          ),
        );
        
        // Navigate back to mechanic dashboard
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error starting service: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showCurrentLocationInfo() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('This is your current location'),
        duration: Duration(seconds: 2),
      ),
    );
  }
  void _showCustomerInfo() {
    // During navigation, mechanic is actively working - prevent dismissal
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: false, // Prevent dismissal during active navigation
      enableDrag: false, // Prevent drag dismissal during active navigation
      builder: (context) => _buildCustomerInfoSheet(),
    );
  }

  Widget _buildCustomerInfoSheet() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            
            // Customer info
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.red[100],
                  child: const Icon(
                    Icons.person,
                    size: 30,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.customerName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.serviceType,
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
            
            const SizedBox(height: 20),
            
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _callCustomer(),
                    icon: const Icon(Icons.phone),
                    label: const Text('Call Customer'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color.fromARGB(255, 176, 12, 1),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _messageCustomer(),
                    icon: const Icon(Icons.message),
                    label: const Text('Message'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color.fromARGB(255, 176, 12, 1),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _callCustomer() {
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Calling ${widget.customerName}...'),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _messageCustomer() {
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Opening chat...'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Navigate to Customer',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (_hasArrived)
            IconButton(
              icon: const Icon(Icons.play_arrow, color: Colors.red),
              onPressed: _startService,
              tooltip: 'Start Service',
            ),
        ],
      ),
      body: Stack(
        children: [          // Google Map
          GoogleMap(
            onMapCreated: (GoogleMapController controller) {
              _mapController = controller;
            },
            initialCameraPosition: CameraPosition(
              target: _currentLocation ?? widget.customerLocation,
              zoom: 14.0,
            ),
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            // Enable all gesture controls for user interaction
            zoomGesturesEnabled: true,
            scrollGesturesEnabled: true,
            rotateGesturesEnabled: true,
            tiltGesturesEnabled: true,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            // Enable interactive features
            compassEnabled: true,
            mapType: MapType.normal,
            trafficEnabled: true, // Show traffic for navigation
            buildingsEnabled: true,
            // Handle user interactions
            onTap: (LatLng position) {
              print('Map tapped at: ${position.latitude}, ${position.longitude}');
            },
            onCameraMove: (CameraPosition position) {
              // Optional: Handle camera movement during navigation
            },
          ),
          
          // Top navigation info card
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: _buildNavigationInfoCard(),
          ),
          
          // Bottom customer info card
          if (!_hasArrived)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: _buildCustomerCard(),
            ),
          
          // Arrived notification
          if (_hasArrived)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: _buildArrivedCard(),
            ),
          
          // Navigation buttons
          Positioned(
            bottom: _hasArrived ? 100 : 140,
            right: 16,
            child: Column(
              children: [
                FloatingActionButton(
                  mini: true,
                  backgroundColor: Colors.white,
                  heroTag: "location",
                  onPressed: () {
                    if (_mapController != null && _currentLocation != null) {
                      _mapController!.animateCamera(
                        CameraUpdate.newLatLngZoom(_currentLocation!, 16.0),
                      );
                    }
                  },
                  child: const Icon(
                    Icons.my_location,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  mini: true,
                  backgroundColor: Colors.white,
                  heroTag: "refresh",
                  onPressed: _calculateRoute,
                  child: const Icon(
                    Icons.refresh,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationInfoCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _hasArrived ? Colors.red[100] : Colors.blue[100],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _hasArrived ? Icons.check : Icons.navigation,
                    color: _hasArrived ? Colors.red : Colors.blue,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _hasArrived ? 'You have arrived!' : 'Navigating to customer',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _hasArrived ? 'Ready to start service' : widget.customerName,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            if (!_hasArrived && (_distance.isNotEmpty || _duration.isNotEmpty)) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  if (_distance.isNotEmpty)
                    Column(
                      children: [
                        const Icon(
                          Icons.location_on,
                          color: Colors.blue,
                          size: 20,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _distance,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        const Text(
                          'Distance',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  if (_duration.isNotEmpty)
                    Column(
                      children: [
                        const Icon(
                          Icons.access_time,
                          color: Colors.orange,
                          size: 20,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _duration,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        const Text(
                          'Duration',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 25,
              backgroundColor: Colors.red[100],
              child: const Icon(
                Icons.person,
                color: Colors.red,
                size: 25,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.customerName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    widget.serviceType,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: _callCustomer,
              icon: const Icon(Icons.phone, color: Colors.red),
            ),
            IconButton(
              onPressed: _messageCustomer,
              icon: const Icon(Icons.message, color: Colors.blue),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArrivedCard() {
    return Card(
      elevation: 4,
      color: Colors.red[50],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Text(
                'You have arrived at the customer location!',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: _startService,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Start Service'),
            ),
          ],
        ),
      ),
    );
  }
}










