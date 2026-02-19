import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/customer_invoice_realtime_service.dart';
import '../services/paymongo_service.dart';
import '../customer/cash_payment_screen.dart';
import '../screens/mobile_paymongo_screen.dart';
import '../config/payment_config.dart';
import 'customer_job_completion_qr.dart';

class CustomerInvoiceBottomSheet extends StatefulWidget {
  final Map<String, dynamic> serviceRequest;
  final VoidCallback? onPaymentCompleted;
  final VoidCallback? onClose;

  const CustomerInvoiceBottomSheet({
    Key? key,
    required this.serviceRequest,
    this.onPaymentCompleted,
    this.onClose,
  }) : super(key: key);

  @override
  State<CustomerInvoiceBottomSheet> createState() => _CustomerInvoiceBottomSheetState();
}

class _CustomerInvoiceBottomSheetState extends State<CustomerInvoiceBottomSheet> {
  Map<String, dynamic>? _currentInvoice;
  bool _isLoading = true;
  bool _isProcessingPayment = false;
  String _selectedPaymentMethod = 'paymongo';

  @override
  void initState() {
    super.initState();
    _loadInvoice();
    _startListeningToInvoices();
  }

  void _loadInvoice() async {
    try {
      final customerId = widget.serviceRequest['customer_id'];
      final requestId = widget.serviceRequest['id'];
      
      // Get current invoices for this request
      final invoices = await CustomerInvoiceRealtimeService.instance.getCurrentInvoices(customerId);
      final requestInvoice = invoices.where((inv) => inv['request_id'] == requestId).toList();
      
      if (requestInvoice.isNotEmpty) {
        setState(() {
          _currentInvoice = requestInvoice.first;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error loading invoice: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _startListeningToInvoices() {
    final customerId = widget.serviceRequest['customer_id'];
    
    CustomerInvoiceRealtimeService.instance.startListening(customerId);
    
    // Listen for new invoices
    CustomerInvoiceRealtimeService.instance.invoiceStream.listen((invoice) {
      if (invoice['request_id'] == widget.serviceRequest['id']) {
        setState(() {
          _currentInvoice = invoice;
        });
        
        if (invoice['status'] == 'sent') {
          _showInvoiceReceivedNotification();
        }
      }
    });
  }

  void _showInvoiceReceivedNotification() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.receipt, color: Colors.white),
            SizedBox(width: 8),
            Text('📧 New invoice received!'),
          ],
        ),
        backgroundColor: Colors.blue,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _acceptInvoice() async {
    if (_currentInvoice == null) return;

    try {
      final success = await CustomerInvoiceRealtimeService.instance.acceptInvoice(_currentInvoice!['id']);
      
      if (success) {
        setState(() {
          _currentInvoice!['status'] = 'accepted';
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Invoice accepted! You can now proceed with payment.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('❌ Error accepting invoice: $e');
    }
  }

  Future<void> _rejectInvoice() async {
    if (_currentInvoice == null) return;

    final reason = await _showRejectDialog();
    if (reason == null) return;

    try {
      final success = await CustomerInvoiceRealtimeService.instance.rejectInvoice(_currentInvoice!['id'], reason);
      
      if (success) {
        setState(() {
          _currentInvoice!['status'] = 'rejected';
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Invoice rejected'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('❌ Error rejecting invoice: $e');
    }
  }

  Future<String?> _showRejectDialog() async {
    String reason = '';
    
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Invoice'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please provide a reason for rejecting this invoice:'),
            const SizedBox(height: 16),
            TextField(
              onChanged: (value) => reason = value,
              decoration: const InputDecoration(
                hintText: 'Enter reason here...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: reason.isNotEmpty ? () => Navigator.pop(context, reason) : null,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _processPayment() async {
    if (_currentInvoice == null) return;

  // Handle Cash Payment - Open camera screen (only if enabled)
  if (_selectedPaymentMethod == 'cash' && PaymentConfig.allowCashPayments) {
      print('💵 Cash payment selected - Opening camera screen...');
      
      final result = await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => CashPaymentScreen(
            invoice: _currentInvoice!,
            serviceRequest: widget.serviceRequest,
          ),
        ),
      );

      // Check if payment photo was submitted successfully
      if (result != null && result['success'] == true) {
        setState(() {
          _currentInvoice!['status'] = 'pending_verification';
          _currentInvoice!['payment_method'] = 'cash';
          _currentInvoice!['verification_id'] = result['verification_id'];
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.pending, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Text('💰 Cash payment photo submitted! Waiting for verification...'),
                ),
              ],
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ),
        );
      }
      
      return; // Exit early for cash payments
    }

    // TEMPORARY: Direct payment update (bypass PayMongo since it's not working)
    // When PayMongo is fixed, restore the original code below
    setState(() {
      _isProcessingPayment = true;
    });

    try {
      final invoiceId = _currentInvoice!['id'];
      final amount = (_currentInvoice!['total_amount'] as num).toDouble();
      final requestId = widget.serviceRequest['id'];
      
      print('💳 Processing direct payment (PayMongo bypassed) for invoice: $invoiceId');
      
      // Mark invoice as paid
      await CustomerInvoiceRealtimeService.instance.markInvoiceAsPaid(
        invoiceId,
        {
          'payment_method': _selectedPaymentMethod,
          'gateway': 'direct_test', // Temporary - change to 'paymongo' when fixed
          'amount': amount,
          'paid_at': DateTime.now().toIso8601String(),
        },
      );
      
      // Update service request payment status
      await Supabase.instance.client.from('service_requests').update({
        'payment_status': 'completed',
        'payment_completed_at': DateTime.now().toIso8601String(),
        'status': 'invoice_paid',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', requestId);
      
      // Update or create payment record
      final existingPayment = await Supabase.instance.client
          .from('payments')
          .select('id')
          .eq('request_id', requestId)
          .maybeSingle();
          
      if (existingPayment != null) {
        await Supabase.instance.client.from('payments').update({
          'status': 'completed',
          'payment_method': _selectedPaymentMethod,
          'payment_gateway': 'direct_test',
          'processed_at': DateTime.now().toIso8601String(),
        }).eq('request_id', requestId);
      } else {
        // Only insert if provider_id exists (mechanic should be assigned for invoice payment)
        final providerId = widget.serviceRequest['provider_id'];
        if (providerId != null) {
          await Supabase.instance.client.from('payments').insert({
            'request_id': requestId,
            'customer_id': widget.serviceRequest['customer_id'],
            'provider_id': providerId,
            'amount': amount,
            'provider_amount': amount * 0.9,
            'platform_fee': amount * 0.1,
            'status': 'completed',
            'payment_method': _selectedPaymentMethod,
            'payment_gateway': 'direct_test',
            'processed_at': DateTime.now().toIso8601String(),
          });
        } else {
          print('⚠️ No provider_id available, skipping payment record insert');
        }
      }

      setState(() {
        _currentInvoice!['status'] = 'paid';
        _isProcessingPayment = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('💰 Payment successful! Invoice marked as paid.'),
            backgroundColor: Colors.green,
          ),
        );
      }

      widget.onPaymentCompleted?.call();
      
      print('✅ Direct payment completed for invoice: $invoiceId');
      
    } catch (e) {
      print('❌ Error processing direct payment: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Payment failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      setState(() {
        _isProcessingPayment = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '📧 Service Invoice',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                onPressed: widget.onClose,
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_currentInvoice == null)
            const Center(
              child: Text(
                'No invoice available yet.\nWaiting for mechanic to send invoice...',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            )
          else
            _buildInvoiceContent(),
        ],
      ),
    );
  }

  Widget _buildInvoiceContent() {
    final currencyFormat = NumberFormat.currency(locale: 'en_PH', symbol: '₱');
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Invoice details
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Invoice #${_currentInvoice!['invoice_number']}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text('Service: ${widget.serviceRequest['title']}'),
              Text('Description: ${widget.serviceRequest['description'] ?? 'N/A'}'),
              const SizedBox(height: 12),
              
              // Invoice items
              if (_currentInvoice!['items'] != null && _currentInvoice!['items'].isNotEmpty)
                ...(_currentInvoice!['items'] as List).map((item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text(item['description'] ?? 'Service Item')),
                      Text(currencyFormat.format(item['amount'] ?? 0)),
                    ],
                  ),
                )),
              
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total Amount:',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    currencyFormat.format(_currentInvoice!['total_amount']),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Status and actions
        _buildStatusAndActions(),
      ],
    );
  }

  Widget _buildStatusAndActions() {
    final status = _currentInvoice!['status'];
    
    switch (status) {
      case 'sent':
      case 'generated':
        return Column(
          children: [
            const Text(
              '⏳ Invoice received! Please review and accept to proceed with payment.',
              style: TextStyle(color: Colors.orange),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _rejectInvoice,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    child: const Text('Reject', style: TextStyle(color: Colors.white)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _acceptInvoice,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    child: const Text('Accept Invoice', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ],
        );
        
      case 'accepted':
        return Column(
          children: [
            const Text(
              '✅ Invoice accepted! Choose payment method:',
              style: TextStyle(color: Colors.green),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            
            // Payment method selection
            DropdownButtonFormField<String>(
              value: _selectedPaymentMethod,
              decoration: const InputDecoration(
                labelText: 'Payment Method',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem(value: 'paymongo', child: Text('PayMongo (Cards/GCash)')),
                if (PaymentConfig.allowCashPayments) const DropdownMenuItem(value: 'cash', child: Text('Cash Payment')),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedPaymentMethod = value!;
                });
              },
            ),
            const SizedBox(height: 16),
            
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isProcessingPayment ? null : _processPayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: _isProcessingPayment
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          SizedBox(width: 8),
                          Text('Processing...', style: TextStyle(color: Colors.white)),
                        ],
                      )
                    : const Text('Pay Now', style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            ),
          ],
        );
      
      case 'pending_verification':
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange),
              ),
              child: Column(
                children: [
                  Icon(Icons.pending_actions, color: Colors.orange[700], size: 48),
                  const SizedBox(height: 8),
                  Text(
                    '⏳ Pending Verification',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange[900],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your cash payment photo has been submitted.\nWaiting for mechanic/shop owner to verify your payment.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.orange[800],
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.orange[700], size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'You will be notified once your payment is verified.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.orange[800],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
        
      case 'paid':
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green),
              ),
              child: const Column(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 48),
                  SizedBox(height: 8),
                  Text(
                    '💰 Payment Successful!',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Show the QR code below to the mechanic to complete your service.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.green),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // QR Code for job completion
            CustomerJobCompletionQR(
              serviceRequest: widget.serviceRequest,
            ),
          ],
        );
        
      case 'rejected':
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red),
          ),
          child: const Column(
            children: [
              Icon(Icons.cancel, color: Colors.red, size: 48),
              SizedBox(height: 8),
              Text(
                '❌ Invoice Rejected',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Please discuss with the mechanic for a revised invoice.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red),
              ),
            ],
          ),
        );
        
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  void dispose() {
    CustomerInvoiceRealtimeService.instance.stopListening();
    super.dispose();
  }
}