import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import '../customer/mechanic_accepted_payment_screen.dart';

class CustomerNotificationService {
  static final CustomerNotificationService _instance = CustomerNotificationService._internal();
  static CustomerNotificationService get instance => _instance;
  CustomerNotificationService._internal();

  final _supabase = Supabase.instance.client;
  
  // Multiple stream subscriptions for comprehensive real-time updates
  StreamSubscription? _serviceRequestSubscription;
  StreamSubscription? _invoiceSubscription;
  StreamSubscription? _paymentSubscription;
  StreamSubscription? _workProgressSubscription;
  StreamSubscription? _notificationSubscription;
  
  BuildContext? _currentContext;
  String? _currentCustomerId;
  bool _isListening = false;

  /// Start listening for all types of real-time notifications
  void startListening(BuildContext context) {
    if (_isListening) return;
    
    _currentContext = context;
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    _currentCustomerId = user.id;
    print('🔔 Starting comprehensive customer notification listener for: ${user.id}');
    _isListening = true;

    // Start all notification streams
    _startServiceRequestNotifications();
    _startInvoiceNotifications();
    _startPaymentNotifications();
    _startWorkProgressNotifications();
    _startGeneralNotifications();
  }

  /// Stop all notification listeners
  void stopListening() {
    _serviceRequestSubscription?.cancel();
    _invoiceSubscription?.cancel();
    _paymentSubscription?.cancel();
    _workProgressSubscription?.cancel();
    _notificationSubscription?.cancel();
    
    _serviceRequestSubscription = null;
    _invoiceSubscription = null;
    _paymentSubscription = null;
    _workProgressSubscription = null;
    _notificationSubscription = null;
    
    _currentContext = null;
    _currentCustomerId = null;
    _isListening = false;
    print('🔔 Customer notification listener stopped');
  }

  /// Listen for service request updates (mechanic assignment, acceptance, arrival, etc.)
  void _startServiceRequestNotifications() {
    if (_currentCustomerId == null) return;

    _serviceRequestSubscription?.cancel();
    _serviceRequestSubscription = _supabase
        .from('service_requests')
        .stream(primaryKey: ['id'])
        .listen((data) => _handleServiceRequestUpdate(data));
  }

  /// Listen for invoice notifications
  void _startInvoiceNotifications() {
    if (_currentCustomerId == null) return;

    _invoiceSubscription?.cancel();
    _invoiceSubscription = _supabase
        .from('invoices')
        .stream(primaryKey: ['id'])
        .listen((data) => _handleInvoiceUpdate(data));
  }

  /// Listen for payment confirmations
  void _startPaymentNotifications() {
    if (_currentCustomerId == null) return;

    _paymentSubscription?.cancel();
    _paymentSubscription = _supabase
        .from('payments')
        .stream(primaryKey: ['id'])
        .listen((data) => _handlePaymentUpdate(data));
  }

  /// Listen for work progress updates
  void _startWorkProgressNotifications() {
    if (_currentCustomerId == null) return;

    _workProgressSubscription?.cancel();
    _workProgressSubscription = _supabase
        .from('service_requests')
        .stream(primaryKey: ['id'])
        .listen((data) => _handleWorkProgressUpdate(data));
  }

  /// Listen for general notifications
  void _startGeneralNotifications() {
    if (_currentCustomerId == null) return;

    _notificationSubscription?.cancel();
    _notificationSubscription = _supabase
        .from('notifications')
        .stream(primaryKey: ['id'])
        .listen((data) => _handleGeneralNotification(data));
  }

  /// Handle invoice notifications
  void _handleInvoiceUpdate(List<Map<String, dynamic>> data) {
    if (_currentContext == null || _currentCustomerId == null) return;

    for (final invoice in data) {
      // Filter for current customer's invoices
      if (invoice['customer_id'] != _currentCustomerId) continue;

      final status = invoice['status']?.toString();
      final amount = invoice['total_amount']?.toString() ?? '0';
      final invoiceId = invoice['id']?.toString() ?? '';

      switch (status) {
        case 'sent':
          _showNotification(
            '📄 New Invoice Received',
            'Invoice #$invoiceId for ₱$amount has been sent by your mechanic',
            Colors.blue,
            Icons.receipt_long,
          );
          break;
        case 'paid':
          _showNotification(
            '✅ Payment Confirmed',
            'Your payment of ₱$amount has been confirmed',
            Colors.green,
            Icons.payment,
          );
          break;
        case 'overdue':
          _showNotification(
            '⚠️ Invoice Overdue',
            'Invoice #$invoiceId is now overdue. Please pay ₱$amount',
            Colors.orange,
            Icons.warning,
          );
          break;
      }
    }
  }

  /// Handle payment notifications
  void _handlePaymentUpdate(List<Map<String, dynamic>> data) {
    if (_currentContext == null || _currentCustomerId == null) return;

    for (final payment in data) {
      // Filter for current customer's payments
      if (payment['customer_id'] != _currentCustomerId) continue;

      final status = payment['status']?.toString();
      final amount = payment['amount']?.toString() ?? '0';
      final method = payment['payment_method']?.toString() ?? 'card';

      switch (status) {
        case 'processing':
          _showNotification(
            '💳 Payment Processing',
            'Your payment of ₱$amount is being processed',
            Colors.blue,
            Icons.payment,
          );
          break;
        case 'completed':
          _showNotification(
            '✅ Payment Successful',
            'Payment of ₱$amount completed successfully via $method',
            Colors.green,
            Icons.check_circle,
          );
          break;
        case 'failed':
          _showNotification(
            '❌ Payment Failed',
            'Payment of ₱$amount failed. Please try again',
            Colors.red,
            Icons.error,
          );
          break;
      }
    }
  }

  /// Handle work progress notifications
  void _handleWorkProgressUpdate(List<Map<String, dynamic>> data) {
    if (_currentContext == null || _currentCustomerId == null) return;

    for (final request in data) {
      // Filter for current customer's requests
      if (request['customer_id'] != _currentCustomerId) continue;

      final status = request['status']?.toString();
      final requestId = request['id']?.toString() ?? '';

      switch (status) {
        case 'assigned':
          _showNotification(
            '👤 Mechanic Assigned',
            'A mechanic has been assigned to your request #$requestId',
            Colors.blue,
            Icons.person_add,
          );
          break;
        case 'accepted':
          _showNotification(
            '✅ Request Accepted',
            'Your mechanic has accepted the job and is on the way',
            Colors.green,
            Icons.check_circle,
          );
          break;
        case 'in_progress':
          _showNotification(
            '🔧 Work Started',
            'Your mechanic has started working on your vehicle',
            Colors.orange,
            Icons.build,
          );
          break;
        case 'inspection_started':
          _showNotification(
            '🔍 Inspection Started',
            'Vehicle inspection has begun',
            Colors.blue,
            Icons.search,
          );
          break;
        case 'inspection_completed':
          _showNotification(
            '✅ Inspection Complete',
            'Vehicle inspection completed. Waiting for estimate',
            Colors.green,
            Icons.check_circle_outline,
          );
          break;
        case 'estimate_provided':
          _showNotification(
            '📋 Estimate Ready',
            'Repair estimate has been provided. Please review',
            Colors.purple,
            Icons.description,
          );
          break;
        case 'work_started':
          _showNotification(
            '🔧 Repair Started',
            'Vehicle repair work has begun',
            Colors.orange,
            Icons.build_circle,
          );
          break;
        case 'work_completed':
          _showNotification(
            '🎉 Work Completed',
            'Your vehicle repair has been completed!',
            Colors.green,
            Icons.celebration,
          );
          break;
        case 'completed':
          _showNotification(
            '✅ Service Complete',
            'Your service request has been completed successfully',
            Colors.green,
            Icons.check_circle,
          );
          break;
      }
    }
  }

  /// Handle general notifications
  void _handleGeneralNotification(List<Map<String, dynamic>> data) {
    if (_currentContext == null || _currentCustomerId == null) return;

    for (final notification in data) {
      // Filter for current customer's notifications
      if (notification['user_id'] != _currentCustomerId) continue;
      if (notification['user_type'] != 'customer') continue;

      final title = notification['title']?.toString() ?? 'Notification';
      final message = notification['message']?.toString() ?? '';
      final type = notification['type']?.toString() ?? 'info';

      Color color = Colors.blue;
      IconData icon = Icons.notifications;

      switch (type) {
        case 'success':
          color = Colors.green;
          icon = Icons.check_circle;
          break;
        case 'warning':
          color = Colors.orange;
          icon = Icons.warning;
          break;
        case 'error':
          color = Colors.red;
          icon = Icons.error;
          break;
        case 'info':
        default:
          color = Colors.blue;
          icon = Icons.info;
          break;
      }

      _showNotification(title, message, color, icon);
    }
  }

  /// Show notification to user with snackbar
  void _showNotification(String title, String message, Color color, IconData icon) {
    if (_currentContext == null) return;

    print('🔔 Customer notification: $title - $message');

    ScaffoldMessenger.of(_currentContext!).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                  if (message.isNotEmpty)
                    Text(
                      message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: color,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  /// Handle service request updates
  void _handleServiceRequestUpdate(List<Map<String, dynamic>> data) async {
    if (_currentContext == null) return;

    for (final request in data) {
      final status = request['status'];
      final mechanicId = request['assigned_mechanic_id'];
      
      // Check if mechanic just accepted and payment is required
      if (status == 'awaiting_payment' && mechanicId != null) {
        await _showPaymentRequiredDialog(request);
      }
    }
  }

  /// Show payment required dialog and navigate to payment screen
  Future<void> _showPaymentRequiredDialog(Map<String, dynamic> serviceRequest) async {
    if (_currentContext == null) return;

    try {
      // Get mechanic information
      final mechanicInfo = await _getMechanicInfo(serviceRequest['assigned_mechanic_id']);
      
      // Calculate service amount (you can customize this logic)
      final serviceAmount = _calculateServiceAmount(serviceRequest);

      // Show dialog first
      await showDialog(
        context: _currentContext!,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 28),
              const SizedBox(width: 8),
              const Text('Mechanic Found!'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${mechanicInfo['full_name'] ?? 'A mechanic'} has accepted your service request.',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.payment, color: Colors.orange[700]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Please complete payment to proceed with the service.',
                        style: TextStyle(
                          color: Colors.orange[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                _navigateToPaymentScreen(serviceRequest, mechanicInfo, serviceAmount);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6B35),
                foregroundColor: Colors.white,
              ),
              child: Text('Pay ₱${serviceAmount.toStringAsFixed(2)}'),
            ),
          ],
        ),
      );
    } catch (e) {
      print('❌ Error showing payment dialog: $e');
    }
  }

  /// Navigate to payment screen
  void _navigateToPaymentScreen(
    Map<String, dynamic> serviceRequest,
    Map<String, dynamic> mechanicInfo,
    double serviceAmount,
  ) {
    if (_currentContext == null) return;

    Navigator.of(_currentContext!).push(
      MaterialPageRoute(
        builder: (context) => MechanicAcceptedPaymentScreen(
          serviceRequestId: serviceRequest['id'],
          serviceRequest: serviceRequest,
          mechanicInfo: mechanicInfo,
          serviceAmount: serviceAmount,
        ),
      ),
    );
  }

  /// Get mechanic information
  Future<Map<String, dynamic>> _getMechanicInfo(String mechanicId) async {
    try {
      final response = await _supabase
          .from('users')
          .select('id, full_name, phone_number, profile_image_url')
          .eq('id', mechanicId)
          .single();
      
      return response;
    } catch (e) {
      print('❌ Error getting mechanic info: $e');
      return {
        'id': mechanicId,
        'full_name': 'Mechanic',
        'phone_number': '',
        'profile_image_url': null,
      };
    }
  }

  /// Calculate service amount based on service type
  double _calculateServiceAmount(Map<String, dynamic> serviceRequest) {
    // Base pricing logic - you can customize this
    const basePrices = {
      'tire_change': 500.0,
      'battery_jump': 300.0,
      'fuel_delivery': 200.0,
      'lockout_service': 400.0,
      'towing': 800.0,
      'general_repair': 600.0,
    };

    final serviceType = serviceRequest['service_type']?.toString().toLowerCase() ?? '';
    final estimatedPrice = serviceRequest['estimated_price'];
    
    // Use estimated price if available, otherwise use base pricing
    if (estimatedPrice != null && estimatedPrice > 0) {
      return estimatedPrice.toDouble();
    }
    
    return basePrices[serviceType] ?? 500.0;
  }
}