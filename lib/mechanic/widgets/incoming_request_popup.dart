import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/roadaid_colors.dart';
import 'dart:async';

class IncomingRequestPopup extends StatefulWidget {
  final Map<String, dynamic> requestData;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const IncomingRequestPopup({
    Key? key,
    required this.requestData,
    required this.onAccept,
    required this.onReject,
  }) : super(key: key);

  @override
  State<IncomingRequestPopup> createState() => _IncomingRequestPopupState();
}

class _IncomingRequestPopupState extends State<IncomingRequestPopup>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _countdownController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _countdownAnimation;
  
  Timer? _countdownTimer;
  int _remainingSeconds = 30;
  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();
    
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _countdownController = AnimationController(
      duration: const Duration(seconds: 30),
      vsync: this,
    );
    
    _scaleAnimation = CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    );
    
    _countdownAnimation = CurvedAnimation(
      parent: _countdownController,
      curve: Curves.linear,
    );

    _startAnimations();
    _startCountdown();
    
    // Haptic feedback for incoming request
    HapticFeedback.heavyImpact();
  }

  void _startAnimations() {
    _scaleController.forward();
    _countdownController.forward();
  }

  void _startCountdown() {
    _remainingSeconds = widget.requestData['timeout_seconds'] ?? 30;
    
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _remainingSeconds--;
        });
        
        if (_remainingSeconds <= 0) {
          timer.cancel();
          _autoReject();
        } else if (_remainingSeconds <= 5) {
          // Urgent pulse for last 5 seconds
          HapticFeedback.selectionClick();
        }
      }
    });
  }

  void _autoReject() {
    if (!_isAnimating) {
      _isAnimating = true;
      widget.onReject();
    }
  }

  void _handleAccept() {
    if (!_isAnimating) {
      _isAnimating = true;
      HapticFeedback.heavyImpact();
      _countdownTimer?.cancel();
      
      // Scale down animation before closing
      _scaleController.reverse().then((_) {
        widget.onAccept();
      });
    }
  }

  void _handleReject() {
    if (!_isAnimating) {
      _isAnimating = true;
      HapticFeedback.mediumImpact();
      _countdownTimer?.cancel();
      
      // Scale down animation before closing
      _scaleController.reverse().then((_) {
        widget.onReject();
      });
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _scaleController.dispose();
    _countdownController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false, // Prevent back button
      child: Scaffold(
        backgroundColor: Colors.black54,
        body: Center(
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Container(
              margin: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    spreadRadius: 5,
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header with countdown
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: widget.requestData['is_emergency'] == true
                          ? RoadAidColors.warning
                          : RoadAidColors.primary,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                widget.requestData['is_emergency'] == true
                                    ? '🚨 EMERGENCY REQUEST'
                                    : 'New Service Request',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            // Countdown circle
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  AnimatedBuilder(
                                    animation: _countdownAnimation,
                                    builder: (context, child) {
                                      return CircularProgressIndicator(
                                        value: 1 - _countdownAnimation.value,
                                        strokeWidth: 3,
                                        valueColor: const AlwaysStoppedAnimation<Color>(
                                          Colors.white,
                                        ),
                                        backgroundColor: Colors.white.withOpacity(0.3),
                                      );
                                    },
                                  ),
                                  Text(
                                    '$_remainingSeconds',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Auto-reject in $_remainingSeconds seconds',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Content
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Service type and priority
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color.fromARGB(255, 176, 12, 1).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  widget.requestData['service_type'] ?? 'Service',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Color.fromARGB(255, 176, 12, 1),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                            if (widget.requestData['priority'] == 'high') ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'HIGH',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Customer info
                        _InfoRow(
                          icon: Icons.person,
                          label: 'Customer',
                          value: widget.requestData['customer_name'] ?? 'Unknown',
                        ),
                        
                        const SizedBox(height: 12),
                        
                        // Vehicle info
                        if (widget.requestData['vehicle'] != null)
                          _InfoRow(
                            icon: Icons.directions_car,
                            label: 'Vehicle',
                            value: _getVehicleInfo(),
                          ),
                        
                        const SizedBox(height: 12),
                        
                        // Location
                        _InfoRow(
                          icon: Icons.location_on,
                          label: 'Location',
                          value: widget.requestData['pickup_address'] ?? 'Unknown location',
                          maxLines: 2,
                        ),
                        
                        const SizedBox(height: 12),
                        
                        // Distance and estimated pay
                        Row(
                          children: [
                            Expanded(
                              child: _InfoRow(
                                icon: Icons.route,
                                label: 'Distance',
                                value: _getDistanceText(),
                              ),
                            ),
                            Expanded(
                              child: _InfoRow(
                                icon: Icons.attach_money,
                                label: 'Est. Pay',
                                value: _getEstimatedPay(),
                              ),
                            ),
                          ],
                        ),
                        
                        // Problem description if available
                        if (widget.requestData['description'] != null &&
                            widget.requestData['description'].toString().isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _InfoRow(
                            icon: Icons.description,
                            label: 'Problem',
                            value: widget.requestData['description'],
                            maxLines: 3,
                          ),
                        ],
                      ],
                    ),
                  ),
                  
                  // Action buttons
                  Container(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        // Reject button
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _handleReject,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: RoadAidColors.reject,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              'Reject',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        
                        const SizedBox(width: 16),
                        
                        // Accept button
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: _handleAccept,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: RoadAidColors.accept,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              'Accept Job',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
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
        ),
      ),
    );
  }

  String _getVehicleInfo() {
    final vehicle = widget.requestData['vehicle'];
    if (vehicle == null) return 'Unknown vehicle';
    
    return '${vehicle['brand_name']} ${vehicle['model_name']} (${vehicle['year']})';
  }

  String _getDistanceText() {
    final distance = widget.requestData['distance_km'];
    if (distance == null) return 'Unknown';
    
    if (distance < 1) {
      return '${(distance * 1000).round()}m';
    } else {
      return '${distance.toStringAsFixed(1)}km';
    }
  }

  String _getEstimatedPay() {
    final price = widget.requestData['estimated_price'];
    if (price == null) return 'TBD';
    
    return '₱${price.toStringAsFixed(0)}';
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final int maxLines;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 16,
          color: const Color.fromARGB(255, 176, 12, 1),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
                maxLines: maxLines,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
