import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:geolocator/geolocator.dart';
import '../services/qr_code_service.dart';
import '../services/maps_direction_service.dart';
import 'dart:async';

class MechanicJobCompletionScreen extends StatefulWidget {
  final String jobId;
  final Map<String, dynamic> jobDetails;

  const MechanicJobCompletionScreen({
    super.key,
    required this.jobId,
    required this.jobDetails,
  });

  @override
  State<MechanicJobCompletionScreen> createState() => _MechanicJobCompletionScreenState();
}

class _MechanicJobCompletionScreenState extends State<MechanicJobCompletionScreen>
    with TickerProviderStateMixin {
  
  // Controllers and State
  GoogleMapController? _mapController;
  MobileScannerController? _scannerController;
  late AnimationController _pulseController;
  late AnimationController _scanLineController;
  
  // Map State
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  LatLng? _currentLocation;
  LatLng? _customerLocation;
  bool _isLoadingDirections = false;
  String _routeInfo = '';
  
  // QR Scanner State
  bool _isQRScannerActive = false;
  bool _isProcessingQR = false;
  String _qrScanStatus = 'Position QR code within the frame';
  
  // Job State
  bool _isCompletingJob = false;
  String _completionStatus = '';

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeLocation();
    _setupCustomerLocation();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _scanLineController.dispose();
    _scannerController?.dispose();
    super.dispose();
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _scanLineController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
  }

  Future<void> _initializeLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final newPermission = await Geolocator.requestPermission();
        if (newPermission == LocationPermission.denied) {
          _showError('Location permission is required for navigation');
          return;
        }
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
      });

      _updateMapMarkers();
    } catch (e) {
      print('❌ Error getting current location: $e');
      _showError('Failed to get current location');
    }
  }

  void _setupCustomerLocation() {
    final pickupLat = widget.jobDetails['pickup_latitude'];
    final pickupLng = widget.jobDetails['pickup_longitude'];
    
    if (pickupLat != null && pickupLng != null) {
      setState(() {
        _customerLocation = LatLng(
          double.parse(pickupLat.toString()),
          double.parse(pickupLng.toString()),
        );
      });
      _updateMapMarkers();
      _loadDirections();
    }
  }

  void _updateMapMarkers() {
    final markers = <Marker>[];

    // Current location marker (mechanic)
    if (_currentLocation != null) {
      markers.add(Marker(
        markerId: const MarkerId('mechanic_location'),
        position: _currentLocation!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        infoWindow: const InfoWindow(
          title: 'Your Location',
          snippet: 'Mechanic',
        ),
      ));
    }

    // Customer location marker
    if (_customerLocation != null) {
      markers.add(Marker(
        markerId: const MarkerId('customer_location'),
        position: _customerLocation!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(
          title: 'Customer Location',
          snippet: widget.jobDetails['pickup_address'] ?? 'Service Location',
        ),
      ));
    }

    setState(() {
      _markers = markers.toSet();
    });
  }

  Future<void> _loadDirections() async {
    if (_currentLocation == null || _customerLocation == null) return;

    setState(() {
      _isLoadingDirections = true;
      _routeInfo = 'Loading route...';
    });

    try {
      // Use your API for directions with polyline
      final directions = await MapsDirectionService.instance.getDirectionsWithPolyline(
        origin: _currentLocation!,
        destination: _customerLocation!,
      );

      if (directions != null && mounted) {
        // Create polyline from your API
        final polyline = MapsDirectionService.instance.createPolyline(
          polylineId: 'route_to_customer',
          points: directions['polyline_points'] as List<LatLng>,
          color: const Color.fromARGB(255, 176, 12, 1),
          width: 5,
        );

        setState(() {
          _polylines = {polyline};
          _routeInfo = '${directions['total_distance']} • ${directions['total_duration']}';
          _isLoadingDirections = false;
        });

        // Animate camera to show entire route
        _animateCameraToShowRoute();
      } else {
        setState(() {
          _routeInfo = 'Unable to load route';
          _isLoadingDirections = false;
        });
      }
    } catch (e) {
      print('❌ Error loading directions: $e');
      setState(() {
        _routeInfo = 'Route unavailable';
        _isLoadingDirections = false;
      });
    }
  }

  void _animateCameraToShowRoute() async {
    if (_mapController == null || _currentLocation == null || _customerLocation == null) return;

    final bounds = LatLngBounds(
      southwest: LatLng(
        _currentLocation!.latitude < _customerLocation!.latitude
            ? _currentLocation!.latitude
            : _customerLocation!.latitude,
        _currentLocation!.longitude < _customerLocation!.longitude
            ? _currentLocation!.longitude
            : _customerLocation!.longitude,
      ),
      northeast: LatLng(
        _currentLocation!.latitude > _customerLocation!.latitude
            ? _currentLocation!.latitude
            : _customerLocation!.latitude,
        _currentLocation!.longitude > _customerLocation!.longitude
            ? _currentLocation!.longitude
            : _customerLocation!.longitude,
      ),
    );

    await _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 100),
    );
  }

  void _toggleQRScanner() {
    setState(() {
      _isQRScannerActive = !_isQRScannerActive;
    });

    if (_isQRScannerActive) {
      _scannerController = MobileScannerController(
        detectionSpeed: DetectionSpeed.normal,
        facing: CameraFacing.back,
      );
      _qrScanStatus = 'Position QR code within the frame';
    } else {
      _scannerController?.dispose();
      _scannerController = null;
    }
  }

  Future<void> _onQRDetected(BarcodeCapture capture) async {
    if (_isProcessingQR) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String qrCode = barcodes.first.rawValue ?? '';
    if (qrCode.isEmpty) return;

    setState(() {
      _isProcessingQR = true;
      _qrScanStatus = 'Processing QR code...';
    });

    try {
      // Verify QR code with your service
      final success = await QRCodeService.instance.verifyAndProcessQRScan(
        qrCode: qrCode,
        serviceRequestId: widget.jobId,
      );

      if (success) {
        setState(() {
          _qrScanStatus = 'QR verified successfully!';
          _isQRScannerActive = false;
        });

        _scannerController?.dispose();
        _scannerController = null;

        _showSuccessDialog('Job completed successfully via QR scan!');
      } else {
        setState(() {
          _qrScanStatus = 'QR verification failed. Please try again.';
          _isProcessingQR = false;
        });
      }
    } catch (e) {
      setState(() {
        _qrScanStatus = 'Error: ${e.toString()}';
        _isProcessingQR = false;
      });
    }
  }

  Future<void> _manualCompleteJob() async {
    // Show reason dialog first
    final reason = await _showReasonDialog();
    if (reason == null || reason.isEmpty) return;

    setState(() {
      _isCompletingJob = true;
      _completionStatus = 'Completing job manually...';
    });

    try {
      final success = await QRCodeService.instance.manualCompleteJob(
        serviceRequestId: widget.jobId,
        reason: reason,
      );

      if (success) {
        _showSuccessDialog('Job completed manually!');
      } else {
        _showError('Failed to complete job manually');
      }
    } catch (e) {
      _showError('Error: ${e.toString()}');
    } finally {
      setState(() {
        _isCompletingJob = false;
        _completionStatus = '';
      });
    }
  }

  Future<String?> _showReasonDialog() async {
    final TextEditingController reasonController = TextEditingController();

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Manual Completion'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Why are you completing this job manually?',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'e.g., QR scanner not working, customer\'s phone died, etc.',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(reasonController.text);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromARGB(255, 176, 12, 1),
              foregroundColor: Colors.white,
            ),
            child: const Text('Complete Job'),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.red, size: 28),
            const SizedBox(width: 8),
            const Text('Success'),
          ],
        ),
        content: Text(message),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(true); // Return to previous screen
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final customer = widget.jobDetails['customer'] ?? {};
    final customerName = '${customer['first_name'] ?? ''} ${customer['last_name'] ?? ''}'.trim();
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 176, 12, 1),
        title: const Text(
          'Complete Job',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadDirections,
          ),
        ],
      ),
      body: Column(
        children: [
          // Job Info Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withAlpha(26),
                  spreadRadius: 1,
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color.fromARGB(255, 176, 12, 1).withAlpha(26),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.build,
                        color: Color.fromARGB(255, 176, 12, 1),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.jobDetails['service_type'] ?? 'Service Job',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            customerName.isNotEmpty ? customerName : 'Customer',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (_routeInfo.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.directions,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _routeInfo,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (_isLoadingDirections) ...[
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[600]!),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Map Section
          Expanded(
            flex: _isQRScannerActive ? 1 : 2,
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withAlpha(51),
                    spreadRadius: 2,
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: GoogleMap(
                  onMapCreated: (GoogleMapController controller) {
                    _mapController = controller;
                    if (_currentLocation != null && _customerLocation != null) {
                      _animateCameraToShowRoute();
                    }
                  },
                  initialCameraPosition: CameraPosition(
                    target: _currentLocation ?? const LatLng(14.5995, 120.9842), // Manila default
                    zoom: 15,
                  ),
                  markers: _markers,
                  polylines: _polylines,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
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
            ),
          ),

          // QR Scanner Section
          if (_isQRScannerActive)
            Expanded(
              flex: 2,
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withAlpha(51),
                      spreadRadius: 2,
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    children: [
                      // Camera Feed
                      if (_scannerController != null)
                        MobileScanner(
                          controller: _scannerController!,
                          onDetect: _onQRDetected,
                        ),
                      
                      // Scanning Overlay
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(77),
                        ),
                      ),
                      
                      // Scan Frame
                      Center(
                        child: Container(
                          width: 250,
                          height: 250,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.white,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Stack(
                            children: [
                              // Corner indicators
                              ...List.generate(4, (index) {
                                final isLeft = index % 2 == 0;
                                final isTop = index < 2;
                                return Positioned(
                                  left: isLeft ? 0 : null,
                                  right: isLeft ? null : 0,
                                  top: isTop ? 0 : null,
                                  bottom: isTop ? null : 0,
                                  child: Container(
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      color: const Color.fromARGB(255, 176, 12, 1),
                                      borderRadius: BorderRadius.only(
                                        topLeft: Radius.circular(isLeft && isTop ? 16 : 0),
                                        topRight: Radius.circular(!isLeft && isTop ? 16 : 0),
                                        bottomLeft: Radius.circular(isLeft && !isTop ? 16 : 0),
                                        bottomRight: Radius.circular(!isLeft && !isTop ? 16 : 0),
                                      ),
                                    ),
                                  ),
                                );
                              }),
                              
                              // Scanning line animation
                              AnimatedBuilder(
                                animation: _scanLineController,
                                builder: (context, child) {
                                  return Positioned(
                                    top: 250 * _scanLineController.value - 1,
                                    left: 0,
                                    right: 0,
                                    child: Container(
                                      height: 2,
                                      color: const Color.fromARGB(255, 176, 12, 1),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color.fromARGB(255, 176, 12, 1).withAlpha(128),
                                              blurRadius: 4,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      // Status Text
                      Positioned(
                        bottom: 30,
                        left: 0,
                        right: 0,
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 20),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black.withAlpha(179),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _qrScanStatus,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Action Buttons
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withAlpha(26),
                  spreadRadius: 1,
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              children: [
                // QR Scanner Toggle Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isProcessingQR ? null : _toggleQRScanner,
                    icon: Icon(
                      _isQRScannerActive ? Icons.close : Icons.qr_code_scanner,
                      size: 24,
                    ),
                    label: Text(
                      _isQRScannerActive ? 'Close Scanner' : 'Scan Customer QR Code',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isQRScannerActive 
                          ? Colors.grey[600] 
                          : const Color.fromARGB(255, 176, 12, 1),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Manual Completion Button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isCompletingJob ? null : _manualCompleteJob,
                    icon: _isCompletingJob
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.done_outline, size: 24),
                    label: Text(
                      _isCompletingJob ? 'Completing...' : 'Complete Manually',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color.fromARGB(255, 176, 12, 1),
                      side: const BorderSide(
                        color: Color.fromARGB(255, 176, 12, 1),
                        width: 2,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),

                if (_completionStatus.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    _completionStatus,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}










