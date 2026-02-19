import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

class CustomerInvoiceRealtimeService {
  static final CustomerInvoiceRealtimeService _instance = CustomerInvoiceRealtimeService._internal();
  static CustomerInvoiceRealtimeService get instance => _instance;
  CustomerInvoiceRealtimeService._internal();

  final _supabase = Supabase.instance.client;
  StreamSubscription<List<Map<String, dynamic>>>? _invoiceSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _requestStatusSubscription;
  
  // Controllers for streams
  final _invoiceController = StreamController<Map<String, dynamic>>.broadcast();
  final _requestStatusController = StreamController<Map<String, dynamic>>.broadcast();

  // Stream getters
  Stream<Map<String, dynamic>> get invoiceStream => _invoiceController.stream;
  Stream<Map<String, dynamic>> get requestStatusStream => _requestStatusController.stream;

  bool _isListening = false;

  // Start listening for invoice updates for a specific customer
  Future<void> startListening(String customerId) async {
    try {
      if (_isListening) {
        print('🔄 Already listening for invoices');
        return;
      }

      print('🎧 Starting invoice real-time listening for customer: $customerId');

      // Listen for new invoices sent to this customer
      _invoiceSubscription = _supabase
          .from('invoices')
          .stream(primaryKey: ['id'])
          .eq('customer_id', customerId)
          .listen((data) {
            for (final invoice in data) {
              print('📧 New invoice received: ${invoice['id']} - Status: ${invoice['status']}');
              _invoiceController.add(invoice);
            }
          });

      // Listen for service request status changes that affect invoices
      _requestStatusSubscription = _supabase
          .from('service_requests')
          .stream(primaryKey: ['id'])
          .eq('customer_id', customerId)
          .listen((data) {
            for (final request in data) {
              if (request['status'] == 'invoice_sent' || 
                  request['status'] == 'invoice_accepted' || 
                  request['status'] == 'invoice_paid' ||
                  request['status'] == 'completed') {
                print('📊 Service request status update: ${request['id']} - ${request['status']}');
                _requestStatusController.add(request);
              }
            }
          });

      _isListening = true;
      print('✅ Invoice real-time listening started successfully');

    } catch (e) {
      print('❌ Error starting invoice listening: $e');
    }
  }

  // Stop listening
  void stopListening() {
    try {
      _invoiceSubscription?.cancel();
      _requestStatusSubscription?.cancel();
      _isListening = false;
      print('🛑 Invoice real-time listening stopped');
    } catch (e) {
      print('❌ Error stopping invoice listening: $e');
    }
  }

  // Get current invoices for a customer
  Future<List<Map<String, dynamic>>> getCurrentInvoices(String customerId) async {
    try {
      final response = await _supabase
          .from('invoices')
          .select('''
            *,
            service_request:service_requests!invoices_request_id_fkey(
              id,
              title,
              description,
              service_type,
              pickup_address,
              status
            ),
            mechanic:user_profiles!invoices_mechanic_id_fkey(
              first_name,
              last_name,
              phone_number
            ),
            talyer_owner:user_profiles!invoices_talyer_owner_id_fkey(
              first_name,
              last_name,
              phone_number
            )
          ''')
          .eq('customer_id', customerId)
          .order('accepted_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('❌ Error getting current invoices: $e');
      return [];
    }
  }

  // Get pending invoices (sent but not yet accepted/paid)
  Future<List<Map<String, dynamic>>> getPendingInvoices(String customerId) async {
    try {
      final response = await _supabase
          .from('invoices')
          .select('''
            *,
            service_request:service_requests!invoices_request_id_fkey(
              id,
              title,
              description,
              service_type,
              pickup_address,
              status
            ),
            mechanic:user_profiles!invoices_mechanic_id_fkey(
              first_name,
              last_name,
              phone_number
            ),
            talyer_owner:user_profiles!invoices_talyer_owner_id_fkey(
              first_name,
              last_name,
              phone_number
            )
          ''')
          .eq('customer_id', customerId)
          .inFilter('status', ['sent', 'generated'])
          .order('accepted_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('❌ Error getting pending invoices: $e');
      return [];
    }
  }

  // Accept an invoice
  Future<bool> acceptInvoice(String invoiceId) async {
    try {
      print('✅ Accepting invoice: $invoiceId');
      
      await _supabase
          .from('invoices')
          .update({
            'status': 'accepted',
            'accepted_at': DateTime.now().toIso8601String(),
          })
          .eq('id', invoiceId);

      print('✅ Invoice accepted successfully');
      return true;
    } catch (e) {
      print('❌ Error accepting invoice: $e');
      return false;
    }
  }

  // Reject an invoice
  Future<bool> rejectInvoice(String invoiceId, String reason) async {
    try {
      print('❌ Rejecting invoice: $invoiceId - Reason: $reason');
      
      await _supabase
          .from('invoices')
          .update({
            'status': 'rejected',
            'notes': reason,
          })
          .eq('id', invoiceId);

      print('✅ Invoice rejected successfully');
      return true;
    } catch (e) {
      print('❌ Error rejecting invoice: $e');
      return false;
    }
  }

  // Mark invoice as paid (after payment completion)
  Future<bool> markInvoiceAsPaid(String invoiceId, Map<String, dynamic> paymentDetails) async {
    try {
      print('💰 Marking invoice as paid: $invoiceId');
      
      // First get the invoice details to find the request_id and mechanic_id
      final invoiceResponse = await _supabase
          .from('invoices')
          .select('request_id, mechanic_id, invoice_number, total_amount')
          .eq('id', invoiceId)
          .single();
      
      final requestId = invoiceResponse['request_id'];
      final mechanicId = invoiceResponse['mechanic_id'];
      final invoiceNumber = invoiceResponse['invoice_number'];
      final totalAmount = invoiceResponse['total_amount'];
      
      // Update invoice status to paid
      await _supabase
          .from('invoices')
          .update({
            'status': 'paid',
            'paid_at': DateTime.now().toIso8601String(),
            'payment_details': paymentDetails,
            'selected_payment_method': paymentDetails['payment_method'] ?? 'unknown',
          })
          .eq('id', invoiceId);

      // Update service request status to invoice_paid
      await _supabase
          .from('service_requests')
          .update({
            'status': 'invoice_paid',
            'payment_status': 'completed',
            'payment_completed_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', requestId);

      // Send notification to mechanic about payment
      if (mechanicId != null) {
        try {
          await _supabase.from('notifications').insert({
            'user_id': mechanicId,
            'title': '💰 Payment Received!',
            'body': 'Customer paid invoice $invoiceNumber for ₱${totalAmount?.toStringAsFixed(2) ?? "0.00"}. You can now scan QR code to complete the job.',
            'type': 'invoice_paid',
            'data': {
              'invoice_id': invoiceId,
              'request_id': requestId,
              'invoice_number': invoiceNumber,
              'amount': totalAmount,
              'payment_method': paymentDetails['payment_method'],
            },
            'read': false,
            'created_at': DateTime.now().toIso8601String(),
          });
          print('✅ Payment notification sent to mechanic: $mechanicId');
        } catch (notifError) {
          print('⚠️ Failed to send notification to mechanic: $notifError');
          // Continue even if notification fails
        }
      }

      print('✅ Invoice marked as paid successfully');
      print('✅ Service request status updated to invoice_paid');
      return true;
    } catch (e) {
      print('❌ Error marking invoice as paid: $e');
      return false;
    }
  }

  // Dispose resources
  void dispose() {
    stopListening();
    _invoiceController.close();
    _requestStatusController.close();
  }
}