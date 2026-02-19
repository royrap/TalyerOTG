import 'package:flutter/material.dart';
import 'dart:async';
import '../services/real_time_eta_service.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class RealTimeETAWidget extends StatefulWidget {
  final String serviceRequestId;
  final String mechanicId;
  final LatLng customerLocation;
  final String? mechanicName;

  const RealTimeETAWidget({
    Key? key,
    required this.serviceRequestId,
    required this.mechanicId,
    required this.customerLocation,
    this.mechanicName,
  }) : super(key: key);

  @override
  State<RealTimeETAWidget> createState() => _RealTimeETAWidgetState();
}

class _RealTimeETAWidgetState extends State<RealTimeETAWidget>
    with TickerProviderStateMixin {
  StreamSubscription<Map<String, dynamic>>? _etaSubscription;
  Map<String, dynamic>? _currentETA;
  bool _isLoading = true;
  
  late AnimationController _pulseController;
  late AnimationController _slideController;
  late Animation<double> _pulseAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    
    // Initialize animations
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutBack,
    ));
    
    _startETATracking();
    _slideController.forward();
  }

  @override
  void dispose() {
    _etaSubscription?.cancel();
    _pulseController.dispose();
    _slideController.dispose();
    RealTimeETAService.instance.stopETATracking();
    super.dispose();
  }

  void _startETATracking() {
    _etaSubscription = RealTimeETAService.instance.trackMechanicETA(
      serviceRequestId: widget.serviceRequestId,
      mechanicId: widget.mechanicId,
      customerLocation: widget.customerLocation,
    ).listen(
      (etaData) {
        if (mounted) {
          setState(() {
            _currentETA = etaData;
            _isLoading = false;
          });
        }
      },
      onError: (error) {
        print('❌ ETA tracking error: $error');
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1E88E5), Color(0xFF1976D2)],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withOpacity(0.3),
              spreadRadius: 0,
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: _isLoading
            ? _buildLoadingState()
            : _currentETA != null
                ? _buildETAContent()
                : _buildErrorState(),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) => Transform.scale(
              scale: _pulseAnimation.value,
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.location_on,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Calculating ETA...',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Getting real-time location data',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildETAContent() {
    final eta = _currentETA!;
    final etaMinutes = eta['eta_minutes'] as int;
    final trafficCondition = eta['traffic_condition'] as String? ?? 'normal';
    final distance = eta['distance_km'] as double? ?? 0.0;
    final mechanicName = widget.mechanicName ?? 'Your mechanic';

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Main ETA Display
          Row(
            children: [
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) => Transform.scale(
                  scale: _pulseAnimation.value,
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.directions_car,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      RealTimeETAService.formatETAText(etaMinutes),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$mechanicName is on the way',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Traffic and Distance Info
          Row(
            children: [
              _buildInfoChip(
                icon: Icons.timeline,
                label: '${distance.toStringAsFixed(1)} km',
                color: Colors.white.withOpacity(0.9),
              ),
              const SizedBox(width: 12),
              _buildInfoChip(
                icon: Icons.traffic,
                label: _getTrafficText(trafficCondition),
                color: RealTimeETAService.getTrafficColor(trafficCondition),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Last Updated Info
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.update,
                size: 14,
                color: Colors.white.withOpacity(0.7),
              ),
              const SizedBox(width: 4),
              Text(
                'Updated ${_getTimeAgo(eta['last_updated'])}',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.location_disabled,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ETA Unavailable',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Mechanic location not available',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _getTrafficText(String condition) {
    switch (condition.toLowerCase()) {
      case 'heavy':
        return 'Heavy traffic';
      case 'moderate':
        return 'Moderate traffic';
      case 'light':
        return 'Light traffic';
      case 'estimated':
        return 'Estimated';
      default:
        return 'Normal traffic';
    }
  }

  String _getTimeAgo(String? timestamp) {
    if (timestamp == null) return 'now';
    
    try {
      final time = DateTime.parse(timestamp);
      final diff = DateTime.now().difference(time);
      
      if (diff.inSeconds < 60) {
        return 'now';
      } else if (diff.inMinutes < 60) {
        return '${diff.inMinutes}m ago';
      } else {
        return '${diff.inHours}h ago';
      }
    } catch (e) {
      return 'now';
    }
  }
}