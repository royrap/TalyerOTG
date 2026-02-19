import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import '../screens/enhanced_service_tracking_screen.dart';

class MechanicWaitingPaymentScreen extends StatefulWidget {
  final String serviceRequestId;
  final Map<String, dynamic> customerInfo;
  final Map<String, dynamic> mechanicInfo;
  final VoidCallback? onPaymentReceived;

  const MechanicWaitingPaymentScreen({
    Key? key,
    required this.serviceRequestId,
    required this.customerInfo,
    required this.mechanicInfo,
    this.onPaymentReceived,
  }) : super(key: key);

  @override
  State<MechanicWaitingPaymentScreen> createState() => _MechanicWaitingPaymentScreenState();
}

class _MechanicWaitingPaymentScreenState extends State<MechanicWaitingPaymentScreen>
    with TickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  StreamSubscription? _paymentSubscription;
  bool _isWaitingForPayment = true;
  String _currentStatus = 'awaiting_payment';
  
  // Animation controllers
  late AnimationController _pulseController;
  late AnimationController _fadeController;
  late AnimationController _rotationController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    
    // Initialize animations
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _rotationController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();
    
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    ));
    
    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _rotationController,
      curve: Curves.linear,
    ));
    
    _fadeController.forward();
    _startPaymentListener();
  }

  @override
  void dispose() {
    _paymentSubscription?.cancel();
    _pulseController.dispose();
    _fadeController.dispose();
    _rotationController.dispose();
    super.dispose();
  }

  void _startPaymentListener() {
    // Listen for payment status changes on the service request
    _paymentSubscription = _supabase
        .from('service_requests')
        .stream(primaryKey: ['id'])
        .eq('id', widget.serviceRequestId)
        .listen((data) {
      if (data.isNotEmpty) {
        final request = data.first;
        final paymentStatus = request['payment_status'];
        final status = request['status'];
        
        print('🔧 Payment status update: $paymentStatus, Status: $status');
        
        if (mounted) {
          setState(() {
            _currentStatus = status;
          });
          
          // If payment is completed, proceed to tracking
          if (paymentStatus == 'completed' || 
              status == 'paid' || 
              status == 'payment_completed' || 
              status == 'ready_to_assign' ||  // 🎯 This is what PayMongo sets after payment
              status == 'in_progress') {
            print('🎯 Payment detected! Status: $status, PaymentStatus: $paymentStatus - proceeding to tracking');
            _proceedToTracking();
          } else {
            print('💤 Still waiting... Status: $status, PaymentStatus: $paymentStatus');
          }
        }
      }
    });
  }

  void _proceedToTracking() {
    if (!mounted) return;
    
    setState(() {
      _isWaitingForPayment = false;
    });
    
    // Call the callback if provided (new flow)
    if (widget.onPaymentReceived != null) {
      widget.onPaymentReceived!();
      return;
    }
    
    // Fallback to old navigation (for backward compatibility)
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => EnhancedServiceTrackingScreen(
          serviceRequestId: widget.serviceRequestId,
          customerInfo: widget.customerInfo,
          mechanicInfo: widget.mechanicInfo,
          isMechanicView: true,
        ),
      ),
    );
  }

  void _cancelJob() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Service'),
        content: const Text(
          'Are you sure you want to cancel this service? The customer will be notified.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('No, Keep Waiting'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _cancelService();
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelService() async {
    try {
      // Update service request status to cancelled
      await _supabase
          .from('service_requests')
          .update({
            'status': 'cancelled',
            'assigned_mechanic_id': null,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', widget.serviceRequestId);

      // Create notification for customer
      await _supabase.from('notifications').insert({
        'user_id': widget.customerInfo['customer_id'],
        'title': 'Service Cancelled',
        'body': 'Your mechanic had to cancel the service. You can request another mechanic.',
        'type': 'service_cancelled',
        'data': {
          'service_request_id': widget.serviceRequestId,
        },
      });

      if (mounted) {
        Navigator.of(context).pop(); // Return to dashboard
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Service cancelled. Customer has been notified.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      print('❌ Error cancelling service: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error cancelling service: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: const Color(0xFFFF6B35),
        foregroundColor: Colors.white,
        title: const Text('Waiting for Payment'),
        elevation: 0,
        automaticallyImplyLeading: false, // Prevent going back
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                height: MediaQuery.of(context).size.height - 200, // Account for AppBar and padding
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Main waiting animation
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _pulseAnimation.value,
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFFFF6B35).withOpacity(0.1),
                              border: Border.all(
                                color: const Color(0xFFFF6B35),
                                width: 3,
                              ),
                            ),
                            child: const Icon(
                              Icons.payment,
                              size: 60,
                              color: Color(0xFFFF6B35),
                            ),
                          ),
                        );
                      },
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Title
                    const Text(
                      'Waiting for Customer Payment',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFFF6B35),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Description
                    Text(
                      'The customer needs to complete payment before you can proceed to their location.',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Loading indicator
                    AnimatedBuilder(
                      animation: _rotationAnimation,
                      builder: (context, child) {
                        return Transform.rotate(
                          angle: _rotationAnimation.value * 2 * 3.14159,
                          child: const Icon(
                            Icons.hourglass_empty,
                            size: 40,
                            color: Color(0xFFFF6B35),
                          ),
                        );
                      },
                    ),
                    
                    const SizedBox(height: 16),
                    
                    Text(
                      'Please wait...',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[500],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Customer info card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Customer Information',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.person, color: Color(0xFFFF6B35)),
                          const SizedBox(width: 8),
                          Text(
                            widget.customerInfo['customer_name'] ?? 'Customer',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.phone, color: Color(0xFFFF6B35)),
                          const SizedBox(width: 8),
                          Text(
                            widget.customerInfo['phone_number'] ?? 'N/A',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.location_on, color: Color(0xFFFF6B35)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              widget.customerInfo['pickup_address'] ?? 'Location',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.build, color: Color(0xFFFF6B35)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              widget.customerInfo['service_type'] ?? 'Service Request',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Info card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info, color: Colors.blue[700]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'You will automatically proceed to the customer location once payment is confirmed.',
                        style: TextStyle(color: Colors.blue[700]),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Cancel button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _cancelJob,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Cancel Service',
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
      ),
    );
  }
}