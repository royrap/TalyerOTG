import 'package:flutter/material.dart';
import '../models/invoice.dart';
import '../services/customer_invoice_service.dart';
import '../services/supabase_service.dart';
import 'modern_invoice_screen.dart';
import 'job_completion_qr_screen.dart';

class CustomerInvoiceDetailsScreen extends StatefulWidget {
  final Invoice invoice;

  const CustomerInvoiceDetailsScreen({
    Key? key,
    required this.invoice,
  }) : super(key: key);

  @override
  State<CustomerInvoiceDetailsScreen> createState() => _CustomerInvoiceDetailsScreenState();
}

class _CustomerInvoiceDetailsScreenState extends State<CustomerInvoiceDetailsScreen> {
  bool _isLoading = false;
  Map<String, dynamic>? _vehicleData;
  bool _loadingVehicle = true;
  
  @override
  void initState() {
    super.initState();
    _loadVehicleData();
  }
  
  Future<void> _loadVehicleData() async {
    try {
      // Fetch service request to get vehicle_id
      final serviceRequest = await SupabaseService.client
          .from('service_requests')
          .select('vehicle_id')
          .eq('id', widget.invoice.requestId)
          .maybeSingle();
      
      if (serviceRequest != null && serviceRequest['vehicle_id'] != null) {
        // Fetch vehicle details
        final vehicle = await SupabaseService.client
            .from('vehicles')
            .select('brand_name, model_name, plate_number, year, color')
            .eq('id', serviceRequest['vehicle_id'])
            .maybeSingle();
        
        if (mounted) {
          setState(() {
            _vehicleData = vehicle;
            _loadingVehicle = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _loadingVehicle = false;
          });
        }
      }
    } catch (e) {
      print('Error loading vehicle data: $e');
      if (mounted) {
        setState(() {
          _loadingVehicle = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final invoice = widget.invoice;
    final canAccept = invoice.status.toLowerCase() == 'sent';
    final canPay = invoice.status.toLowerCase() == 'accepted';
    final isPaid = invoice.status.toLowerCase() == 'paid' || invoice.status.toLowerCase() == 'completed';

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Color.fromARGB(255, 176, 12, 1),
        title: Text(
          'Invoice #${invoice.id.substring(0, 8)}',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Card
            _buildStatusCard(invoice),
            
            const SizedBox(height: 20),
            
            // Invoice Summary
            _buildInvoiceSummary(invoice),
            
            const SizedBox(height: 20),
            
            // Items Breakdown
            _buildItemsBreakdown(invoice),
            
            const SizedBox(height: 20),
            
            // Service Details
            _buildServiceDetails(invoice),
            
            if (invoice.notes?.isNotEmpty == true) ...[
              const SizedBox(height: 20),
              _buildNotesSection(invoice),
            ],
            
            const SizedBox(height: 30),
            
            // Action Buttons
            _buildActionButtons(invoice, canAccept, canPay, isPaid),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(Invoice invoice) {
    Color statusColor;
    IconData statusIcon;
    String statusText;
    String statusDescription;

    switch (invoice.status.toLowerCase()) {
      case 'pending':
        statusColor = Colors.orange;
        statusIcon = Icons.hourglass_empty;
        statusText = 'Pending Review';
        statusDescription = 'Invoice is being prepared by the mechanic';
        break;
      case 'sent':
        statusColor = Colors.blue;
        statusIcon = Icons.mail_outline;
        statusText = 'Awaiting Your Response';
        statusDescription = 'Please review the invoice and accept or dispute if needed';
        break;
      case 'accepted':
        statusColor = Colors.purple;
        statusIcon = Icons.check_circle_outline;
        statusText = 'Accepted - Awaiting Payment';
        statusDescription = 'You have accepted this invoice. Please proceed with payment';
        break;
      case 'paid':
        statusColor = Colors.green;
        statusIcon = Icons.payment;
        statusText = 'Payment Completed';
        statusDescription = 'Payment successful. Funds held in escrow until service completion';
        break;
      case 'completed':
        statusColor = Colors.green[700]!;
        statusIcon = Icons.verified;
        statusText = 'Service Completed';
        statusDescription = 'Service completed and payment released to mechanic';
        break;
      case 'disputed':
        statusColor = Colors.red;
        statusIcon = Icons.warning;
        statusText = 'Disputed';
        statusDescription = 'This invoice is under review due to a dispute';
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help_outline;
        statusText = invoice.status.toUpperCase();
        statusDescription = 'Current status of your invoice';
    }

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [statusColor.withOpacity(0.1), statusColor.withOpacity(0.05)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(statusIcon, color: statusColor, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        statusDescription,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoiceSummary(Invoice invoice) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Invoice Summary',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            _buildSummaryRow('Subtotal:', '₱${invoice.subtotal.toStringAsFixed(2)}'),
            _buildSummaryRow('Tax:', '₱${invoice.tax.toStringAsFixed(2)}'),
            const Divider(thickness: 1),
            _buildSummaryRow(
              'Total:',
              '₱${invoice.total.toStringAsFixed(2)}',
              isTotal: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsBreakdown(Invoice invoice) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Service Items',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            ...invoice.items.map((item) => _buildItemRow(item)),
          ],
        ),
      ),
    );
  }

  Widget _buildItemRow(InvoiceItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.description,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (item.type.isNotEmpty)
                  Text(
                    'Type: ${item.type}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              'Qty: ${item.quantity}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              '₱${item.unitPrice.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              '₱${item.total.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceDetails(Invoice invoice) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Service Details',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // Vehicle Information
            if (_loadingVehicle)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color.fromARGB(255, 176, 12, 1),
                      ),
                    ),
                    SizedBox(width: 12),
                    Text('Loading vehicle info...'),
                  ],
                ),
              )
            else if (_vehicleData != null) ...[
              Row(
                children: [
                  const Icon(Icons.directions_car, size: 18, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${_vehicleData!['brand_name']} ${_vehicleData!['model_name']} - ${_vehicleData!['plate_number']}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            
            _buildDetailRow('Invoice Date:', _formatDate(invoice.createdAt)),
            if (invoice.sentAt != null)
              _buildDetailRow('Sent Date:', _formatDate(invoice.sentAt!)),
            if (invoice.acceptedAt != null)
              _buildDetailRow('Accepted Date:', _formatDate(invoice.acceptedAt!)),
            if (invoice.paidAt != null)
              _buildDetailRow('Payment Date:', _formatDate(invoice.paidAt!)),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesSection(Invoice invoice) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Notes',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              invoice.notes!,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(Invoice invoice, bool canAccept, bool canPay, bool isPaid) {
    return Column(
      children: [
        if (canAccept) ...[
          // Accept Invoice Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : () => _acceptInvoice(invoice),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      'Accept Invoice',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          // Dispute Invoice Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _isLoading ? null : () => _disputeInvoice(invoice),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Dispute Invoice',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ] else if (canPay) ...[
          // Direct Payment Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : () => _navigateToPayment(invoice),
              icon: const Icon(Icons.payment),
              label: Text('Pay Now - ₱${invoice.total.toStringAsFixed(2)}'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 176, 12, 1),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ] else if (isPaid) ...[
          // Payment Completed Info
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Color(0xFFEF5350).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.red, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Payment Completed',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.red[700],
                        ),
                      ),
                      Text(
                        'Your payment of \$${invoice.total.toStringAsFixed(2)} has been processed',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.red[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Generate QR Code Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _generateQRCode(invoice),
              icon: const Icon(Icons.qr_code, size: 24),
              label: const Text(
                'Show Job Completion QR Code',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1976D2),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Colors.blue[700],
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Show QR code to the mechanic when service is completed to finalize the job',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.blue[700],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isTotal ? Colors.black : Colors.grey[600],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isTotal ? 18 : 14,
              fontWeight: FontWeight.bold,
              color: isTotal ? Colors.red[700] : Colors.black87,
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
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
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

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _acceptInvoice(Invoice invoice) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final success = await CustomerInvoiceService.instance.acceptInvoice(invoice.id);
      
      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invoice accepted successfully! You can now proceed with payment.'),
              backgroundColor: Colors.red,
            ),
          );
          Navigator.of(context).pop(true); // Return to previous screen with refresh
        }
      } else {
        throw Exception('Failed to accept invoice');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error accepting invoice: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _disputeInvoice(Invoice invoice) async {
    final reason = await _showDisputeDialog();
    if (reason == null || reason.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final success = await CustomerInvoiceService.instance.disputeInvoice(invoice.id, reason);
      
      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invoice dispute submitted successfully. The mechanic will be notified.'),
              backgroundColor: Colors.orange,
            ),
          );
          Navigator.of(context).pop(true); // Return to previous screen with refresh
        }
      } else {
        throw Exception('Failed to dispute invoice');
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
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<String?> _showDisputeDialog() async {
    final TextEditingController controller = TextEditingController();
    
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Dispute Invoice'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Please explain why you are disputing this invoice:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Enter your reason for disputing...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final reason = controller.text.trim();
              if (reason.isNotEmpty) {
                Navigator.of(context).pop(reason);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Submit Dispute'),
          ),
        ],
      ),
    );
  }

  Future<void> _navigateToPayment(Invoice invoice) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ModernInvoiceScreen(
          invoice: invoice,
        ),
      ),
    );

    if (result == true && mounted) {
      // Payment successful, go back to invoices list
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _generateQRCode(Invoice invoice) async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Navigate directly to the job completion QR screen
      // This screen will check payment status and generate QR only if payment is confirmed
      final result = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (context) => JobCompletionQRScreen(
            serviceRequestId: invoice.requestId,
            jobDetails: {
              'title': 'Service Invoice #${invoice.id.substring(0, 8)}',
              'final_price': invoice.total.toStringAsFixed(2),
              'invoice_id': invoice.id,
              'customer_id': invoice.customerId,
              'mechanic_id': invoice.providerId,
            },
          ),
        ),
      );
      
      // If job was completed, go back to home
      if (result == true && mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening QR code screen: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}











