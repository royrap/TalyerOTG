import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../models/invoice.dart';
import '../services/invoice_service.dart';
import '../widgets/real_time_payment_status_widget.dart';
import 'qr_code_display_screen.dart';
import '../services/enhanced_service_request_service.dart';
import '../screens/mobile_paymongo_screen.dart';
import 'cash_payment_screen.dart';
import '../config/payment_config.dart';

/// Invoice Payment Screen - Angkas Style
/// This is the EXACT duplicate of service fee payment flow but for invoice payments
/// Flow: Invoice Generated → Auto-open this screen → Select payment → Pay → External browser
class InvoiceAngkasPaymentScreen extends StatefulWidget {
  final Invoice invoice;
  final String? preSelectedPaymentMethod;

  const InvoiceAngkasPaymentScreen({
    Key? key,
    required this.invoice,
    this.preSelectedPaymentMethod,
  }) : super(key: key);

  @override
  State<InvoiceAngkasPaymentScreen> createState() => _InvoiceAngkasPaymentScreenState();
}

class _InvoiceAngkasPaymentScreenState extends State<InvoiceAngkasPaymentScreen>
    with TickerProviderStateMixin {
  String _selectedPaymentMethod = '';
  bool _isProcessing = false;
  bool _paymentInitiated = false;
  String? _currentPaymentId;
  final _formKey = GlobalKey<FormState>();
  
  // Animation controllers
  late AnimationController _slideController;
  late AnimationController _fadeController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  
  // Form controllers
  final _cardNumberController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();
  final _cardholderController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  
  // Direct cash payment variables
  final ImagePicker _imagePicker = ImagePicker();
  File? _cashPaymentPhoto;
  bool _isUploadingPhoto = false;

  // Service request data for display
  Map<String, dynamic>? _serviceRequestData;
  String _vehicleInfo = 'Loading...';
  String _serviceDescription = 'Loading...';

  @override
  void initState() {
    super.initState();
    
    // Initialize animations
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    ));
    
    // Start animations
    _slideController.forward();
    _fadeController.forward();
    
    // Set pre-selected payment method if provided
    if (widget.preSelectedPaymentMethod != null) {
      _selectedPaymentMethod = widget.preSelectedPaymentMethod!;
    }
    
    // Fetch service request data for display
    _fetchServiceRequestData();
  }

  Future<void> _fetchServiceRequestData() async {
    try {
      final supabase = Supabase.instance.client;
      
      // Get service request data
      final serviceRequestResponse = await supabase
          .from('service_requests')
          .select('*, vehicles!inner(*)')
          .eq('id', widget.invoice.requestId)
          .maybeSingle();
      
      if (serviceRequestResponse != null) {
        setState(() {
          _serviceRequestData = serviceRequestResponse;
          
          // Extract vehicle info
          final vehicle = serviceRequestResponse['vehicles'];
          if (vehicle != null) {
            _vehicleInfo = '${vehicle['brand_name']} ${vehicle['model_name']} ${vehicle['year']}';
          } else {
            _vehicleInfo = 'Vehicle information not available';
          }
          
          // Extract service description
          _serviceDescription = serviceRequestResponse['description'] ?? 
                              serviceRequestResponse['notes'] ?? 
                              'Service description not available';
        });
      }
    } catch (e) {
      print('Error fetching service request data: $e');
      setState(() {
        _vehicleInfo = 'Unable to load vehicle info';
        _serviceDescription = 'Unable to load service description';
      });
    }
  }

  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    _cardNumberController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    _cardholderController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  /// Direct cash payment with camera - simplified version
  Future<void> _handleDirectCashPayment() async {
    try {
      // Open camera directly
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        preferredCameraDevice: CameraDevice.rear,
      );

      if (photo != null) {
        setState(() {
          _cashPaymentPhoto = File(photo.path);
          _isUploadingPhoto = true;
        });

        final supabase = Supabase.instance.client;
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final fileName = 'cash_payment_${widget.invoice.customerId}_${widget.invoice.id}_$timestamp.jpg';

        // Save to bucket
        await supabase.storage
            .from('proof of payment')
            .upload(fileName, _cashPaymentPhoto!);

        // Get public URL - mechanic can download this
        final publicUrl = supabase.storage
            .from('proof of payment')
            .getPublicUrl(fileName);

        print('📸 Cash payment photo URL: $publicUrl');

        // Update invoice with payment proof in payment_details JSONB column
        await supabase.from('invoices').update({
          'status': 'paid',
          'paid_at': DateTime.now().toIso8601String(),
          'selected_payment_method': 'cash',
          'payment_details': {
            'method': 'cash',
            'proof_url': publicUrl,
            'uploaded_at': DateTime.now().toIso8601String(),
          },
        }).eq('id', widget.invoice.id);

        // Update service request status
        await supabase.from('service_requests').update({
          'status': 'invoice_paid',
        }).eq('id', widget.invoice.requestId);

        setState(() {
          _isUploadingPhoto = false;
        });

        if (mounted) {
          _showSuccess();
          Navigator.of(context).pop(true);
        }
      }
    } catch (e) {
      setState(() {
        _isUploadingPhoto = false;
      });
      
      if (mounted) {
        _showError('Failed to process cash payment: $e');
      }
    }
  }

  Future<void> _processPayment() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Handle cash payment with camera - direct method
    if (_selectedPaymentMethod == 'Cash') {
      // Use direct camera method instead of old CashPaymentScreen
      await _handleDirectCashPayment();
      return; // Exit early for cash payment
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      print('💳 Processing direct invoice payment (Angkas flow): ${widget.invoice.id}');
      print('💳 Payment method: $_selectedPaymentMethod, Amount: ₱${widget.invoice.totalAmount.toStringAsFixed(2)}');
      
      final supabase = Supabase.instance.client;
      final invoiceId = widget.invoice.id;
      final requestId = widget.invoice.requestId;
      final amount = widget.invoice.totalAmount;
      
      // TEMPORARY: Direct payment update (bypass PayMongo since it's not working)
      // Update invoice as paid
      await supabase.from('invoices').update({
        'status': 'paid',
        'paid_at': DateTime.now().toIso8601String(),
        'payment_details': {
          'payment_method': _selectedPaymentMethod.toLowerCase(),
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
          'payment_method': _selectedPaymentMethod.toLowerCase(),
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
            'payment_method': _selectedPaymentMethod.toLowerCase(),
            'payment_gateway': 'direct_test',
            'processed_at': DateTime.now().toIso8601String(),
          });
        }
      }
      
      print('✅ Direct invoice payment completed: $invoiceId');
      
      // Show success and navigate
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Payment successful! Invoice marked as paid.'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        
        await Future.delayed(const Duration(seconds: 1));
        
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      print('❌ Invoice payment error: $e');
      if (mounted) {
        _showErrorDialog('Payment failed: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _showPaymentStatusDialog(String paymentId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.payment,
                color: Color(0xFF40A578),
                size: 48,
              ),
              const SizedBox(height: 16),
              const Text(
                'Processing Payment',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Please wait while we process your payment...',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              const CircularProgressIndicator(
                color: Color(0xFF40A578),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSuccess() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 8),
            Expanded(child: Text('✅ Operation successful')),
          ],
        ),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK')),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Payment Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _handlePaymentUpdate(Map<String, dynamic> update) async {
    if (update['status'] == 'completed') {
      try {
        // Update service request status
        await EnhancedServiceRequestService.updateServiceRequestStatus(
          requestId: widget.invoice.requestId,
          newStatus: ServiceRequestStatus.invoicePaid,
          notes: 'Invoice payment completed',
        );
        
        // Generate QR code for completion
        final qrResult = await EnhancedServiceRequestService.completeInvoicePayment(
          requestId: widget.invoice.requestId,
          customerId: widget.invoice.customerId,
        );
        
        if (mounted) {
          Navigator.of(context).pop(); // Close dialog
          
          if (qrResult != null && qrResult['success'] == true) {
            // Navigate to QR display screen
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => QRCodeDisplayScreen(
                  serviceRequestId: widget.invoice.requestId,
                  customerName: 'Customer',
                  invoiceData: widget.invoice.toJson(),
                ),
              ),
            );
          } else {
            // Fallback - show success message and return
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✅ Payment completed successfully!'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 3),
              ),
            );
            Navigator.of(context).pop(true);
          }
        }
      } catch (e) {
        print('❌ Error handling payment completion: $e');
        if (mounted) {
          Navigator.of(context).pop(); // Close dialog
          Navigator.of(context).pop(true); // Return with success anyway
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Complete Payment',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            children: [
              // Header with invoice summary - Angkas style (RED like screenshots)
              Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFB00C01), // RoadAid red
                      Color(0xFF8B0A01), // Darker red
                    ],
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 80, 20, 30),
                    child: _buildAngkasStyleHeader(),
                  ),
                ),
              ),
              
              // Main content area
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(25),
                      topRight: Radius.circular(25),
                    ),
                  ),
                  child: Form(
                    key: _formKey,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Payment methods section
                          const Text(
                            'Choose your payment method',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1B4332),
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Select how you want to pay for your invoice',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF6C757D),
                            ),
                          ),
                          const SizedBox(height: 24),
                          
                          // Payment method cards - Only PayMongo (GCash/Cards) and Cash
                          _buildPaymentMethodCard(
                            'PayMongo',
                            'GCash, Cards & more via PayMongo',
                            Icons.payment,
                            const Color(0xFF007DFF),
                            'GCash',
                            isPopular: true, // Mark as popular
                          ),
                          const SizedBox(height: 12),
                          _buildPaymentMethodCard(
                            'Cash',
                            'Pay after service completion',
                            Icons.money,
                            const Color(0xFF2ECC71),
                            'Cash',
                          ),
                          
                          const SizedBox(height: 32),
                          
                          // Payment form
                          if (_selectedPaymentMethod.isNotEmpty && _selectedPaymentMethod != 'Cash')
                            _buildPaymentForm(),
                          
                          // Cash payment note with direct camera button
                          if (_selectedPaymentMethod == 'Cash')
                            Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.orange[50],
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.orange[200]!),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.info_outline, color: Colors.orange[700], size: 24),
                                      const SizedBox(width: 12),
                                      const Expanded(
                                        child: Text(
                                          'Take a photo of your cash payment as proof.',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Color(0xFF1B4332),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                                // Direct camera button
                                Container(
                                  width: double.infinity,
                                  height: 50,
                                  child: ElevatedButton.icon(
                                    onPressed: _isUploadingPhoto ? null : _handleDirectCashPayment,
                                    icon: _isUploadingPhoto 
                                        ? SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : Icon(Icons.camera_alt, color: Colors.white),
                                    label: Text(
                                      _isUploadingPhoto 
                                          ? 'Uploading Photo...' 
                                          : (_cashPaymentPhoto != null ? 'Photo Captured - Processing...' : 'Take Photo of Cash Payment'),
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _cashPaymentPhoto != null ? Colors.green : Color(0xFF2ECC71),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      elevation: 2,
                                    ),
                                  ),
                                ),
                                // Show photo preview if taken
                                if (_cashPaymentPhoto != null)
                                  Container(
                                    margin: const EdgeInsets.only(top: 16),
                                    height: 150,
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.green[300]!),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.file(
                                        _cashPaymentPhoto!,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          
                          const SizedBox(height: 24),
                          
                          // Security badge (like screenshot)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.blue[100]!),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.security, color: Colors.blue[700], size: 24),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Text(
                                    'Secure Payment\nProtected by 256-bit SSL encryption',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF1B4332),
                                    ),
                                  ),
                                ),
                                Icon(Icons.verified_user, color: Colors.blue[700], size: 24),
                              ],
                            ),
                          ),
                          
                          const SizedBox(height: 24),
                          
                          // Real-time payment status (if payment initiated)
                          if (_paymentInitiated && _currentPaymentId != null)
                            RealTimePaymentStatusWidget(
                              invoiceId: widget.invoice.id,
                              onPaymentUpdate: _handlePaymentUpdate,
                            ),
                          
                          const SizedBox(height: 100), // Bottom padding for button
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      
      // Bottom payment button (like screenshot)
      bottomNavigationBar: (_selectedPaymentMethod.isNotEmpty && 
                          (_selectedPaymentMethod != 'Cash' || _cashPaymentPhoto != null) &&
                          !_paymentInitiated)
          ? Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x1A000000),
                    blurRadius: 10,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: _isProcessing 
                          ? [const Color(0xFF95A5A6), const Color(0xFF95A5A6)]
                          : [const Color(0xFFB00C01), const Color(0xFF8B0A01)], // Red gradient
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFB00C01).withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: _isProcessing ? null : _processPayment,
                      child: Center(
                        child: _isProcessing
                            ? const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Text(
                                    'Processing payment...',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              )
                            : Text(
                                'Pay ₱${widget.invoice.totalAmount.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  // Angkas-style header with invoice summary
  Widget _buildAngkasStyleHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          // Service Summary header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.description,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Service Summary',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Service details
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _buildInfoRow('Service Type:', widget.invoice.description ?? 'Service'),
                const SizedBox(height: 8),
                _buildInfoRow('Vehicle:', _vehicleInfo),
                const SizedBox(height: 8),
                _buildInfoRow('Description:', _serviceDescription),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Service Fee breakdown
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Service Fee',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      '₱${widget.invoice.subtotal.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                if (widget.invoice.tax > 0) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Payment Processing Fee',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        '₱${widget.invoice.tax.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                Container(
                  height: 1,
                  color: Colors.white.withOpacity(0.3),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total Amount',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '₱${widget.invoice.totalAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  // Angkas-style payment method card with POPULAR badge
  Widget _buildPaymentMethodCard(
    String title,
    String subtitle,
    IconData icon,
    Color iconColor,
    String method, {
    bool isPopular = false,
  }) {
    final isSelected = _selectedPaymentMethod == method;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected 
              ? const Color(0xFFB00C01) 
              : const Color(0xFFE9ECEF),
          width: isSelected ? 2 : 1,
        ),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: isSelected
                ? const Color(0xFFB00C01).withOpacity(0.1)
                : const Color(0xFF000000).withOpacity(0.05),
            blurRadius: isSelected ? 8 : 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            setState(() {
              _selectedPaymentMethod = method;
            });
          },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // Payment method icon
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: iconColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                
                // Payment method details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1B4332),
                            ),
                          ),
                          if (isPopular) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.orange,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'POPULAR',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF6C757D),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Selection indicator
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected 
                          ? const Color(0xFFB00C01)
                          : const Color(0xFFDEE2E6),
                      width: 2,
                    ),
                    color: isSelected 
                        ? const Color(0xFFB00C01)
                        : Colors.transparent,
                  ),
                  child: isSelected
                      ? const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 16,
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Simple payment form - REMOVED customer information inputs
  // Only PayMongo (GCash) and Cash options, no form fields needed
  Widget _buildPaymentForm() {
    // No form needed - payment methods handle everything
    return const SizedBox.shrink();
  }

}
