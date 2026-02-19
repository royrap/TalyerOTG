import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/supabase_service.dart';

class MechanicInvoiceBottomSheet extends StatefulWidget {
  final Map<String, dynamic> invoiceData;
  final VoidCallback? onClose;

  const MechanicInvoiceBottomSheet({
    Key? key,
    required this.invoiceData,
    this.onClose,
  }) : super(key: key);

  @override
  State<MechanicInvoiceBottomSheet> createState() => _MechanicInvoiceBottomSheetState();
}

class _MechanicInvoiceBottomSheetState extends State<MechanicInvoiceBottomSheet>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late Animation<double> _slideAnimation;
  bool _isExpanded = true;
  String? _customerName;
  String? _customerPhone;
  String? _paymentProofUrl; // Cash payment photo URL
  bool _isLoadingCustomerInfo = true;
  bool _isInvoicePaid = false;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeInOut,
    ));
    
    // Start the slide animation
    _slideController.forward();
    
    // Load customer information
    _loadCustomerInfo();
    
    // Check if invoice is paid
    _checkInvoiceStatus();
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomerInfo() async {
    try {
      final serviceRequestId = widget.invoiceData['serviceRequestId'] ?? widget.invoiceData['requestId'];
      final invoiceId = widget.invoiceData['invoiceId'];
      
      // Get payment proof from invoice's payment_details
      if (invoiceId != null) {
        final invoice = await SupabaseService.client
            .from('invoices')
            .select('payment_details')
            .eq('id', invoiceId)
            .maybeSingle();
        
        if (invoice != null && invoice['payment_details'] != null && mounted) {
          final paymentDetails = invoice['payment_details'] as Map<String, dynamic>?;
          if (paymentDetails != null && paymentDetails['proof_url'] != null) {
            setState(() {
              _paymentProofUrl = paymentDetails['proof_url'];
            });
          }
        }
      }
      
      if (serviceRequestId == null) return;

      // Get service request to find customer
      final serviceRequest = await SupabaseService.client
          .from('service_requests')
          .select('customer_id')
          .eq('id', serviceRequestId)
          .maybeSingle();
          
      if (serviceRequest != null) {
        if (serviceRequest['customer_id'] != null) {
          final customerId = serviceRequest['customer_id'];
          
          // Get customer profile
          final customerProfile = await SupabaseService.client
              .from('user_profiles')
              .select('first_name, last_name, phone_number')
              .eq('id', customerId)
              .maybeSingle();

          if (customerProfile != null && mounted) {
            setState(() {
              _customerName = '${customerProfile['first_name']} ${customerProfile['last_name']}';
              _customerPhone = customerProfile['phone_number'];
              _isLoadingCustomerInfo = false;
            });
          }
        }
      }
    } catch (e) {
      print('❌ Error loading customer info: $e');
      if (mounted) {
        setState(() {
          _isLoadingCustomerInfo = false;
        });
      }
    }
  }

  Future<void> _checkInvoiceStatus() async {
    try {
      final invoiceId = widget.invoiceData['invoiceId'];
      if (invoiceId == null) return;

      // Check if invoice is paid
      final invoice = await SupabaseService.client
          .from('invoices')
          .select('status')
          .eq('id', invoiceId)
          .maybeSingle();

      if (invoice != null && mounted) {
        setState(() {
          _isInvoicePaid = invoice['status'] == 'paid';
        });
      }
    } catch (e) {
      print('❌ Error checking invoice status: $e');
    }
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation.drive(
        Tween<Offset>(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ),
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 10,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // Header
            GestureDetector(
              onTap: _toggleExpanded,
              child: Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Invoice icon
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: _isInvoicePaid 
                            ? const Color.fromARGB(255, 76, 175, 80)
                            : const Color.fromARGB(255, 255, 152, 0),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isInvoicePaid ? Icons.payment : Icons.receipt,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    
                    // Invoice info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isInvoicePaid ? '💰 Invoice Paid!' : '📋 Invoice Sent',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: _isInvoicePaid 
                                  ? const Color.fromARGB(255, 27, 94, 32)
                                  : const Color.fromARGB(255, 237, 108, 2),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _isInvoicePaid ? 'Payment received successfully' : 'Waiting for customer payment',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Amount: ₱${widget.invoiceData['amount'] ?? widget.invoiceData['totalAmount'] ?? 'N/A'}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color.fromARGB(255, 176, 12, 1),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Close button
                    IconButton(
                      onPressed: () {
                        if (widget.onClose != null) {
                          widget.onClose!();
                        }
                      },
                      icon: const Icon(Icons.close, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
            
            // Expandable content
            if (_isExpanded) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Invoice details
                    _buildInvoiceDetails(),
                    const SizedBox(height: 20),
                    
                    // Customer info
                    _buildCustomerInfo(),
                    const SizedBox(height: 20),
                    
                    // Payment status
                    _buildPaymentStatus(),
                    const SizedBox(height: 20),
                    
                    // Cash payment proof (if available)
                    if (_paymentProofUrl != null)
                      _buildCashPaymentProof(),
                    if (_paymentProofUrl != null)
                      const SizedBox(height: 20),
                    
                    // Action buttons
                    _buildActionButtons(),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInvoiceDetails() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Invoice Details',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _buildDetailRow('Invoice ID:', widget.invoiceData['invoiceId']?.toString() ?? 'N/A'),
          _buildDetailRow('Service:', widget.invoiceData['description'] ?? widget.invoiceData['issueTitle'] ?? 'General Service'),
          _buildDetailRow('Service Fee:', '₱${widget.invoiceData['serviceFee'] ?? 'N/A'}'),
          _buildDetailRow('Parts Cost:', '₱${widget.invoiceData['partsCost'] ?? 'N/A'}'),
          _buildDetailRow('Total Amount:', '₱${widget.invoiceData['amount'] ?? widget.invoiceData['totalAmount'] ?? 'N/A'}'),
          if (widget.invoiceData['createdAt'] != null || widget.invoiceData['created_at'] != null)
            _buildDetailRow('Sent:', _formatDateTime(widget.invoiceData['createdAt'] ?? widget.invoiceData['created_at'])),
        ],
      ),
    );
  }

  Widget _buildCustomerInfo() {
    if (_isLoadingCustomerInfo) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.blue[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue[200]!),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text('Loading customer information...'),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Customer Information',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          if (_customerName != null) ...[
            _buildDetailRow('Name:', _customerName!),
            if (_customerPhone != null)
              _buildDetailRow('Phone:', _customerPhone!),
          ] else ...[
            const Text(
              'Customer information not available',
              style: TextStyle(
                fontSize: 14,
                fontStyle: FontStyle.italic,
                color: Colors.grey,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPaymentStatus() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isInvoicePaid ? Colors.red[50] : Colors.orange[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isInvoicePaid ? Colors.red[200]! : Colors.orange[200]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _isInvoicePaid ? Icons.check_circle : Icons.schedule,
                color: _isInvoicePaid ? Colors.red : Colors.orange,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                _isInvoicePaid ? 'Payment Received' : 'Payment Pending',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _isInvoicePaid ? Colors.red[800] : Colors.orange[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _isInvoicePaid 
                ? 'The customer has successfully paid this invoice. You can now complete the service.'
                : 'Waiting for customer to pay the invoice. They will receive a notification.',
            style: TextStyle(
              fontSize: 14,
              color: _isInvoicePaid ? Colors.red[700] : Colors.orange[700],
            ),
          ),
        ],
      ),
    );
  }

  /// Widget to display cash payment proof photo
  Widget _buildCashPaymentProof() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.photo_camera, color: Colors.green[700], size: 20),
              const SizedBox(width: 8),
              Text(
                'Cash Payment Proof',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Image preview
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              _paymentProofUrl!,
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
          // Download button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                final url = Uri.parse(_paymentProofUrl!);
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                }
              },
              icon: const Icon(Icons.download, size: 18),
              label: const Text('View / Download Image'),
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
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        if (!_isInvoicePaid) ...[
          // Resend Invoice button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                _resendInvoice();
              },
              icon: const Icon(Icons.send),
              label: const Text('Resend Invoice'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 176, 12, 1),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        
        // Contact Customer button (if available)
        if (_customerPhone != null)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                // Add phone call functionality here
                print('📞 Calling customer: $_customerPhone');
                // You can use url_launcher to make a phone call
                // launch('tel:$_customerPhone');
              },
              icon: const Icon(Icons.phone),
              label: const Text('Contact Customer'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color.fromARGB(255, 176, 12, 1),
                side: const BorderSide(color: Color.fromARGB(255, 176, 12, 1)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        
        if (_customerPhone != null) const SizedBox(height: 12),
        
        // Close button
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: () {
              if (widget.onClose != null) {
                widget.onClose!();
              }
            },
            child: const Text(
              'Close',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _formatDateTime(String dateTimeString) {
    try {
      final dateTime = DateTime.parse(dateTimeString);
      return DateFormat('MMM dd, yyyy \'at\' h:mm a').format(dateTime);
    } catch (e) {
      return dateTimeString;
    }
  }

  void _resendInvoice() {
    // Implement resend invoice functionality
    print('🔄 Resending invoice...');
    
    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('📧 Invoice resent successfully!'),
        backgroundColor: Color.fromARGB(255, 76, 175, 80),
      ),
    );
  }
}