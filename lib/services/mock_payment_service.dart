// MOCK PAYMENT SERVICE - Temporary fix for testing
// Create this file: lib/services/mock_payment_service.dart

import 'dart:async';
import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockPaymentService {
  static final MockPaymentService _instance = MockPaymentService._internal();
  static MockPaymentService get instance => _instance;
  MockPaymentService._internal();

  final _supabase = Supabase.instance.client;

  /// Mock version of processPayment for testing
  Future<Map<String, dynamic>?> processPayment({
    required String invoiceId,
    required String paymentMethod,
    required Map<String, dynamic> paymentDetails,
  }) async {
    try {
      print('🧪 [MockPaymentService] Processing mock payment...');
      print('🧪 Invoice ID: $invoiceId');
      print('🧪 Payment Method: $paymentMethod');
      
      // Simulate processing delay
      await Future.delayed(const Duration(seconds: 2));
      
      // Generate mock payment ID
      final paymentId = 'mock_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1000)}';
      
      // Return mock payment data
      final mockPayment = {
        'id': paymentId,
        'invoice_id': invoiceId,
        'amount': 565.00,
        'payment_method': paymentMethod,
        'status': 'processing',
        'transaction_id': 'mock_txn_${Random().nextInt(10000)}',
        'created_at': DateTime.now().toIso8601String(),
        'payment_details': paymentDetails,
      };
      
      print('✅ [MockPaymentService] Mock payment created: $paymentId');
      
      // Simulate payment completion after 3 seconds and update database
      Timer(const Duration(seconds: 3), () async {
        await _completePaymentSimulation(invoiceId, paymentId);
      });
      
      return mockPayment;
    } catch (e) {
      print('❌ [MockPaymentService] Error: $e');
      return null;
    }
  }

  /// Complete payment simulation by updating invoice status
  Future<void> _completePaymentSimulation(String invoiceId, String paymentId) async {
    try {
      print('🎯 [MockPaymentService] Completing payment simulation for invoice: $invoiceId');
      
      // Get invoice details first
      final invoice = await _supabase
          .from('invoices')
          .select('request_id, customer_id, provider_id, total_amount')
          .eq('id', invoiceId)
          .single();

      // Create payment record
      await _supabase
          .from('payments')
          .insert({
            'id': paymentId,
            'request_id': invoice['request_id'],
            'customer_id': invoice['customer_id'],
            'provider_id': invoice['provider_id'],
            'invoice_id': invoiceId,
            'amount': invoice['total_amount'],
            'payment_method': 'mock_payment',
            'payment_gateway': 'mock',
            'transaction_id': 'mock_txn_${Random().nextInt(10000)}',
            'status': 'completed',
            'processed_at': DateTime.now().toIso8601String(),
            'created_at': DateTime.now().toIso8601String(),
          });
      
      // Update invoice status to paid
      await _supabase
          .from('invoices')
          .update({
            'status': 'paid',
            'paid_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', invoiceId);

      // Update service request status
      await _supabase
          .from('service_requests')
          .update({
            'status': 'invoice_paid',
            'payment_status': 'completed',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', invoice['request_id']);
        
      print('✅ [MockPaymentService] Service request ${invoice['request_id']} updated to invoice_paid');
      print('✅ [MockPaymentService] Mock payment completed and invoice marked as paid: $paymentId');
    } catch (e) {
      print('❌ [MockPaymentService] Error completing payment simulation: $e');
    }
  }
}

// TO USE THIS MOCK SERVICE:
// In your enhanced_invoice_payment_screen.dart, temporarily replace:
// 
// final payment = await RealTimePaymentService.instance.processPayment(
//   invoiceId: widget.invoice.id,
//   paymentMethod: _selectedPaymentMethod,
//   paymentDetails: paymentDetails,
// );
//
// WITH:
//
// final payment = await MockPaymentService.instance.processPayment(
//   invoiceId: widget.invoice.id,
//   paymentMethod: _selectedPaymentMethod,
//   paymentDetails: paymentDetails,
// );
//
// Don't forget to import the mock service:
// import '../services/mock_payment_service.dart';
