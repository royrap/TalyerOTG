import 'package:flutter/material.dart';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/invoice.dart';
import '../services/customer_invoice_service.dart';
import '../widgets/real_time_payment_status_widget.dart';
import 'modern_invoice_screen.dart';
import 'invoice_angkas_payment_screen.dart';

class RealTimeInvoiceScreen extends StatefulWidget {
  const RealTimeInvoiceScreen({Key? key}) : super(key: key);

  @override
  State<RealTimeInvoiceScreen> createState() => _RealTimeInvoiceScreenState();
}

class _RealTimeInvoiceScreenState extends State<RealTimeInvoiceScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late StreamSubscription<List<Invoice>> _invoicesSubscription;
  
  List<Invoice> _allInvoices = [];
  List<Invoice> _pendingInvoices = [];
  List<Invoice> _paidInvoices = [];
  List<Invoice> _completedInvoices = [];
  
  // Store payment proof URLs by invoice ID
  Map<String, Map<String, dynamic>> _paymentProofs = {};
  
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _subscribeToInvoiceUpdates();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _invoicesSubscription.cancel();
    super.dispose();
  }

  void _subscribeToInvoiceUpdates() {
    _invoicesSubscription = CustomerInvoiceService.instance
        .getCustomerInvoicesStream()
        .listen(
      (invoices) {
        if (mounted) {
          setState(() {
            _allInvoices = invoices;
            _categorizeInvoices();
            _isLoading = false;
            _error = null;
          });
          // Load payment proofs for paid invoices
          _loadPaymentProofs();
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() {
            _error = error.toString();
            _isLoading = false;
          });
        }
      },
    );
  }

  void _categorizeInvoices() {
    _pendingInvoices = _allInvoices
        .where((invoice) => ['sent', 'accepted'].contains(invoice.status))
        .toList();
    
    _paidInvoices = _allInvoices
        .where((invoice) => invoice.status == 'paid')
        .toList();
    
    _completedInvoices = _allInvoices
        .where((invoice) => invoice.status == 'completed')
        .toList();
  }
  
  /// Load payment proof URLs for paid invoices
  Future<void> _loadPaymentProofs() async {
    final supabase = Supabase.instance.client;
    
    // Get all paid and completed invoices
    final paidInvoices = _allInvoices.where(
      (invoice) => ['paid', 'completed'].contains(invoice.status)
    ).toList();
    
    for (final invoice in paidInvoices) {
      try {
        final invoiceData = await supabase
            .from('invoices')
            .select('payment_details, selected_payment_method')
            .eq('id', invoice.id)
            .maybeSingle();
        
        if (invoiceData != null && invoiceData['payment_details'] != null) {
          final paymentDetails = invoiceData['payment_details'] as Map<String, dynamic>?;
          if (paymentDetails != null && paymentDetails['proof_url'] != null) {
            if (mounted) {
              setState(() {
                _paymentProofs[invoice.id] = {
                  'proof_url': paymentDetails['proof_url'],
                  'payment_method': invoiceData['selected_payment_method'],
                };
              });
            }
          }
        }
      } catch (e) {
        print('Error loading payment proof for invoice ${invoice.id}: $e');
      }
    }
  }

  Future<void> _refreshInvoices() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final invoices = await CustomerInvoiceService.instance.getCustomerInvoices();
      if (mounted) {
        setState(() {
          _allInvoices = invoices;
          _categorizeInvoices();
          _isLoading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoices'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          // Container(
          //   margin: const EdgeInsets.only(right: 16, top: 12, bottom: 12),
          //   padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          //   decoration: BoxDecoration(
          //     color: Colors.red[100],
          //     borderRadius: BorderRadius.circular(12),
          //     border: Border.all(color: Colors.red[300]!),
          //   ),
          //   child: Row(
          //     mainAxisSize: MainAxisSize.min,
          //     children: [
          //       Container(
          //         width: 8,
          //         height: 8,
          //         decoration: const BoxDecoration(
          //           color: Colors.red,
          //           shape: BoxShape.circle,
          //         ),
          //       ),
          //       const SizedBox(width: 6),
          //       const Text(
          //        '',
          //         style: TextStyle(
          //           color: Color.fromARGB(255, 255, 255, 255),
          //           fontWeight: FontWeight.bold,
          //           fontSize: 12,
          //         ),
          //       ),
          //     ],
          //   ),
          // ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color.fromARGB(255, 176, 12, 1),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color.fromARGB(255, 176, 12, 1),
          tabs: [
            Tab(
              text: 'All (${_allInvoices.length})',
              icon: const Icon(Icons.list_alt),
            ),
            Tab(
              text: 'Pending (${_pendingInvoices.length})',
              icon: const Icon(Icons.pending_actions),
            ),
            Tab(
              text: 'Paid (${_paidInvoices.length})',
              icon: const Icon(Icons.payment),
            ),
            Tab(
              text: 'Completed (${_completedInvoices.length})',
              icon: const Icon(Icons.check_circle),
            ),
          ],
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading invoices...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              'Error loading invoices',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _refreshInvoices,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return TabBarView(
      controller: _tabController,
      children: [
        _buildInvoiceList(_allInvoices),
        _buildInvoiceList(_pendingInvoices),
        _buildInvoiceList(_paidInvoices),
        _buildInvoiceList(_completedInvoices),
      ],
    );
  }

  Widget _buildInvoiceList(List<Invoice> invoices) {
    if (invoices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No invoices found',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Invoices will appear here when mechanics send them',
              style: TextStyle(
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshInvoices,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: invoices.length,
        itemBuilder: (context, index) {
          return _buildInvoiceCard(invoices[index]);
        },
      ),
    );
  }

  Widget _buildInvoiceCard(Invoice invoice) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: InkWell(
        onTap: () => _handleInvoiceTap(invoice),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          invoice.description,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Invoice #${invoice.id.substring(0, 8).toUpperCase()}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _buildStatusBadge(invoice.status),
                      const SizedBox(height: 4),
                      Text(
                        '₱${invoice.totalAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color.fromARGB(255, 176, 12, 1),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatDate(invoice.createdAt),
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(
                    Icons.list_alt,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${invoice.items.length} item${invoice.items.length != 1 ? 's' : ''}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              
              // Cash Payment Proof for paid invoices
              if (_paymentProofs.containsKey(invoice.id) && 
                  _paymentProofs[invoice.id]!['proof_url'] != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.withOpacity(0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.camera_alt, size: 16, color: Colors.green[700]),
                          const SizedBox(width: 6),
                          Text(
                            'Cash Payment Proof',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.green[700],
                              fontSize: 13,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              _paymentProofs[invoice.id]!['payment_method']?.toString().toUpperCase() ?? 'CASH',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Colors.green[700],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          _paymentProofs[invoice.id]!['proof_url'],
                          height: 120,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              height: 120,
                              color: Colors.grey[200],
                              child: const Center(child: CircularProgressIndicator()),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              height: 80,
                              color: Colors.grey[200],
                              child: const Center(
                                child: Text('Failed to load image', style: TextStyle(fontSize: 11)),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            _showPaymentProofFullScreen(_paymentProofs[invoice.id]!['proof_url']);
                          },
                          icon: const Icon(Icons.fullscreen, size: 16),
                          label: const Text('View Full Screen', style: TextStyle(fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green[600],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              
              // Real-time payment status for paid invoices
              if (invoice.status == 'paid') ...[
                const SizedBox(height: 12),
                RealTimePaymentStatusWidget(
                  invoiceId: invoice.id,
                  onPaymentUpdate: (paymentData) {
                    // Payment status updated, refresh invoices if needed
                    final status = paymentData['status']?.toString().toLowerCase() ?? '';
                    if (status == 'released_to_provider') {
                      _refreshInvoices();
                    }
                  },
                ),
              ],
              
              // Action buttons
              if (['sent', 'accepted'].contains(invoice.status)) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (invoice.status == 'sent') ...[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _disputeInvoice(invoice),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                          ),
                          child: const Text('Dispute'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _acceptInvoice(invoice),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Accept'),
                        ),
                      ),
                    ] else if (invoice.status == 'accepted') ...[
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _payInvoice(invoice),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color.fromARGB(255, 176, 12, 1),
                            foregroundColor: Colors.white,
                          ),
                          child: Text('Pay ₱${invoice.totalAmount.toStringAsFixed(2)}'),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String text;
    IconData icon;

    switch (status.toLowerCase()) {
      case 'sent':
        color = Colors.orange;
        text = 'SENT';
        icon = Icons.send;
        break;
      case 'accepted':
        color = Colors.blue;
        text = 'ACCEPTED';
        icon = Icons.thumb_up;
        break;
      case 'paid':
        color = Colors.green;
        text = 'PAID';
        icon = Icons.payment;
        break;
      case 'completed':
        color = Colors.green;
        text = 'COMPLETED';
        icon = Icons.check_circle;
        break;
      case 'disputed':
        color = Colors.red;
        text = 'DISPUTED';
        icon = Icons.report_problem;
        break;
      default:
        color = Colors.grey;
        text = status.toUpperCase();
        icon = Icons.info;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  void _handleInvoiceTap(Invoice invoice) {
    // Show invoice details
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (context, scrollController) => _buildInvoiceDetails(invoice, scrollController),
      ),
    );
  }

  Widget _buildInvoiceDetails(Invoice invoice, ScrollController scrollController) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        controller: scrollController,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 50,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Invoice Details',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                _buildStatusBadge(invoice.status),
              ],
            ),
            const SizedBox(height: 20),
            
            // Invoice items
            const Text(
              'Items',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            
            ...invoice.items.map((item) => _buildInvoiceItem(item)),
            
            const Divider(height: 32),
            
            // Totals
            _buildTotalRow('Subtotal', invoice.subtotal),
            // _buildTotalRow('Tax', invoice.tax),
            const SizedBox(height: 8),
            _buildTotalRow('Total', invoice.totalAmount, isTotal: true),
            
            const SizedBox(height: 24),
            
            // Cash Payment Proof if available
            if (_paymentProofs.containsKey(invoice.id) && 
                _paymentProofs[invoice.id]!['proof_url'] != null) ...[
              const Text(
                'Cash Payment Proof',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.withOpacity(0.2)),
                ),
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        _paymentProofs[invoice.id]!['proof_url'],
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            height: 200,
                            color: Colors.grey[200],
                            child: const Center(child: CircularProgressIndicator()),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            height: 150,
                            color: Colors.grey[200],
                            child: const Center(
                              child: Text('Failed to load image'),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          _showPaymentProofFullScreen(_paymentProofs[invoice.id]!['proof_url']);
                        },
                        icon: const Icon(Icons.fullscreen, size: 18),
                        label: const Text('View Full Screen'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[600],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
            
            // Payment status if paid
            // if (invoice.status == 'paid') ...[
            //   const Text(
            //     'Payment Status',
            //     style: TextStyle(
            //       fontSize: 18,
            //       fontWeight: FontWeight.bold,
            //     ),
            //   ),
            //   const SizedBox(height: 12),
            //   RealTimePaymentStatusWidget(
            //     invoiceId: invoice.id,
            //     onPaymentUpdate: (paymentData) {
            //       final status = paymentData['status']?.toString().toLowerCase() ?? '';
            //       if (status == 'released_to_provider') {
            //         Navigator.of(context).pop();
            //         _refreshInvoices();
            //       }
            //     },
            //   ),
            // ],
          ],
        ),
      ),
    );
  }

  Widget _buildInvoiceItem(dynamic item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.description,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Qty: ${item.quantity} × ₱${item.unitPrice.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '₱${item.total.toStringAsFixed(2)}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalRow(String label, double amount, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 18 : 16,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            '₱${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: isTotal ? 18 : 16,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isTotal ? const Color.fromARGB(255, 176, 12, 1) : null,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _acceptInvoice(Invoice invoice) async {
    try {
      print('✅ Accepting invoice: ${invoice.id}');
      final success = await CustomerInvoiceService.instance.acceptInvoice(invoice.id);
      
      if (success && mounted) {
        print('✅ Invoice accepted successfully - navigating to payment screen');
        
        // Show brief success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Invoice accepted! Proceeding to payment...'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 1),
          ),
        );
        
        // Automatically navigate to Angkas-style payment screen (like service fee flow)
        await Future.delayed(const Duration(milliseconds: 500));
        
        if (mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => InvoiceAngkasPaymentScreen(invoice: invoice),
            ),
          ).then((result) {
            // Refresh invoices after payment
            if (result != null && result['success'] == true) {
              print('✅ Payment flow completed, refreshing invoices');
              _refreshInvoices();
            }
          });
        }
      }
    } catch (e) {
      print('❌ Error accepting invoice: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error accepting invoice: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _disputeInvoice(Invoice invoice) async {
    final reason = await _showDisputeDialog();
    if (reason != null && reason.isNotEmpty) {
      try {
        final success = await CustomerInvoiceService.instance.disputeInvoice(invoice.id, reason);
        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invoice disputed successfully'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error disputing invoice: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<String?> _showDisputeDialog() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Dispute Invoice'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please provide a reason for disputing this invoice:'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'Enter dispute reason...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Dispute'),
          ),
        ],
      ),
    );
  }

  void _payInvoice(Invoice invoice) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ModernInvoiceScreen(invoice: invoice),
      ),
    ).then((success) {
      if (success == true) {
        _refreshInvoices();
      }
    });
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
  
  /// Show payment proof in full screen
  void _showPaymentProofFullScreen(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            // Full screen image with zoom
            InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4.0,
              child: Center(
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.broken_image, size: 64, color: Colors.white54),
                          SizedBox(height: 16),
                          Text('Failed to load image', style: TextStyle(color: Colors.white54)),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            // Close button
            Positioned(
              top: 40,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            // Title
            Positioned(
              top: 48,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.camera_alt, color: Colors.white, size: 16),
                    SizedBox(width: 6),
                    Text(
                      'Cash Payment Proof',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}











