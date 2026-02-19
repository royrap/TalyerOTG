import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/shop_based_request_service.dart';
import 'dart:async';

/// 📲 Incoming Shop Request Popup (Mechanic Side)
/// 
/// Full-screen modal that shows when a mechanic receives a shop-based request.
/// Similar to Grab/JoyRide driver request notification.
class IncomingShopRequestPopup extends StatefulWidget {
  final String requestId;
  final String mechanicId;
  final String shopId;
  final Map<String, dynamic> requestData;

  const IncomingShopRequestPopup({
    Key? key,
    required this.requestId,
    required this.mechanicId,
    required this.shopId,
    required this.requestData,
  }) : super(key: key);

  @override
  State<IncomingShopRequestPopup> createState() => _IncomingShopRequestPopupState();
}

class _IncomingShopRequestPopupState extends State<IncomingShopRequestPopup> with SingleTickerProviderStateMixin {
  final _shopService = ShopBasedRequestService.instance;
  
  bool _isProcessing = false;
  int _timeRemaining = 30; // 30 seconds to accept/reject
  Timer? _countdownTimer;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _startCountdown();
    _setupPulseAnimation();
  }

  void _setupPulseAnimation() {
    _pulseController = AnimationController(
      duration: Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (_timeRemaining > 0) {
        setState(() {
          _timeRemaining--;
        });
      } else {
        timer.cancel();
        _autoReject();
      }
    });
  }

  void _autoReject() {
    if (mounted && !_isProcessing) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Request expired - no response in time'),
          backgroundColor: Colors.orange,
        ),
      );
      Navigator.of(context).pop(false);
    }
  }

  Future<void> _handleAccept() async {
    if (_isProcessing) return;

    setState(() => _isProcessing = true);
    _countdownTimer?.cancel();

    try {
      final result = await _shopService.acceptRequest(
        requestId: widget.requestId,
        mechanicId: widget.mechanicId,
        shopId: widget.shopId,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        // Success! Show confirmation
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Request accepted! View job details'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        
        // Return true to indicate acceptance
        Navigator.of(context).pop(true);

      } else {
        // Handle errors
        final error = result['error'];
        String message = result['message'] ?? 'Failed to accept request';

        if (error == 'already_accepted') {
          message = 'Another mechanic has already accepted this request';
        } else if (error == 'not_authorized') {
          message = 'You are not authorized for this shop';
        } else if (error == 'wrong_shop') {
          message = 'This request is for a different shop';
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: Colors.red,
            ),
          );
          Navigator.of(context).pop(false);
        }
      }

    } catch (e) {
      print('❌ Error accepting request: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _handleReject() async {
    if (_isProcessing) return;

    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Decline Request?'),
        content: Text('Are you sure you want to decline this service request?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('Decline'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isProcessing = true);
    _countdownTimer?.cancel();

    try {
      await _shopService.rejectRequest(
        requestId: widget.requestId,
        mechanicId: widget.mechanicId,
        reason: 'Mechanic declined the request',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Request declined'),
            backgroundColor: Colors.grey[700],
          ),
        );
        Navigator.of(context).pop(false);
      }

    } catch (e) {
      print('❌ Error rejecting request: $e');
      
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final customer = widget.requestData['customer'] as Map<String, dynamic>? ?? {};
    final vehicle = widget.requestData['vehicle'] as Map<String, dynamic>? ?? {};
    final customerName = '${customer['first_name'] ?? ''} ${customer['last_name'] ?? ''}'.trim();
    final customerPhone = customer['phone_number'] ?? 'No phone';
    final customerPhoto = customer['profile_image_url'];
    final customerRating = (customer['rating'] ?? 0.0) as double;

    final vehicleBrand = vehicle['brand_name'] ?? 'Unknown';
    final vehicleModel = vehicle['model_name'] ?? 'Unknown';
    final vehicleColor = vehicle['color'] ?? 'Unknown';
    final vehiclePlate = vehicle['plate_number'] ?? 'N/A';

    final serviceTitle = widget.requestData['title'] ?? 'Service Request';
    final serviceDescription = widget.requestData['description'] ?? 'No description';
    final pickupAddress = widget.requestData['pickup_address'] ?? 'Customer location';
    
    final pickupLat = widget.requestData['pickup_latitude'] as double?;
    final pickupLng = widget.requestData['pickup_longitude'] as double?;
    final distance = widget.requestData['distance_km'] as double? ?? 0.0;

    return WillPopScope(
      onWillPop: () async {
        // Prevent dismissal by back button during processing
        return !_isProcessing;
      },
      child: Scaffold(
        backgroundColor: Colors.black.withOpacity(0.85),
        body: SafeArea(
          child: Column(
            children: [
              // Header with countdown
              Container(
                padding: EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'New Service Request',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _pulseAnimation.value,
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: _timeRemaining > 10 ? Colors.green : Colors.red,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${_timeRemaining}s',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              // Main content card
              Expanded(
                child: Container(
                  margin: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Customer Info
                              Row(
                                children: [
                                  // Profile photo
                                  CircleAvatar(
                                    radius: 40,
                                    backgroundColor: Colors.grey[300],
                                    backgroundImage: customerPhoto != null 
                                        ? NetworkImage(customerPhoto)
                                        : null,
                                    child: customerPhoto == null
                                        ? Icon(Icons.person, size: 40, color: Colors.grey[600])
                                        : null,
                                  ),
                                  SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          customerName.isEmpty ? 'Customer' : customerName,
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(Icons.star, size: 16, color: Colors.amber),
                                            SizedBox(width: 4),
                                            Text(
                                              customerRating.toStringAsFixed(1),
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(Icons.phone, size: 14, color: Colors.grey[600]),
                                            SizedBox(width: 4),
                                            Text(
                                              customerPhone,
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),

                              SizedBox(height: 24),
                              Divider(),
                              SizedBox(height: 16),

                              // Service Details
                              _SectionTitle(icon: Icons.build, title: 'Service Requested'),
                              SizedBox(height: 8),
                              Text(
                                serviceTitle,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                serviceDescription,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                  height: 1.4,
                                ),
                              ),

                              SizedBox(height: 20),

                              // Vehicle Details
                              _SectionTitle(icon: Icons.directions_car, title: 'Vehicle Information'),
                              SizedBox(height: 8),
                              Container(
                                padding: EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  children: [
                                    _InfoRow(label: 'Brand', value: vehicleBrand),
                                    _InfoRow(label: 'Model', value: vehicleModel),
                                    _InfoRow(label: 'Color', value: vehicleColor),
                                    _InfoRow(label: 'Plate #', value: vehiclePlate, isLast: true),
                                  ],
                                ),
                              ),

                              SizedBox(height: 20),

                              // Location
                              _SectionTitle(icon: Icons.location_on, title: 'Pickup Location'),
                              SizedBox(height: 8),
                              Text(
                                pickupAddress,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[700],
                                ),
                              ),
                              if (distance > 0) ...[
                                SizedBox(height: 8),
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.blue[50],
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.straighten, size: 14, color: Colors.blue[700]),
                                      SizedBox(width: 4),
                                      Text(
                                        '${distance.toStringAsFixed(1)} km away',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.blue[700],
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              // Map preview (if coordinates available)
                              if (pickupLat != null && pickupLng != null) ...[
                                SizedBox(height: 12),
                                Container(
                                  height: 150,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.grey[300]!),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: GoogleMap(
                                      initialCameraPosition: CameraPosition(
                                        target: LatLng(pickupLat, pickupLng),
                                        zoom: 15,
                                      ),
                                      markers: {
                                        Marker(
                                          markerId: MarkerId('pickup'),
                                          position: LatLng(pickupLat, pickupLng),
                                          infoWindow: InfoWindow(title: 'Customer Location'),
                                        ),
                                      },
                                      zoomControlsEnabled: false,
                                      myLocationButtonEnabled: false,
                                      mapToolbarEnabled: false,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),

                      // Action Buttons
                      Container(
                        padding: EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: Offset(0, -5),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            // Reject Button
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _isProcessing ? null : _handleReject,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red[50],
                                  foregroundColor: Colors.red[700],
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
                                ),
                                child: _isProcessing
                                    ? SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation(Colors.red),
                                        ),
                                      )
                                    : Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.close, size: 20),
                                          SizedBox(width: 8),
                                          Text(
                                            'Decline',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                            
                            SizedBox(width: 16),
                            
                            // Accept Button
                            Expanded(
                              flex: 2,
                              child: ElevatedButton(
                                onPressed: _isProcessing ? null : _handleAccept,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green[600],
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 2,
                                ),
                                child: _isProcessing
                                    ? SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation(Colors.white),
                                        ),
                                      )
                                    : Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.check_circle, size: 22),
                                          SizedBox(width: 8),
                                          Text(
                                            'Accept Job',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
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
}

/// Section Title Widget
class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[700]),
        SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ),
      ],
    );
  }
}

/// Info Row Widget
class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isLast;

  const _InfoRow({
    required this.label,
    required this.value,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        if (!isLast) ...[
          SizedBox(height: 8),
          Divider(height: 1),
          SizedBox(height: 8),
        ],
      ],
    );
  }
}
