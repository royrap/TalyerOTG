import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/invoice.dart';
import 'auth_service.dart';
import 'talyer_owner_service.dart';
import 'user_data_service.dart';

class InvoiceService {
  static final InvoiceService _instance = InvoiceService._internal();
  static InvoiceService get instance => _instance;
  InvoiceService._internal();

  final _supabase = Supabase.instance.client;

  /// Initialize and verify invoice table structure
  Future<bool> initializeInvoiceTable() async {
    try {
      print('🔧 Checking invoice table structure...');
      
      // Try a simple query to see what columns exist
      await _supabase
          .from('invoices')
          .select('id')
          .limit(1);
      
      print('✅ Invoice table exists and is accessible');
      return true;
    } catch (e) {
      print('❌ Invoice table issue: $e');
      
      if (e.toString().contains('items')) {
        print('🔧 Items column missing - this is handled in the code');
        return true; // We handle this gracefully
      }
      
      return false;
    }
  }

  /// Simple invoice generation without complex items (backup method)
  Future<Invoice?> generateSimpleInvoice({
    required String requestId,
    required String serviceDescription,
    required double amount,
    required String notes,
    double taxRate = 0.0, // No tax - removed fees
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('No authenticated user');

      print('🧾 InvoiceService.generateSimpleInvoice() - Creating simple invoice for job: $requestId');

      // Get service provider record for current user (include talyer_owner_id)
      // Handle case where user might have multiple service provider records
      final serviceProviders = await _supabase
          .from('service_providers')
          .select('id, talyer_owner_id, user_id')
          .eq('user_id', user.id)
          .limit(1);
      
      if (serviceProviders.isEmpty) {
        throw Exception('No service provider record found for user');
      }
      
      final serviceProvider = serviceProviders.first;
      
      // Ensure we have talyer_owner_id - if not, use the user_id as fallback
      String talyerOwnerId = serviceProvider['talyer_owner_id'] ?? user.id;

      // Get service request details to get customer ID
      final serviceRequest = await _supabase
          .from('service_requests')
          .select('customer_id, title')
          .eq('id', requestId)
          .single();

      // Calculate totals - NO FEES
      final subtotal = amount;
      final platformFee = 0.0; // No platform fee
      final tax = 0.0; // No tax
      final total = subtotal; // Total equals subtotal
      final providerNetAmount = subtotal; // Provider gets full amount

      // Generate invoice number
      final invoiceNumber = 'INV-${DateTime.now().millisecondsSinceEpoch}';

      // Create simple invoice record without items column
      final invoiceData = {
        'request_id': requestId,
        'provider_id': serviceProvider['id'],
        'customer_id': serviceRequest['customer_id'],
        'talyer_owner_id': talyerOwnerId, // Use the fallback-handled talyer_owner_id
        'mechanic_id': user.id, // Add mechanic_id as the current user
        'invoice_number': invoiceNumber,
        'issued_at': DateTime.now().toIso8601String(),
        'due_date': DateTime.now().add(const Duration(days: 7)).toIso8601String(),
        'status': 'sent',
        'subtotal': subtotal,
        'platform_fee': platformFee,
        'total_amount': total,
        'provider_net_amount': providerNetAmount,
        'talyer_net_amount': providerNetAmount, // Same as provider_net_amount
        'tax': tax,
        'notes': '$serviceDescription\n\n$notes',
        'sent_at': DateTime.now().toIso8601String(),
      };

      final result = await _supabase
          .from('invoices')
          .insert(invoiceData)
          .select()
          .single();

      print('🧾 Simple invoice created successfully: ${result['id']}');
      
      // Send invoice to customer's message inbox
      await _sendInvoiceToCustomerInbox(
        requestId: requestId,
        customerId: serviceRequest['customer_id'],
        providerId: serviceProvider['id'],
        invoiceData: result,
      );

      // Update service request status
      await _supabase
          .from('service_requests')
          .update({
            'status': 'invoice_sent',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', requestId);
      
      // Convert to Invoice object
      final invoiceObj = Invoice.fromJson(result);
      await _sendInvoiceToCustomer(invoiceObj);
      
      return invoiceObj;
    } catch (e) {
      print('❌ Error generating simple invoice: $e');
      return null;
    }
  }

  /// Generate invoice after inspection (Mechanic POV)
  Future<Invoice?> generateInvoice({
    required String requestId,
    required List<InvoiceItem> items,
    required String notes,
    double taxRate = 0.0, // No tax - removed fees
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('No authenticated user');

      print('🧾 InvoiceService.generateInvoice() - Creating invoice for job: $requestId');

      // Get service provider record for current user (include talyer_owner_id)
      // Handle case where user might have multiple service provider records
      final serviceProviders = await _supabase
          .from('service_providers')
          .select('id, talyer_owner_id, user_id')
          .eq('user_id', user.id)
          .limit(1);
      
      if (serviceProviders.isEmpty) {
        throw Exception('No service provider record found for user');
      }
      
      final serviceProvider = serviceProviders.first;
      
      // Ensure we have talyer_owner_id - if not, use the user_id as fallback
      String talyerOwnerId = serviceProvider['talyer_owner_id'] ?? user.id;

      // Get service request details to get customer ID
      final serviceRequest = await _supabase
          .from('service_requests')
          .select('customer_id, title')
          .eq('id', requestId)
          .single();

      // Calculate totals - NO FEES
      final subtotal = items.fold(0.0, (sum, item) => sum + item.total);
      final platformFee = 0.0; // No platform fee
      final tax = 0.0; // No tax
      final total = subtotal; // Total equals subtotal
      final providerNetAmount = subtotal; // Provider gets full amount

      // Generate invoice number
      final invoiceNumber = 'INV-${DateTime.now().millisecondsSinceEpoch}';

      // Create invoice record - aligned with RoadAid schema
      final invoiceData = {
        'request_id': requestId,
        'provider_id': serviceProvider['id'],
        'customer_id': serviceRequest['customer_id'],
        'talyer_owner_id': talyerOwnerId, // Use the fallback-handled talyer_owner_id
        'mechanic_id': user.id, // Add mechanic_id as the current user
        'invoice_number': invoiceNumber,
        'issued_at': DateTime.now().toIso8601String(),
        'due_date': DateTime.now().add(const Duration(days: 7)).toIso8601String(),
        'status': 'sent', // Automatically sent to customer's inbox
        'subtotal': subtotal,
        'platform_fee': platformFee,
        'total_amount': total,
        'provider_net_amount': providerNetAmount,
        'talyer_net_amount': providerNetAmount, // Same as provider_net_amount
        'tax': tax,
        'notes': notes,
        'sent_at': DateTime.now().toIso8601String(),
      };

      // Try to include items, but handle gracefully if column doesn't exist
      try {
        invoiceData['items'] = items.map((item) => item.toJson()).toList();
        print('🧾 Including invoice items in database');
      } catch (e) {
        print('⚠️ Warning: Could not include items in invoice (possibly missing column): $e');
        // Continue without items - they can be stored separately if needed
      }

      final result = await _supabase
          .from('invoices')
          .insert(invoiceData)
          .select()
          .single();

      print('🧾 Invoice created successfully: ${result['id']}');
      
      // Send invoice to customer's message inbox (as per RoadAid requirements)
      await _sendInvoiceToCustomerInbox(
        requestId: requestId,
        customerId: serviceRequest['customer_id'],
        providerId: serviceProvider['id'],
        invoiceData: result,
      );

      // Update service request status
      await _supabase
          .from('service_requests')
          .update({
            'status': 'invoice_sent',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', requestId);
      
      // Automatically send the invoice and notify customer
      final invoiceObj = Invoice.fromJson(result);
      await _sendInvoiceToCustomer(invoiceObj);
      
      return invoiceObj;
    } catch (e) {
      print('❌ Error generating invoice: $e');
      
      // If it's a column error, try the simple invoice method as fallback
      if (e.toString().contains('items') || e.toString().contains('PGRST204')) {
        print('🔄 Falling back to simple invoice generation...');
        
        // Calculate total amount from items
        final totalAmount = items.fold(0.0, (sum, item) => sum + item.total);
        final description = items.map((item) => '${item.quantity}x ${item.description}').join(', ');
        
        return await generateSimpleInvoice(
          requestId: requestId,
          serviceDescription: description,
          amount: totalAmount,
          notes: notes,
          taxRate: taxRate,
        );
      }
      
      return null;
    }
  }

  /// Send invoice to customer's message inbox (RoadAid specific requirement)
  Future<void> _sendInvoiceToCustomerInbox({
    required String requestId,
    required String customerId,
    required String providerId,
    required Map<String, dynamic> invoiceData,
  }) async {
    try {
      // Get provider's user_id for sending message
      final provider = await _supabase
          .from('service_providers')
          .select('user_id')
          .eq('id', providerId)
          .single();

      // Send invoice as a message in the customer's inbox
      final messageText = '''
🧾 Invoice Generated - ${invoiceData['invoice_number']}

Your service has been completed and an invoice has been generated:

💰 Subtotal: ₱${invoiceData['subtotal']}
🏢 Platform Fee: ₱${invoiceData['platform_fee']}
📄 Total Amount: ₱${invoiceData['total_amount']}

⏰ Due Date: ${DateTime.parse(invoiceData['due_date']).day}/${DateTime.parse(invoiceData['due_date']).month}/${DateTime.parse(invoiceData['due_date']).year}

Please review and accept the invoice to proceed with payment.

Note: ${invoiceData['notes'] ?? 'No additional notes provided.'}
      ''';

      await _supabase.from('messages').insert({
        'request_id': requestId,
        'sender_id': provider['user_id'],
        'receiver_id': customerId,
        'message': messageText,
        'sent_at': DateTime.now().toIso8601String(),
      });

      // Send notification
      await _supabase.from('notifications').insert({
        'user_id': customerId,
        'title': 'Invoice Received',
        'body': 'You have received an invoice for ₱${invoiceData['total_amount']}. Please check your messages.',
        'type': 'invoice',
        'data': {
          'invoice_id': invoiceData['id'],
          'invoice_number': invoiceData['invoice_number'],
          'total_amount': invoiceData['total_amount'],
          'request_id': requestId,
        },
        'created_at': DateTime.now().toIso8601String(),
      });

      print('✅ Invoice sent to customer inbox successfully');
    } catch (e) {
      print('❌ Error sending invoice to customer inbox: $e');
    }
  }

  // Internal method to send invoice to customer with notifications
  Future<void> _sendInvoiceToCustomer(Invoice invoice) async {
    try {
      print('🧾 Sending invoice to customer...');
      
      // Update invoice status to sent
      await _supabase
          .from('invoices')
          .update({
            'status': 'sent',
            'sent_at': DateTime.now().toIso8601String(),
          })
          .eq('id', invoice.id);

      // Update service request status
      await _supabase
          .from('service_requests')
          .update({'status': 'invoice_sent'})
          .eq('id', invoice.requestId);

      // Get mechanic details for notification
      final mechanic = await _supabase
          .from('user_profiles')
          .select('first_name, last_name')
          .eq('id', (await _supabase
              .from('service_providers')
              .select('user_id')
              .eq('id', invoice.providerId)
              .single())['user_id'])
          .single();

      final mechanicName = '${mechanic['first_name']} ${mechanic['last_name']}';

      // Send chat notification to customer
      await _sendInvoiceNotification(
        invoice.requestId,
        invoice.customerId,
        mechanicName,
        invoice.id,
      );

      print('🧾 Invoice sent and customer notified');
    } catch (e) {
      print('❌ Error in _sendInvoiceToCustomer: $e');
      throw e;
    }
  }

  // Send chat notification about invoice
  Future<void> _sendInvoiceNotification(
    String requestId,
    String customerId,
    String mechanicName,
    String invoiceId,
  ) async {
    try {
      // Get current user (mechanic) ID
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      // Insert message into chat
      await _supabase.from('messages').insert({
        'request_id': requestId,
        'sender_id': user.id,
        'receiver_id': customerId,
        'message': '🧾 You\'ve received an invoice from $mechanicName. Tap to view details and proceed with payment. Status: Pending',
        'sent_at': DateTime.now().toIso8601String(),
        'is_read': false,
      });

      print('🧾 Invoice notification sent to customer chat');
    } catch (e) {
      print('❌ Error sending invoice notification: $e');
    }
  }

  // Send invoice to customer (public method)
  Future<bool> sendInvoice(String invoiceId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('No authenticated user');

      print('🧾 InvoiceService.sendInvoice() - Sending invoice: $invoiceId');

      // Get service provider record for current user
      // Handle case where user might have multiple service provider records
      final serviceProviders = await _supabase
          .from('service_providers')
          .select('id')
          .eq('user_id', user.id)
          .limit(1);
      
      if (serviceProviders.isEmpty) {
        throw Exception('No service provider record found for user');
      }
      
      final serviceProvider = serviceProviders.first;

      // Get invoice details
      final invoiceData = await _supabase
          .from('invoices')
          .select('*')
          .eq('id', invoiceId)
          .eq('provider_id', serviceProvider['id'])
          .single();

      final invoice = Invoice.fromJson(invoiceData);
      await _sendInvoiceToCustomer(invoice);

      return true;
    } catch (e) {
      print('❌ Error sending invoice: $e');
      return false;
    }
  }

  // Get invoice for service request
  Future<Invoice?> getInvoiceForJob(String requestId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('No authenticated user');

      print('🧾 InvoiceService.getInvoiceForJob() - Getting invoice for job: $requestId');

      // Get service provider record for current user
      // Handle case where user might have multiple service provider records
      final serviceProviders = await _supabase
          .from('service_providers')
          .select('id')
          .eq('user_id', user.id)
          .limit(1);
      
      if (serviceProviders.isEmpty) {
        throw Exception('No service provider record found for user');
      }
      
      final serviceProvider = serviceProviders.first;

      final result = await _supabase
          .from('invoices')
          .select('*')
          .eq('request_id', requestId)
          .eq('provider_id', serviceProvider['id'])
          .maybeSingle();

      if (result != null) {
        return Invoice.fromJson(result);
      }
      return null;
    } catch (e) {
      print('❌ Error getting invoice: $e');
      return null;
    }
  }

  // Check if invoice is paid (for mechanic)
  Future<bool> isInvoicePaid(String requestId) async {
    try {
      final invoice = await getInvoiceForJob(requestId);
      return invoice?.status == 'paid';
    } catch (e) {
      print('❌ Error checking payment status: $e');
      return false;
    }
  }

  // Generate completion QR for customer (called from customer side)
  Future<String?> generateCompletionQR(String requestId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('No authenticated user');

      print('🔗 InvoiceService.generateCompletionQR() - Generating QR for job: $requestId');

      // Generate unique completion code
      final completionCode = '${requestId}_${DateTime.now().millisecondsSinceEpoch}';

      // Store completion code in database
      await _supabase
          .from('job_completion_codes')
          .insert({
            'request_id': requestId,
            'customer_id': user.id,
            'completion_code': completionCode,
            'created_at': DateTime.now().toIso8601String(),
            'expires_at': DateTime.now().add(Duration(hours: 24)).toIso8601String(),
            'is_used': false,
          });

      print('🔗 Completion QR generated: $completionCode');
      return completionCode;
    } catch (e) {
      print('❌ Error generating completion QR: $e');
      return null;
    }
  }

  // Verify and use completion QR (called from mechanic side)
  Future<bool> verifyCompletionQR(String qrCode, String requestId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('No authenticated user');

      print('🔍 InvoiceService.verifyCompletionQR() - Verifying QR: $qrCode');

      // Check if QR code is valid and not used
      final qrRecord = await _supabase
          .from('job_completion_codes')
          .select('*')
          .eq('completion_code', qrCode)
          .eq('request_id', requestId)
          .eq('is_used', false)
          .gte('expires_at', DateTime.now().toIso8601String())
          .maybeSingle();

      if (qrRecord == null) {
        print('❌ Invalid or expired QR code');
        return false;
      }

      // Get provider ID for mechanic status update
      // Handle case where user might have multiple service provider records
      final serviceProviders = await _supabase
          .from('service_providers')
          .select('id')
          .eq('user_id', user.id)
          .limit(1);
      
      if (serviceProviders.isEmpty) {
        throw Exception('No service provider record found for user');
      }
      
      final serviceProviderId = serviceProviders.first['id'];

      // Mark QR as used
      await _supabase
          .from('job_completion_codes')
          .update({
            'is_used': true,
            'used_at': DateTime.now().toIso8601String(),
            'used_by_provider_id': serviceProviderId,
          })
          .eq('completion_code', qrCode);

      // Update job status to completed
      await _supabase
          .from('service_requests')
          .update({
            'status': 'completed',
            'completed_at': DateTime.now().toIso8601String(),
          })
          .eq('id', requestId);

      // Update invoice status to completed
      await _supabase
          .from('invoices')
          .update({
            'status': 'completed',
            'completed_at': DateTime.now().toIso8601String(),
          })
          .eq('request_id', requestId);

      // Update mechanic availability after job completion
      try {
        await TalyerOwnerService.instance.updateMechanicStatusOnJobCompletion(
          serviceProviderId, 
          'completed'
        );
      } catch (mechanicStatusError) {
        print('⚠️ Warning: Could not update mechanic availability: $mechanicStatusError');
        // Don't fail the job completion if mechanic status update fails
      }

      // Process payment release to mechanic
      await _releasePaymentToMechanic(requestId);

      print('✅ Job completed and payment released');
      return true;
    } catch (e) {
      print('❌ Error verifying completion QR: $e');
      return false;
    }
  }

  // Process payment when customer pays invoice
  Future<bool> processInvoicePayment(String invoiceId, Map<String, dynamic> paymentDetails) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('No authenticated user');

      print('💳 Processing payment for invoice: $invoiceId');

      // Get invoice details
      final invoice = await _supabase
          .from('invoices')
          .select('*')
          .eq('id', invoiceId)
          .eq('customer_id', user.id)
          .single();

      // Create payment record (held in escrow)
      final paymentData = {
        'request_id': invoice['request_id'],
        'customer_id': user.id,
        'provider_id': invoice['provider_id'],
        'amount': invoice['total_amount'],
        'platform_fee': invoice['platform_fee'] ?? 0.00,
        'provider_amount': invoice['provider_net_amount'],
        'payment_gateway': paymentDetails['gateway'] ?? 'paymongo',
        'transaction_id': paymentDetails['transaction_id'],
        'status': 'held_in_escrow', // Held until job completion
        'processed_at': DateTime.now().toIso8601String(),
      };

      await _supabase.from('payments').insert(paymentData);

      // Update invoice status
      await _supabase
          .from('invoices')
          .update({
            'status': 'paid',
            'paid_at': DateTime.now().toIso8601String(),
          })
          .eq('id', invoiceId);

      // Update service request status
      await _supabase
          .from('service_requests')
          .update({'status': 'invoice_paid'})
          .eq('id', invoice['request_id']);

      // Generate completion QR code for customer
      final qrCode = await generateCompletionQR(invoice['request_id']);

      // Send notification to mechanic about payment
      await _notifyMechanicPaymentReceived(invoice['request_id'], invoice['provider_id']);

      print('✅ Payment processed and held in escrow. QR code: $qrCode');
      return true;
    } catch (e) {
      print('❌ Error processing payment: $e');
      return false;
    }
  }

  // Release payment to mechanic after job completion
  Future<void> _releasePaymentToMechanic(String requestId) async {
    try {
      print('💸 Releasing payment to mechanic for job: $requestId');

      // Update payment status from escrow to released
      await _supabase
          .from('payments')
          .update({
            'status': 'released_to_provider',
            'processed_at': DateTime.now().toIso8601String(),
          })
          .eq('request_id', requestId);

      print('✅ Payment released to mechanic');
    } catch (e) {
      print('❌ Error releasing payment: $e');
    }
  }

  // Notify mechanic that payment has been received
  Future<void> _notifyMechanicPaymentReceived(String requestId, String providerId) async {
    try {
      // Get mechanic user ID
      final mechanicUser = await _supabase
          .from('service_providers')
          .select('user_id')
          .eq('id', providerId)
          .single();

      // Get customer info
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final customer = await _supabase
          .from('user_profiles')
          .select('first_name, last_name')
          .eq('id', user.id)
          .single();

      final customerName = '${customer['first_name']} ${customer['last_name']}';

      // Send message to mechanic
      await _supabase.from('messages').insert({
        'request_id': requestId,
        'sender_id': user.id,
        'receiver_id': mechanicUser['user_id'],
        'message': '💳 Payment received from $customerName! Job is now ready for completion. Ask customer to show QR code when service is finished.',
        'sent_at': DateTime.now().toIso8601String(),
        'is_read': false,
      });

      print('📱 Payment notification sent to mechanic');
    } catch (e) {
      print('❌ Error notifying mechanic: $e');
    }
  }

  // Real-time stream for invoice status changes
  Stream<Invoice?> getInvoiceStream(String requestId) async* {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('No authenticated user');

      // Get service provider ID
      // Handle case where user might have multiple service provider records
      final serviceProviders = await _supabase
          .from('service_providers')
          .select('id')
          .eq('user_id', user.id)
          .limit(1);
      
      if (serviceProviders.isEmpty) {
        throw Exception('No service provider record found for user');
      }
      
      final serviceProvider = serviceProviders.first;

      final providerId = serviceProvider['id'];
      
      // Yield initial data
      yield await getInvoiceForJob(requestId);

      // Listen for real-time changes to invoices for this request
      await for (final _ in _supabase
          .from('invoices')
          .stream(primaryKey: ['id'])
          .eq('request_id', requestId)) {
        
        print('🧾 Real-time update received for invoice on request $requestId');
        
        // Verify this invoice belongs to this provider and fetch fresh data
        try {
          final updatedInvoice = await getInvoiceForJob(requestId);
          if (updatedInvoice?.providerId == providerId) {
            yield updatedInvoice;
          }
        } catch (e) {
          print('❌ Error fetching updated invoice: $e');
          // Continue with stream, don't break it
        }
      }
    } catch (e) {
      print('❌ Error in invoice stream: $e');
      rethrow;
    }
  }

  // ========================================
  // CUSTOMER-SPECIFIC METHODS (RoadAid Requirements)
  // ========================================

  /// Accept invoice (Customer POV - Step 1 in RoadAid flow)
  Future<bool> acceptInvoice(String invoiceId) async {
    try {
      final userId = AuthService.instance.userId;
      if (userId == null) throw Exception('User not authenticated');

      print('✅ Customer accepting invoice: $invoiceId');

      await _supabase
          .from('invoices')
          .update({
            'status': 'accepted',
            'accepted_at': DateTime.now().toIso8601String(),
          })
          .eq('id', invoiceId)
          .eq('customer_id', userId);

      // Update service request status
      final invoice = await _supabase
          .from('invoices')
          .select('request_id')
          .eq('id', invoiceId)
          .single();

      await _supabase
          .from('service_requests')
          .update({
            'status': 'invoice_accepted',
          })
          .eq('id', invoice['request_id']);

      print('✅ Invoice accepted successfully');
      return true;
    } catch (e) {
      print('❌ Error accepting invoice: $e');
      return false;
    }
  }

  /// Process invoice payment (Customer POV - Step 2 in RoadAid flow)
  /// Payment is held by Admin (escrow logic)
  Future<Map<String, dynamic>?> processCustomerInvoicePayment({
    required String invoiceId,
    required String paymentMethod,
    String? phoneNumber, // Optional - will use user profile if not provided
  }) async {
    try {
      final userId = AuthService.instance.userId;
      if (userId == null) throw Exception('User not authenticated');

      print('💳 Processing invoice payment: $invoiceId');

      // Get invoice details
      final invoice = await _supabase
          .from('invoices')
          .select('*')
          .eq('id', invoiceId)
          .eq('customer_id', userId)
          .single();

      if (invoice['status'] != 'accepted' && invoice['status'] != 'sent') {
        // Allow payment for both accepted and sent invoices
        if (invoice['status'] == 'sent') {
          // Automatically accept the invoice when customer proceeds to pay
          await acceptInvoice(invoiceId);
        } else {
          throw Exception('Invoice must be accepted before payment');
        }
      }

      // For cash payments, handle differently
      if (paymentMethod.toLowerCase() == 'cash') {
        // Update invoice status to cash payment
        await _supabase
            .from('invoices')
            .update({
              'status': 'cash_payment',
            })
            .eq('id', invoiceId);

        return {
          'success': true,
          'payment_method': 'cash',
          'message': 'Cash payment confirmed'
        };
      }

      // Get user profile data automatically if phoneNumber not provided
      String? userPhoneNumber = phoneNumber;
      if (userPhoneNumber == null || userPhoneNumber.isEmpty) {
        try {
          final userProfile = await _supabase
              .from('user_profiles')
              .select('phone_number')
              .eq('id', userId)
              .single();
          
          userPhoneNumber = userProfile['phone_number'];
          print('📱 Using user profile phone number: $userPhoneNumber');
        } catch (e) {
          print('⚠️ Warning: Could not fetch user phone number: $e');
          // Continue without phone number for credit card payments
        }
      }

      // For digital payments, create PayMongo checkout session
      final paymentData = {
        'amount': (invoice['total_amount'] * 100).round(), // PayMongo expects cents
        'currency': 'PHP',
        'description': 'Invoice Payment: ${invoice['invoice_number']}',
        'invoice_id': invoiceId,
        'customer_id': userId,
        'payment_method': paymentMethod,
      };

      if (userPhoneNumber != null && userPhoneNumber.isNotEmpty) {
        paymentData['phone_number'] = userPhoneNumber;
      }

      // Create PayMongo checkout session using existing PayMongo service
      final checkoutResponse = await UserDataService.processPaymentWithPayMongo(
        serviceRequestId: invoice['request_id'],
        amount: invoice['total_amount'].toDouble(),
        paymentMethod: paymentMethod,
        phoneNumber: userPhoneNumber,
      );

      if (checkoutResponse['checkout_url'] != null) {
        // Create payment record in pending status
        final paymentData = {
          'request_id': invoice['request_id'],
          'customer_id': invoice['customer_id'],
          'provider_id': invoice['provider_id'],
          'invoice_id': invoiceId, // Link payment to invoice
          'amount': invoice['total_amount'],
          'platform_fee': invoice['platform_fee'],
          'provider_amount': invoice['provider_net_amount'],
          'payment_gateway': 'paymongo',
          'transaction_id': checkoutResponse['transaction_id'],
          'status': 'pending',
          'created_at': DateTime.now().toIso8601String(),
        };

        await _supabase
            .from('payments')
            .insert(paymentData);

        // Update invoice payment details (keep current status)
        await _supabase
            .from('invoices')
            .update({
              'payment_details': {
                'gateway': 'paymongo',
                'transaction_id': checkoutResponse['transaction_id'],
                'payment_method': paymentMethod,
                'phone_number': userPhoneNumber,
              },
            })
            .eq('id', invoiceId);

        print('✅ Invoice payment checkout session created');
        return {
          'success': true,
          'checkout_url': checkoutResponse['checkout_url'],
          'transaction_id': checkoutResponse['transaction_id'],
        };
      } else {
        throw Exception('Failed to create payment checkout session');
      }
    } catch (e) {
      print('❌ Error processing invoice payment: $e');
      return null;
    }
  }



  /// Get pending invoices for customer to review
  Future<List<Map<String, dynamic>>> getPendingCustomerInvoices() async {
    try {
      final userId = AuthService.instance.userId;
      if (userId == null) throw Exception('User not authenticated');

      final invoices = await _supabase
          .from('invoices')
          .select('''
            *,
            service_requests (
              title,
              description,
              pickup_address
            ),
            service_providers (
              company_name,
              user_profiles!service_providers_user_id_fkey (
                first_name,
                last_name
              )
            )
          ''')
          .eq('customer_id', userId)
          .inFilter('status', ['sent', 'accepted'])
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(invoices);
    } catch (e) {
      print('❌ Error fetching pending invoices: $e');
      return [];
    }
  }

  /// Complete job and release payment after QR verification (Admin/System logic)
  Future<bool> releasePaymentAfterQRVerification(String invoiceId) async {
    try {
      print('🏁 Releasing payment after QR verification for invoice: $invoiceId');

      // Get invoice details
      final invoice = await _supabase
          .from('invoices')
          .select('request_id, provider_id, provider_net_amount')
          .eq('id', invoiceId)
          .single();

      // Update payment status to completed for this request
      await _supabase
          .from('payments')
          .update({
            'status': 'completed',
            'processed_at': DateTime.now().toIso8601String(),
          })
          .eq('request_id', invoice['request_id']);

      // Update invoice to completed
      await _supabase
          .from('invoices')
          .update({
            'status': 'completed',
            'completed_at': DateTime.now().toIso8601String(),
          })
          .eq('id', invoiceId);

      // Notify mechanic that payment has been released
      final provider = await _supabase
          .from('service_providers')
          .select('user_id')
          .eq('id', invoice['provider_id'])
          .single();

      await _supabase.from('notifications').insert({
        'user_id': provider['user_id'],
        'title': 'Payment Released',
        'body': 'Your payment of ₱${invoice['provider_net_amount']} has been released from escrow. The job is now complete!',
        'type': 'payment_release',
        'data': {
          'amount': invoice['provider_net_amount'],
          'invoice_id': invoiceId,
        },
        'created_at': DateTime.now().toIso8601String(),
      });

      print('✅ Payment released successfully');
      return true;
    } catch (e) {
      print('❌ Error releasing payment: $e');
      return false;
    }
  }
}
