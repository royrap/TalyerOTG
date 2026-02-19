import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';
import '../../services/supabase_service.dart';
import '../../services/maps_service.dart';
import '../../services/logging_service.dart';
import '../../widgets/history_bottom_sheet.dart';
import '../../widgets/review_dialog.dart';

class CustomerServiceTrackingBottomSheet extends StatefulWidget {
  final String serviceRequestId;
  final VoidCallback? onClose;
  final bool showHistoryButton;

  const CustomerServiceTrackingBottomSheet({
    Key? key,
    required this.serviceRequestId,
    this.onClose,
    this.showHistoryButton = true, // Default to true for backward compatibility
  }) : super(key: key);

  @override
  State<CustomerServiceTrackingBottomSheet> createState() => _CustomerServiceTrackingBottomSheetState();
}

class _CustomerServiceTrackingBottomSheetState extends State<CustomerServiceTrackingBottomSheet>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late Animation<double> _slideAnimation;
  bool _isExpanded = false;
  Map<String, dynamic>? _serviceRequest;
  String? _mechanicName;
  String? _mechanicPhone;
  LatLng? _mechanicLocation;
  bool _isLoadingData = true;
  String _currentStatus = 'Loading...';
  String? _previousStatus; // Track previous status to detect changes
  StreamSubscription? _realtimeSubscription; // Real-time updates
  // MapsService for realtime synced polylines/markers
  final MapsService _mapsService = MapsService();
  StreamSubscription<List<LatLng>>? _routeSubscription;
  StreamSubscription? _mapsTrackingSubscription;
  GoogleMapController? _mapController;
  Set<Polyline> _polylines = <Polyline>{};
  Set<Marker> _markers = <Marker>{};
  List<LatLng>? _lastRoutePoints;
  BitmapDescriptor? _mechanicIcon;
  BitmapDescriptor? _customerIcon;
  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeInOut,
    ));
    
    // Start the slide animation
    _slideController.forward();
    
    // Load service request data
    _loadServiceData();
    
    // Set up real-time listener for status changes
    _setupRealtimeListener();
  }

  @override
  void dispose() {
    _slideController.dispose();
    _realtimeSubscription?.cancel(); // Cancel subscription
    // Stop maps tracking and cancel subscriptions
    _routeSubscription?.cancel();
    _mapsTrackingSubscription?.cancel();
    try {
      _mapsService.stopRealTimeTracking();
    } catch (_) {}
    super.dispose();
  }
  
  void _setupRealtimeListener() {
    // Listen for changes to the service request
    _realtimeSubscription = SupabaseService.client
        .from('service_requests')
        .stream(primaryKey: ['id'])
        .eq('id', widget.serviceRequestId)
        .listen((List<Map<String, dynamic>> data) {
          if (data.isNotEmpty && mounted) {
            final newRequest = data.first;
            final newStatus = newRequest['status'] as String?;
            
            LoggingService().debug('📡 Real-time update received - Status: $newStatus, Previous: $_previousStatus');
            LoggingService().debug('🔍 Current _serviceRequest status: ${_serviceRequest?['status']}');
            LoggingService().debug('🔍 Checking completion: newStatus=$newStatus, _previousStatus=$_previousStatus');
            
            // Check if status changed to completed
            // Allow dialog to show even on first load if status is completed
            if (newStatus == 'completed') {
              // Only show dialog if we haven't shown it before (previous was not completed)
              if (_previousStatus != 'completed') {
                LoggingService().info('🎉 Job completed! Showing completion dialog...');
                // Use a slight delay to ensure dialog context is ready
                Future.delayed(const Duration(milliseconds: 500), () {
                  if (mounted) {
                    LoggingService().debug('✅ Calling _showJobCompletionDialog()');
                    _showJobCompletionDialog();
                  } else {
                    LoggingService().debug('❌ Widget not mounted, skipping dialog');
                  }
                });
              } else {
                LoggingService().debug('ℹ️ Status is completed but dialog already shown (previous was also completed)');
              }
            }
            
            // Update state
            setState(() {
              _previousStatus = newStatus; // Update to current status
              _serviceRequest = newRequest;
              _currentStatus = _getStatusDisplayText(newStatus);
            });
          }
        });
  }
  
  void _showJobCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismissing by tapping outside
      builder: (context) => WillPopScope(
        onWillPop: () async => false, // Prevent dismissing with back button
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green[700],
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: Colors.white,
                  size: 36,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Text(
                  'Job Completed!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color.fromARGB(255, 27, 94, 32),
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your service has been completed successfully.',
                style: TextStyle(
                  fontSize: 17,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green[200]!, width: 2),
                ),
                child: Row(
                  children: [
                    Icon(Icons.stars, color: Colors.green[700], size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Would you like to rate your mechanic?',
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.green[900],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Thank you for using RoadAid!',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          actions: [
            OutlinedButton.icon(
              onPressed: () {
                LoggingService().debug('📱 Close button pressed - dismissing dialog and bottom sheet');
                Navigator.pop(context); // Close dialog
                if (widget.onClose != null) {
                  widget.onClose!();
                }
                Navigator.pop(context); // Close tracking bottom sheet
              },
              icon: const Icon(Icons.close, size: 20),
              label: const Text('Close', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.grey[700],
                side: BorderSide(color: Colors.grey[400]!, width: 2),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () {
                LoggingService().debug('⭐ Rate Mechanic button pressed');
                Navigator.pop(context); // Close dialog
                _openReviewScreen(); // Open review screen
              },
              icon: const Icon(Icons.star_rate, size: 22),
              label: const Text('Rate Mechanic', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 176, 12, 1),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
          actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        ),
      ),
    );
  }
  
  void _openReviewScreen() {
    // Close the tracking bottom sheet
    if (widget.onClose != null) {
      widget.onClose!();
    }
    Navigator.pop(context);
    
    // Navigate to review dialog
    final mechanicId = _serviceRequest?['assigned_mechanic_id'];
    final serviceTitle = _serviceRequest?['title'] ?? _serviceRequest?['service_type'] ?? 'Roadside Assistance';
    
    if (mechanicId != null) {
      showDialog(
        context: context,
        builder: (context) => ReviewDialog(
          requestId: widget.serviceRequestId,
          providerId: mechanicId,
          serviceTitle: serviceTitle,
          onReviewSubmitted: () {
            // Review submitted callback
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Thank you for your review!'),
                backgroundColor: Colors.green,
              ),
            );
          },
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to open review - mechanic information not found'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<void> _loadServiceData() async {
    try {
      // Get service request details
      final serviceRequest = await SupabaseService.getServiceRequestById(widget.serviceRequestId);
      if (serviceRequest != null && mounted) {
        setState(() {
          _serviceRequest = serviceRequest;
          _currentStatus = _getStatusDisplayText(serviceRequest['status']);
        });

        // Load mechanic info if assigned
        if (serviceRequest['assigned_mechanic_id'] != null) {
          await _loadMechanicInfo(serviceRequest['assigned_mechanic_id']);
          // Start MapsService realtime tracking so customer sees same polyline
          _startMapsRealtimeTrackingIfReady(serviceRequest);
        }
      }
    } catch (e) {
      LoggingService().error('❌ Error loading service data: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingData = false;
        });
      }
    }
  }

  Future<void> _loadMechanicInfo(String mechanicId) async {
    try {
      final mechanicProfile = await SupabaseService.client
          .from('user_profiles')
          .select('first_name, last_name, phone_number, current_latitude, current_longitude')
          .eq('id', mechanicId)
          .maybeSingle();

      if (mechanicProfile != null && mounted) {
        setState(() {
          _mechanicName = '${mechanicProfile['first_name']} ${mechanicProfile['last_name']}';
          _mechanicPhone = mechanicProfile['phone_number'];
          
          if (mechanicProfile['current_latitude'] != null && 
              mechanicProfile['current_longitude'] != null) {
            _mechanicLocation = LatLng(
              (mechanicProfile['current_latitude'] as num).toDouble(),
              (mechanicProfile['current_longitude'] as num).toDouble(),
            );
            // If we have mechanic and customer locations, start maps tracking
            _startMapsRealtimeTrackingIfReady(_serviceRequest);
          }
        });
      }
    } catch (e) {
      LoggingService().error('❌ Error loading mechanic info: $e');
    }
  }

  String _getStatusDisplayText(String? status) {
    switch (status) {
      case 'pending':
        return 'Request Submitted';
      case 'confirmed':
        return 'Service Confirmed';
      case 'in_progress':
        return 'Mechanic En Route';
      case 'arrived':
        return 'Mechanic Arrived';
      case 'invoice_sent':
        return 'Invoice Sent';
      case 'invoice_paid':
        return 'Payment Complete';
      case 'completed':
        return 'Service Complete';
      case 'cancelled':
        return 'Service Cancelled';
      default:
        return status ?? 'Unknown Status';
    }
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
      case 'in_progress':
        return Colors.blue;
      case 'arrived':
        return Colors.purple;
      case 'invoice_sent':
        return Colors.amber;
      case 'invoice_paid':
        return const Color.fromARGB(255, 76, 175, 80);
      case 'completed':
        return const Color.fromARGB(255, 27, 94, 32);
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }

  Future<void> _handleCancelRequest() async {
    // Show confirmation dialog
    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Request'),
        content: const Text(
          'Are you sure you want to cancel this service request? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No, Keep Request'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (shouldCancel != true) return;

    try {
      // Update the service request status to cancelled
      await SupabaseService.client
          .from('service_requests')
          .update({'status': 'cancelled'})
          .eq('id', widget.serviceRequestId);

      if (!mounted) return;

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Request cancelled successfully'),
          backgroundColor: Colors.green,
        ),
      );

      // Close the bottom sheet
      if (widget.onClose != null) {
        widget.onClose!();
      }
      Navigator.pop(context);

    } catch (e) {
      LoggingService().error('❌ Error cancelling request: $e');
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to cancel request: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _navigateToFullTracking() {
    // TODO: Navigate to actual tracking screen when implemented
    // For now, just show a message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Full tracking screen not yet implemented'),
        backgroundColor: Colors.blue,
      ),
    );
    
    /* When tracking screen is implemented, use this:
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CustomerServiceRequestStatusScreenRealTime(
          serviceRequestId: widget.serviceRequestId,
        ),
      ),
    );
    */
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation.drive(
        Tween<Offset>(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ),
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 10,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // Header
            GestureDetector(
              onTap: _toggleExpanded,
              child: Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Status icon
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: _getStatusColor(_serviceRequest?['status']),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _getStatusIcon(_serviceRequest?['status']),
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    
                    // Service info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _currentStatus,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (_serviceRequest != null) ...[
                            Text(
                              _serviceRequest!['issue_title'] ?? 'Service Request',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[700],
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Request ID: ${widget.serviceRequestId}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ] else if (_isLoadingData) ...[
                            const Text(
                              'Loading service details...',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    
                    // Expand/Close icon
                    Icon(
                      _isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: Colors.grey,
                    ),
                  ],
                ),
              ),
            ),
            
            // Expandable content
            if (_isExpanded) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Service details
                    if (_serviceRequest != null) _buildServiceDetails(),
                    const SizedBox(height: 12),
                    // Embedded map showing mechanic/customer and route
                    SizedBox(
                      height: 180,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: GoogleMap(
                          initialCameraPosition: CameraPosition(
                            target: _mechanicLocation ?? LatLng(14.5995, 120.9842),
                            zoom: 14,
                          ),
                          myLocationEnabled: false,
                          myLocationButtonEnabled: false,
                          zoomControlsEnabled: true,
                          // Enable gesture recognizers so the map remains interactive inside a bottom sheet
                          gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                            Factory<EagerGestureRecognizer>(() => EagerGestureRecognizer()),
                          },
                          markers: _markers,
                          polylines: _polylines,
                          mapType: MapType.normal,
                          zoomGesturesEnabled: true,
                          scrollGesturesEnabled: true,
                          tiltGesturesEnabled: true,
                          rotateGesturesEnabled: true,
                          compassEnabled: true,
                          mapToolbarEnabled: true,
                          onMapCreated: (controller) async {
                            _mapController = controller;
                            LoggingService().debug('🧭 [CustomerSheet] onMapCreated - map controller ready');
                            // If we have a buffered route, wait a bit then apply it (smoother rendering)
                            if (_lastRoutePoints != null && _lastRoutePoints!.isNotEmpty) {
                              try {
                                await Future.delayed(const Duration(milliseconds: 200));
                                final poly = _mapsService.createRoutePolyline(_lastRoutePoints!);
                                setState(() {
                                  _polylines = {poly};
                                  _markers = {}; // start clean
                                });
                                final cameraUpdate = _mapsService.calculateCameraBounds(_lastRoutePoints!.first, _lastRoutePoints!.last);
                                _mapController?.animateCamera(cameraUpdate);
                                LoggingService().debug('🧭 [CustomerSheet] Applied buffered route with ${_lastRoutePoints!.length} points on map creation (after delay)');
                                // Add pickup and mechanic markers for context
                                await _updatePickupMarker();
                                if (_mechanicLocation != null) _updateMechanicMarker(_mechanicLocation!);
                              } catch (e) {
                                LoggingService().error('❌ [CustomerSheet] Failed to apply buffered route on map create: $e');
                              }
                            }
                            // Ensure MapsService tracking is started when map becomes available
                            try {
                              if (_serviceRequest != null) {
                                LoggingService().debug('🧭 [CustomerSheet] onMapCreated - ensuring MapsService tracking is started');
                                await _startMapsRealtimeTrackingIfReady(_serviceRequest);
                              }
                            } catch (e) {
                              LoggingService().error('❌ [CustomerSheet] Error starting MapsService on map create: $e');
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // Mechanic info
                    _buildMechanicInfo(),
                    const SizedBox(height: 20),
                    
                    // Action buttons
                    _buildActionButtons(),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _getStatusIcon(String? status) {
    switch (status) {
      case 'pending':
        return Icons.schedule;
      case 'confirmed':
        return Icons.check_circle;
      case 'in_progress':
        return Icons.directions_car;
      case 'arrived':
        return Icons.location_on;
      case 'invoice_sent':
        return Icons.receipt;
      case 'invoice_paid':
        return Icons.payment;
      case 'completed':
        return Icons.done_all;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }

  Widget _buildServiceDetails() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Service Details',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _buildDetailRow('Issue:', _serviceRequest!['issue_title'] ?? 'N/A'),
          if (_serviceRequest!['issue_description'] != null)
            _buildDetailRow('Description:', _serviceRequest!['issue_description']),
          _buildDetailRow('Location:', _serviceRequest!['location'] ?? 'N/A'),
          if (_serviceRequest!['created_at'] != null)
            _buildDetailRow('Requested:', _formatDateTime(_serviceRequest!['created_at'])),
        ],
      ),
    );
  }

  Widget _buildMechanicInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Assigned Mechanic',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          if (_mechanicName != null) ...[
            _buildDetailRow('Name:', _mechanicName!),
            if (_mechanicPhone != null)
              _buildDetailRow('Phone:', _mechanicPhone!),
            _buildDetailRow('Status:', 'Active'),
          ] else if (_serviceRequest?['assigned_mechanic_id'] != null) ...[
            const Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Text('Loading mechanic info...'),
              ],
            ),
          ] else ...[
            const Text(
              'No mechanic assigned yet',
              style: TextStyle(
                fontSize: 14,
                fontStyle: FontStyle.italic,
                color: Colors.grey,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Update or add mechanic marker on the embedded map
  void _updateMechanicMarker(LatLng location) {
    // Ensure icons are ready
    Future.wait([
      _mechanicIcon != null ? Future.value(_mechanicIcon) : _mapsService.getMechanicMarkerIcon(),
      _customerIcon != null ? Future.value(_customerIcon) : _mapsService.getCustomerMarkerIcon(),
    ]).then((icons) {
      _mechanicIcon ??= icons[0] as BitmapDescriptor?;
      _customerIcon ??= icons[1] as BitmapDescriptor?;

      final marker = Marker(
        markerId: const MarkerId('mechanic_marker'),
        position: location,
        infoWindow: const InfoWindow(title: 'Mechanic'),
        icon: _mechanicIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      );

      setState(() {
        _markers.removeWhere((m) => m.markerId.value == 'mechanic_marker');
        _markers.add(marker);
      });
    });
  }

  // Update or add pickup/customer marker on the embedded map
  Future<void> _updatePickupMarker() async {
    try {
      if (_serviceRequest == null) return;
      final pickupLat = _serviceRequest!['pickup_latitude'];
      final pickupLng = _serviceRequest!['pickup_longitude'];
      if (pickupLat == null || pickupLng == null) return;

      final loc = LatLng((pickupLat as num).toDouble(), (pickupLng as num).toDouble());

      // Ensure icons are ready
      _customerIcon ??= await _mapsService.getCustomerMarkerIcon();

      final marker = Marker(
        markerId: const MarkerId('pickup_marker'),
        position: loc,
        infoWindow: const InfoWindow(title: 'Pickup'),
        icon: _customerIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      );

      if (mounted) {
        setState(() {
          _markers.removeWhere((m) => m.markerId.value == 'pickup_marker');
          _markers.add(marker);
        });
      }
    } catch (e) {
      print('❌ [CustomerSheet] Error updating pickup marker: $e');
    }
  }

  // Fit the camera to show the full route
  Future<void> _fitCameraToBounds(List<LatLng> routePoints) async {
    if (_mapController == null || routePoints.isEmpty) return;

    try {
      double south = routePoints.first.latitude;
      double north = routePoints.first.latitude;
      double west = routePoints.first.longitude;
      double east = routePoints.first.longitude;

      for (final p in routePoints) {
        if (p.latitude < south) south = p.latitude;
        if (p.latitude > north) north = p.latitude;
        if (p.longitude < west) west = p.longitude;
        if (p.longitude > east) east = p.longitude;
      }

      final bounds = LatLngBounds(
        southwest: LatLng(south, west),
        northeast: LatLng(north, east),
      );

      final cameraUpdate = CameraUpdate.newLatLngBounds(bounds, 60);
      await _mapController!.animateCamera(cameraUpdate);
    } catch (e) {
      // Fallback: animate to first point
      if (routePoints.isNotEmpty) {
        await _mapController!.animateCamera(CameraUpdate.newLatLng(routePoints.first));
      }
    }
  }

  // Start the MapsService realtime tracking when both mechanic and customer locations available
  Future<void> _startMapsRealtimeTrackingIfReady(Map<String, dynamic>? serviceRequest) async {
    if (serviceRequest == null) return;
    try {
      final assignedMechanicId = serviceRequest['assigned_mechanic_id'] as String?;
      final pickupLat = serviceRequest['pickup_latitude'];
      final pickupLng = serviceRequest['pickup_longitude'];

      if (assignedMechanicId == null || pickupLat == null || pickupLng == null) return;

      final customerLocation = LatLng((pickupLat as num).toDouble(), (pickupLng as num).toDouble());

      // Cancel prior subscriptions
      _routeSubscription?.cancel();
      _mapsTrackingSubscription?.cancel();

      // Start MapsService tracking
  LoggingService().debug('🧭 [CustomerSheet] Starting MapsService.startRealTimeTracking with mechanicId: $assignedMechanicId, customerLocation: $customerLocation');
      await _mapsService.startRealTimeTracking(
        serviceRequestId: widget.serviceRequestId,
        customerLocation: customerLocation,
        mechanicId: assignedMechanicId,
      );
  LoggingService().debug('🧭 [CustomerSheet] MapsService.startRealTimeTracking returned (no exception)');

      // Subscribe to route and tracking streams
      _routeSubscription = _mapsService.routeStream.listen((routePoints) async {
  LoggingService().debug('🧭 [CustomerSheet] routeStream event received: ${routePoints.length} points');
        if (!mounted) return;

        // Always buffer the latest route (so onMapCreated can apply it)
        _lastRoutePoints = routePoints;

        if (routePoints.isEmpty) {
          LoggingService().debug('🧭 [CustomerSheet] Received empty route points, ignoring');
          return;
        }

        // Log a small sample of the geometry (first 3 and last 3) to help trace straight-line issues
        try {
          final startSample = routePoints.take(3).map((p) => '${p.latitude.toStringAsFixed(6)},${p.longitude.toStringAsFixed(6)}').join(' | ');
          final endSample = routePoints.length > 3
              ? routePoints.skip(routePoints.length - 3).map((p) => '${p.latitude.toStringAsFixed(6)},${p.longitude.toStringAsFixed(6)}').join(' | ')
              : '';
          LoggingService().debug('🧭 [CustomerSheet] route sample start: $startSample end: $endSample');
        } catch (e) {
          LoggingService().debug('🧭 [CustomerSheet] Failed to log route sample: $e');
        }

        // If the map controller is not ready, keep the buffered route and return
        if (_mapController == null) {
          LoggingService().debug('🧭 [CustomerSheet] Map controller not ready yet - buffered ${routePoints.length} points');
          return;
        }

        // Force-replace any existing polylines with the authoritative route from MapsService
        try {
          final poly = _mapsService.createRoutePolyline(routePoints);
          setState(() {
            // Clear existing polylines then set the new one to ensure no stale fallback remains
            _polylines = {poly};
            // Keep markers minimal: show pickup and mechanic markers for context
            _markers = {};
          });

          // Fit camera to show the new route on the embedded map using MapsService helper
          try {
            final cameraUpdate = _mapsService.calculateCameraBounds(routePoints.first, routePoints.last);
            await _mapController?.animateCamera(cameraUpdate);
          } catch (e) {
            await _fitCameraToBounds(routePoints);
          }

          // Update contextual markers outside setState to avoid slowing render
          await _updatePickupMarker();
          if (_mechanicLocation != null) await _updateMechanicMarker(_mechanicLocation!);

          LoggingService().debug('🧭 [CustomerSheet] Applied authoritative route with ${routePoints.length} points');
        } catch (e) {
          LoggingService().error('❌ [CustomerSheet] Failed to apply route: $e');
        }
      });

      _mapsTrackingSubscription = _mapsService.trackingDataStream.listen((data) {
        if (mounted && data.isNotEmpty) {
          setState(() {
            // Update mechanic location and marker if available
            final mechanicRaw = data['mechanic_location'];
            if (mechanicRaw is LatLng) {
              _mechanicLocation = mechanicRaw;
            } else if (mechanicRaw is Map) {
              final lat = mechanicRaw['latitude'] ?? mechanicRaw['lat'];
              final lng = mechanicRaw['longitude'] ?? mechanicRaw['lng'] ?? mechanicRaw['lon'];
              if (lat != null && lng != null) {
                _mechanicLocation = LatLng((lat as num).toDouble(), (lng as num).toDouble());
              }
            }

            if (_mechanicLocation != null) {
              _updateMechanicMarker(_mechanicLocation!);
            }
          });
        }
      });
    } catch (e) {
      LoggingService().error('❌ Error starting MapsService tracking in customer sheet: $e');
    }
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    final hasMechanicAssigned = _serviceRequest?['assigned_mechanic_id'] != null;
    
    return Column(
      children: [
        // Track Service button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _navigateToFullTracking,
            icon: const Icon(Icons.location_on),
            label: const Text('View Full Tracking'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromARGB(255, 176, 12, 1),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        
        // Cancel Request button - only show when NO mechanic is assigned
        if (!hasMechanicAssigned) ...[
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _handleCancelRequest,
              icon: const Icon(Icons.cancel),
              label: const Text('Cancel Request'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red[700],
                side: BorderSide(color: Colors.red[700]!),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        
        // Service History button - only show on home screen
        if (widget.showHistoryButton) ...[
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                HistoryBottomSheet.showCustomerHistory(context);
              },
              icon: const Icon(Icons.history),
              label: const Text('Service History'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.blue[700],
                side: BorderSide(color: Colors.blue[700]!),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
        
        // Contact Mechanic button (if available)
        if (_mechanicPhone != null)
          Column(
            children: [
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    // Add phone call functionality here
                    LoggingService().debug('📞 Calling mechanic: $_mechanicPhone');
                    // You can use url_launcher to make a phone call
                    // launch('tel:$_mechanicPhone');
                  },
                  icon: const Icon(Icons.phone),
                  label: const Text('Contact Mechanic'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color.fromARGB(255, 176, 12, 1),
                    side: const BorderSide(color: Color.fromARGB(255, 176, 12, 1)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        
        // Close button
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: () {
              if (widget.onClose != null) {
                widget.onClose!();
              }
            },
            child: const Text(
              'Close',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _formatDateTime(String dateTimeString) {
    try {
      final dateTime = DateTime.parse(dateTimeString);
      final now = DateTime.now();
      final difference = now.difference(dateTime);
      
      if (difference.inDays > 0) {
        return '${difference.inDays} days ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} hours ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} minutes ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return dateTimeString;
    }
  }
}










