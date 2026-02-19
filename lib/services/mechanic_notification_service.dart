import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

class MechanicNotificationService {
  static final MechanicNotificationService _instance = MechanicNotificationService._internal();
  static MechanicNotificationService get instance => _instance;
  MechanicNotificationService._internal();

  final _supabase = Supabase.instance.client;
  StreamSubscription? _notificationSubscription;
  StreamSubscription? _invoiceSubscription;
  StreamSubscription? _paymentSubscription;
  BuildContext? _currentContext;

  /// Start listening for real-time notifications for mechanics
  void startListening(BuildContext context) {
    _currentContext = context;
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    print('🔔 Starting mechanic notification listener for: ${user.id}');

    _startInvoiceNotifications();
    _startPaymentNotifications();
    _startGeneralNotifications();
  }

  /// Stop all notification listeners
  void stopListening() {
    _notificationSubscription?.cancel();
    _invoiceSubscription?.cancel();
    _paymentSubscription?.cancel();
    _notificationSubscription = null;
    _invoiceSubscription = null;
    _paymentSubscription = null;
    _currentContext = null;
    print('🔔 Mechanic notification listeners stopped');
  }

  /// Listen for invoice-related notifications
  void _startInvoiceNotifications() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      // Get service provider ID
      final serviceProviders = await _supabase
          .from('service_providers')
          .select('id')
          .eq('user_id', user.id)
          .limit(1);

      if (serviceProviders.isEmpty) return;
      final providerId = serviceProviders.first['id'];

      // Listen for invoice status changes
      _invoiceSubscription = _supabase
          .from('invoices')
          .stream(primaryKey: ['id'])
          .eq('provider_id', providerId)
          .listen((data) {
            if (_currentContext != null && data.isNotEmpty) {
              for (final invoice in data) {
                _handleInvoiceUpdate(invoice);
              }
            }
          });

      print('📧 Invoice notifications started for provider: $providerId');
    } catch (e) {
      print('❌ Error starting invoice notifications: $e');
    }
  }

  /// Listen for payment-related notifications
  void _startPaymentNotifications() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      // Get service provider ID
      final serviceProviders = await _supabase
          .from('service_providers')
          .select('id')
          .eq('user_id', user.id)
          .limit(1);

      if (serviceProviders.isEmpty) return;
      final providerId = serviceProviders.first['id'];

      // Listen for payment status changes
      _paymentSubscription = _supabase
          .from('payments')
          .stream(primaryKey: ['id'])
          .eq('provider_id', providerId)
          .listen((data) {
            if (_currentContext != null && data.isNotEmpty) {
              for (final payment in data) {
                _handlePaymentUpdate(payment);
              }
            }
          });

      print('💳 Payment notifications started for provider: $providerId');
    } catch (e) {
      print('❌ Error starting payment notifications: $e');
    }
  }

  /// Listen for general notifications
  void _startGeneralNotifications() {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    _notificationSubscription = _supabase
        .from('notifications')
        .stream(primaryKey: ['id'])
        .listen((data) {
          if (_currentContext != null && data.isNotEmpty) {
            for (final notification in data) {
              // Only show unread notifications for the current user
              final userId = notification['user_id'];
              final isRead = notification['read'] ?? false;
              final currentUserId = _supabase.auth.currentUser?.id;
              
              if (userId == currentUserId && !isRead) {
                _handleGeneralNotification(notification);
              }
            }
          }
        });

    print('🔔 General notifications started for user: ${user.id}');
  }

  /// Handle invoice status updates
  void _handleInvoiceUpdate(Map<String, dynamic> invoice) {
    final status = invoice['status']?.toString().toLowerCase();
    final amount = invoice['total_amount'];
    final invoiceNumber = invoice['invoice_number'];

    switch (status) {
      case 'accepted':
        _showSnackBarNotification(
          '✅ Invoice Accepted!',
          'Customer accepted invoice $invoiceNumber for ₱${amount?.toStringAsFixed(2)}',
          Colors.green,
          Icons.check_circle,
        );
        break;
      case 'paid':
      case 'invoice_paid':
        _showSnackBarNotification(
          '💰 Payment Received!',
          'Customer paid invoice $invoiceNumber for ₱${amount?.toStringAsFixed(2)}',
          Colors.blue,
          Icons.payment,
        );
        break;
      case 'disputed':
        _showSnackBarNotification(
          '⚠️ Invoice Disputed',
          'Customer disputed invoice $invoiceNumber',
          Colors.orange,
          Icons.warning,
        );
        break;
    }
  }

  /// Handle payment status updates
  void _handlePaymentUpdate(Map<String, dynamic> payment) {
    final status = payment['status']?.toString().toLowerCase();
    final amount = payment['amount'];

    switch (status) {
      case 'completed':
      case 'released_to_provider':
        _showSnackBarNotification(
          '💸 Payment Released!',
          'Payment of ₱${amount?.toStringAsFixed(2)} has been released to you',
          Colors.green,
          Icons.account_balance_wallet,
        );
        break;
      case 'in_escrow':
        _showSnackBarNotification(
          '🏦 Payment Secured',
          'Payment of ₱${amount?.toStringAsFixed(2)} is held in escrow',
          Colors.blue,
          Icons.security,
        );
        break;
      case 'failed':
        _showSnackBarNotification(
          '❌ Payment Failed',
          'Payment processing failed. Please contact support.',
          Colors.red,
          Icons.error,
        );
        break;
    }
  }

  /// Handle general notifications
  void _handleGeneralNotification(Map<String, dynamic> notification) {
    final title = notification['title'] ?? 'Notification';
    final body = notification['body'] ?? '';
    final type = notification['type']?.toString().toLowerCase();

    IconData icon = Icons.notifications;
    Color color = Colors.blue;

    switch (type) {
      case 'payment':
      case 'payment_release':
      case 'invoice_paid':
        icon = Icons.payment;
        color = Colors.green;
        break;
      case 'invoice':
        icon = Icons.receipt;
        color = Colors.blue;
        break;
      case 'job':
      case 'service':
        icon = Icons.build;
        color = Colors.orange;
        break;
      case 'warning':
        icon = Icons.warning;
        color = Colors.orange;
        break;
      case 'error':
        icon = Icons.error;
        color = Colors.red;
        break;
    }

    _showSnackBarNotification(title, body, color, icon);
  }

  /// Show snack bar notification
  void _showSnackBarNotification(String title, String message, Color color, IconData icon) {
    if (_currentContext == null) return;

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
                      fontSize: 14,
                      color: Colors.white,
                    ),
                  ),
                  if (message.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      message,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(_currentContext!).hideCurrentSnackBar();
          },
        ),
      ),
    );

    print('📱 Mechanic notification: $title - $message');
  }

  /// Force refresh notifications (for debugging)
  Future<void> refreshNotifications() async {
    print('🔄 Refreshing mechanic notifications...');
    stopListening();
    if (_currentContext != null) {
      startListening(_currentContext!);
    }
  }
}