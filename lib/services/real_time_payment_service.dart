import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';
import 'talyer_owner_service.dart';

class RealTimePaymentService {
  static final RealTimePaymentService _instance = RealTimePaymentService._internal();
  static RealTimePaymentService get instance => _instance;
  RealTimePaymentService._internal();

  final _supabase = Supabase.instance.client;
  
  // Real-time payment status streams
  StreamSubscription? _paymentStatusSubscription;
  StreamSubscription? _invoiceStatusSubscription;
  
  // Controllers for real-time updates
  final _paymentStatusController = StreamController<Map<String, dynamic>>.broadcast();
  final _invoiceStatusController = StreamController<Map<String, dynamic>>.broadcast();
  
  // Getters for streams
  Stream<Map<String, dynamic>> get paymentStatusStream => _paymentStatusController.stream;
  Stream<Map<String, dynamic>> get invoiceStatusStream => _invoiceStatusController.stream;

  // Initialize real-time listeners
  Future<void> initialize() async {
    try {
      final userId = AuthService.instance.userId;
      if (userId == null) {
        print('❌ No authenticated user for real-time payment service');
        return;
      }

      print('🔄 Initializing real-time payment service for user: $userId');

      // Listen to payment status changes
      _paymentStatusSubscription = _supabase
          .from('payments')
          .stream(primaryKey: ['id'])
          .eq('customer_id', userId)
          .listen((List<Map<String, dynamic>> data) {
            for (final payment in data) {
              _paymentStatusController.add({
                'type': 'payment_update',
                'data': payment,
                'timestamp': DateTime.now().toIso8601String(),
              });
              
              // Only log important status changes to reduce spam
              final status = payment['status'];
              if (status == 'completed' || status == 'failed' || status == 'cancelled') {
                print('💳 Important payment update: ${payment['id']} - Status: $status');
              }
            }
          });

      // Listen to invoice status changes
      _invoiceStatusSubscription = _supabase
          .from('invoices')
          .stream(primaryKey: ['id'])
          .eq('customer_id', userId)
          .listen((List<Map<String, dynamic>> data) {
            for (final invoice in data) {
              _invoiceStatusController.add({
                'type': 'invoice_update',
                'data': invoice,
                'timestamp': DateTime.now().toIso8601String(),
              });
              
              print('🧾 Real-time invoice update: ${invoice['id']} - Status: ${invoice['status']}');
            }
          });

      print('✅ Real-time payment service initialized successfully');
    } catch (e) {
      print('❌ Error initializing real-time payment service: $e');
    }
  }

  // Process payment with real-time updates
  Future<Map<String, dynamic>?> processPayment({
    required String invoiceId,
    required String paymentMethod,
    required Map<String, dynamic> paymentDetails,
  }) async {
    try {
      final userId = AuthService.instance.userId;
      if (userId == null) throw Exception('No authenticated user');

      print('💳 Processing real-time payment for invoice: $invoiceId');

      // Get invoice details
      final invoice = await _supabase
          .from('invoices')
          .select('*')
          .eq('id', invoiceId)
          .eq('customer_id', userId)
          .single();

      if (invoice['status'] != 'accepted') {
        throw Exception('Invoice must be accepted before payment');
      }

      // Create payment record with real-time tracking
      final paymentData = {
        'id': _generatePaymentId(),
        'request_id': invoice['request_id'],
        'customer_id': userId,
        'provider_id': invoice['provider_id'],
        'invoice_id': invoiceId,
        'amount': invoice['total_amount'],
        'platform_fee': invoice['platform_fee'] ?? 0.00,
        'provider_amount': invoice['provider_net_amount'],
        'payment_method': paymentMethod,
        'payment_gateway': _getPaymentGateway(paymentMethod),
        'transaction_id': _generateTransactionId(),
        'status': 'processing', // Start with processing status
        'payment_details': paymentDetails,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Insert payment record
      final payment = await _supabase
          .from('payments')
          .insert(paymentData)
          .select()
          .single();

      // Simulate payment processing with status updates
      await _simulatePaymentProcessing(payment['id'], invoiceId, paymentMethod);

      return payment;
    } catch (e) {
      print('❌ Error processing payment: $e');
      return null;
    }
  }

  // Simulate payment processing with real-time status updates
  Future<void> _simulatePaymentProcessing(String paymentId, String invoiceId, String paymentMethod) async {
    try {
      // Step 1: Processing
      await _updatePaymentStatus(paymentId, 'processing', 'Payment being processed...');
      await Future.delayed(const Duration(seconds: 2));

      // Step 2: Validating
      await _updatePaymentStatus(paymentId, 'validating', 'Validating payment details...');
      await Future.delayed(const Duration(seconds: 1));

      // Step 3: Confirming
      await _updatePaymentStatus(paymentId, 'confirming', 'Confirming transaction...');
      await Future.delayed(const Duration(seconds: 2));

      // Step 4: Completed and held in escrow
      await _updatePaymentStatus(paymentId, 'in_escrow', 'Payment held in escrow until service completion');
      
      // Update invoice status to paid
      await _supabase
          .from('invoices')
          .update({
            'status': 'paid',
            'payment_id': paymentId,
            'paid_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', invoiceId);

      // Update service request payment status
      final invoice = await _supabase
          .from('invoices')
          .select('request_id')
          .eq('id', invoiceId)
          .single();

      await _supabase
          .from('service_requests')
          .update({
            'status': 'ready_to_assign', // 🎯 CRITICAL: Should be ready for mechanic assignment
            'payment_status': 'completed',
            'payment_method': paymentMethod,
            'final_price': await _getInvoiceAmount(invoiceId),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', invoice['request_id']);

      // Notify mechanic that payment is in escrow
      await _notifyMechanicPaymentReceived(paymentId);

      print('✅ Payment processing completed successfully');
    } catch (e) {
      print('❌ Error in payment processing: $e');
      await _updatePaymentStatus(paymentId, 'failed', 'Payment processing failed: $e');
    }
  }

  // Update payment status with real-time notification
  Future<void> _updatePaymentStatus(String paymentId, String status, String message) async {
    try {
      await _supabase
          .from('payments')
          .update({
            'status': status,
            'status_message': message,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', paymentId);

      print('💳 Payment status updated: $paymentId - $status - $message');
    } catch (e) {
      print('❌ Error updating payment status: $e');
    }
  }

  // Get current payment status for an invoice
  Future<Map<String, dynamic>?> getPaymentStatus(String invoiceId) async {
    try {
      final payment = await _supabase
          .from('payments')
          .select('*')
          .eq('invoice_id', invoiceId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      return payment;
    } catch (e) {
      print('❌ Error getting payment status: $e');
      return null;
    }
  }

  // Release payment to mechanic after service completion
  Future<bool> releasePaymentToMechanic(String paymentId, String qrCode) async {
    try {
      print('💸 Releasing payment to mechanic: $paymentId');

      // Verify QR code
      final codeResponse = await _supabase
          .from('job_completion_codes')
          .select('*')
          .eq('completion_code', qrCode)
          .eq('is_used', false)
          .maybeSingle();

      if (codeResponse == null) {
        throw Exception('Invalid or already used QR code');
      }

      // Check if QR code is expired (24 hours)
      final createdAt = DateTime.parse(codeResponse['created_at']);
      if (DateTime.now().difference(createdAt).inHours > 24) {
        throw Exception('QR code has expired');
      }

      // Mark QR code as used
      await _supabase
          .from('job_completion_codes')
          .update({
            'is_used': true,
            'used_at': DateTime.now().toIso8601String(),
          })
          .eq('completion_code', qrCode);

      // Update payment status to released
      await _supabase
          .from('payments')
          .update({
            'status': 'released_to_provider',
            'released_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', paymentId);

      // Update service request status to completed
      final serviceRequestUpdate = await _supabase
          .from('service_requests')
          .update({
            'status': 'completed',
            'completed_at': DateTime.now().toIso8601String(),
          })
          .eq('id', codeResponse['service_request_id'])
          .select('provider_id')
          .single();

      // Update invoice status to completed
      await _supabase
          .from('invoices')
          .update({
            'status': 'completed',
            'completed_at': DateTime.now().toIso8601String(),
          })
          .eq('payment_id', paymentId);

      // Update mechanic availability after job completion
      if (serviceRequestUpdate['provider_id'] != null) {
        try {
          await TalyerOwnerService.instance.updateMechanicStatusOnJobCompletion(
            serviceRequestUpdate['provider_id'], 
            'completed'
          );
        } catch (mechanicStatusError) {
          print('⚠️ Warning: Could not update mechanic availability: $mechanicStatusError');
          // Don't fail the payment release if mechanic status update fails
        }
      }

      print('✅ Payment released to mechanic successfully');
      return true;
    } catch (e) {
      print('❌ Error releasing payment: $e');
      return false;
    }
  }

  // Get payment history with real-time updates
  Stream<List<Map<String, dynamic>>> getPaymentHistoryStream() async* {
    try {
      final userId = AuthService.instance.userId;
      if (userId == null) throw Exception('No authenticated user');

      // Yield initial data
      final payments = await _supabase
          .from('payments')
          .select('''
            *,
            invoices(*),
            service_requests(
              id,
              service_type,
              problem_description,
              pickup_address
            ),
            service_providers(
              id,
              company_name,
              user_profiles(first_name, last_name, phone_number)
            )
          ''')
          .eq('customer_id', userId)
          .order('created_at', ascending: false);

      yield payments;

      // Listen for real-time updates
      await for (final _ in _supabase
          .from('payments')
          .stream(primaryKey: ['id'])
          .eq('customer_id', userId)) {
        
        final updatedPayments = await _supabase
            .from('payments')
            .select('''
              *,
              invoices(*),
              service_requests(
                id,
                service_type,
                problem_description,
                pickup_address
              ),
              service_providers(
                id,
                company_name,
                user_profiles(first_name, last_name, phone_number)
              )
            ''')
            .eq('customer_id', userId)
            .order('created_at', ascending: false);

        yield updatedPayments;
      }
    } catch (e) {
      print('❌ Error in payment history stream: $e');
      yield [];
    }
  }

  // Helper methods
  String _generatePaymentId() {
    return 'PAY_${DateTime.now().millisecondsSinceEpoch}_${(1000 + (9000 * (DateTime.now().millisecondsSinceEpoch % 1000) / 1000)).round()}';
  }

  String _generateTransactionId() {
    return 'TXN_${DateTime.now().millisecondsSinceEpoch}_${(10000 + (90000 * (DateTime.now().millisecondsSinceEpoch % 1000) / 1000)).round()}';
  }

  String _getPaymentGateway(String paymentMethod) {
    switch (paymentMethod.toLowerCase()) {
      case 'credit card':
      case 'debit card':
      case 'card':
        return 'paymongo';
      case 'gcash':
        return 'paymongo';
      case 'paymaya':
        return 'paymongo';
      case 'cash':
        return 'cash';
      default:
        return 'paymongo';
    }
  }

  Future<double> _getInvoiceAmount(String invoiceId) async {
    try {
      final invoice = await _supabase
          .from('invoices')
          .select('total_amount')
          .eq('id', invoiceId)
          .single();
      
      return (invoice['total_amount'] as num?)?.toDouble() ?? 0.0;
    } catch (e) {
      print('❌ Error getting invoice amount: $e');
      return 0.0;
    }
  }

  Future<void> _notifyMechanicPaymentReceived(String paymentId) async {
    try {
      // Get payment details
      final payment = await _supabase
          .from('payments')
          .select('''
            *,
            service_providers(
              user_id,
              company_name
            ),
            invoices(invoice_number)
          ''')
          .eq('id', paymentId)
          .single();

      // Send notification to mechanic
      await _supabase.from('notifications').insert({
        'user_id': payment['service_providers']['user_id'],
        'title': 'Payment Received',
        'body': 'Payment of ₱${payment['amount']} for invoice ${payment['invoices']['invoice_number']} is held in escrow. Complete the service to release payment.',
        'type': 'payment_escrow',
        'data': {
          'payment_id': paymentId,
          'amount': payment['amount'],
          'invoice_number': payment['invoices']['invoice_number'],
        },
        'created_at': DateTime.now().toIso8601String(),
        'is_read': false,
      });

      print('✅ Mechanic notification sent for payment: $paymentId');
    } catch (e) {
      print('❌ Error sending mechanic notification: $e');
    }
  }

  // Cleanup method
  void dispose() {
    _paymentStatusSubscription?.cancel();
    _invoiceStatusSubscription?.cancel();
    _paymentStatusController.close();
    _invoiceStatusController.close();
  }
}










