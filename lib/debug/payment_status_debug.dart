import '../services/supabase_service.dart';

class PaymentStatusDebug {
  static Future<void> printPaymentFlowStatus(String requestId) async {
    try {
      print('🔍 === PAYMENT STATUS DEBUG FOR REQUEST: $requestId ===');
      
      // Check service request status
      final serviceRequest = await SupabaseService.client
          .from('service_requests')
          .select('id, status, payment_status, payment_completed_at, updated_at')
          .eq('id', requestId)
          .single();
      
      print('📋 Service Request Status:');
      print('   - Status: ${serviceRequest['status']}');
      print('   - Payment Status: ${serviceRequest['payment_status']}');
      print('   - Payment Completed At: ${serviceRequest['payment_completed_at']}');
      print('   - Updated At: ${serviceRequest['updated_at']}');
      
      // Check invoice status
      final invoices = await SupabaseService.client
          .from('invoices')
          .select('id, status, paid_at, updated_at')
          .eq('request_id', requestId);
      
      if (invoices.isNotEmpty) {
        final invoice = invoices.first;
        print('📧 Invoice Status:');
        print('   - Invoice ID: ${invoice['id']}');
        print('   - Status: ${invoice['status']}');
        print('   - Paid At: ${invoice['paid_at']}');
        print('   - Updated At: ${invoice['updated_at']}');
      } else {
        print('📧 No invoice found for this request');
      }
      
      // Check payment records
      final payments = await SupabaseService.client
          .from('payments')
          .select('id, status, processed_at, payment_method')
          .eq('request_id', requestId);
      
      if (payments.isNotEmpty) {
        print('💰 Payment Records:');
        for (final payment in payments) {
          print('   - Payment ID: ${payment['id']}');
          print('   - Status: ${payment['status']}');
          print('   - Method: ${payment['payment_method']}');
          print('   - Processed At: ${payment['processed_at']}');
        }
      } else {
        print('💰 No payment records found');
      }
      
      print('🔍 === END DEBUG ===');
      
    } catch (e) {
      print('❌ Error debugging payment status: $e');
    }
  }
  
  static Future<void> simulatePaymentFlow(String requestId) async {
    try {
      print('🧪 === SIMULATING PAYMENT FLOW FOR REQUEST: $requestId ===');
      
      // Step 1: Get invoice
      final invoices = await SupabaseService.client
          .from('invoices')
          .select('*')
          .eq('request_id', requestId);
      
      if (invoices.isEmpty) {
        print('❌ No invoice found - cannot simulate payment');
        return;
      }
      
      final invoice = invoices.first;
      final invoiceId = invoice['id'];
      
      print('Step 1: Invoice found - $invoiceId');
      
      // Step 2: Update invoice status to paid
      await SupabaseService.client
          .from('invoices')
          .update({
            'status': 'paid',
            'paid_at': DateTime.now().toIso8601String(),
          })
          .eq('id', invoiceId);
      
      print('Step 2: Invoice marked as paid');
      
      // Step 3: Update service request status
      await SupabaseService.client
          .from('service_requests')
          .update({
            'status': 'invoice_paid',
            'payment_status': 'completed',
            'payment_completed_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', requestId);
      
      print('Step 3: Service request status updated');
      
      // Step 4: Create payment record
      await SupabaseService.client
          .from('payments')
          .insert({
            'id': 'sim_payment_${DateTime.now().millisecondsSinceEpoch}',
            'request_id': requestId,
            'customer_id': invoice['customer_id'],
            'provider_id': invoice['provider_id'],
            'invoice_id': invoiceId,
            'amount': invoice['total_amount'] ?? invoice['subtotal'],
            'payment_method': 'simulation',
            'payment_gateway': 'debug',
            'transaction_id': 'sim_txn_${DateTime.now().millisecondsSinceEpoch}',
            'status': 'completed',
            'processed_at': DateTime.now().toIso8601String(),
            'created_at': DateTime.now().toIso8601String(),
          });
      
      print('Step 4: Payment record created');
      
      print('✅ Payment simulation completed successfully');
      
      // Print final status
      await printPaymentFlowStatus(requestId);
      
    } catch (e) {
      print('❌ Error simulating payment flow: $e');
    }
  }
}