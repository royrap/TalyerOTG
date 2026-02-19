import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/supabase_service.dart';
import '../../services/auth_service.dart';
import '../../shared/services/google_maps_service.dart';
import '../../services/maps_service.dart';
import '../enhanced_invoice_generation_screen.dart';
import '../mechanic_qr_scanner_page.dart';
import '../../widgets/history_bottom_sheet.dart';

// Platform channel for native phone calling
const platform = MethodChannel('roadaid/phone_launcher');

// Helper function to make phone calls using native Android intent
Future<bool> makePhoneCallNative(String phoneNumber) async {
  try {
    print('🔥 Attempting native phone call to: $phoneNumber');
    final bool result = await platform.invokeMethod('makePhoneCall', {'phoneNumber': phoneNumber});
    print('✅ Native phone call result: $result');
    return result;
  } on PlatformException catch (e) {
    print('❌ Native phone call failed: ${e.message}');
    return false;
  }
}

class MechanicJobTrackingBottomSheet extends StatefulWidget {
  final String serviceRequestId;
  final Map<String, dynamic> customerInfo;
  final VoidCallback onCancelJob;
  final VoidCallback? onJobCompleted; // New callback for when job is actually completed

  const MechanicJobTrackingBottomSheet({
    Key? key,
    required this.serviceRequestId,
    required this.customerInfo,
    required this.onCancelJob,
    this.onJobCompleted, // Optional callback
  }) : super(key: key);

  @override
  State<MechanicJobTrackingBottomSheet> createState() => _MechanicJobTrackingBottomSheetState();
}

class _MechanicJobTrackingBottomSheetState extends State<MechanicJobTrackingBottomSheet> {
  // Real-time location tracking state
  Timer? _locationUpdateTimer;
  StreamSubscription? _customerLocationSubscription;
  StreamSubscription? _invoiceStatusSubscription; // Add invoice status subscription
  StreamSubscription? _serviceStatusSubscription; // Add service status subscription
  LatLng? _customerLocation;
  String _customerAddress = 'Loading...';
  
  // Map and location state
  LatLng? _mechanicLocation;
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  // MapsService for realtime synced polylines
  final MapsService _mapsService = MapsService();
  StreamSubscription<List<LatLng>>? _routeSubscription;
  StreamSubscription? _mapsTrackingSubscription;
  
  // Customer info state
  String? _customerName;
  String? _customerPhone;
  String? _customerProfileImage;
  String? _serviceType;
  String? _description;
  String? _serviceStatus;
  String? _distanceToCustomer;
  String? _durationToCustomer;

  // Job progress state
  bool _invoiceGenerated = false;
  bool _invoiceAccepted = false;
  bool _canScanQR = false;

  // Map type
  MapType _currentMapType = MapType.normal;

  @override
  void initState() {
    super.initState();
    _initializeJobTracking();
  }

  @override
  void dispose() {
    _locationUpdateTimer?.cancel();
    _customerLocationSubscription?.cancel();
    _invoiceStatusSubscription?.cancel(); // Cancel invoice status listener
    _serviceStatusSubscription?.cancel(); // Cancel service status listener
    // Stop maps realtime tracking and cancel subscriptions
    _routeSubscription?.cancel();
    _mapsTrackingSubscription?.cancel();
    try {
      _mapsService.stopRealTimeTracking();
    } catch (_) {}
    super.dispose();
  }

  // Initialize job tracking system
  Future<void> _initializeJobTracking() async {
    await _loadCustomerInfo();
    await _loadCustomerLocation();
    await _getCurrentMechanicLocation();
    _startRealTimeLocationTracking();
    _startInvoiceStatusListener(); // Add real-time invoice status listener
  }

  // Load customer information
  Future<void> _loadCustomerInfo() async {
    try {
      print('👤 Loading customer info for service request: ${widget.serviceRequestId}');
      
      // Load from provided customerInfo first
      _customerName = widget.customerInfo['customer_name'] ?? 'Customer';
      _customerPhone = widget.customerInfo['phone_number'] ?? '';
      _serviceType = widget.customerInfo['service_type'] ?? 'Service Request';
      _description = widget.customerInfo['description'] ?? '';
      
      // Load additional details from database
      final serviceRequest = await SupabaseService.getServiceRequestById(widget.serviceRequestId);
      
      if (serviceRequest != null && mounted) {
        setState(() {
          _serviceStatus = serviceRequest['status']?.toString() ?? 'unknown';
        });
        
        // Check invoice status
        await _checkInvoiceStatus();
        
        // Load customer profile details
        final customerId = serviceRequest['customer_id'];
        if (customerId != null) {
          final customerProfile = await SupabaseService.client
              .from('user_profiles')
              .select('first_name, last_name, phone_number, profile_image_url')
              .eq('id', customerId)
              .maybeSingle();
          
          if (customerProfile != null && mounted) {
            setState(() {
              _customerName = '${customerProfile['first_name'] ?? ''} ${customerProfile['last_name'] ?? ''}'.trim();
              if (_customerName!.isEmpty) _customerName = 'Customer';
              _customerPhone = customerProfile['phone_number'] ?? _customerPhone;
              _customerProfileImage = customerProfile['profile_image_url'];
            });
          }
        }
      }
    } catch (e) {
      print('❌ Error loading customer info: $e');
    }
  }

  // Check invoice status for this service request
  Future<void> _checkInvoiceStatus() async {
    try {
      // First check service request status as it's the main source of truth
      final serviceRequest = await SupabaseService.client
          .from('service_requests')
          .select('status, payment_status')
          .eq('id', widget.serviceRequestId)
          .single();
          
      final serviceStatus = serviceRequest['status'];
      final paymentStatus = serviceRequest['payment_status'];
      
      print('📊 Service status: $serviceStatus, Payment status: $paymentStatus');
      
      // Try to get the latest invoice (handle multiple invoices by getting the most recent)
      final invoices = await SupabaseService.client
          .from('invoices')
          .select('id, status, accepted_at')
          .eq('request_id', widget.serviceRequestId)
          .order('accepted_at', ascending: false)
          .limit(1);
      
      bool invoiceExists = invoices.isNotEmpty;
      String? invoiceStatus;
      String? latestInvoiceId;
      
      if (invoiceExists) {
        final latestInvoice = invoices.first;
        invoiceStatus = latestInvoice['status'];
        latestInvoiceId = latestInvoice['id'];
        print('📧 Latest invoice found: $latestInvoiceId with status: $invoiceStatus');
      } else {
        print('📧 No invoices found for service request');
      }
      
      if (mounted) {
        setState(() {
          _invoiceGenerated = invoiceExists;
          
          // Enable QR scanning based on multiple conditions:
          // 1. Service request status is invoice_paid (main condition)
          // 2. Payment status is completed
          // 3. Invoice status is paid/accepted (if exists)  
          // 4. Fallback: if job is in progress and has basic data, allow QR scanning
          bool canScan = serviceStatus == 'invoice_paid' || 
                        paymentStatus == 'completed' ||
                        (invoiceStatus != null && (invoiceStatus == 'paid' || invoiceStatus == 'accepted')) ||
                        (serviceStatus == 'in_progress' && latestInvoiceId != null); // Fallback for testing/development
          
          _canScanQR = canScan;
          _invoiceAccepted = invoiceStatus == 'accepted' || invoiceStatus == 'paid' || paymentStatus == 'completed';
          
          print('🎯 QR scan enabled: $canScan (serviceStatus: $serviceStatus, paymentStatus: $paymentStatus, invoiceStatus: $invoiceStatus)');
        });
      }
    } catch (e) {
      print('❌ Error checking invoice status: $e');
      
      // Fallback: if there's an error, still try to enable QR scanning if we have basic job data
      if (mounted) {
        setState(() {
          _canScanQR = false; // Conservative approach on error
        });
      }
    }
  }

  // Navigate to detailed invoice generation screen
  Future<void> _generateInvoice() async {
    try {
      // Get service request details for invoice screen WITH customer info
      final serviceRequest = await SupabaseService.client
          .from('service_requests')
          .select('''
            *,
            customer:user_profiles!service_requests_customer_id_fkey(
              id,
              first_name,
              last_name,
              phone_number,
              email
            )
          ''')
          .eq('id', widget.serviceRequestId)
          .single();

      print('📋 Navigating to invoice generation for service: ${widget.serviceRequestId}');
      print('👤 Customer info: ${serviceRequest['customer']}');

      // Navigate to enhanced invoice generation screen
      if (mounted) {
        final result = await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => EnhancedInvoiceGenerationScreen(
              jobId: widget.serviceRequestId,
              jobDetails: serviceRequest,
            ),
          ),
        );

        // If invoice was sent successfully, refresh the invoice status
        if (result == true) {
          print('✅ Invoice sent successfully, refreshing status...');
          await _checkInvoiceStatus();
        }
      }
    } catch (e) {
      print('❌ Error navigating to invoice generation: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening invoice screen: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Camera-based QR scanning method using full-screen page
  Future<void> _scanQRWithCamera() async {
    print('📷 _scanQRWithCamera() method called - Opening Camera Scanner');
    
    try {
      // First try to get mechanic ID from AuthService
      String? mechanicId = AuthService.instance.currentUser?.id;
      print('🔍 Mechanic ID from AuthService: $mechanicId');
      
      // If AuthService returns null, try to get from service request data
      if (mechanicId == null) {
        print('⚠️ AuthService returned null, fetching from database...');
        
        // Get mechanic ID from the service request
        final serviceRequest = await SupabaseService.client
            .from('service_requests')
            .select('assigned_mechanic_id')
            .eq('id', widget.serviceRequestId)
            .maybeSingle();
        
        mechanicId = serviceRequest?['assigned_mechanic_id'] as String?;
        print('🔍 Mechanic ID from database: $mechanicId');
      }
      
      // If still null, show error
      if (mechanicId == null) {
        print('❌ Mechanic ID is null - cannot proceed');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Error: Mechanic ID not found. Please re-login.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 4),
            ),
          );
        }
        return;
      }

      print('✅ Mechanic ID found: $mechanicId');
      print('📱 About to navigate - ServiceRequestId: ${widget.serviceRequestId}');
      print('📱 JobTitle: ${widget.customerInfo['service_type'] ?? 'Service'}');
      print('🚀 Pushing MechanicQRScannerPage to Navigator...');
      
      // Navigate to full-screen QR scanner page
      final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) {
            print('🏗️ Building MechanicQRScannerPage widget...');
            return MechanicQRScannerPage(
              serviceRequestId: widget.serviceRequestId,
              jobTitle: widget.customerInfo['service_type'] ?? 'Service',
              onJobCompleted: () async {
                // Handle successful QR scan
                print('🎉 QR scan successful - job completed!');
                
                // Mark job as completed in database
                await _markJobAsCompleted();
                
                // Notify parent component that job is completed
                widget.onJobCompleted?.call();
              },
            );
          },
        ),
      );
      
      print('🔙 Navigator returned from QR scanner with result: $result');
      
      if (result == true) {
        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 8),
                  Text('🎉 Job completed! Added to job history.'),
                ],
              ),
              backgroundColor: Colors.red[700],
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      print('❌ ERROR opening QR scanner page!');
      print('❌ Error type: ${e.runtimeType}');
      print('❌ Error message: $e');
      print('❌ Stack trace: $stackTrace');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ QR scanner failed: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  // Mark job as completed in database
  Future<void> _markJobAsCompleted() async {
    try {
      await SupabaseService.client
          .from('service_requests')
          .update({
            'status': 'completed',
            'completed_at': DateTime.now().toIso8601String(),
          })
          .eq('id', widget.serviceRequestId);
          
      print('✅ Job marked as completed in database');
    } catch (e) {
      print('❌ Error marking job as completed: $e');
    }
  }

  // Load customer location for the request
  Future<void> _loadCustomerLocation() async {
    try {
      if (widget.serviceRequestId.isEmpty) return;
      
      // Load from provided customerInfo first
      final pickupLat = widget.customerInfo['pickup_latitude'];
      final pickupLng = widget.customerInfo['pickup_longitude'];
      final pickupAddress = widget.customerInfo['pickup_address'];
      
      if (pickupLat != null && pickupLng != null && mounted) {
        setState(() {
          _customerLocation = LatLng(pickupLat.toDouble(), pickupLng.toDouble());
          _customerAddress = pickupAddress ?? 'Loading address...';
        });
        
        // Get address if not provided
        if (pickupAddress == null || pickupAddress.isEmpty) {
          try {
            final address = await GoogleMapsService.getAddressFromCoordinates(_customerLocation!);
            if (mounted && address != null) {
              setState(() {
                _customerAddress = address;
              });
            }
          } catch (e) {
            print('❌ Error getting customer address: $e');
          }
        }
        
        await _updateMarkers();
        await _updateDistanceAndDuration();
      }
    } catch (e) {
      print('❌ Error loading customer location: $e');
    }
  }

  // Start real-time location tracking
  void _startRealTimeLocationTracking() {
    print('🚀 Starting real-time location tracking...');
    
    // Periodic updates every 15 seconds
    _locationUpdateTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      _updateMechanicLocation();
    });
    
    // Real-time updates via Supabase subscriptions
    _listenToLocationUpdates();
  }

  // Update mechanic location
  Future<void> _updateMechanicLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      
      if (mounted) {
        setState(() {
          _mechanicLocation = LatLng(position.latitude, position.longitude);
        });
        
        await _updateMarkers();
        await _updateDistanceAndDuration();
        await _showRouteAutomatically();
        
        // Update mechanic location in database
        await _updateMechanicLocationInDatabase(position);
      }
    } catch (e) {
      print('❌ Error updating mechanic location: $e');
    }
  }

  // Update mechanic location in database
  Future<void> _updateMechanicLocationInDatabase(Position position) async {
    try {
      final mechanicUserId = AuthService.instance.currentUser?.id;
      if (mechanicUserId == null) return;
      
      print('📤 Upserting mechanic location to mechanic_locations for user: $mechanicUserId -> ${position.latitude}, ${position.longitude} (request=${widget.serviceRequestId})');

      // Include service_request_id when available so realtime listeners
      // that filter by request can receive updates for this tracking row.
      final upsertPayload = {
        'user_id': mechanicUserId,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'heading': position.heading,
        'speed': position.speed,
        'altitude': position.altitude,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (widget.serviceRequestId.isNotEmpty) {
        upsertPayload['service_request_id'] = widget.serviceRequestId;
      }

    // Perform upsert and request the stored row back for verification
    final upsertResult = await SupabaseService.client
      .from('mechanic_locations')
      .upsert(upsertPayload)
      .select()
      .maybeSingle();

    print('📥 mechanic_locations upsert result: $upsertResult');
    } catch (e) {
      print('❌ Error updating mechanic location in database: $e');
    }
  }

  // Listen to real-time location updates
  void _listenToLocationUpdates() {
    try {
      _customerLocationSubscription = SupabaseService.client
          .from('service_requests')
          .stream(primaryKey: ['id'])
          .eq('id', widget.serviceRequestId)
          .listen((data) {
            if (data.isNotEmpty && mounted) {
              final request = data.first;
              final status = request['status']?.toString();
              if (status != null && status != _serviceStatus) {
                setState(() {
                  _serviceStatus = status;
                });
              }
            }
          });
    } catch (e) {
      print('❌ Error setting up location updates: $e');
    }
  }

  // Listen to real-time invoice status updates
  void _startInvoiceStatusListener() {
    try {
      print('🎧 Starting real-time invoice status listener for service: ${widget.serviceRequestId}');
      
      // Listen to invoice updates
      _invoiceStatusSubscription = SupabaseService.client
          .from('invoices')
          .stream(primaryKey: ['id'])
          .eq('request_id', widget.serviceRequestId)
          .listen((data) {
            if (data.isNotEmpty && mounted) {
              // Get the latest invoice (most recent)
              final latestInvoice = data.reduce((a, b) => 
                DateTime.parse(a['accepted_at'] ?? a['updated_at'] ?? DateTime.now().toIso8601String()).isAfter(DateTime.parse(b['accepted_at'] ?? b['updated_at'] ?? DateTime.now().toIso8601String())) ? a : b);
              
              final status = latestInvoice['status']?.toString();
              final invoiceId = latestInvoice['id'];
              
              print('📧 Real-time invoice update: $invoiceId - Status: $status');
              
              // Re-check full status to get comprehensive state
              _checkInvoiceStatus();

              // Show notification when invoice is paid
              if (status == 'paid' || status == 'accepted') {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(status == 'paid' 
                        ? '🎉 Invoice paid! You can now scan QR code to complete the job.'
                        : '✅ Invoice accepted! Waiting for payment to enable QR scanning.'),
                    backgroundColor: status == 'paid' ? Colors.red : Colors.blue,
                    duration: const Duration(seconds: 5),
                  ),
                );
              }
            }
          });

      // Also listen to service request status for comprehensive updates
      _serviceStatusSubscription = SupabaseService.client
          .from('service_requests')
          .stream(primaryKey: ['id'])
          .eq('id', widget.serviceRequestId)
          .listen((data) {
            if (data.isNotEmpty && mounted) {
              final request = data.first;
              final status = request['status']?.toString();
              final paymentStatus = request['payment_status']?.toString();
              
              print('📡 Service request update: status=$status, paymentStatus=$paymentStatus');
              
              if (status != _serviceStatus) {
                setState(() {
                  _serviceStatus = status;
                });
                
                // If status is invoice_paid, enable QR scanning
                if (status == 'invoice_paid') {
                  _checkInvoiceStatus(); // Refresh comprehensive status
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('🎉 Payment received! You can now scan QR code to complete the job.'),
                      backgroundColor: Colors.red,
                      duration: Duration(seconds: 5),
                    ),
                  );
                }
              }
            }
          });
    } catch (e) {
      print('❌ Error starting invoice status listener: $e');
    }
  }

  // Get current mechanic location
  Future<void> _getCurrentMechanicLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      if (mounted) {
        setState(() {
          _mechanicLocation = LatLng(position.latitude, position.longitude);
        });
        
        await _updateMarkers();
        await _updateDistanceAndDuration();
      }
    } catch (e) {
      print('❌ Error getting current mechanic location: $e');
    }
  }

  // Update distance and duration between mechanic and customer location using Google Maps API
  Future<void> _updateDistanceAndDuration() async {
    if (_mechanicLocation != null && _customerLocation != null) {
      try {
        // For now, use straight-line distance calculation
        // TODO: Implement GoogleMapsService.getDistanceAndDuration method
        _calculateStraightLineDistance();
      } catch (e) {
        print('❌ Error getting distance and duration: $e');
        _calculateStraightLineDistance();
      }
    }
  }

  // Fallback method for straight-line distance calculation
  void _calculateStraightLineDistance() {
    if (_mechanicLocation != null && _customerLocation != null && mounted) {
      final distance = _calculateDistanceBetweenPoints(_mechanicLocation!, _customerLocation!);
      setState(() {
        _distanceToCustomer = '${distance.toStringAsFixed(1)} km';
        _durationToCustomer = '~${(distance * 3).toInt()} min'; // Rough estimate
      });
    }
  }

  // Calculate distance between two points in kilometers
  double _calculateDistanceBetweenPoints(LatLng point1, LatLng point2) {
    return Geolocator.distanceBetween(
          point1.latitude,
          point1.longitude,
          point2.latitude,
          point2.longitude,
        ) / 1000; // Convert to kilometers
  }

  // Automatically show route with Google Maps API route points
  Future<void> _showRouteAutomatically() async {
    if (_mechanicLocation != null && _customerLocation != null) {
      try {
        // Start MapsService realtime tracking which will keep route in sync between apps
        String mechanicId = AuthService.instance.currentUser?.id ?? '';
        if (mechanicId.trim().isEmpty) {
          // Try to resolve mechanicId from the service request as a fallback
          try {
            final request = await SupabaseService.client
                .from('service_requests')
                .select('assigned_mechanic_id')
                .eq('id', widget.serviceRequestId)
                .maybeSingle();
            mechanicId = request?['assigned_mechanic_id'] as String? ?? '';
            print('🔍 Resolved mechanicId from request: $mechanicId');
          } catch (e) {
            print('⚠️ Failed to resolve mechanicId from service_request: $e');
          }
        }

        print('🗺️ Starting MapsService realtime tracking (mechanic bottom sheet) with mechanicId: $mechanicId');

        await _mapsService.startRealTimeTracking(
          serviceRequestId: widget.serviceRequestId,
          customerLocation: _customerLocation!,
          mechanicId: mechanicId,
        );

        // Cancel existing subscriptions if any
        _routeSubscription?.cancel();
        _mapsTrackingSubscription?.cancel();

        // Listen to route stream and render blue polyline using MapsService helper
        _routeSubscription = _mapsService.routeStream.listen((routePoints) {
          if (mounted && routePoints.isNotEmpty) {
            setState(() {
              _polylines = {_mapsService.createRoutePolyline(routePoints)};
            });
            _animateCameraToShowRoute(routePoints);
            print('🗺️ Real-time route displayed (maps service): ${routePoints.length} points');
          }
        });

        // Listen to tracking data stream to update markers and mechanic/customer positions
        _mapsTrackingSubscription = _mapsService.trackingDataStream.listen((data) {
          if (mounted && data.isNotEmpty) {
            setState(() {
              _mechanicLocation = data['mechanic_location'] ?? _mechanicLocation;
              _customerLocation = data['customer_location'] ?? _customerLocation;
              _distanceToCustomer = data['distance'] ?? _distanceToCustomer;
              _durationToCustomer = data['duration'] ?? _durationToCustomer;
            });
            _updateMarkers();
          }
        });
      } catch (e) {
        print('❌ Error starting MapsService realtime route: $e');
        _showFallbackRoute();
      }
    }
  }

  // Show fallback straight-line route when API is unavailable
  void _showFallbackRoute() {
    if (_mechanicLocation != null && _customerLocation != null && mounted) {
      setState(() {
        _polylines = {
          Polyline(
            polylineId: const PolylineId('fallback_route'),
            points: [_mechanicLocation!, _customerLocation!],
            color: Colors.orange, // Different color for direct route
            width: 4,
            patterns: [PatternItem.dash(20), PatternItem.gap(20)], // Dashed line for direct route
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
            geodesic: true,
          ),
        };
      });
      
      // Auto-fit camera to show both points
      _animateCameraToShowPoints();
      
      print('🗺️ Direct route displayed (fallback)');
    }
  }
  
  // Animate camera to show route points
  void _animateCameraToShowRoute(List<LatLng> routePoints) {
    if (_mapController != null && routePoints.isNotEmpty) {
      // Calculate bounds that include all route points
      double minLat = routePoints.first.latitude;
      double maxLat = routePoints.first.latitude;
      double minLng = routePoints.first.longitude;
      double maxLng = routePoints.first.longitude;
      
      for (final point in routePoints) {
        minLat = math.min(minLat, point.latitude);
        maxLat = math.max(maxLat, point.latitude);
        minLng = math.min(minLng, point.longitude);
        maxLng = math.max(maxLng, point.longitude);
      }
      
      final bounds = LatLngBounds(
        southwest: LatLng(minLat, minLng),
        northeast: LatLng(maxLat, maxLng),
      );
      
      _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 100.0), // 100px padding
      );
    }
  }

  // Animate camera to show mechanic location and customer location
  void _animateCameraToShowPoints() {
    if (_mapController != null && _mechanicLocation != null && _customerLocation != null) {
      final bounds = _calculateBounds([_mechanicLocation!, _customerLocation!]);
      _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 100.0),
      );
    }
  }

  // Calculate bounds for multiple points
  LatLngBounds _calculateBounds(List<LatLng> points) {
    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final point in points) {
      minLat = math.min(minLat, point.latitude);
      maxLat = math.max(maxLat, point.latitude);
      minLng = math.min(minLng, point.longitude);
      maxLng = math.max(maxLng, point.longitude);
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  // Update map markers
  Future<void> _updateMarkers() async {
    final Set<Marker> markers = {};
    
    // Add customer location marker
    if (_customerLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('customer_location'),
          position: _customerLocation!,
          icon: await _buildCustomerMarkerIcon(),
          infoWindow: InfoWindow(
            title: _customerName ?? 'Customer',
            snippet: 'Pickup Location',
          ),
        ),
      );
    }
    
    // Add mechanic location marker
    if (_mechanicLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('mechanic_location'),
          position: _mechanicLocation!,
          icon: await _buildMechanicMarkerIcon(),
          infoWindow: const InfoWindow(
            title: 'You',
            snippet: 'Current Location',
          ),
        ),
      );
    }
    
    if (mounted) {
      setState(() {
        _markers = markers;
      });
    }
  }

  Future<BitmapDescriptor> _buildCustomerMarkerIcon() async {
    try {
      // Create a custom marker for customer
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      const size = Size(120, 120);
      
      // Draw customer marker (blue circle with person icon)
      final paint = Paint()
        ..color = const Color(0xFF1976D2)
        ..style = PaintingStyle.fill;
      
      canvas.drawCircle(const Offset(60, 60), 50, paint);
      
      // Draw white border
      final borderPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6;
      
      canvas.drawCircle(const Offset(60, 60), 50, borderPaint);
      
      // Draw person icon
      final textPainter = TextPainter(
        text: const TextSpan(
          text: '👤',
          style: TextStyle(fontSize: 40),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, const Offset(40, 40));
      
      final picture = recorder.endRecording();
      final image = await picture.toImage(size.width.toInt(), size.height.toInt());
      final pngBytes = await image.toByteData(format: ui.ImageByteFormat.png);
      
      return BitmapDescriptor.fromBytes(pngBytes!.buffer.asUint8List());
    } catch (_) {
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
    }
  }

  Future<BitmapDescriptor> _buildMechanicMarkerIcon() async {
    try {
      // Create a custom marker for mechanic
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      const size = Size(120, 120);
      
      // Draw mechanic marker (red circle with tool icon)
      final paint = Paint()
        ..color = const Color(0xFFEF5350)
        ..style = PaintingStyle.fill;
      
      canvas.drawCircle(const Offset(60, 60), 50, paint);
      
      // Draw white border
      final borderPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6;
      
      canvas.drawCircle(const Offset(60, 60), 50, borderPaint);
      
      // Draw tool icon
      final textPainter = TextPainter(
        text: const TextSpan(
          text: '🔧',
          style: TextStyle(fontSize: 40),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, const Offset(40, 40));
      
      final picture = recorder.endRecording();
      final image = await picture.toImage(size.width.toInt(), size.height.toInt());
      final pngBytes = await image.toByteData(format: ui.ImageByteFormat.png);
      
      return BitmapDescriptor.fromBytes(pngBytes!.buffer.asUint8List());
    } catch (_) {
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
    }
  }

  // Call customer directly
  Future<void> _callCustomer(String phoneNumber) async {
    try {
      // Try native Android method first
      final success = await makePhoneCallNative(phoneNumber);
      if (success) {
        print('✅ Native phone call successful');
        return;
      }
      
      // Fallback to URL launcher
      final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
        print('✅ Phone call launched via URL launcher');
      } else {
        throw Exception('Could not launch phone app');
      }
    } catch (e) {
      print('❌ Error making phone call: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Unable to make phone call: $e')),
              ],
            ),
            backgroundColor: Colors.red[700],
          ),
        );
      }
    }
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF1A1A1A),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with customer info
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFEF5350), Color(0xFFE53935)],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: _customerProfileImage != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(25),
                              child: Image.network(
                                _customerProfileImage!,
                                width: 50,
                                height: 50,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Icon(
                                    Icons.person,
                                    color: Colors.white,
                                    size: 30,
                                  );
                                },
                              ),
                            )
                          : const Icon(
                              Icons.person,
                              color: Colors.white,
                              size: 30,
                            ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _customerName ?? 'Customer',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _serviceType ?? 'Service Request',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // History Button
                    Container(
                      margin: EdgeInsets.only(left: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: IconButton(
                        onPressed: () => HistoryBottomSheet.showMechanicHistory(context),
                        icon: const Icon(
                          Icons.history,
                          color: Colors.white,
                          size: 24,
                        ),
                        tooltip: 'View Earnings & History',
                      ),
                    ),
                    if (_customerPhone != null && _customerPhone!.isNotEmpty)
                      Container(
                        margin: EdgeInsets.only(left: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: IconButton(
                          onPressed: () => _callCustomer(_customerPhone!),
                          icon: const Icon(
                            Icons.phone,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Status indicator
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _getStatusDisplayText(_serviceStatus ?? 'accepted'),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Job details
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Job Details',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 12),
                
                _buildDetailRow('Service:', _serviceType ?? 'Service Request'),
                if (_description != null && _description!.isNotEmpty)
                  _buildDetailRow('Description:', _description!),
                _buildDetailRow('Location:', _customerAddress),
                if (_distanceToCustomer != null)
                  _buildDetailRow('Distance:', _distanceToCustomer!),
                if (_durationToCustomer != null)
                  _buildDetailRow('ETA:', _durationToCustomer!),
              ],
            ),
          ),
          
          // Map
          Container(
            height: 300,
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  spreadRadius: 0,
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _customerLocation != null
                  ? GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: _customerLocation!,
                        zoom: 15,
                      ),
                      markers: _markers,
                      polylines: _polylines,
                      mapType: _currentMapType,
                      myLocationEnabled: false,
                      myLocationButtonEnabled: false,
                      zoomControlsEnabled: true,
                      // Enable all gesture controls for movable map
                      zoomGesturesEnabled: true,
                      scrollGesturesEnabled: true,
                      tiltGesturesEnabled: true,
                      rotateGesturesEnabled: true,
                      compassEnabled: true,
                      mapToolbarEnabled: true,
                      // CRITICAL: Allow map gestures to work in bottom sheet
                      gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                        Factory<EagerGestureRecognizer>(
                          () => EagerGestureRecognizer(),
                        ),
                      },
                      onMapCreated: (GoogleMapController controller) {
                        _mapController = controller;
                        if (_mechanicLocation != null) {
                          _showRouteAutomatically();
                        }
                      },
                      onTap: (position) {
                        // Optional: Handle map tap
                      },
                    )
                  : Container(
                      color: Colors.grey[200],
                      child: const Center(
                        child: CircularProgressIndicator(color: Color(0xFFEF5350)),
                      ),
                    ),
            ),
          ),
          
          // Dynamic Action buttons based on job progress
          _buildActionButtons(),
        ],
      ),
    );
  }

  String _getStatusDisplayText(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
        return 'JOB ACCEPTED';
      case 'in_progress':
        return 'IN PROGRESS';
      case 'awaiting_payment':
        return 'AWAITING PAYMENT';
      case 'paid':
        return 'PAYMENT RECEIVED';
      case 'ready_to_assign':
        return 'READY TO START';
      case 'assigned':
        return 'ASSIGNED';
      case 'inspection_completed':
        return 'INSPECTION DONE';
      case 'invoice_sent':
        return 'INVOICE SENT';
      case 'invoice_paid':
        return 'INVOICE PAID';
      case 'completed':
        return 'COMPLETED';
      default:
        return status.toUpperCase();
    }
  }

  // Build action buttons based on job progress
  Widget _buildActionButtons() {
    print('🎯 Building action buttons - _canScanQR: $_canScanQR, _invoiceGenerated: $_invoiceGenerated, _invoiceAccepted: $_invoiceAccepted');
    
    if (_canScanQR) {
      print('🎯 QR scan buttons should be visible!');
    } else {
      print('❌ QR scan buttons are hidden because _canScanQR is false');
    }
    
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Invoice Generation Button (shown first)
          if (!_invoiceGenerated)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _generateInvoice,
                icon: const Icon(Icons.receipt_long, size: 20),
                label: const Text(
                  'Create Detailed Invoice',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

          // Status message when invoice is generated but not accepted
          if (_invoiceGenerated && !_invoiceAccepted)
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.hourglass_empty, color: Colors.orange[700]),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Waiting for customer to accept the invoice...',
                          style: TextStyle(
                            color: Colors.orange[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _generateInvoice, // Reuse same function to edit
                      icon: const Icon(Icons.edit_note, size: 18),
                      label: const Text(
                        'Edit Invoice Details',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[600],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // QR Scan Options (shown after invoice is accepted)
          if (_canScanQR) ...[
            // Camera Scan Button (Primary option)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _scanQRWithCamera,
                icon: const Icon(Icons.camera_alt, size: 20),
                label: const Text(
                  'Scan QR with Camera',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF5350),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
