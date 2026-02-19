import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/invoice.dart';
import 'mechanic_history_service.dart';

class MechanicInvoiceService {
  static final MechanicInvoiceService _instance = MechanicInvoiceService._internal();
  static MechanicInvoiceService get instance => _instance;
  MechanicInvoiceService._internal();

  final _supabase = Supabase.instance.client;

  // Get all invoices for the current mechanic
  Future<List<Invoice>> getMechanicInvoices() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('No authenticated user');

      print('🔧💰 MechanicInvoiceService.getMechanicInvoices() - Loading invoices for mechanic: ${user.id}');

      final result = await _supabase
          .from('invoices')
          .select('''
            *,
            service_requests!inner(
              service_type,
              pickup_address,
              customer_id
            ),
            user_profiles!invoices_customer_id_fkey!inner(
              first_name,
              last_name,
              phone_number
            )
          ''')
          .eq('mechanic_id', user.id)
          .order('accepted_at', ascending: false);

      return result.map((data) => Invoice.fromJson(data)).toList();
    } catch (e) {
      print('❌ Error getting mechanic invoices: $e');
      return [];
    }
  }

  // Get invoices by status
  Future<List<Invoice>> getInvoicesByStatus(String status) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('No authenticated user');

      final result = await _supabase
          .from('invoices')
          .select('''
            *,
            service_requests!inner(
              service_type,
              pickup_address,
              customer_id
            ),
            user_profiles!invoices_customer_id_fkey!inner(
              first_name,
              last_name,
              phone_number
            )
          ''')
          .eq('mechanic_id', user.id)
          .eq('status', status)
          .order('accepted_at', ascending: false);

      return result.map((data) => Invoice.fromJson(data)).toList();
    } catch (e) {
      print('❌ Error getting invoices by status: $e');
      return [];
    }
  }

  // Get pending invoices count
  Future<int> getPendingInvoicesCount() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return 0;

      // Get pending invoices (status = pending OR sent)
      final pendingResult = await _supabase
          .from('invoices')
          .select('id')
          .eq('mechanic_id', user.id)
          .eq('status', 'pending');

      final sentResult = await _supabase
          .from('invoices')
          .select('id')
          .eq('mechanic_id', user.id)
          .eq('status', 'sent');

      return pendingResult.length + sentResult.length;
    } catch (e) {
      print('❌ Error getting pending invoices count: $e');
      return 0;
    }
  }

  // Get paid invoices count
  Future<int> getPaidInvoicesCount() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return 0;

      final result = await _supabase
          .from('invoices')
          .select('id')
          .eq('mechanic_id', user.id)
          .eq('status', 'paid');

      return result.length;
    } catch (e) {
      print('❌ Error getting paid invoices count: $e');
      return 0;
    }
  }

  // Get total pending amount
  Future<double> getTotalPendingAmount() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return 0.0;

      // Get total pending amount (status = pending OR sent)
      final pendingAmountResult = await _supabase
          .from('invoices')
          .select('total_amount')
          .eq('mechanic_id', user.id)
          .eq('status', 'pending');

      final sentAmountResult = await _supabase
          .from('invoices')
          .select('total_amount')
          .eq('mechanic_id', user.id)
          .eq('status', 'sent');

      double total = 0.0;
      for (var item in [...pendingAmountResult, ...sentAmountResult]) {
        final amount = item['total_amount'];
        if (amount != null) {
          total += (amount is num) ? amount.toDouble() : double.tryParse(amount.toString()) ?? 0.0;
        }
      }

      return total;
    } catch (e) {
      print('❌ Error getting total pending amount: $e');
      return 0.0;
    }
  }

  // Get comprehensive earnings and invoice summary
  Future<Map<String, dynamic>> getMechanicFinancialSummary() async {
    try {
      final earningsSummary = await MechanicHistoryService.instance.getEarningsSummary();
      final pendingInvoices = await getPendingInvoicesCount();
      final paidInvoices = await getPaidInvoicesCount();
      final totalPendingAmount = await getTotalPendingAmount();
      final invoices = await getMechanicInvoices();

      return {
        // From earnings summary
        'total_earnings': earningsSummary.totalEarnings,
        'net_earnings': earningsSummary.netEarnings,
        'total_platform_fees': earningsSummary.totalPlatformFees,
        'earnings_this_month': earningsSummary.earningsThisMonth,
        'earnings_this_week': earningsSummary.earningsThisWeek,
        'completed_jobs': earningsSummary.completedJobs,
        'cancelled_jobs': earningsSummary.cancelledJobs,
        'average_rating': earningsSummary.averageRating,
        'total_hours_worked': earningsSummary.totalHoursWorked,
        
        // Invoice-specific data
        'pending_invoices': pendingInvoices,
        'paid_invoices': paidInvoices,
        'total_invoices': invoices.length,
        'total_pending_amount': totalPendingAmount,
        'disputed_invoices': invoices.where((inv) => inv.status == 'disputed').length,
        'cancelled_invoices': invoices.where((inv) => inv.status == 'cancelled').length,
      };
    } catch (e) {
      print('❌ Error getting mechanic financial summary: $e');
      return {
        'total_earnings': 0.0,
        'net_earnings': 0.0,
        'total_platform_fees': 0.0,
        'earnings_this_month': 0.0,
        'earnings_this_week': 0.0,
        'completed_jobs': 0,
        'cancelled_jobs': 0,
        'average_rating': 0.0,
        'total_hours_worked': 0.0,
        'pending_invoices': 0,
        'paid_invoices': 0,
        'total_invoices': 0,
        'total_pending_amount': 0.0,
        'disputed_invoices': 0,
        'cancelled_invoices': 0,
      };
    }
  }

  // Get recent transactions (invoices + history)
  Future<List<Map<String, dynamic>>> getRecentTransactions({int limit = 10}) async {
    try {
      final invoices = await getMechanicInvoices();
      final history = await MechanicHistoryService.instance.getRecentJobHistory();
      
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
          'net_earnings': job.netEarnings,
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

  // Create invoice and add to history
  Future<bool> createInvoiceAndUpdateHistory({
    required String serviceRequestId,
    required String customerId,
    required List<Map<String, dynamic>> items,
    required double subtotal,
    required double tax,
    required double total,
    String? notes,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('No authenticated user');

      print('🔧💰 MechanicInvoiceService.createInvoiceAndUpdateHistory() - Creating invoice for request: $serviceRequestId');

      // Create the invoice
      await _supabase.from('invoices').insert({
        'request_id': serviceRequestId,
        'customer_id': customerId,
        'mechanic_id': user.id,
        'subtotal': subtotal,
        'tax': tax,
        'total_amount': total,
        'status': 'pending',
        'items': items,
        'notes': notes,
        'created_at': DateTime.now().toIso8601String(),
      });

      // Update job history when invoice is created
      await MechanicHistoryService.instance.addJobToHistory(
        serviceRequestId: serviceRequestId,
        customerId: customerId,
        jobTitle: 'Invoice Generated',
        jobDescription: notes ?? 'Service invoice created',
        jobStatus: 'invoice_generated',
        totalAmount: total,
      );

      // Update service request status
      await _supabase
          .from('service_requests')
          .update({'status': 'invoice_sent'})
          .eq('id', serviceRequestId);

      print('✅ Invoice created and history updated successfully');
      return true;
    } catch (e) {
      print('❌ Error creating invoice and updating history: $e');
      return false;
    }
  }

  // Mark invoice as paid and update history
  Future<bool> markInvoiceAsPaid(String invoiceId, String serviceRequestId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('No authenticated user');

      print('🔧💰 MechanicInvoiceService.markInvoiceAsPaid() - Marking invoice as paid: $invoiceId');

      // Update invoice status
      await _supabase
          .from('invoices')
          .update({
            'status': 'paid',
            'paid_at': DateTime.now().toIso8601String(),
          })
          .eq('id', invoiceId)
          .eq('mechanic_id', user.id);

      // Get invoice details for history
      final invoice = await _supabase
          .from('invoices')
          .select('total_amount, customer_id')
          .eq('id', invoiceId)
          .single();

      // Update job history
      await MechanicHistoryService.instance.addJobToHistory(
        serviceRequestId: serviceRequestId,
        customerId: invoice['customer_id'],
        jobTitle: 'Payment Received',
        jobDescription: 'Invoice payment completed successfully',
        jobStatus: 'completed',
        totalAmount: invoice['total_amount']?.toDouble(),
      );

      print('✅ Invoice marked as paid and history updated successfully');
      return true;
    } catch (e) {
      print('❌ Error marking invoice as paid: $e');
      return false;
    }
  }

  // Real-time stream for mechanic invoices
  Stream<List<Invoice>> getMechanicInvoicesStream() async* {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('No authenticated user');

      // Yield initial data
      yield await getMechanicInvoices();

      // Listen for real-time changes
      await for (final _ in _supabase
          .from('invoices')
          .stream(primaryKey: ['id'])
          .eq('mechanic_id', user.id)) {
        
        print('🔧💰 Real-time invoice update received');
        
        try {
          final updatedInvoices = await getMechanicInvoices();
          yield updatedInvoices;
        } catch (e) {
          print('❌ Error fetching updated invoices: $e');
        }
      }
    } catch (e) {
      print('❌ Error in mechanic invoices stream: $e');
      rethrow;
    }
  }

  // Get earnings by date range
  Future<List<Map<String, dynamic>>> getEarningsByDateRange({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('No authenticated user');

      final result = await _supabase
          .from('invoices')
          .select('total_amount, provider_net_amount, platform_fee, paid_at, status')
          .eq('mechanic_id', user.id)
          .eq('status', 'paid')
          .gte('paid_at', startDate.toIso8601String())
          .lte('paid_at', endDate.toIso8601String())
          .order('paid_at', ascending: false);

      return result;
    } catch (e) {
      print('❌ Error getting earnings by date range: $e');
      return [];
    }
  }
}