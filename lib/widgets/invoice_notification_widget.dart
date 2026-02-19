import 'package:flutter/material.dart';
import '../models/invoice.dart';
import '../services/customer_invoice_service.dart';
import '../customer/customer_invoice_details_screen.dart';

class InvoiceNotificationWidget extends StatefulWidget {
  final String requestId;

  const InvoiceNotificationWidget({
    Key? key,
    required this.requestId,
  }) : super(key: key);

  @override
  State<InvoiceNotificationWidget> createState() => _InvoiceNotificationWidgetState();
}

class _InvoiceNotificationWidgetState extends State<InvoiceNotificationWidget> {
  Invoice? _latestInvoice;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLatestInvoice();
  }

  Future<void> _loadLatestInvoice() async {
    try {
      final invoices = await CustomerInvoiceService.instance.getCustomerInvoices();
      
      // Find the latest invoice for this request
      final requestInvoices = invoices.where((invoice) => invoice.requestId == widget.requestId).toList();
      
      if (!mounted) return; // Check if widget is still mounted
      
      if (requestInvoices.isNotEmpty) {
        // Sort by creation date and get the latest
        requestInvoices.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        if (mounted) { // Check again before setState
          setState(() {
            _latestInvoice = requestInvoices.first;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) { // Check before setState
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('❌ Error loading latest invoice: $e');
      if (mounted) { // Check before setState
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        height: 60,
        child: Center(
          child: CircularProgressIndicator(
            color: Color.fromARGB(255, 176, 12, 1),
          ),
        ),
      );
    }

    if (_latestInvoice == null) {
      return const SizedBox.shrink();
    }

    final invoice = _latestInvoice!;
    final needsAction = invoice.status.toLowerCase() == 'sent';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Card(
        elevation: needsAction ? 4 : 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: needsAction ? Border.all(color: Colors.blue, width: 2) : null,
            gradient: needsAction 
                ? LinearGradient(
                    colors: [Colors.blue.withOpacity(0.1), Colors.blue.withOpacity(0.05)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
          ),
          child: InkWell(
            onTap: () => _navigateToInvoiceDetails(),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _getStatusColor().withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _getStatusIcon(),
                          color: _getStatusColor(),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Invoice Received',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              _getStatusText(),
                              style: TextStyle(
                                fontSize: 12,
                                color: _getStatusColor(),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (needsAction)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'ACTION NEEDED',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Invoice details
                  Row(
                    children: [
                      Icon(Icons.receipt, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Text(
                        '${invoice.items.length} item(s) • ₱${invoice.total.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Action text
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDate(invoice.createdAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            needsAction ? 'Review & Pay' : 'View Invoice',
                            style: TextStyle(
                              fontSize: 14,
                              color: needsAction ? Colors.blue : Color.fromARGB(255, 176, 12, 1),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                            color: needsAction ? Colors.blue : Color.fromARGB(255, 176, 12, 1),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _getStatusColor() {
    switch (_latestInvoice!.status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'sent':
        return Colors.blue;
      case 'accepted':
        return Colors.purple;
      case 'paid':
        return Colors.green;
      case 'completed':
        return Colors.green[700]!;
      case 'disputed':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon() {
    switch (_latestInvoice!.status.toLowerCase()) {
      case 'pending':
        return Icons.hourglass_empty;
      case 'sent':
        return Icons.mail_outline;
      case 'accepted':
        return Icons.check_circle_outline;
      case 'paid':
        return Icons.payment;
      case 'completed':
        return Icons.verified;
      case 'disputed':
        return Icons.warning;
      default:
        return Icons.receipt;
    }
  }

  String _getStatusText() {
    switch (_latestInvoice!.status.toLowerCase()) {
      case 'pending':
        return 'Being prepared';
      case 'sent':
        return 'Awaiting your response';
      case 'accepted':
        return 'Awaiting payment';
      case 'paid':
        return 'Payment completed';
      case 'completed':
        return 'Service completed';
      case 'disputed':
        return 'Under review';
      default:
        return _latestInvoice!.status;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _navigateToInvoiceDetails() {
    if (!mounted) return; // Check if widget is still mounted
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CustomerInvoiceDetailsScreen(
          invoice: _latestInvoice!,
        ),
      ),
    ).then((_) {
      // Reload invoice data when returning, but only if widget is still mounted
      if (mounted) {
        _loadLatestInvoice();
      }
    });
  }
}
