import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/invoice.dart';
import '../services/paymongo_service.dart';
import '../services/supabase_service.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'MobilePayMongoScreen.dart';
import '../config/payment_config.dart';

class InvoicePaymentScreen extends StatefulWidget {
  final Invoice invoice;

  const InvoicePaymentScreen({
    Key? key,
    required this.invoice,
  }) : super(key: key);

  @override
  State<InvoicePaymentScreen> createState() => _InvoicePaymentScreenState();
}

class _InvoicePaymentScreenState extends State<InvoicePaymentScreen> {
  String? _selectedCategory; // 'online' or 'cash'
  bool _isProcessing = false;
  File? _cashPhoto;
  File? _receiptPhoto;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Select Payment Method',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: const Color.fromARGB(255, 176, 12, 1),
        foregroundColor: Colors.white,
        elevation: 2,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Invoice Summary Card
            _buildInvoiceSummary(),
            const SizedBox(height: 24),

            // Payment Method Selection
            _buildPaymentCategorySelection(),
            const SizedBox(height: 24),

            // Cash Payment Instructions (if cash selected)
            if (_selectedCategory == 'cash') ...[
              _buildCashPaymentInstructions(),
              const SizedBox(height: 16),
              _buildCashPhotoSection(),
              const SizedBox(height: 24),
            ],

            // Proceed Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isProcessing || _selectedCategory == null
                    ? null
                    : _handlePaymentProceed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 176, 12, 1),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                ),
                child: _isProcessing
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              strokeWidth: 2,
                            ),
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Processing...',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      )
                    : Text(
                        _selectedCategory == 'cash' 
                            ? 'Submit Cash Payment'
                            : 'Proceed to Online Payment',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoiceSummary() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 176, 12, 1).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.receipt_long,
                  color: Color.fromARGB(255, 176, 12, 1),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Invoice Summary',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSummaryRow('Invoice ID', widget.invoice.id.substring(0, 8).toUpperCase()),
          _buildSummaryRow('Service', widget.invoice.description),
          _buildSummaryRow('Date', DateFormat('MMM dd, yyyy').format(widget.invoice.createdAt)),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Amount',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '₱${widget.invoice.total.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color.fromARGB(255, 176, 12, 1),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentCategorySelection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.payment,
                  color: Colors.blue,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Choose Payment Method',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Online Payment Option
          _buildPaymentOption(
            category: 'online',
            icon: Icons.credit_card,
            title: 'Online Payment',
            subtitle: 'Pay via GCash, Card, or PayMaya',
            color: Colors.blue,
          ),
          
          const SizedBox(height: 12),
          
          // Cash Payment Option (hidden when feature flag is off)
          if (PaymentConfig.allowCashPayments)
            _buildPaymentOption(
              category: 'cash',
              icon: Icons.money,
              title: 'Cash Payment',
              subtitle: 'Pay with cash and upload photo',
              color: Colors.green,
            ),
        ],
      ),
    );
  }

  Widget _buildPaymentOption({
    required String category,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    final isSelected = _selectedCategory == category;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedCategory = category;
            if (category != 'cash') {
              _cashPhoto = null;
              _receiptPhoto = null;
            }
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? color : Colors.grey[300]!,
              width: isSelected ? 2 : 1,
            ),
            color: isSelected ? color.withOpacity(0.05) : Colors.grey[50],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? color : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCashPaymentInstructions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.amber[900], size: 20),
              const SizedBox(width: 8),
              Text(
                'Cash Payment Instructions',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber[900],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInstructionStep('1', 'Pay the mechanic in cash'),
          _buildInstructionStep('2', 'Take a photo of the cash amount'),
          _buildInstructionStep('3', 'Take a photo of the receipt/invoice'),
          _buildInstructionStep('4', 'Submit for verification'),
        ],
      ),
    );
  }

  Widget _buildInstructionStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.amber[700],
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[800],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCashPhotoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Upload Photos',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        
        // Cash Photo
        _buildPhotoUploadCard(
          title: 'Cash Photo',
          subtitle: 'Photo of the cash amount',
          file: _cashPhoto,
          onTap: () => _takePhoto(isCashPhoto: true),
        ),
        
        const SizedBox(height: 12),
        
        // Receipt Photo
        _buildPhotoUploadCard(
          title: 'Receipt/Invoice Photo',
          subtitle: 'Photo of the receipt or invoice',
          file: _receiptPhoto,
          onTap: () => _takePhoto(isCashPhoto: false),
        ),
      ],
    );
  }

  Widget _buildPhotoUploadCard({
    required String title,
    required String subtitle,
    required File? file,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: file != null ? Colors.green[50] : Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: file != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          file,
                          fit: BoxFit.cover,
                        ),
                      )
                    : Icon(
                        Icons.add_a_photo,
                        color: Colors.grey[400],
                        size: 28,
                      ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                file != null ? Icons.check_circle : Icons.camera_alt,
                color: file != null ? Colors.green : Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _takePhoto({required bool isCashPhoto}) async {
    try {
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (photo != null) {
        setState(() {
          if (isCashPhoto) {
            _cashPhoto = File(photo.path);
          } else {
            _receiptPhoto = File(photo.path);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error taking photo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handlePaymentProceed() async {
    if (_selectedCategory == 'online') {
      await _processOnlinePayment();
    } else if (_selectedCategory == 'cash') {
      await _processCashPayment();
    }
  }

  Future<void> _processOnlinePayment() async {
    setState(() {
      _isProcessing = true;
    });

    try {
      print('💳 Processing direct online payment for invoice: ${widget.invoice.id}');
      
      final supabase = Supabase.instance.client;
      final invoiceId = widget.invoice.id;
      final requestId = widget.invoice.requestId;
      final amount = widget.invoice.total;
      
      // TEMPORARY: Direct payment update (bypass PayMongo since it's not working)
      // Update invoice as paid
      await supabase.from('invoices').update({
        'status': 'paid',
        'paid_at': DateTime.now().toIso8601String(),
        'payment_details': {
          'payment_method': 'gcash',
          'gateway': 'direct_test',
          'amount': amount,
          'paid_at': DateTime.now().toIso8601String(),
        },
      }).eq('id', invoiceId);
      
      // Update service request status
      await supabase.from('service_requests').update({
        'status': 'invoice_paid',
        'payment_status': 'completed',
        'payment_completed_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', requestId);
      
      // Update or create payment record
      final existingPayment = await supabase
          .from('payments')
          .select('id')
          .eq('request_id', requestId)
          .maybeSingle();
          
      if (existingPayment != null) {
        await supabase.from('payments').update({
          'status': 'completed',
          'payment_method': 'gcash',
          'payment_gateway': 'direct_test',
          'processed_at': DateTime.now().toIso8601String(),
        }).eq('request_id', requestId);
      } else {
        // Only insert if provider_id exists
        if (widget.invoice.providerId != null) {
          await supabase.from('payments').insert({
            'request_id': requestId,
            'customer_id': widget.invoice.customerId,
            'provider_id': widget.invoice.providerId,
            'amount': amount,
            'provider_amount': amount * 0.9,
            'platform_fee': amount * 0.1,
            'status': 'completed',
            'payment_method': 'gcash',
            'payment_gateway': 'direct_test',
            'processed_at': DateTime.now().toIso8601String(),
          });
        }
      }
      
      print('✅ Direct online payment completed for invoice: $invoiceId');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment successful! Invoice marked as paid.'),
            backgroundColor: Colors.green,
          ),
        );
        
        Navigator.pop(context, {
          'success': true, 
          'method': 'online', 
          'pending': false,
          'request_id': widget.invoice.requestId,
          'invoice_id': widget.invoice.id,
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  // Show payment UI as bottom sheet on mobile
  Future<void> _showMobilePaymentBottomSheet(String checkoutUrl) async {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: MobilePayMongoScreen(
          checkoutUrl: checkoutUrl,
          invoiceId: widget.invoice.id,
          amount: widget.invoice.total.toStringAsFixed(2),
        ),
      ),
    );
  }

  // Show payment UI as dialog on desktop
  Future<void> _showDesktopPaymentDialog(String checkoutUrl) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.7,
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              // Dialog header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Color(0xFFE53E3E),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Complete Payment',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              // Payment info
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.blue.shade50,
                child: Row(
                  children: [
                    const Icon(Icons.payment, color: Colors.blue),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'PayMongo Payment',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Amount: ₱${widget.invoice.total.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () async {
                        await launchUrl(
                          Uri.parse(checkoutUrl),
                          mode: LaunchMode.externalApplication,
                        );
                      },
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('Open in Browser'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              // WebView content
              Expanded(
                child: kIsWeb
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.web,
                              size: 64,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Please use the "Open in Browser" button above',
                              style: TextStyle(fontSize: 16),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: () async {
                                await launchUrl(
                                  Uri.parse(checkoutUrl),
                                  mode: LaunchMode.externalApplication,
                                );
                              },
                              icon: const Icon(Icons.launch),
                              label: const Text('Open Payment Page'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFE53E3E),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 32,
                                  vertical: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : WebViewWidget(
                        controller: WebViewController()
                          ..setJavaScriptMode(JavaScriptMode.unrestricted)
                          ..setBackgroundColor(const Color(0x00000000))
                          ..setNavigationDelegate(
                            NavigationDelegate(
                              onPageFinished: (url) {
                                if (url.contains('success') ||
                                    url.contains('completed')) {
                                  Navigator.pop(context);
                                }
                              },
                            ),
                          )
                          ..loadRequest(Uri.parse(checkoutUrl)),
                      ),
              ),
              // Bottom info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  border: Border(
                    top: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.security, color: Colors.green.shade600, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Secure payment powered by PayMongo',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _processCashPayment() async {
    // Validate photos
    if (_cashPhoto == null || _receiptPhoto == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload both cash and receipt photos'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      // Upload photos to Supabase Storage
      final supabase = SupabaseService.client;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
    // Upload cash photo
    final cashPhotoPath = 'cash_payments/${widget.invoice.id}_cash_$timestamp.jpg';
    await supabase.storage
      .from('payment-verifications')
      .upload(cashPhotoPath, _cashPhoto!);
    final cashPhotoUrl = supabase.storage
      .from('payment-verifications')
      .getPublicUrl(cashPhotoPath);

    // Upload receipt photo
    final receiptPhotoPath = 'cash_payments/${widget.invoice.id}_receipt_$timestamp.jpg';
    await supabase.storage
      .from('payment-verifications')
      .upload(receiptPhotoPath, _receiptPhoto!);
    final receiptPhotoUrl = supabase.storage
      .from('payment-verifications')
      .getPublicUrl(receiptPhotoPath);

      // Only save uploaded image URLs into the invoice's payment_details JSONB
      // (do not create a separate cash_payment_verifications row here)
      await supabase.from('invoices').update({
        'status': 'pending_verification',
        'selected_payment_method': 'cash',
        'requires_cash_verification': true,
        'payment_details': {
          'method': 'cash',
          'cash_photo_url': cashPhotoUrl,
          'receipt_photo_url': receiptPhotoUrl,
          'submitted_at': DateTime.now().toIso8601String(),
          'verification_status': 'pending',
        }
      }).eq('id', widget.invoice.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cash payment submitted for verification!'),
            backgroundColor: Colors.green,
          ),
        );
        
        Navigator.pop(context, {'success': true, 'method': 'cash'});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting cash payment: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }
}

// PayMongo WebView Screen
class PayMongoWebView extends StatefulWidget {
  final String checkoutUrl;
  final String invoiceId;

  const PayMongoWebView({
    Key? key,
    required this.checkoutUrl,
    required this.invoiceId,
  }) : super(key: key);

  @override
  State<PayMongoWebView> createState() => _PayMongoWebViewState();
}

class _PayMongoWebViewState extends State<PayMongoWebView> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            setState(() {
              _isLoading = true;
            });
          },
          onPageFinished: (url) {
            setState(() {
              _isLoading = false;
            });
            
            // Check if payment was successful
            if (url.contains('success') || url.contains('payment_intent')) {
              Future.delayed(const Duration(seconds: 2), () {
                if (mounted) {
                  Navigator.pop(context, true);
                }
              });
            }
          },
          onNavigationRequest: (request) {
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.checkoutUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Payment'),
        backgroundColor: const Color.fromARGB(255, 176, 12, 1),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context, false),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(
                color: Color.fromARGB(255, 176, 12, 1),
              ),
            ),
        ],
      ),
    );
  }
}
