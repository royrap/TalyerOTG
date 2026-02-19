import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import '../models/invoice.dart';
import 'invoice_payment_screen.dart';

class CustomerInvoicesScreen extends StatefulWidget {
  @override
  _CustomerInvoicesScreenState createState() => _CustomerInvoicesScreenState();
}

class _CustomerInvoicesScreenState extends State<CustomerInvoicesScreen> {
  StreamSubscription? _invoiceStreamSubscription;
  List<Map<String, dynamic>> _invoices = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchInvoices();
    _startRealTimeUpdates();
  }

  @override
  void dispose() {
    _invoiceStreamSubscription?.cancel();
    super.dispose();
  }

  /// Start real-time updates for invoices
  void _startRealTimeUpdates() {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    
    if (user == null) return;

    _invoiceStreamSubscription?.cancel();
    _invoiceStreamSubscription = supabase
        .from('invoices')
        .stream(primaryKey: ['id'])
        .eq('customer_id', user.id)
        .listen((data) {
          _handleInvoiceUpdate(data);
        });
  }

  /// Handle real-time invoice updates
  void _handleInvoiceUpdate(List<Map<String, dynamic>> data) async {
    // Refetch invoices with complete data including relations
    await _fetchInvoices();
  }
  
  /// Load payment proof URLs from invoices for cash payments
  Future<void> _loadPaymentProofUrls() async {
    for (int i = 0; i < _invoices.length; i++) {
      final invoice = _invoices[i];
      final status = invoice['status']?.toString().toLowerCase();
      
      // Only process paid invoices
      if (status == 'paid' && invoice['payment_details'] != null) {
        try {
          final paymentDetails = invoice['payment_details'] as Map<String, dynamic>?;
          if (paymentDetails != null && paymentDetails['proof_url'] != null) {
            if (mounted) {
              setState(() {
                _invoices[i]['payment_proof_url'] = paymentDetails['proof_url'];
                _invoices[i]['payment_method'] = invoice['selected_payment_method'];
              });
            }
          }
        } catch (e) {
          print('Error loading payment proof for invoice $i: $e');
        }
      }
    }
  }

  Future<void> _fetchInvoices() async {
    setState(() => _isLoading = true);
    
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) {
      setState(() {
        _invoices = [];
        _isLoading = false;
      });
      return;
    }

    try {
      final response = await supabase
        .from('invoices')
        .select('*, payment_details, selected_payment_method, service_requests(*, shops(*))')
        .eq('customer_id', user.id)
        .order('issued_at', ascending: false);

      setState(() {
        _invoices = List<Map<String, dynamic>>.from(response as List);
        _isLoading = false;
      });
      
      // Load payment proof URLs for paid invoices
      _loadPaymentProofUrls();
    } catch (e) {
      // Handle error, e.g., show a snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching invoices: $e')),
        );
      }
      setState(() {
        _invoices = [];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('My Invoices'),
        backgroundColor: Colors.blueAccent,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _fetchInvoices,
            tooltip: 'Refresh Invoices',
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _invoices.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'No invoices found.',
                        style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Invoices will appear here when sent by mechanics.',
                        style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchInvoices,
                  child: ListView.builder(
                    itemCount: _invoices.length,
                    itemBuilder: (context, index) {
                      final invoice = _invoices[index];
                      final request = invoice['service_requests'];
                      final shop = request != null ? request['shops'] : null;

                      return Card(
                        margin: EdgeInsets.all(8.0),
                        elevation: 3,
                        child: Column(
                          children: [
                            ListTile(
                              leading: CircleAvatar(
                                backgroundColor: _getStatusColor(invoice['status']),
                                child: Icon(
                                  _getStatusIcon(invoice['status']),
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                'Invoice #${invoice['invoice_number']}',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(height: 4),
                                  Text('Shop: ${shop != null ? shop['shop_name'] : 'N/A'}'),
                                  Text(
                                    'Amount: ₱${invoice['total_amount']}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.red[700],
                                    ),
                                  ),
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(invoice['status']).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: _getStatusColor(invoice['status']),
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      '${invoice['status']}'.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: _getStatusColor(invoice['status']),
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Date: ${invoice['issued_at'] ?? invoice['created_at'] ?? ''}',
                                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                              trailing: Icon(Icons.arrow_forward_ios, size: 16),
                              onTap: () {
                                // TODO: Navigate to invoice details screen
                              },
                            ),                            
                            // Cash Payment Proof section for paid invoices
                            if (invoice['status']?.toLowerCase() == 'paid' && 
                                invoice['payment_proof_url'] != null)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                                child: Container(
                                  padding: const EdgeInsets.all(14),
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
                                          Icon(Icons.camera_alt, size: 18, color: Colors.green[700]),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Cash Payment Proof',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: Colors.green[700],
                                              fontSize: 14,
                                            ),
                                          ),
                                          const Spacer(),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.green.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              invoice['payment_method']?.toString().toUpperCase() ?? 'CASH',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.green[700],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      // Image preview
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.network(
                                          invoice['payment_proof_url'],
                                          height: 150,
                                          width: double.infinity,
                                          fit: BoxFit.cover,
                                          loadingBuilder: (context, child, loadingProgress) {
                                            if (loadingProgress == null) return child;
                                            return Container(
                                              height: 150,
                                              color: Colors.grey[200],
                                              child: const Center(child: CircularProgressIndicator()),
                                            );
                                          },
                                          errorBuilder: (context, error, stackTrace) {
                                            return Container(
                                              height: 100,
                                              color: Colors.grey[200],
                                              child: const Center(
                                                child: Text('Failed to load image'),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      // View full screen button
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton.icon(
                                          onPressed: () {
                                            _showPaymentProofFullScreen(invoice['payment_proof_url']);
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
                              ),
                                                        // Add Pay button for unpaid invoices
                            if (invoice['status']?.toLowerCase() == 'sent' || 
                                invoice['status']?.toLowerCase() == 'pending' ||
                                invoice['status']?.toLowerCase() == 'accepted')
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                                child: SizedBox(
                                  width: double.infinity,
                                  height: 48,
                                  child: ElevatedButton(
                                    onPressed: () async {
                                      // Create Invoice model from map
                                      final invoiceModel = Invoice(
                                        id: invoice['id'] ?? '',
                                        requestId: invoice['service_request_id'] ?? '',
                                        providerId: invoice['provider_id'] ?? '',
                                        customerId: invoice['customer_id'] ?? '',
                                        items: [], // Empty items for now
                                        subtotal: (invoice['labor_cost'] as num?)?.toDouble() ?? 0.0,
                                        tax: 0.0,
                                        total: (invoice['total_amount'] as num?)?.toDouble() ?? 0.0,
                                        status: invoice['status'] ?? 'pending',
                                        createdAt: invoice['created_at'] != null 
                                            ? DateTime.parse(invoice['created_at']) 
                                            : DateTime.now(),
                                        sentAt: invoice['sent_at'] != null 
                                            ? DateTime.parse(invoice['sent_at']) 
                                            : null,
                                        acceptedAt: invoice['accepted_at'] != null 
                                            ? DateTime.parse(invoice['accepted_at']) 
                                            : null,
                                        paidAt: invoice['paid_at'] != null 
                                            ? DateTime.parse(invoice['paid_at']) 
                                            : null,
                                        notes: invoice['notes'],
                                      );
                                      
                                      // Navigate to payment screen
                                      final result = await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => InvoicePaymentScreen(
                                            invoice: invoiceModel,
                                          ),
                                        ),
                                      );
                                      
                                      // Refresh invoices after payment
                                      if (result == true) {
                                        await _fetchInvoices();
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color.fromARGB(255, 176, 12, 1),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      elevation: 2,
                                    ),
                                    child: Text(
                                      'Pay ₱${invoice['total_amount']}',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  /// Get color based on invoice status
  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'paid':
        return Colors.green;
      case 'sent':
        return Colors.blue;
      case 'overdue':
        return Colors.red;
      case 'draft':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  /// Get icon based on invoice status
  IconData _getStatusIcon(String? status) {
    switch (status?.toLowerCase()) {
      case 'paid':
        return Icons.check_circle;
      case 'sent':
        return Icons.send;
      case 'overdue':
        return Icons.warning;
      case 'draft':
        return Icons.edit;
      default:
        return Icons.receipt;
    }
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











