import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/invoice.dart';
import 'real_time_payment_service.dart';
import 'paymongo_service.dart';
import 'customer_history_service.dart';

class CustomerInvoiceService {
  static final CustomerInvoiceService _instance = CustomerInvoiceService._internal();
  static CustomerInvoiceService get instance => _instance;
  CustomerInvoiceService._internal();

  final _supabase = Supabase.instance.client;

  // Initialize real-time services
  Future<void> initialize() async {
    await RealTimePaymentService.instance.initialize();
  }

  // Get all invoices for the current customer
  Future<List<Invoice>> getCustomerInvoices() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('No authenticated user');

      print('🧾 CustomerInvoiceService.getCustomerInvoices() - Loading invoices for customer: ${user.id}');

      // Simplified query - removed nested !inner joins that were causing issues
      final result = await _supabase
          .from('invoices')
          .select('*')
          .eq('customer_id', user.id)
          .order('issued_at', ascending: false);

      print('🧾 Found ${result.length} invoices for customer');
      
      return result.map((data) => Invoice.fromJson(data)).toList();
    } catch (e) {
      print('❌ Error getting customer invoices: $e');
      return [];
    }
  }

  // Get specific invoice by ID
  Future<Invoice?> getInvoiceById(String invoiceId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('No authenticated user');

      print('🧾 CustomerInvoiceService.getInvoiceById() - Loading invoice: $invoiceId');

      // Simplified query - removed nested !inner joins
      final result = await _supabase
          .from('invoices')
          .select('*')
          .eq('id', invoiceId)
          .eq('customer_id', user.id)
          .single();

      return Invoice.fromJson(result);
    } catch (e) {
      print('❌ Error getting invoice by ID: $e');
      return null;
    }
  }

  // Accept invoice (customer agrees to the charges)
  Future<bool> acceptInvoice(String invoiceId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('No authenticated user');

      print('🧾 CustomerInvoiceService.acceptInvoice() - Accepting invoice: $invoiceId');

      // Update invoice status to accepted
      await _supabase
          .from('invoices')
          .update({
            'status': 'accepted',
            'accepted_at': DateTime.now().toIso8601String(),
          })
          .eq('id', invoiceId)
          .eq('customer_id', user.id);

      // Send notification to mechanic
      await _sendInvoiceAcceptanceNotification(invoiceId);

      print('🧾 Invoice accepted successfully');
      return true;
    } catch (e) {
      print('❌ Error accepting invoice: $e');
      return false;
    }
  }

  // Process payment with real-time updates
  Future<Map<String, dynamic>?> processPaymentRealTime({
    required String invoiceId,
    required String paymentMethod,
    required Map<String, dynamic> paymentDetails,
  }) async {
    try {
      return await RealTimePaymentService.instance.processPayment(
        invoiceId: invoiceId,
        paymentMethod: paymentMethod,
        paymentDetails: paymentDetails,
      );
    } catch (e) {
      print('❌ Error processing real-time payment: $e');
      return null;
    }
  }

  // Create PayMongo payment for invoice
  Future<Map<String, dynamic>?> createPayMongoPayment({
    required String invoiceId,
    required String paymentMethod, // 'card', 'gcash', 'paymaya'
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('No authenticated user');

      final invoice = await getInvoiceById(invoiceId);
      if (invoice == null) throw Exception('Invoice not found');

      print('💳 Creating PayMongo payment for invoice: $invoiceId');

      final paymentIntent = await PayMongoService.instance.createPaymentIntent(
        invoiceId: invoiceId,
        amount: invoice.totalAmount,
        description: 'RoadAid Service Payment - ${invoice.description}',
        metadata: {
          'customer_id': user.id,
          'payment_method': paymentMethod,
          'app_source': 'RoadAid_mobile',
        },
      );

      if (paymentIntent != null) {
        // Update payment record with PayMongo details
        await _supabase.from('payments').update({
          'payment_gateway': 'paymongo',
          'transaction_id': paymentIntent['id'],
          'payment_details': paymentIntent,
          'status': 'processing',
        }).eq('invoice_id', invoiceId);

        print('✅ PayMongo payment intent created: ${paymentIntent['id']}');
        return paymentIntent;
      }

      return null;
    } catch (e) {
      print('❌ Error creating PayMongo payment: $e');
      throw Exception('Failed to create payment: ${e.toString()}');
    }
  }

  // Create PayMongo QR payment
  Future<String?> createPayMongoQRPayment(String invoiceId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('No authenticated user');

      final invoice = await getInvoiceById(invoiceId);
      if (invoice == null) throw Exception('Invoice not found');

      print('📱 Creating PayMongo QR payment for invoice: $invoiceId');

      final qrUrl = await PayMongoService.instance.createQRCodeForPayment(
        invoiceId: invoiceId,
        amount: invoice.totalAmount,
        description: 'RoadAid Service Payment - ${invoice.description}',
      );

      if (qrUrl != null) {
        // Update payment record
        await _supabase.from('payments').update({
          'payment_gateway': 'paymongo',
          'payment_method': 'qr_code',
          'payment_details': {'qr_url': qrUrl},
          'status': 'awaiting_payment',
        }).eq('invoice_id', invoiceId);

        print('✅ PayMongo QR payment created: $qrUrl');
        return qrUrl;
      }

      return null;
    } catch (e) {
      print('❌ Error creating PayMongo QR payment: $e');
      throw Exception('Failed to create QR payment: ${e.toString()}');
    }
  }

  // Check PayMongo payment status
  Future<Map<String, dynamic>?> checkPayMongoPaymentStatus(String invoiceId) async {
    try {
      final payment = await _supabase
          .from('payments')
          .select('transaction_id, payment_details, status')
          .eq('invoice_id', invoiceId)
          .eq('payment_gateway', 'paymongo')
          .maybeSingle();

      if (payment == null) return null;

      final paymentIntentId = payment['transaction_id'];
      if (paymentIntentId == null) return payment;

      // Get latest status from PayMongo
      final paymentIntent = await PayMongoService.instance.getPaymentIntentStatus(paymentIntentId);
      
      if (paymentIntent != null) {
        final status = paymentIntent['attributes']['status'];
        
        // Update local status if different
        if (status != payment['status']) {
          await _supabase.from('payments').update({
            'status': status,
            'payment_details': paymentIntent,
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('invoice_id', invoiceId);
        }

        return {
          'status': status,
          'payment_intent': paymentIntent,
          'local_payment': payment,
        };
      }

      return payment;
    } catch (e) {
      print('❌ Error checking PayMongo payment status: $e');
      return null;
    }
  }

  // Get payment history with real-time updates
  Stream<List<Map<String, dynamic>>> getPaymentHistoryStream() {
    return RealTimePaymentService.instance.getPaymentHistoryStream();
  }

  // Process payment for invoice
  Future<bool> payInvoice(String invoiceId, Map<String, dynamic> paymentData) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('No authenticated user');

      print('🧾 CustomerInvoiceService.payInvoice() - Processing payment for invoice: $invoiceId');

      // Get invoice details
      final invoice = await getInvoiceById(invoiceId);
      if (invoice == null) throw Exception('Invoice not found');

      // Simulate payment processing (integrate with actual payment gateway)
      await _processPayment(invoice, paymentData);

      // Update invoice status to paid
      await _supabase
          .from('invoices')
          .update({
            'status': 'paid',
            'paid_at': DateTime.now().toIso8601String(),
          })
          .eq('id', invoiceId)
          .eq('customer_id', user.id);

      // Update service request status
      await _supabase
          .from('service_requests')
          .update({'status': 'invoice_paid'})
          .eq('id', invoice.requestId);

      // Add job to customer history
      await CustomerHistoryService.instance.addJobToHistory(
        serviceRequestId: invoice.requestId,
        jobTitle: 'Service Payment Completed',
        jobDescription: 'Service payment completed successfully',
        jobStatus: 'invoice_paid',
        mechanicId: invoice.providerId, // Assuming provider is mechanic
        totalAmount: invoice.totalAmount,
      );

      // Send payment confirmation to mechanic
      await _sendPaymentConfirmationNotification(invoiceId, invoice.requestId);

      print('🧾 Invoice payment processed successfully');
      return true;
    } catch (e) {
      print('❌ Error processing invoice payment: $e');
      return false;
    }
  }

  // Dispute/reject invoice
  Future<bool> disputeInvoice(String invoiceId, String reason) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('No authenticated user');

      print('🧾 CustomerInvoiceService.disputeInvoice() - Disputing invoice: $invoiceId');

      // Update invoice with dispute status and reason
      await _supabase
          .from('invoices')
          .update({
            'status': 'disputed',
            'notes': reason,
          })
          .eq('id', invoiceId)
          .eq('customer_id', user.id);

      // Send dispute notification to mechanic
      await _sendInvoiceDisputeNotification(invoiceId, reason);

      print('🧾 Invoice disputed successfully');
      return true;
    } catch (e) {
      print('❌ Error disputing invoice: $e');
      return false;
    }
  }

  // Real-time stream for customer invoices
  Stream<List<Invoice>> getCustomerInvoicesStream() async* {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('No authenticated user');

      // Yield initial data
      yield await getCustomerInvoices();

      // Listen for real-time changes
      await for (final _ in _supabase
          .from('invoices')
          .stream(primaryKey: ['id'])
          .eq('customer_id', user.id)) {
        
        print('🧾 Real-time invoice update received');
        
        try {
          final updatedInvoices = await getCustomerInvoices();
          yield updatedInvoices;
        } catch (e) {
          print('❌ Error fetching updated invoices: $e');
        }
      }
    } catch (e) {
      print('❌ Error in customer invoices stream: $e');
      rethrow;
    }
  }

  // Send acceptance notification to mechanic
  Future<void> _sendInvoiceAcceptanceNotification(String invoiceId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      // Get invoice and service request details
      final invoice = await getInvoiceById(invoiceId);
      if (invoice == null) return;

      // Get customer name
      final customerProfile = await _supabase
          .from('user_profiles')
          .select('first_name, last_name')
          .eq('id', user.id)
          .single();

      final customerName = '${customerProfile['first_name']} ${customerProfile['last_name']}';

      // Get mechanic ID from service provider
      final provider = await _supabase
          .from('service_providers')
          .select('user_id')
          .eq('id', invoice.providerId)
          .single();

      // Send message to mechanic
      await _supabase.from('messages').insert({
        'request_id': invoice.requestId,
        'sender_id': user.id,
        'receiver_id': provider['user_id'],
  'message': '✅ $customerName accepted the invoice for ₱${invoice.total.toStringAsFixed(2)}. Proceeding to payment...',
        'sent_at': DateTime.now().toIso8601String(),
        'is_read': false,
      });

      print('🧾 Invoice acceptance notification sent to mechanic');
    } catch (e) {
      print('❌ Error sending invoice acceptance notification: $e');
    }
  }

  // Send payment confirmation to mechanic
  Future<void> _sendPaymentConfirmationNotification(String invoiceId, String requestId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      // Get invoice details
      final invoice = await getInvoiceById(invoiceId);
      if (invoice == null) return;

      // Get customer name
      final customerProfile = await _supabase
          .from('user_profiles')
          .select('first_name, last_name')
          .eq('id', user.id)
          .single();

      final customerName = '${customerProfile['first_name']} ${customerProfile['last_name']}';

      // Get mechanic ID from service provider
      final provider = await _supabase
          .from('service_providers')
          .select('user_id')
          .eq('id', invoice.providerId)
          .single();

      // Send payment confirmation message
      await _supabase.from('messages').insert({
        'request_id': requestId,
        'sender_id': user.id,
        'receiver_id': provider['user_id'],
  'message': '💳 Payment confirmed! $customerName has paid ₱${invoice.total.toStringAsFixed(2)} for the service. Funds are held in escrow until service completion is verified.',
        'sent_at': DateTime.now().toIso8601String(),
        'is_read': false,
      });

      print('🧾 Payment confirmation notification sent to mechanic');
    } catch (e) {
      print('❌ Error sending payment confirmation notification: $e');
    }
  }

  // Send dispute notification to mechanic
  Future<void> _sendInvoiceDisputeNotification(String invoiceId, String reason) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      // Get invoice details
      final invoice = await getInvoiceById(invoiceId);
      if (invoice == null) return;

      // Get customer name
      final customerProfile = await _supabase
          .from('user_profiles')
          .select('first_name, last_name')
          .eq('id', user.id)
          .single();

      final customerName = '${customerProfile['first_name']} ${customerProfile['last_name']}';

      // Get mechanic ID from service provider
      final provider = await _supabase
          .from('service_providers')
          .select('user_id')
          .eq('id', invoice.providerId)
          .single();

      // Send dispute message
      await _supabase.from('messages').insert({
        'request_id': invoice.requestId,
        'sender_id': user.id,
        'receiver_id': provider['user_id'],
  'message': '⚠️ $customerName has disputed the invoice for ₱${invoice.total.toStringAsFixed(2)}. Reason: $reason',
        'sent_at': DateTime.now().toIso8601String(),
        'is_read': false,
      });

      print('🧾 Invoice dispute notification sent to mechanic');
    } catch (e) {
      print('❌ Error sending invoice dispute notification: $e');
    }
  }

  // Simulate payment processing
  Future<void> _processPayment(Invoice invoice, Map<String, dynamic> paymentData) async {
    // Simulate payment gateway processing
    await Future.delayed(Duration(seconds: 2));
    
    // Here you would integrate with PayMongo instead of:
    // - PayPal (removed)
    // - Stripe (replaced with PayMongo)
    // - GCash (now via PayMongo)
    // - PayMaya (now via PayMongo)
    // etc.
    
  print('🧾 Payment processed: ₱${invoice.total.toStringAsFixed(2)} via ${paymentData['method']}');
  }

  // Decline an invoice
  Future<void> declineInvoice(String invoiceId, String reason) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('No authenticated user');

      print('🧾 CustomerInvoiceService.declineInvoice() - Declining invoice: $invoiceId');

      await _supabase
          .from('invoices')
          .update({
            'status': 'declined',
            'decline_reason': reason,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', invoiceId)
          .eq('customer_id', user.id);

      print('✅ Invoice declined successfully');
    } catch (e) {
      print('❌ Error declining invoice: $e');
      throw Exception('Failed to decline invoice: ${e.toString()}');
    }
  }

  // Update invoice payment status
  Future<void> updateInvoiceStatus(String invoiceId, String status, {String? paymentMethod}) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('No authenticated user');

      print('🧾 CustomerInvoiceService.updateInvoiceStatus() - Updating invoice: $invoiceId to $status');

      Map<String, dynamic> updateData = {
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (status == 'paid') {
        updateData['paid_at'] = DateTime.now().toIso8601String();
      }

      await _supabase
          .from('invoices')
          .update(updateData)
          .eq('id', invoiceId)
          .eq('customer_id', user.id);

      print('✅ Invoice status updated successfully');
    } catch (e) {
      print('❌ Error updating invoice status: $e');
      throw Exception('Failed to update invoice status: ${e.toString()}');
    }
  }

  // Get customer service history with invoices
  Future<Map<String, dynamic>> getCustomerServiceSummary() async {
    try {
      final historyStats = await CustomerHistoryService.instance.getJobHistoryStats();
      final invoices = await getCustomerInvoices();
      
      final pendingInvoices = invoices.where((inv) => inv.status == 'pending' || inv.status == 'sent').length;
      final paidInvoices = invoices.where((inv) => inv.status == 'paid').length;
      
      return {
        ...historyStats,
        'pending_invoices': pendingInvoices,
        'paid_invoices': paidInvoices,
        'total_invoices': invoices.length,
      };
    } catch (e) {
      print('❌ Error getting customer service summary: $e');
      return {
        'completed_jobs': 0,
        'cancelled_jobs': 0,
        'total_spent': 0.0,
        'average_rating_given': 0.0,
        'total_jobs': 0,
        'pending_invoices': 0,
        'paid_invoices': 0,
        'total_invoices': 0,
      };
    }
  }

  // Get recent transactions (invoices + history)
  Future<List<Map<String, dynamic>>> getRecentTransactions({int limit = 10}) async {
    try {
      final invoices = await getCustomerInvoices();
      final history = await CustomerHistoryService.instance.getRecentJobHistory();
      
      List<Map<String, dynamic>> transactions = [];
      
      // Add invoices as transactions
      for (var invoice in invoices) {
        transactions.add({
          'type': 'invoice',
          'id': invoice.id,
          'title': 'Invoice #${invoice.id.substring(0, 8)}',
          'amount': invoice.totalAmount,
          'status': invoice.status,
          'date': invoice.createdAt,
          'data': invoice,
        });
      }
      
      // Add history as transactions
      for (var job in history) {
        transactions.add({
          'type': 'job',
          'id': job.id,
          'title': job.jobTitle,
          'amount': job.totalAmount,
          'status': job.jobStatus,
          'date': job.createdAt,
          'data': job,
        });
      }
      
      // Sort by date (newest first) and limit
      transactions.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));
      
      return transactions.take(limit).toList();
    } catch (e) {
      print('❌ Error getting recent transactions: $e');
      return [];
    }
  }
}
