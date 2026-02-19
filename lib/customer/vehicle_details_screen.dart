import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import '../mechanic/mechanic_waiting_screen.dart';
import '../services/user_data_service.dart';
import '../services/auth_service.dart';
import '../shared/widgets/add_vehicle_dialog.dart';
import '../services/enhanced_service_request_service.dart';

class VehicleDetailsScreen extends StatefulWidget {
  final String? issueType;
  final String? issueDescription;
  final String? issueTitle;
  final Map<String, dynamic>? preSelectedMechanic; // Add parameter for pre-selected mechanic
  
  const VehicleDetailsScreen({
    Key? key,
    this.issueType,
    this.issueDescription,
    this.issueTitle,
    this.preSelectedMechanic,
  }) : super(key: key);

  @override
  State<VehicleDetailsScreen> createState() => _VehicleDetailsScreenState();
}

class _VehicleDetailsScreenState extends State<VehicleDetailsScreen> {
  final TextEditingController _modelController = TextEditingController();
  final TextEditingController _yearController = TextEditingController();
  final TextEditingController _issueController = TextEditingController();
  bool _isLoading = true;
  List<Map<String, dynamic>> _userVehicles = [];
  Map<String, dynamic>? _selectedVehicle;
  
  // Location state variables - Fix initialization with non-empty defaults
  LatLng? _currentLocation;
  LatLng? _selectedLocation;
  bool _isLoadingLocation = false;
  String _locationError = '';
  String _currentAddress = 'Getting your location...'; // Non-empty default
  String _selectedAddress = 'No location selected'; // Non-empty default (was empty string)
  Set<Marker> _markers = {};
  bool _isUsingCurrentLocation = true; // Toggle between current and pinned location
  
  @override
  void initState() {
    super.initState();
    _loadUserVehicles();
    _getCurrentLocation();
    _issueController.addListener(_onIssueChanged);
    
    // Pre-fill issue description if provided
    if (widget.issueDescription != null) {
      _issueController.text = widget.issueDescription!;
    }
  }

  @override
  void dispose() {
    _issueController.removeListener(_onIssueChanged);
    _issueController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  void _onIssueChanged() {
    setState(() {}); // Triggers rebuild when issue description changes
  }
  
  Future<void> _loadUserVehicles() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final authService = AuthService.instance;
      final userId = authService.userId;
      
      if (userId != null) {
        final vehicles = await UserDataService.getUserVehicles();
        
        setState(() {
          _userVehicles = vehicles;
          _isLoading = false;
          
          // If user has vehicles, select the primary one by default
          if (vehicles.isNotEmpty) {
            _selectedVehicle = vehicles.firstWhere(
              (v) => v['is_primary'] == true,
              orElse: () => vehicles.first,
            );
          }
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading vehicles: $e');
      setState(() {
        _isLoading = false;
      });    }
  }
  
  /// Get current user location with address
  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
      _locationError = '';
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled.');
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

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final currentLatLng = LatLng(position.latitude, position.longitude);
      
      setState(() {
        _currentLocation = currentLatLng;
        _selectedLocation = currentLatLng; // Initially set to current location
        _isUsingCurrentLocation = true;
        _isLoadingLocation = false;
      });

      // Get address for current location
      await _getAddressFromCoordinates(currentLatLng, isCurrentLocation: true);
      
      // Update markers
      _updateMarkers();

    } catch (e) {
      setState(() {
        _isLoadingLocation = false;
        _locationError = e.toString();
        _currentAddress = 'Location unavailable: Please enable GPS or enter manually';
      });
    }
  }

  // Get address from coordinates
  Future<void> _getAddressFromCoordinates(LatLng coordinates, {bool isCurrentLocation = false}) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        coordinates.latitude, 
        coordinates.longitude
      );
      
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        
        // Build address with fallbacks for each component
        List<String> addressParts = [];
        
        if (place.street?.isNotEmpty == true) addressParts.add(place.street!);
        if (place.locality?.isNotEmpty == true) addressParts.add(place.locality!);
        if (place.administrativeArea?.isNotEmpty == true) addressParts.add(place.administrativeArea!);
        if (place.country?.isNotEmpty == true) addressParts.add(place.country!);
        
        String address = addressParts.isNotEmpty 
            ? addressParts.join(', ')
            : 'Address: ${coordinates.latitude.toStringAsFixed(4)}, ${coordinates.longitude.toStringAsFixed(4)}';
        
        setState(() {
          if (isCurrentLocation) {
            _currentAddress = address;
          } else {
            _selectedAddress = address;
          }
        });
      } else {
        // Fallback to coordinates if no placemark found
        String fallbackAddress = 'Coordinates: ${coordinates.latitude.toStringAsFixed(6)}, ${coordinates.longitude.toStringAsFixed(6)}';
        
        setState(() {
          if (isCurrentLocation) {
            _currentAddress = fallbackAddress;
          } else {
            _selectedAddress = fallbackAddress;
          }
        });
      }
    } catch (e) {
      print('Error getting address: $e');
      
      // Fallback to coordinates on error
      String errorFallbackAddress = 'Location: ${coordinates.latitude.toStringAsFixed(4)}, ${coordinates.longitude.toStringAsFixed(4)}';
      
      setState(() {
        if (isCurrentLocation) {
          _currentAddress = errorFallbackAddress;
        } else {
          _selectedAddress = errorFallbackAddress;
        }
      });
    }
  }

  // Handle map tap for pinning location
  void _onMapTap(LatLng tappedLocation) {
    setState(() {
      _selectedLocation = tappedLocation;
      _isUsingCurrentLocation = false;
    });
    
    // Get address for the pinned location
    _getAddressFromCoordinates(tappedLocation, isCurrentLocation: false);
    
    // Update markers
    _updateMarkers();
  }

  // Update map markers
  void _updateMarkers() {
    Set<Marker> markers = {};
    
    // Add current location marker (blue)
    if (_currentLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('current_location'),
          position: _currentLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: const InfoWindow(
            title: 'Your Current Location',
            snippet: 'GPS detected location',
          ),
        ),
      );
    }
    
    // Add selected location marker (red) - only if different from current location
    if (_selectedLocation != null && !_isUsingCurrentLocation) {
      markers.add(
        Marker(
          markerId: const MarkerId('selected_location'),
          position: _selectedLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: const InfoWindow(
            title: 'Selected Service Location',
            snippet: 'Tap to change location',
          ),
        ),
      );
    }
    
    setState(() {
      _markers = markers;
    });
  }

  // Use current location
  void _useCurrentLocation() {
    if (_currentLocation != null) {
      setState(() {
        _selectedLocation = _currentLocation;
        _isUsingCurrentLocation = true;
      });
      _updateMarkers();
    }
  }

  // Build location selection widget
  Widget _buildLocationSelection() {
    final activeLocation = _selectedLocation ?? _currentLocation;
    final activeAddress = _isUsingCurrentLocation ? _currentAddress : _selectedAddress;
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.location_on,
                color: _isUsingCurrentLocation ? Colors.blue : Colors.red,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                _isUsingCurrentLocation ? 'Current Location' : 'Selected Location',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Address display
          if (_isLoadingLocation)
            const Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 8),
                Text('Getting your location...'),
              ],
            )
          else if (_locationError.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.error, color: Colors.red[600], size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _locationError,
                      style: TextStyle(color: Colors.red[600], fontSize: 12),
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.place,
                    color: Colors.grey[600],
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      activeAddress,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          
          const SizedBox(height: 16),
          
          // Location buttons
          Row(
            children: [
              // Use Current Location button
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _currentLocation != null ? _useCurrentLocation : null,
                  icon: const Icon(Icons.my_location, size: 18),
                  label: const Text('Current Location'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isUsingCurrentLocation ? Colors.blue : Colors.grey[300],
                    foregroundColor: _isUsingCurrentLocation ? Colors.white : Colors.grey[700],
                    elevation: _isUsingCurrentLocation ? 2 : 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              
              const SizedBox(width: 12),
              
              // Pin Location indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: !_isUsingCurrentLocation ? Colors.red[50] : Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: !_isUsingCurrentLocation ? Colors.red[200]! : Colors.grey[300]!,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.push_pin,
                      color: !_isUsingCurrentLocation ? Colors.red[600] : Colors.grey[600],
                      size: 18,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Tap map to pin',
                      style: TextStyle(
                        color: !_isUsingCurrentLocation ? Colors.red[600] : Colors.grey[600],
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Build Google Map widget
  Widget _buildGoogleMap() {
    if (_currentLocation == null && !_isLoadingLocation) {
      return Container(
        height: 300,
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.location_off, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text('Location not available'),
              Text('Please enable location services'),
            ],
          ),
        ),
      );
    }

    return Container(
      height: 300,
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: GoogleMap(
          onMapCreated: (GoogleMapController controller) {
            // Map controller initialized
          },
          initialCameraPosition: CameraPosition(
            target: _currentLocation ?? const LatLng(14.5995, 120.9842), // Default to Manila
            zoom: 15,
          ),
          markers: _markers,
          onTap: _onMapTap,
          onCameraMove: (CameraPosition position) {
            // Allow smooth finger movement and panning
            setState(() {
              // Update any UI elements during camera movement if needed
            });
          },
          onCameraIdle: () {
            // Camera stopped moving - could update location here if needed
          },
          myLocationEnabled: true,
          myLocationButtonEnabled: false, // We have our own button
          zoomControlsEnabled: false, // Disable default zoom controls
          compassEnabled: true,
          rotateGesturesEnabled: true,
          scrollGesturesEnabled: true,
          zoomGesturesEnabled: true,
          tiltGesturesEnabled: true,
          // Allow all finger gestures for natural map interaction
          gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
            Factory<EagerGestureRecognizer>(
              () => EagerGestureRecognizer(),
            ),
          },
          mapToolbarEnabled: false,
        ),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vehicle Details'),
        backgroundColor: const Color.fromARGB(255, 176, 12, 1),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Location Selection Section
            _buildLocationSelection(),
            
            // Google Map Section
            _buildGoogleMap(),
            
            // Issue Information (if provided)
            if (widget.issueTitle != null || widget.issueDescription != null)
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info, color: Colors.blue[600]),
                        const SizedBox(width: 8),
                        const Text(
                          'Service Information',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    if (widget.issueTitle != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Issue: ${widget.issueTitle}',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                    if (widget.issueDescription != null) ...[
                      const SizedBox(height: 4),
                      Text('Description: ${widget.issueDescription}'),
                    ],
                  ],
                ),
              ),
            
            // Vehicle Selection Section
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.directions_car, color: Colors.orange),
                      const SizedBox(width: 8),
                      const Text(
                        'Select Your Vehicle',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () => _showAddVehicleDialog(),
                        icon: const Icon(Icons.add),
                        label: const Text('Add Vehicle'),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  if (_isLoading)
                    const Center(
                      child: CircularProgressIndicator(),
                    )
                  else if (_userVehicles.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.directions_car_outlined,
                            size: 48,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No vehicles found',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Add your first vehicle to get started',
                            style: TextStyle(color: Colors.grey),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () => _showAddVehicleDialog(),
                            icon: const Icon(Icons.add),
                            label: const Text('Add Vehicle'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color.fromARGB(255, 176, 12, 1),
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Column(
                      children: [
                        for (int index = 0; index < _userVehicles.length; index++)
                          Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: _selectedVehicle != null && _selectedVehicle!['id'] == _userVehicles[index]['id']
                                    ? const Color.fromARGB(255, 176, 12, 1)
                                    : Colors.grey[300]!,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: _selectedVehicle != null && _selectedVehicle!['id'] == _userVehicles[index]['id']
                                    ? const Color.fromARGB(255, 176, 12, 1)
                                    : Colors.grey[400],
                                child: Icon(
                                  Icons.directions_car,
                                  color: Colors.white,
                                ),
                              ),
                              title: Text(
                                '${_userVehicles[index]['brand_name']} ${_userVehicles[index]['model_name']}',
                                style: TextStyle(
                                  fontWeight: _selectedVehicle != null && _selectedVehicle!['id'] == _userVehicles[index]['id']
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                              subtitle: Text(
                                '${_userVehicles[index]['year']} • ${_userVehicles[index]['color']} • ${_userVehicles[index]['plate_number']}',
                              ),
                              trailing: _selectedVehicle != null && _selectedVehicle!['id'] == _userVehicles[index]['id']
                                  ? const Icon(
                                      Icons.check_circle,
                                      color: Color.fromARGB(255, 176, 12, 1),
                                    )
                                  : null,
                              onTap: () {
                                setState(() {
                                  _selectedVehicle = _userVehicles[index];
                                });
                              },
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
            
            // Continue Button
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: _canProceed() ? _proceedToNextStep : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 176, 12, 1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                child: Text(
                  _selectedVehicle != null && _selectedLocation != null
                      ? 'Continue to Service Request'
                      : 'Select a vehicle and location to continue',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  bool _canProceed() {
    return _selectedVehicle != null && 
           _selectedLocation != null && 
           !_isLoadingLocation;
  }

  void _proceedToNextStep() async {
    if (_selectedVehicle == null || _selectedLocation == null) {
      print('❌ Cannot proceed: Missing vehicle or location');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a vehicle and location'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    final selectedVehicle = _selectedVehicle!;
    final serviceLocation = _selectedLocation!;
    
    // Validate vehicle data
    if (selectedVehicle['id'] == null) {
      print('❌ Vehicle ID is null');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid vehicle data. Please select a different vehicle.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Get the issue description from the controller or widget
    String issueDescription = _issueController.text.trim();
    if (issueDescription.isEmpty && widget.issueDescription != null) {
      issueDescription = widget.issueDescription!.trim();
    }

    // Proceed directly to create service request - no more severe issue checks
    _createServiceRequest(selectedVehicle, serviceLocation, issueDescription);
  }

  void _createServiceRequest(Map<String, dynamic> selectedVehicle, LatLng serviceLocation, String issueDescription) async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Creating service request...'),
          ],
        ),
      ),
    );
    
    try {
      // Better handling for location address with null safety
      String locationAddress = 'Location unavailable';
      if (_isUsingCurrentLocation) {
        final currentAddr = _currentAddress;
        if (currentAddr.trim().isNotEmpty && currentAddr != 'Getting your location...') {
          locationAddress = currentAddr.trim();
        } else {
          locationAddress = 'Current location: ${serviceLocation.latitude.toStringAsFixed(4)}, ${serviceLocation.longitude.toStringAsFixed(4)}';
        }
      } else {
        final selectedAddr = _selectedAddress;
        if (selectedAddr.trim().isNotEmpty && selectedAddr != 'No location selected') {
          locationAddress = selectedAddr.trim();
        } else {
          locationAddress = 'Selected location: ${serviceLocation.latitude.toStringAsFixed(4)}, ${serviceLocation.longitude.toStringAsFixed(4)}';
        }
      }
      
      // Ensure all required strings are non-null with robust validation
      final String safeIssueType = (widget.issueType?.trim().isNotEmpty == true) 
          ? widget.issueType!.trim() 
          : 'General Service';
      
      // Use the issue description from parameter if available, otherwise use widget's description
      final String safeIssueDescription = issueDescription.isNotEmpty 
          ? issueDescription
          : (widget.issueDescription?.trim().isNotEmpty == true) 
              ? widget.issueDescription!.trim() 
              : 'Service request for ${safeIssueType.toLowerCase()}';
      
      final String safeIssueTitle = (widget.issueTitle?.trim().isNotEmpty == true) 
          ? widget.issueTitle!.trim() 
          : safeIssueType;
      
      // Validate final parameters
      if (safeIssueType.isEmpty || safeIssueDescription.isEmpty || safeIssueTitle.isEmpty) {
        throw Exception('Invalid service request data');
      }
      
      print('🔍 Creating service request with data:');
      print('  - Vehicle ID: ${selectedVehicle['id']}');
      print('  - Title: "$safeIssueTitle"');
      print('  - Description: "$safeIssueDescription"');
      print('  - Service Type: "$safeIssueType"');
      print('  - Location: ${serviceLocation.latitude}, ${serviceLocation.longitude}');
      print('  - Address: "$locationAddress"');
      print('  - Shop-based: ${widget.preSelectedMechanic?['serviceType'] == 'shop_based'}');
      
      // ====================================================================
      // 🔍 DEBUG: CHECK SHOP ID
      // ====================================================================
      print('🔍 DEBUG - preSelectedMechanic data:');
      print('  - Full data: ${widget.preSelectedMechanic}');
      print('  - shopId: ${widget.preSelectedMechanic?['shopId']}');
      print('  - shopName: ${widget.preSelectedMechanic?['shopName']}');
      print('  - serviceType: ${widget.preSelectedMechanic?['serviceType']}');
      print('  - providerId: ${widget.preSelectedMechanic?['providerId']}');
      
      final shopId = widget.preSelectedMechanic?['shopId']?.toString();
      final providerId = widget.preSelectedMechanic?['providerId']?.toString();
      // FIX: Check if shopId exists, not serviceType - if user selected a shop, it's shop-based!
      final isShopBased = shopId != null && shopId.isNotEmpty;
      
      print('🎯 Will pass to service:');
      print('  - shopId: $shopId');
      print('  - providerId: $providerId');
      print('  - isShopBased: $isShopBased (based on shopId presence)');
      // ====================================================================
      
      // Create service request with enhanced status tracking
      final serviceRequest = await EnhancedServiceRequestService.createServiceRequestWithStatus(
        vehicleId: selectedVehicle['id'].toString(),
        title: safeIssueTitle,
        description: safeIssueDescription,
        serviceType: safeIssueType,
        latitude: serviceLocation.latitude,
        longitude: serviceLocation.longitude,
        locationAddress: locationAddress,
        // Shop-based vs routing logic
        isShopBased: isShopBased,
        shopId: shopId,
        providerId: providerId,
      );
      
      // Close loading dialog
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
      
      if (serviceRequest != null && serviceRequest['id'] != null) {
        print('✅ Service request created: ${serviceRequest['id']}');
        
        // ====================================================================
        // CHECK FOR NO MECHANICS AVAILABLE ERROR
        // ====================================================================
        final broadcastStatus = serviceRequest['broadcast_status']?.toString();
        final errorType = serviceRequest['error']?.toString();
        final success = serviceRequest['success'];
        final userMessage = serviceRequest['user_message']?.toString();
        
        print('🔍 Checking broadcast status:');
        print('  - broadcast_status: $broadcastStatus');
        print('  - error: $errorType');
        print('  - success: $success');
        print('  - user_message: $userMessage');
        
        // Show error dialog if no mechanics available
        if (broadcastStatus == 'no_mechanics_available' || 
            errorType == 'no_available_mechanics' ||
            success == false) {
          
          print('⚠️ No mechanics available in selected shop - showing alert');
          
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.orange[700],
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'No Mechanics Available',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    userMessage ?? 'Sorry, there are no mechanics available in the selected shop at this time.',
                    style: const TextStyle(fontSize: 15),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.lightbulb_outline, 
                              size: 18, 
                              color: Colors.blue[700],
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Suggestions:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[900],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text('• Select another shop'),
                        const Text('• Try again later'),
                        const Text('• Use broadcast mode (any available mechanic)'),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // Close dialog
                    Navigator.of(context).pop(); // Go back to previous screen
                  },
                  child: const Text(
                    'CANCEL',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // Close dialog
                    Navigator.of(context).pop(); // Go back to shop selection
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[700],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'SELECT ANOTHER SHOP',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          );
          
          return; // Stop here - don't navigate to waiting screen
        }
        
        // ====================================================================
        // SUCCESS - NAVIGATE TO WAITING SCREEN
        // ====================================================================
        
        // Add service request ID to vehicle details
        final vehicleDetailsWithRequest = Map<String, dynamic>.from(selectedVehicle);
        vehicleDetailsWithRequest['serviceRequestId'] = serviceRequest['id'];        
        
        // Navigate to waiting screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MechanicWaitingScreen(
              serviceRequestId: serviceRequest['id'].toString(),
              issueType: safeIssueType,
              issueDescription: safeIssueDescription,
              issueTitle: safeIssueTitle,
              vehicleBrand: selectedVehicle['brand_name'],
              vehicleModel: selectedVehicle['model_name'],
              vehicleYear: selectedVehicle['year']?.toString(),
              vehicleId: selectedVehicle['id'].toString(),
            ),
          ),
        );
      } else {
        throw Exception('Service request creation returned null or invalid data');
      }
      
    } catch (e, stackTrace) {
      // Close loading dialog if still open
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
      
      print('❌ Error creating service request: $e');
      print('📚 Stack trace: $stackTrace');
      
      // Show error to user with specific message
      String errorMessage = 'Failed to create service request';
      if (e.toString().contains('log in')) {
        errorMessage = 'Please log in to create a service request';
      } else if (e.toString().contains('Vehicle')) {
        errorMessage = 'Invalid vehicle data. Please select a different vehicle.';
      } else if (e.toString().contains('permission')) {
        errorMessage = 'Access denied. Please check your account permissions.';
      } else {
        errorMessage = 'Failed to create service request. Please try again.';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Retry',
            onPressed: _proceedToNextStep,
            textColor: Colors.white,
          ),
        ),
      );
    }
  }
  
  String? getSelectedVehicleId() {
    if (_selectedVehicle != null && _selectedVehicle!.containsKey('id')) {
      return _selectedVehicle!['id'].toString();
    }
    return null;
  }
  
  Future<void> _showAddVehicleDialog() async {
    showDialog(
      context: context,
      builder: (context) => AddVehicleDialog(
        onVehicleAdded: (newVehicle) async {
          await _loadUserVehicles();
          setState(() {
            _selectedVehicle = newVehicle;
          });
        },
      ),
    );
  }
}

// Helper widget classes
class VehicleTypeCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  
  const VehicleTypeCard({
    Key? key,
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? const Color.fromARGB(255, 176, 12, 1).withOpacity(0.1) : Colors.white,
          border: Border.all(
            color: isSelected ? const Color.fromARGB(255, 176, 12, 1) : Colors.grey[300]!,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? const Color.fromARGB(255, 176, 12, 1) : Colors.grey[600],
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? const Color.fromARGB(255, 176, 12, 1) : Colors.black,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RoadAidBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  
  const RoadAidBottomNavBar({
    Key? key,
    required this.currentIndex,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      selectedItemColor: const Color.fromARGB(255, 176, 12, 1),
      unselectedItemColor: Colors.grey,
      currentIndex: currentIndex,
      onTap: onTap,
      items: [
        const BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: 'Home',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.miscellaneous_services),
          label: 'Services',
        ),
        BottomNavigationBarItem(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color.fromARGB(255, 176, 12, 1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.location_on, color: Colors.white),
          ),
          label: 'Request',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.message),
          label: 'Messages',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: 'Profile',
        ),
      ],
    );
  }
}











