import 'package:flutter/material.dart';
import 'dart:async';
import '../models/invoice.dart';
import '../services/customer_invoice_service.dart';
import '../customer/customer_invoice_details_screen.dart';
import '../customer/modern_invoice_screen.dart'; // 🎯 Modern payment screen

class InvoicePopupService {
  static final InvoicePopupService _instance = InvoicePopupService._internal();
  static InvoicePopupService get instance => _instance;
  InvoicePopupService._internal();

  StreamSubscription? _invoiceSubscription;
  BuildContext? _currentContext;

  /// Initialize invoice pop-up notifications
  void initialize(BuildContext context) {
    _currentContext = context;
    _startListeningForInvoices();
  }

  /// Start listening for new invoices and show pop-ups
  void _startListeningForInvoices() {
    _invoiceSubscription?.cancel();
    
    _invoiceSubscription = CustomerInvoiceService.instance
        .getCustomerInvoicesStream()
        .listen((invoices) {
      
      // Check for new invoices with 'sent' status
      final newInvoices = invoices.where((invoice) => 
        invoice.status.toLowerCase() == 'sent' && 
        !_hasBeenShown(invoice.id)
      ).toList();

      for (final invoice in newInvoices) {
        _showInvoicePopup(invoice);
        _markAsShown(invoice.id);
      }
    });
  }

  /// Show invoice pop-up dialog
  void _showInvoicePopup(Invoice invoice) {
    if (_currentContext == null || !(_currentContext!).mounted) return;

    showDialog(
      context: _currentContext!,
      barrierDismissible: false,
      builder: (context) => InvoicePopupDialog(invoice: invoice),
    );
  }

  /// Simple tracking for shown invoices (in production, use persistent storage)
  final Set<String> _shownInvoices = {};
  
  bool _hasBeenShown(String invoiceId) => _shownInvoices.contains(invoiceId);
  void _markAsShown(String invoiceId) => _shownInvoices.add(invoiceId);

  /// Update context when navigating
  void updateContext(BuildContext context) {
    _currentContext = context;
  }

  /// Dispose resources
  void dispose() {
    _invoiceSubscription?.cancel();
    _currentContext = null;
  }
}

/// Enhanced Invoice Pop-up Dialog with Direct Payment
class InvoicePopupDialog extends StatefulWidget {
  final Invoice invoice;

  const InvoicePopupDialog({
    Key? key,
    required this.invoice,
  }) : super(key: key);

  @override
  State<InvoicePopupDialog> createState() => _InvoicePopupDialogState();
}

class _InvoicePopupDialogState extends State<InvoicePopupDialog>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  bool _isProcessing = false;
  String? _selectedPaymentMethod;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 400),
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header with icon and animation
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color.fromARGB(255, 176, 12, 1).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.receipt_long,
                        size: 48,
                        color: Color.fromARGB(255, 176, 12, 1),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Title
                    const Text(
                      '🧾 New Invoice Received!',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color.fromARGB(255, 176, 12, 1),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Invoice details card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDetailRow('Invoice ID', widget.invoice.id.substring(0, 8) + '...'),
                          const SizedBox(height: 8),
                          _buildDetailRow('Created', _formatDate(widget.invoice.createdAt)),
                          
                          if (widget.invoice.items.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            const Text(
                              'Invoice Items:',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...widget.invoice.items.map((item) => Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey[200]!),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          item.description,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: item.type == 'labor' 
                                              ? Colors.blue[100] 
                                              : item.type == 'parts'
                                                  ? Colors.green[100]
                                                  : Colors.orange[100],
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          item.type.toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: item.type == 'labor' 
                                                ? Colors.blue[700] 
                                                : item.type == 'parts'
                                                    ? Colors.green[700]
                                                    : Colors.orange[700],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Qty: ${item.quantity} × ₱${item.unitPrice.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      Text(
                                        '₱${item.total.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: Color.fromARGB(255, 176, 12, 1),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            )).toList(),
                            
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color.fromARGB(255, 176, 12, 1).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                children: [
                                  _buildDetailRow('Subtotal', '₱${widget.invoice.subtotal.toStringAsFixed(2)}'),
                                  if (widget.invoice.tax > 0) ...[
                                    const SizedBox(height: 4),
                                    _buildDetailRow('Tax', '₱${widget.invoice.tax.toStringAsFixed(2)}'),
                                  ],
                                  const SizedBox(height: 8),
                                  Container(
                                    height: 1,
                                    color: const Color.fromARGB(255, 176, 12, 1).withOpacity(0.3),
                                  ),
                                  const SizedBox(height: 8),
                                  _buildDetailRow('Total Amount', '₱${widget.invoice.totalAmount.toStringAsFixed(2)}', isTotal: true),
                                ],
                              ),
                            ),
                          ] else ...[
                            const SizedBox(height: 8),
                            _buildDetailRow('Service', widget.invoice.description),
                            const SizedBox(height: 8),
                            _buildDetailRow('Amount', '₱${widget.invoice.totalAmount.toStringAsFixed(2)}'),
                          ],
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Payment method selection
                    const Text(
                      'Choose Payment Method:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Payment method buttons
                    Row(
                      children: [
                        Expanded(
                          child: _buildPaymentMethodButton(
                            'GCash',
                            Icons.qr_code,
                            Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildPaymentMethodButton(
                            'PayMaya',
                            Icons.qr_code_scanner,
                            Colors.green,
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 12),
                    
                    Row(
                      children: [
                        Expanded(
                          child: _buildPaymentMethodButton(
                            'Card',
                            Icons.credit_card,
                            Colors.purple,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildPaymentMethodButton(
                            'Bank',
                            Icons.account_balance,
                            Colors.indigo,
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Action buttons
                    if (_isProcessing) ...[
                      const CircularProgressIndicator(
                        color: Color.fromARGB(255, 176, 12, 1),
                      ),
                      const SizedBox(height: 8),
                      const Text('Processing payment...'),
                    ] else ...[
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _acceptAndViewInvoice(),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                  color: Color.fromARGB(255, 176, 12, 1),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: const Text(
                                'View Details',
                                style: TextStyle(
                                  color: Color.fromARGB(255, 176, 12, 1),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _selectedPaymentMethod != null 
                                  ? () => _proceedToPayment()
                                  : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color.fromARGB(255, 176, 12, 1),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                disabledBackgroundColor: Colors.grey[300],
                              ),
                              child: const Text(
                                'Pay Now',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    
                    const SizedBox(height: 12),
                    
                    // Close button
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'Maybe Later',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isTotal ? Colors.black87 : Colors.grey[600],
            fontSize: isTotal ? 15 : 14,
            fontWeight: isTotal ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: isTotal ? 16 : 14,
            color: isTotal ? const Color.fromARGB(255, 176, 12, 1) : Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentMethodButton(String method, IconData icon, Color color) {
    final isSelected = _selectedPaymentMethod == method;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPaymentMethod = method;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.white,
          border: Border.all(
            color: isSelected ? color : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? color : Colors.grey[600],
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              method,
              style: TextStyle(
                color: isSelected ? color : Colors.grey[700],
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _acceptAndViewInvoice() async {
    try {
      setState(() => _isProcessing = true);
      
      // Accept the invoice first
      final success = await CustomerInvoiceService.instance.acceptInvoice(widget.invoice.id);
      
      if (success && mounted) {
        Navigator.pop(context); // Close popup
        
        // Navigate to invoice details
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CustomerInvoiceDetailsScreen(invoice: widget.invoice),
          ),
        );
      } else {
        _showError('Failed to accept invoice. Please try again.');
      }
    } catch (e) {
      _showError('Error: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _proceedToPayment() async {
    if (_selectedPaymentMethod == null) return;

    try {
      setState(() => _isProcessing = true);
      
      // Accept invoice first
      final acceptSuccess = await CustomerInvoiceService.instance.acceptInvoice(widget.invoice.id);
      
      if (!acceptSuccess) {
        _showError('Failed to accept invoice');
        return;
      }

      // 🎯 DIRECT PAYMENT FLOW: Go straight to enhanced payment screen for ALL methods
      Navigator.pop(context); // Close popup
      
      final paymentResult = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ModernInvoiceScreen(
            invoice: widget.invoice,
            preSelectedPaymentMethod: _selectedPaymentMethod, // Pass selected method
          ),
        ),
      );
      
      if (paymentResult == true) {
        _showSuccessMessage('Payment completed successfully!');
      }
      
    } catch (e) {
      _showError('Error: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccessMessage(String message) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }
}
