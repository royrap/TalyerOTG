import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/maps_service.dart';

class RealTimeTrackingScreen extends StatefulWidget {
  final String serviceRequestId;
  final String mechanicId;
  final String mechanicName;
  final String mechanicPhone;
  final LatLng customerLocation;

  const RealTimeTrackingScreen({
    super.key,
    required this.serviceRequestId,
    required this.mechanicId,
    required this.mechanicName,
    required this.mechanicPhone,
    required this.customerLocation,
  });

  @override
  State<RealTimeTrackingScreen> createState() => _RealTimeTrackingScreenState();
}

class _RealTimeTrackingScreenState extends State<RealTimeTrackingScreen> {
  GoogleMapController? _mapController;
  final MapsService _mapsService = MapsService();
    // Map data
  Set<Marker> _markers = ;
  Set<Polyline> _polylines = ;
  LatLng? _mechanicLocation;
  
  // Tracking data
  String _distance = '';
  String _duration = '';
  String _eta = '';
  bool _isLoading = true;
  
  // Streams
  StreamSubscription? _routeSubscription;
  StreamSubscription? _trackingDataSubscription;

  @override
  void initState() {
    super.initState();
    _initializeTracking();
  }

  @override
  void dispose() {
    _routeSubscription?.cancel();
    _trackingDataSubscription?.cancel();
    _mapsService.stopRealTimeTracking();
    super.dispose();
  }

  Future<void> _initializeTracking() async {
    try {
      // Start real-time tracking
      await _mapsService.startRealTimeTracking(
        serviceRequestId: widget.serviceRequestId,
        customerLocation: widget.customerLocation,
        mechanicId: widget.mechanicId,
      );      // Listen to route updates
      _routeSubscription = _mapsService.routeStream.listen((routePoints) {
        setState(() {
          if (routePoints.isNotEmpty) {
            _polylines = {_mapsService.createRoutePolyline(routePoints)};
          }
        });
      });

      // Listen to tracking data updates
      _trackingDataSubscription = _mapsService.trackingDataStream.listen((data) {
        if (data.isNotEmpty) {
          setState(() {
            _mechanicLocation = data['mechanic_location'];
            _distance = data['distance'] ?? '';
            _duration = data['duration'] ?? '';
            _eta = data['eta'] ?? '';
            _isLoading = false;
          });

          _updateMarkers();
          _updateCamera();
        }
      });

    } catch (e) {
      print('❌ Error initializing tracking: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _updateMarkers() {
    _markers = _mapsService.createTrackingMarkers(
      mechanicLocation: _mechanicLocation,
      customerLocation: widget.customerLocation,
      onMechanicMarkerTap: () => _showMechanicInfo(),
      onCustomerMarkerTap: () => _showCustomerInfo(),
    );
  }

  void _updateCamera() {
    if (_mapController != null && _mechanicLocation != null) {
      final cameraUpdate = _mapsService.calculateCameraBounds(
        _mechanicLocation!,
        widget.customerLocation,
      );
      _mapController!.animateCamera(cameraUpdate);
    }
  }
  void _showMechanicInfo() {
    // Services are typically in progress during real-time tracking
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: false, // Prevent dismissal during active tracking
      enableDrag: false, // Prevent drag dismissal during active tracking
      builder: (context) => _buildMechanicInfoSheet(),
    );
  }

  void _showCustomerInfo() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('This is your location'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Widget _buildMechanicInfoSheet() {
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
            
            // Mechanic info
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.blue[100],
                  child: const Icon(
                    Icons.build,
                    size: 30,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.mechanicName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Your assigned mechanic',
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
                    onPressed: () => _callMechanic(),
                    icon: const Icon(Icons.phone),
                    label: const Text('Call'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _messagesMechanic(),
                    icon: const Icon(Icons.message),
                    label: const Text('Message'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
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

  void _callMechanic() {
    Navigator.pop(context);
    // Implement phone call functionality
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Calling ${widget.mechanicName}...'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _messagesMechanic() {
    Navigator.pop(context);
    // Navigate to chat screen
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
          'Track Mechanic',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : Stack(
              children: [                // Google Map
                GoogleMap(
                  onMapCreated: (GoogleMapController controller) {
                    _mapController = controller;
                  },
                  initialCameraPosition: CameraPosition(
                    target: widget.customerLocation,
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
                  trafficEnabled: false,
                  buildingsEnabled: true,
                  // Handle user interactions
                  onTap: (LatLng position) {
                    print('Map tapped at: ${position.latitude}, ${position.longitude}');
                  },
                  onCameraMove: (CameraPosition position) {
                    // Optional: Handle camera movement
                  },
                ),
                
                // Top info card
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: _buildTrackingInfoCard(),
                ),
                
                // Bottom action card
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: _buildActionCard(),
                ),
                
                // My location button
                Positioned(
                  bottom: 100,
                  right: 16,
                  child: FloatingActionButton(
                    mini: true,
                    backgroundColor: Colors.white,
                    onPressed: _goToMyLocation,
                    child: const Icon(
                      Icons.my_location,
                      color: Colors.blue,
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildTrackingInfoCard() {
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
                    color: Colors.blue[100],
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.build,
                    color: Colors.blue,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.mechanicName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        'is on the way',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_eta.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'ETA $_eta',
                      style: TextStyle(
                        color: Colors.green[800],
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            
            if (_distance.isNotEmpty || _duration.isNotEmpty) ...[
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

  Widget _buildActionCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _callMechanic,
                icon: const Icon(Icons.phone),
                label: const Text('Call Mechanic'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _messagesMechanic,
                icon: const Icon(Icons.message),
                label: const Text('Message'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _goToMyLocation() {
    if (_mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(widget.customerLocation, 16.0),
      );
    }
  }
}










