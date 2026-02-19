import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

class MechanicInvoiceRealtimeService {
  static final MechanicInvoiceRealtimeService _instance = MechanicInvoiceRealtimeService._internal();
  static MechanicInvoiceRealtimeService get instance => _instance;
  MechanicInvoiceRealtimeService._internal();

  final _supabase = Supabase.instance.client;
  StreamSubscription<List<Map<String, dynamic>>>? _invoiceSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _requestSubscription;
  
  // Controllers for streams
  final _invoiceStatusController = StreamController<Map<String, dynamic>>.broadcast();
  final _jobStatusController = StreamController<Map<String, dynamic>>.broadcast();

  // Stream getters
  Stream<Map<String, dynamic>> get invoiceStatusStream => _invoiceStatusController.stream;
  Stream<Map<String, dynamic>> get jobStatusStream => _jobStatusController.stream;

  bool _isListening = false;

  // Start listening for invoice status updates for a specific mechanic
  Future<void> startListening(String mechanicId) async {
    try {
      if (_isListening) {
        print('🔄 Already listening for invoice updates');
        return;
      }

      print('🎧 Starting mechanic invoice real-time listening for: $mechanicId');

      // Listen for invoice status changes
      _invoiceSubscription = _supabase
          .from('invoices')
          .stream(primaryKey: ['id'])
          .eq('mechanic_id', mechanicId)
          .listen((data) {
            for (final invoice in data) {
              print('📧 Invoice status update: ${invoice['id']} - Status: ${invoice['status']}');
              _invoiceStatusController.add(invoice);
            }
          });

      // Listen for service request status changes
      _requestSubscription = _supabase
          .from('service_requests')
          .stream(primaryKey: ['id'])
          .eq('assigned_mechanic_id', mechanicId)
          .listen((data) {
            for (final request in data) {
              if (request['status'] == 'invoice_accepted' || 
                  request['status'] == 'invoice_paid' ||
                  request['status'] == 'awaiting_completion' ||
                  request['status'] == 'completed') {
                print('📊 Job status update: ${request['id']} - ${request['status']}');
                _jobStatusController.add(request);
              }
            }
          });

      _isListening = true;
      print('✅ Mechanic invoice real-time listening started successfully');

    } catch (e) {
      print('❌ Error starting mechanic invoice listening: $e');
    }
  }

  // Stop listening
  void stopListening() {
    try {
      _invoiceSubscription?.cancel();
      _requestSubscription?.cancel();
      _isListening = false;
      print('🛑 Mechanic invoice real-time listening stopped');
    } catch (e) {
      print('❌ Error stopping mechanic invoice listening: $e');
    }
  }

  // Send invoice to customer (with real-time notification)
  Future<bool> sendInvoiceToCustomer({
    required String requestId,
    required String customerId,
    required String mechanicId,
    required String talyerOwnerId,
    required String providerId,
    required double subtotal,
    required double totalAmount,
    required double talyerNetAmount,
    required List<Map<String, dynamic>> items,
    String? notes,
  }) async {
    try {
      print('📧 Sending invoice to customer...');
      
      // Generate unique invoice number
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final invoiceNumber = 'INV-$timestamp';

      // Create invoice
      await _supabase
          .from('invoices')
          .insert({
            'request_id': requestId,
            'customer_id': customerId,
            'mechanic_id': mechanicId,
            'talyer_owner_id': talyerOwnerId,
            'provider_id': providerId,
            'invoice_number': invoiceNumber,
            'subtotal': subtotal,
            'total_amount': totalAmount,
            'talyer_net_amount': talyerNetAmount,
            'status': 'sent',
            'items': items,
            'notes': notes,
            'sent_at': DateTime.now().toIso8601String(),
            'generated_at': DateTime.now().toIso8601String(),
            'due_date': DateTime.now().add(const Duration(days: 7)).toIso8601String(),
          });

      // Update service request status
      await _supabase
          .from('service_requests')
          .update({
            'status': 'invoice_sent',
            'invoice_generated': true,
            'invoice_number': invoiceNumber,
          })
          .eq('id', requestId);

      print('✅ Invoice sent successfully: $invoiceNumber');
      return true;

    } catch (e) {
      print('❌ Error sending invoice: $e');
      return false;
    }
  }

  // Get invoice status for a specific request
  Future<Map<String, dynamic>?> getInvoiceForRequest(String requestId) async {
    try {
      final response = await _supabase
          .from('invoices')
          .select()
          .eq('request_id', requestId)
          .maybeSingle();

      return response;
    } catch (e) {
      print('❌ Error getting invoice for request: $e');
      return null;
    }
  }

  // Check if customer has paid the invoice
  Future<bool> isInvoicePaid(String invoiceId) async {
    try {
      final response = await _supabase
          .from('invoices')
          .select('status')
          .eq('id', invoiceId)
          .single();

      return response['status'] == 'paid';
    } catch (e) {
      print('❌ Error checking invoice payment status: $e');
      return false;
    }
  }

  // Get job completion QR code data (after payment)
  Future<Map<String, dynamic>?> getJobCompletionQR(String requestId) async {
    try {
      final response = await _supabase
          .from('job_completion_codes')
          .select()
          .eq('request_id', requestId)
          .eq('is_used', false)
          .maybeSingle();

      return response;
    } catch (e) {
      print('❌ Error getting job completion QR: $e');
      return null;
    }
  }

  // Complete job after QR scan
  Future<bool> completeJobAfterQRScan({
    required String requestId,
    required String completionCode,
    required double scanLatitude,
    required double scanLongitude,
  }) async {
    try {
      print('🔍 Completing job after QR scan...');

      // Mark completion code as used
      await _supabase
          .from('job_completion_codes')
          .update({
            'is_used': true,
            'used_at': DateTime.now().toIso8601String(),
            'scan_latitude': scanLatitude,
            'scan_longitude': scanLongitude,
            'verification_status': 'verified',
          })
          .eq('completion_code', completionCode);

      // Update service request to completed
      await _supabase
          .from('service_requests')
          .update({
            'status': 'completed',
            'completed_at': DateTime.now().toIso8601String(),
            'qr_scanned_at': DateTime.now().toIso8601String(),
          })
          .eq('id', requestId);

      print('✅ Job completed successfully via QR scan');
      return true;

    } catch (e) {
      print('❌ Error completing job after QR scan: $e');
      return false;
    }
  }

  // Dispose resources
  void dispose() {
    stopListening();
    _invoiceStatusController.close();
    _jobStatusController.close();
  }
}