import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/paymongo_service.dart';
import '../services/customer_invoice_service.dart';
import '../models/invoice.dart';

class PayMongoQRPaymentScreen extends StatefulWidget {
  final Invoice invoice;

  const PayMongoQRPaymentScreen({
    super.key,
    required this.invoice,
  });

  @override
  State<PayMongoQRPaymentScreen> createState() => _PayMongoQRPaymentScreenState();
}

class _PayMongoQRPaymentScreenState extends State<PayMongoQRPaymentScreen> {
  bool _isLoading = true;
  String? _qrCodeData;
  String? _checkoutUrl;
  String? _error;
  bool _paymentCompleted = false;

  @override
  void initState() {
    super.initState();
    _generatePaymentQR();
    _listenToPaymentStatus();
  }

  Future<void> _generatePaymentQR() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      print('🔗 Generating PayMongo QR code for invoice: ${widget.invoice.id}');

      final checkoutUrl = await PayMongoService.instance.createQRCodeForPayment(
        invoiceId: widget.invoice.id,
        amount: widget.invoice.totalAmount,
        description: 'RoadAid Service Payment - Invoice ${widget.invoice.id}',
      );

      if (checkoutUrl != null && mounted) {
        setState(() {
          _checkoutUrl = checkoutUrl;
          _qrCodeData = checkoutUrl;
          _isLoading = false;
        });
        print('✅ QR code generated successfully');
      } else {
        throw Exception('Failed to generate payment QR code');
      }
    } catch (e) {
      print('❌ Error generating QR code: $e');
      if (mounted) {
        setState(() {
          _error = 'Failed to generate payment QR code: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  void _listenToPaymentStatus() {
    // Listen to real-time payment updates
    CustomerInvoiceService.instance
        .getCustomerInvoicesStream()
        .listen((invoices) {
      final updatedInvoice = invoices.firstWhere(
        (inv) => inv.id == widget.invoice.id,
        orElse: () => widget.invoice,
      );

      if (mounted && updatedInvoice.status == 'paid' && !_paymentCompleted) {
        setState(() {
          _paymentCompleted = true;
        });
        _showPaymentSuccessDialog();
      }
    });
  }

  void _showPaymentSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(
          Icons.check_circle,
          color: Colors.green,
          size: 64,
        ),
        title: const Text('Payment Successful!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Your payment of ₱${widget.invoice.totalAmount.toStringAsFixed(2)} has been processed successfully.'),
            const SizedBox(height: 16),
            const Text(
              'Transaction Details:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text('Invoice: ${widget.invoice.id.substring(0, 8)}...'),
            Text('Amount: ₱${widget.invoice.totalAmount.toStringAsFixed(2)}'),
            Text('Status: Payment Completed'),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(); // Close payment screen
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  Future<void> _retryPayment() async {
    await _generatePaymentQR();
  }

  void _openInBrowser() async {
    if (_checkoutUrl != null) {
      try {
        print('🌐 Opening payment URL in browser: $_checkoutUrl');
        final Uri url = Uri.parse(_checkoutUrl!);
        
        if (await canLaunchUrl(url)) {
          await launchUrl(
            url,
            mode: LaunchMode.inAppWebView, // 🔧 Use in-app web view for mobile compatibility
            webViewConfiguration: const WebViewConfiguration(
              enableJavaScript: true,
              enableDomStorage: true,
            ),
          );
          print('✅ Payment URL opened successfully');
        } else {
          throw Exception('Could not launch URL');
        }
      } catch (e) {
        print('❌ Error opening URL: $e');
        // Fallback: Show URL in snackbar with copy option
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Payment URL: $_checkoutUrl'),
              duration: const Duration(seconds: 8),
              action: SnackBarAction(
                label: 'Copy',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _checkoutUrl!));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Payment URL copied to clipboard'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('QR Payment'),
        backgroundColor: const Color.fromARGB(255, 176, 12, 1),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _paymentCompleted ? _buildPaymentCompletedView() : _buildPaymentView(),
    );
  }

  Widget _buildPaymentCompletedView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.check_circle,
            color: Colors.green,
            size: 100,
          ),
          const SizedBox(height: 24),
          const Text(
            'Payment Completed!',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '₱${widget.invoice.totalAmount.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Invoice: ${widget.invoice.id.substring(0, 8)}...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromARGB(255, 176, 12, 1),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Payment Summary Card
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Payment Summary',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Invoice ID:'),
                      Text(widget.invoice.id.substring(0, 8) + '...'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Amount:'),
                      Text(
                        '₱${widget.invoice.totalAmount.toStringAsFixed(2)}',
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
          ),

          const SizedBox(height: 24),

          // QR Code Section
          if (_isLoading)
            const Center(
              child: Column(
                children: [
                  CircularProgressIndicator(
                    color: Color.fromARGB(255, 176, 12, 1),
                  ),
                  SizedBox(height: 16),
                  Text('Generating payment QR code...'),
                ],
              ),
            )
          else if (_error != null)
            _buildErrorView()
          else if (_qrCodeData != null)
            _buildQRCodeView(),

          const SizedBox(height: 24),

          // Instructions
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'How to Pay:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('1. Open your GCash or PayMaya app'),
                  const Text('2. Scan the QR code above'),
                  const Text('3. Confirm the payment amount'),
                  const Text('4. Complete the payment'),
                  const Text('5. Wait for confirmation'),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info, color: Colors.blue),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Payment status will update automatically once completed.',
                            style: TextStyle(color: Colors.blue),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQRCodeView() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text(
              'Scan to Pay',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: QrImageView(
                data: _qrCodeData!,
                version: QrVersions.auto,
                size: 200.0,
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton.icon(
                  onPressed: _retryPayment,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                ),
                TextButton.icon(
                  onPressed: _openInBrowser,
                  icon: const Icon(Icons.open_in_browser),
                  label: const Text('Open Link'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 64,
            ),
            const SizedBox(height: 16),
            const Text(
              'Payment Setup Failed',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _retryPayment,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 176, 12, 1),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}










