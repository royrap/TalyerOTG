import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/location_based_request_service.dart';
import '../services/auth_service.dart';
import 'dart:async';

class MechanicLocationBasedDashboard extends StatefulWidget {
  const MechanicLocationBasedDashboard({super.key});

  @override
  State<MechanicLocationBasedDashboard> createState() => _MechanicLocationBasedDashboardState();
}

class _MechanicLocationBasedDashboardState extends State<MechanicLocationBasedDashboard> {
  List<Map<String, dynamic>> _nearbyRequests = [];
  bool _isLoading = true;
  bool _isLocationLoading = false;
  String _errorMessage = '';
  double? _mechanicLatitude;
  double? _mechanicLongitude;
  String? _mechanicId;
  Timer? _refreshTimer;
  double _maxDistanceKm = 50.0;

  @override
  void initState() {
    super.initState();
    _initializeMechanic();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeMechanic() async {
    try {
      // Get current mechanic
      final user = await AuthService.getCurrentUser();
      if (user == null) {
        setState(() {
          _errorMessage = 'Please log in to view requests';
          _isLoading = false;
        });
        return;
      }

      _mechanicId = user.id;
      print('👤 Mechanic ID: $_mechanicId');

      // Get mechanic's current location
      await _getCurrentLocation();
      
      // Start periodic refresh
      _startPeriodicRefresh();

    } catch (e) {
      print('❌ Error initializing mechanic: $e');
      setState(() {
        _errorMessage = 'Failed to initialize: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLocationLoading = true;
    });

    try {
      // Check location permissions
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied');
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _mechanicLatitude = position.latitude;
        _mechanicLongitude = position.longitude;
        _isLocationLoading = false;
      });

      print('📍 Mechanic location: ${position.latitude}, ${position.longitude}');

      // Load nearby requests
      await _loadNearbyRequests();

    } catch (e) {
      print('❌ Error getting location: $e');
      setState(() {
        _errorMessage = 'Location error: $e';
        _isLocationLoading = false;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadNearbyRequests() async {
    if (_mechanicId == null || _mechanicLatitude == null || _mechanicLongitude == null) {
      return;
    }

    try {
      print('🔄 Loading nearby requests...');
      
      final requests = await LocationBasedRequestService.getRealtimeNearbyRequests(
        mechanicId: _mechanicId!,
        mechanicLatitude: _mechanicLatitude!,
        mechanicLongitude: _mechanicLongitude!,
        maxDistanceKm: _maxDistanceKm,
      );

      setState(() {
        _nearbyRequests = requests;
        _isLoading = false;
        _errorMessage = '';
      });

      print('📋 Loaded ${requests.length} nearby requests');

    } catch (e) {
      print('❌ Error loading requests: $e');
      setState(() {
        _errorMessage = 'Failed to load requests: $e';
        _isLoading = false;
      });
    }
  }

  void _startPeriodicRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        _loadNearbyRequests();
      }
    });
  }

  Future<void> _acceptRequest(String requestId) async {
    if (_mechanicId == null || _mechanicLatitude == null || _mechanicLongitude == null) {
      return;
    }

    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Accepting request...'),
            ],
          ),
        ),
      );

      final success = await LocationBasedRequestService.acceptNearbyRequest(
        mechanicId: _mechanicId!,
        requestId: requestId,
        mechanicLatitude: _mechanicLatitude!,
        mechanicLongitude: _mechanicLongitude!,
      );

      // Close loading dialog
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Request accepted successfully!'),
            backgroundColor: Colors.red,
          ),
        );
        
        // Refresh the list
        await _loadNearbyRequests();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Failed to accept request. It may no longer be available.'),
            backgroundColor: Colors.red,
          ),
        );
      }

    } catch (e) {
      // Close loading dialog if still open
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Nearby Service Requests',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color.fromARGB(255, 176, 12, 1),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadNearbyRequests,
          ),
          IconButton(
            icon: const Icon(Icons.tune, color: Colors.white),
            onPressed: _showDistanceFilter,
          ),
        ],
      ),
      body: Column(
        children: [
          // Location Status Header
          _buildLocationStatusHeader(),
          
          // Requests List
          Expanded(
            child: _buildRequestsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationStatusHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _mechanicLatitude != null ? Icons.location_on : Icons.location_off,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _mechanicLatitude != null 
                          ? 'Location Active'
                          : 'Getting Location...',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _mechanicLatitude != null 
                          ? 'Showing requests within ${_maxDistanceKm.round()}km'
                          : 'Please wait while we get your location',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (_isLocationLoading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Request Count
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${_nearbyRequests.length} nearby requests',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestsList() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading nearby requests...'),
          ],
        ),
      );
    }

    if (_errorMessage.isNotEmpty) {
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
            Text(
              'Error',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _getCurrentLocation,
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

    if (_nearbyRequests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.location_searching,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No nearby requests',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'There are no service requests within ${_maxDistanceKm.round()}km of your location.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadNearbyRequests,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 176, 12, 1),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadNearbyRequests,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _nearbyRequests.length,
        itemBuilder: (context, index) {
          final request = _nearbyRequests[index];
          return _buildRequestCard(request);
        },
      ),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> request) {
    final urgency = request['urgency'] ?? 'normal';
    final distance = request['distance_km'] as double;
    final distanceText = request['distance_text'] ?? '${distance.toStringAsFixed(1)}km';
    final arrivalTime = request['estimated_arrival_minutes'] ?? 30;
    final customer = request['user_profiles'] ?? {};
    
    Color urgencyColor;
    IconData urgencyIcon;
    
    switch (urgency) {
      case 'high':
        urgencyColor = Colors.red;
        urgencyIcon = Icons.priority_high;
        break;
      case 'medium':
        urgencyColor = Colors.orange;
        urgencyIcon = Icons.schedule;
        break;
      default:
        urgencyColor = Colors.red;
        urgencyIcon = Icons.new_releases;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: urgencyColor.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: urgencyColor.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
              ),
            ),
            child: Row(
              children: [
                Icon(urgencyIcon, color: urgencyColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    request['urgency_text'] ?? 'New request',
                    style: TextStyle(
                      color: urgencyColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    distanceText,
                    style: const TextStyle(
                      color: Colors.blue,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title and Service Type
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        request['title'] ?? 'Service Request',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        request['service_type'] ?? 'General',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 8),
                
                // Description
                if (request['description'] != null && request['description'].toString().isNotEmpty)
                  Text(
                    request['description'],
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                
                const SizedBox(height: 12),
                
                // Customer Info
                Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.grey[300],
                      backgroundImage: customer['profile_image_url'] != null
                          ? NetworkImage(customer['profile_image_url'])
                          : null,
                      child: customer['profile_image_url'] == null
                          ? const Icon(Icons.person, size: 16)
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${customer['first_name'] ?? ''} ${customer['last_name'] ?? ''}'.trim(),
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                          if (customer['phone_number'] != null)
                            Text(
                              customer['phone_number'],
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // Location and Timing
                Row(
                  children: [
                    Icon(Icons.location_on, color: Colors.grey[600], size: 16),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        request['pickup_address'] ?? 'Location not specified',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 4),
                
                Row(
                  children: [
                    Icon(Icons.access_time, color: Colors.grey[600], size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'ETA: ${arrivalTime} minutes',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                    if (request['estimated_price'] != null) ...[
                      const SizedBox(width: 16),
                      Icon(Icons.attach_money, color: Colors.grey[600], size: 16),
                      Text(
                        '₱${request['estimated_price'].toStringAsFixed(0)}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Accept Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _acceptRequest(request['id']),
                    icon: const Icon(Icons.check_circle),
                    label: const Text('Accept Request'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 176, 12, 1),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showDistanceFilter() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Search Distance'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Current range: ${_maxDistanceKm.round()}km'),
            const SizedBox(height: 16),
            Slider(
              value: _maxDistanceKm,
              min: 5.0,
              max: 100.0,
              divisions: 19,
              label: '${_maxDistanceKm.round()}km',
              onChanged: (value) {
                setState(() {
                  _maxDistanceKm = value;
                });
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _loadNearbyRequests();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromARGB(255, 176, 12, 1),
              foregroundColor: Colors.white,
            ),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }
}