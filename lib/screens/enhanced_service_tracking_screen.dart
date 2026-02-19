import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../services/maps_service.dart';
import '../services/supabase_service.dart';
import '../theme/roadaid_colors.dart';
import '../shared/services/google_maps_service.dart';

class EnhancedServiceTrackingScreen extends StatefulWidget {
  final String serviceRequestId;
  final Map<String, dynamic> customerInfo;
  final Map<String, dynamic> mechanicInfo;
  final bool isMechanicView; // true if mechanic is viewing, false if customer

  const EnhancedServiceTrackingScreen({
    super.key,
    required this.serviceRequestId,
    required this.customerInfo,
    required this.mechanicInfo,
    required this.isMechanicView,
  });

  @override
  State<EnhancedServiceTrackingScreen> createState() => _EnhancedServiceTrackingScreenState();
}

class _EnhancedServiceTrackingScreenState extends State<EnhancedServiceTrackingScreen> 
    with TickerProviderStateMixin {
  
  GoogleMapController? _mapController;
  final MapsService _mapsService = MapsService();
  
  // Map data
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  LatLng? _mechanicLocation;
  LatLng? _customerLocation;
  
  // Tracking data
  String _distance = '';
  String _duration = '';
  String _eta = '';
  bool _isLoading = true;
  
  // Animation controllers
  late AnimationController _profileController;
  late AnimationController _mapController2;
  late Animation<double> _profileAnimation;
  late Animation<double> _mapAnimation;
  
  // Real-time streams
  StreamSubscription? _routeSubscription;
  StreamSubscription? _trackingDataSubscription;
  StreamSubscription? _locationSubscription;
  Timer? _locationUpdateTimer;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _initializeCustomerLocation();
    _initializeTracking();
    _startLocationUpdates();
  }

  @override
  void dispose() {
    _profileController.dispose();
    _mapController2.dispose();
    _routeSubscription?.cancel();
    _trackingDataSubscription?.cancel();
    _locationSubscription?.cancel();
    _locationUpdateTimer?.cancel();
    _mapsService.stopRealTimeTracking();
    super.dispose();
  }

  void _setupAnimations() {
    _profileController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _mapController2 = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _profileAnimation = CurvedAnimation(
      parent: _profileController,
      curve: Curves.elasticOut,
    );
    
    _mapAnimation = CurvedAnimation(
      parent: _mapController2,
      curve: Curves.easeInOutCubic,
    );

    // Start animations
    _profileController.forward();
    Future.delayed(const Duration(milliseconds: 300), () {
      _mapController2.forward();
    });
  }

  void _initializeCustomerLocation() {
    // Get customer location from the service request
    final pickupLat = widget.customerInfo['pickup_latitude'];
    final pickupLng = widget.customerInfo['pickup_longitude'];
    
    if (pickupLat != null && pickupLng != null) {
      _customerLocation = LatLng(pickupLat.toDouble(), pickupLng.toDouble());
    }
  }

  Future<void> _initializeTracking() async {
    try {
      // Start real-time tracking
      await _mapsService.startRealTimeTracking(
        serviceRequestId: widget.serviceRequestId,
        customerLocation: _customerLocation!,
        mechanicId: widget.mechanicInfo['id'],
      );

      // Listen to route updates
      _routeSubscription = _mapsService.routeStream.listen((routePoints) {
        if (mounted && routePoints.isNotEmpty) {
          setState(() {
            _polylines = {_createRoutePolyline(routePoints)};
          });
          _updateCameraBounds(routePoints);
        }
      });

      // Listen to tracking data updates
      _trackingDataSubscription = _mapsService.trackingDataStream.listen((data) {
        if (mounted && data.isNotEmpty) {
          setState(() {
            _mechanicLocation = data['mechanic_location'];
            _distance = data['distance'] ?? '';
            _duration = data['duration'] ?? '';
            _eta = data['eta'] ?? '';
            _isLoading = false;
          });
          _updateMarkers();
        }
      });

    } catch (e) {
      print('❌ Error initializing tracking: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _startLocationUpdates() {
    // Update locations every 10 seconds for real-time tracking
    _locationUpdateTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (widget.isMechanicView) {
        _updateMechanicLocation();
      }
      _fetchLatestTrackingData();
    });
  }

  Future<void> _updateMechanicLocation() async {
    try {
      // Validate mechanic ID before making database calls
      final mechanicId = widget.mechanicInfo['id'];
      if (mechanicId == null || mechanicId.toString().isEmpty) {
        print('⚠️ No valid mechanic ID available for location update');
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final newLocation = LatLng(position.latitude, position.longitude);
      
      // Update mechanic location in database
      await SupabaseService.client
          .from('mechanic_availability_status')
          .update({
            'location_latitude': position.latitude,
            'location_longitude': position.longitude,
            'last_status_update': DateTime.now().toIso8601String(),
          })
          .eq('mechanic_id', mechanicId);

      if (mounted) {
        setState(() {
          _mechanicLocation = newLocation;
        });
        _updateMarkers();
      }
    } catch (e) {
      print('❌ Error updating mechanic location: $e');
      // Don't rethrow to prevent app crashes
    }
  }

  Future<void> _fetchLatestTrackingData() async {
    try {
      if (_mechanicLocation != null && _customerLocation != null) {
        // Get updated distance and duration
        final directionsData = await GoogleMapsService.getDistanceMatrix(
          origin: _mechanicLocation!,
          destination: _customerLocation!,
        );

        if (mounted && directionsData != null) {
          setState(() {
            _distance = directionsData['distance'] ?? _distance;
            _duration = directionsData['duration'] ?? _duration;
            _eta = _calculateETA();
          });
        }
      }
    } catch (e) {
      print('❌ Error fetching tracking data: $e');
    }
  }

  String _calculateETA() {
    if (_duration.isEmpty) return '';
    
    try {
      // Parse duration (e.g., "15 mins") and calculate ETA
      final now = DateTime.now();
      final durationValue = _duration.replaceAll(RegExp(r'[^0-9]'), '');
      if (durationValue.isNotEmpty) {
        final minutes = int.parse(durationValue);
        final eta = now.add(Duration(minutes: minutes));
        return '${eta.hour.toString().padLeft(2, '0')}:${eta.minute.toString().padLeft(2, '0')}';
      }
    } catch (e) {
      print('Error calculating ETA: $e');
    }
    
    return '';
  }

  void _updateMarkers() {
    _markers.clear();

    // Customer marker
    if (_customerLocation != null) {
      _markers.add(Marker(
        markerId: const MarkerId('customer'),
        position: _customerLocation!,
        infoWindow: InfoWindow(
          title: widget.customerInfo['customer_name'] ?? 'Customer',
          snippet: 'Service Location',
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      ));
    }

    // Mechanic marker
    if (_mechanicLocation != null) {
      _markers.add(Marker(
        markerId: const MarkerId('mechanic'),
        position: _mechanicLocation!,
        infoWindow: InfoWindow(
          title: widget.mechanicInfo['full_name'] ?? 'Mechanic',
          snippet: widget.isMechanicView ? 'Your Location' : 'Mechanic Location',
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ));
    }
  }

  Polyline _createRoutePolyline(List<LatLng> routePoints) {
    return Polyline(
      polylineId: const PolylineId('route'),
      color: RoadAidColors.primary,
      width: 5,
      points: routePoints,
      patterns: [],
      startCap: Cap.roundCap,
      endCap: Cap.roundCap,
      geodesic: true,
    );
  }

  void _updateCameraBounds(List<LatLng> routePoints) {
    if (_mapController == null || routePoints.isEmpty) return;

    final bounds = _calculateBounds(routePoints);
    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 100),
    );
  }

  LatLngBounds _calculateBounds(List<LatLng> points) {
    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final point in points) {
      minLat = minLat < point.latitude ? minLat : point.latitude;
      maxLat = maxLat > point.latitude ? maxLat : point.latitude;
      minLng = minLng < point.longitude ? minLng : point.longitude;
      maxLng = maxLng > point.longitude ? maxLng : point.longitude;
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(
          widget.isMechanicView ? 'Navigate to Customer' : 'Tracking Mechanic',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: RoadAidColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : Column(
              children: [
                // Profile Information Section
                AnimatedBuilder(
                  animation: _profileAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _profileAnimation.value,
                      child: _buildProfileSection(),
                    );
                  },
                ),
                
                // Map Section
                Expanded(
                  child: AnimatedBuilder(
                    animation: _mapAnimation,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _mapAnimation.value,
                        child: _buildMapSection(),
                      );
                    },
                  ),
                ),
                
                // Action Buttons Section
                _buildActionSection(),
              ],
            ),
    );
  }

  Widget _buildProfileSection() {
    final otherPersonInfo = widget.isMechanicView ? widget.customerInfo : widget.mechanicInfo;
    final title = widget.isMechanicView ? 'Customer Information' : 'Your Mechanic';
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(26),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
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
          const SizedBox(height: 16),
          
          Row(
            children: [
              // Profile Picture
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: RoadAidColors.primary, width: 2),
                ),
                child: ClipOval(
                  child: otherPersonInfo['profile_image_url'] != null
                      ? Image.network(
                          otherPersonInfo['profile_image_url'],
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return _buildDefaultAvatar();
                          },
                        )
                      : _buildDefaultAvatar(),
                ),
              ),
              
              const SizedBox(width: 16),
              
              // Information
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      otherPersonInfo['customer_name'] ?? 
                      otherPersonInfo['full_name'] ?? 
                      'Unknown',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      otherPersonInfo['phone_number'] ?? 
                      otherPersonInfo['customer_phone'] ?? 
                      'No phone',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    // Real-time distance and ETA
                    Row(
                      children: [
                        Icon(Icons.location_on, 
                             size: 16, 
                             color: RoadAidColors.primary),
                        const SizedBox(width: 4),
                        Text(
                          _distance.isNotEmpty ? _distance : 'Calculating...',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        if (_eta.isNotEmpty) ...[
                          const SizedBox(width: 12),
                          Icon(Icons.access_time, 
                               size: 16, 
                               color: RoadAidColors.primary),
                          const SizedBox(width: 4),
                          Text(
                            'ETA: $_eta',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              
              // Call button
              IconButton(
                onPressed: () {
                  // Implement call functionality
                  _makePhoneCall(otherPersonInfo['phone_number'] ?? 
                                otherPersonInfo['customer_phone'] ?? '');
                },
                icon: const Icon(Icons.phone),
                style: IconButton.styleFrom(
                  backgroundColor: RoadAidColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultAvatar() {
    return Container(
      color: RoadAidColors.primary.withAlpha(26),
      child: Icon(
        widget.isMechanicView ? Icons.person : Icons.build,
        color: RoadAidColors.primary,
        size: 30,
      ),
    );
  }

  Widget _buildMapSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(26),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: GoogleMap(
          onMapCreated: (GoogleMapController controller) {
            _mapController = controller;
          },
          initialCameraPosition: CameraPosition(
            target: _customerLocation ?? const LatLng(14.5995, 120.9842),
            zoom: 14,
          ),
          markers: _markers,
          polylines: _polylines,
          myLocationEnabled: widget.isMechanicView,
          myLocationButtonEnabled: widget.isMechanicView,
          trafficEnabled: true,
          zoomControlsEnabled: true,
          mapToolbarEnabled: true,
          // Enable all gesture controls for movable map
          zoomGesturesEnabled: true,
          scrollGesturesEnabled: true,
          tiltGesturesEnabled: true,
          rotateGesturesEnabled: true,
          compassEnabled: true,
        ),
      ),
    );
  }

  Widget _buildActionSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Status indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: RoadAidColors.primary.withAlpha(26),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: RoadAidColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  widget.isMechanicView ? 'Heading to customer' : 'Mechanic on the way',
                  style: TextStyle(
                    color: RoadAidColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Action buttons
          Row(
            children: [
              // Open in Maps app
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _openInMapsApp,
                  icon: const Icon(Icons.map),
                  label: const Text('Open in Maps'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: RoadAidColors.primary,
                    side: BorderSide(color: RoadAidColors.primary),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              
              const SizedBox(width: 12),
              
              // Refresh location
              ElevatedButton.icon(
                onPressed: _refreshLocation,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: RoadAidColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _makePhoneCall(String phoneNumber) {
    // Implement phone call functionality
    print('Calling: $phoneNumber');
    // You can use url_launcher package to make actual calls
  }

  void _openInMapsApp() {
    // Implement opening in external maps app
    print('Opening in maps app...');
    // You can use url_launcher to open Google Maps or Apple Maps
  }

  void _refreshLocation() {
    // Refresh the current location and tracking data
    if (widget.isMechanicView) {
      _updateMechanicLocation();
    }
    _fetchLatestTrackingData();
  }
}










