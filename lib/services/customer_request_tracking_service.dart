import 'dart:async';
import 'package:flutter/material.dart';
import '../screens/enhanced_service_tracking_screen.dart';
import '../services/supabase_service.dart';

class CustomerRequestTrackingService {
  static final CustomerRequestTrackingService _instance = CustomerRequestTrackingService._internal();
  static CustomerRequestTrackingService get instance => _instance;
  CustomerRequestTrackingService._internal();

  StreamSubscription? _requestStatusSubscription;
  BuildContext? _context;

  /// Start monitoring service request status for automatic tracking
  void startMonitoring(BuildContext context, String serviceRequestId) {
    _context = context;
    
    _requestStatusSubscription?.cancel();
    _requestStatusSubscription = SupabaseService.client
        .from('service_requests')
        .stream(primaryKey: ['id'])
        .eq('id', serviceRequestId)
        .listen((data) {
          if (data.isNotEmpty) {
            _handleStatusUpdate(data.first);
          }
        });
    
    print('🎯 Started monitoring service request: $serviceRequestId');
  }

  /// Stop monitoring service request
  void stopMonitoring() {
    _requestStatusSubscription?.cancel();
    _requestStatusSubscription = null;
    _context = null;
    print('🛑 Stopped monitoring service request');
  }

  /// Handle service request status updates
  void _handleStatusUpdate(Map<String, dynamic> requestData) async {
    final status = requestData['status'];
    
    // When request is accepted, automatically show tracking screen
    if (status == 'accepted' && _context != null) {
      final mechanicId = requestData['assigned_mechanic_id'];
      
      if (mechanicId != null) {
        // Fetch mechanic information
        final mechanicInfo = await _fetchMechanicInfo(mechanicId);
        
        // Navigate to tracking screen
        _showTrackingScreen(requestData, mechanicInfo);
      }
    }
  }

  /// Fetch mechanic information from database
  Future<Map<String, dynamic>> _fetchMechanicInfo(String mechanicId) async {
    try {
      final mechanicProfile = await SupabaseService.client
          .from('user_profiles')
          .select('*')
          .eq('id', mechanicId)
          .single();
      
      return {
        'id': mechanicId,
        'full_name': '${mechanicProfile['first_name'] ?? ''} ${mechanicProfile['last_name'] ?? ''}'.trim(),
        'phone_number': mechanicProfile['phone_number'] ?? '',
        'profile_image_url': mechanicProfile['profile_image_url'],
      };
    } catch (e) {
      print('❌ Error fetching mechanic info: $e');
      return {
        'id': mechanicId,
        'full_name': 'Mechanic',
        'phone_number': '',
        'profile_image_url': null,
      };
    }
  }

  /// Show tracking screen to customer
  void _showTrackingScreen(Map<String, dynamic> requestData, Map<String, dynamic> mechanicInfo) {
    if (_context == null) return;

    // Show notification first
    ScaffoldMessenger.of(_context!).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                '✅ Request accepted! ${mechanicInfo['full_name']} is coming to help you.',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 4),
        action: SnackBarAction(
          label: 'TRACK',
          textColor: Colors.white,
          onPressed: () => _navigateToTracking(requestData, mechanicInfo),
        ),
      ),
    );

    // Auto-navigate to tracking after 2 seconds
    Future.delayed(Duration(seconds: 2), () {
      _navigateToTracking(requestData, mechanicInfo);
    });
  }

  /// Navigate to enhanced tracking screen
  void _navigateToTracking(Map<String, dynamic> requestData, Map<String, dynamic> mechanicInfo) {
    if (_context == null) return;

    Navigator.push(
      _context!,
      MaterialPageRoute(
        builder: (context) => EnhancedServiceTrackingScreen(
          serviceRequestId: requestData['id'],
          customerInfo: {
            'customer_name': 'You', // Customer's own request
            'phone_number': '', // Not needed for customer view
            'profile_image_url': null,
            'pickup_latitude': requestData['pickup_latitude'],
            'pickup_longitude': requestData['pickup_longitude'],
            'pickup_address': requestData['pickup_address'],
            'service_type': requestData['service_type'] ?? requestData['title'],
            'description': requestData['description'],
          },
          mechanicInfo: mechanicInfo,
          isMechanicView: false, // This is customer view
        ),
      ),
    );
  }
}

/// Widget to integrate into customer service request screens
class CustomerTrackingWidget extends StatefulWidget {
  final String serviceRequestId;
  final VoidCallback? onRequestAccepted;

  const CustomerTrackingWidget({
    super.key,
    required this.serviceRequestId,
    this.onRequestAccepted,
  });

  @override
  State<CustomerTrackingWidget> createState() => _CustomerTrackingWidgetState();
}

class _CustomerTrackingWidgetState extends State<CustomerTrackingWidget> {
  String _requestStatus = 'pending';
  bool _isAccepted = false;

  @override
  void initState() {
    super.initState();
    CustomerRequestTrackingService.instance.startMonitoring(context, widget.serviceRequestId);
    _monitorRequestStatus();
  }

  @override
  void dispose() {
    CustomerRequestTrackingService.instance.stopMonitoring();
    super.dispose();
  }

  void _monitorRequestStatus() {
    SupabaseService.client
        .from('service_requests')
        .stream(primaryKey: ['id'])
        .eq('id', widget.serviceRequestId)
        .listen((data) {
          if (data.isNotEmpty && mounted) {
            setState(() {
              _requestStatus = data.first['status'] ?? 'pending';
              _isAccepted = _requestStatus == 'accepted';
            });
            
            if (_isAccepted && widget.onRequestAccepted != null) {
              widget.onRequestAccepted!();
            }
          }
        });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAccepted) {
      // Show waiting for mechanic UI
      return Container(
        padding: EdgeInsets.all(16),
        margin: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange.withAlpha(26),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.withAlpha(77)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Finding Available Mechanics',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Please wait while we connect you with a nearby mechanic...',
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
          ],
        ),
      );
    }

    // Show accepted status
    return Container(
      padding: EdgeInsets.all(16),
      margin: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withAlpha(26),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withAlpha(77)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.check_circle,
            color: Colors.green,
            size: 24,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Request Accepted! Your mechanic is on the way.',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.green[700],
              ),
            ),
          ),
        ],
      ),
    );
  }
}










