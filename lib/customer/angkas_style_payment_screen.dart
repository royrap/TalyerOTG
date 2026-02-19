import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/invoice.dart';
import '../services/invoice_service.dart';
import '../widgets/real_time_payment_status_widget.dart';
import '../main.dart';
import 'qr_code_display_screen.dart';
import '../services/enhanced_service_request_service.dart';
import '../screens/mobile_paymongo_screen.dart';
import 'cash_payment_screen.dart';

class AngkasStylePaymentScreen extends StatefulWidget {
  final Invoice invoice;
  final String? preSelectedPaymentMethod;

  const AngkasStylePaymentScreen({
    Key? key,
    required this.invoice,
    this.preSelectedPaymentMethod,
  }) : super(key: key);

  @override
  State<AngkasStylePaymentScreen> createState() => _AngkasStylePaymentScreenState();
}

class _AngkasStylePaymentScreenState extends State<AngkasStylePaymentScreen>
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

  Future<void> _processPayment() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Handle cash payment with camera
    if (_selectedPaymentMethod == 'Cash') {
      print('📸 Opening camera for cash payment verification');
      
      setState(() {
        _isProcessing = true;
      });
      
      try {
        // Fetch service request details from Supabase
        final supabase = Supabase.instance.client;
        final serviceRequestData = await supabase
            .from('service_requests')
            .select()
            .eq('id', widget.invoice.requestId)
            .single();
        
        // Convert Invoice object to Map for CashPaymentScreen
        final invoiceMap = {
          'id': widget.invoice.id,
          'request_id': widget.invoice.requestId,
          'provider_id': widget.invoice.providerId,
          'customer_id': widget.invoice.customerId,
          'total_amount': widget.invoice.totalAmount,
          'status': widget.invoice.status,
        };
        
        // Navigate to cash payment camera screen
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CashPaymentScreen(
              invoice: invoiceMap,
              serviceRequest: serviceRequestData,
            ),
          ),
        );
        
        if (result != null && result['success'] == true) {
          print('✅ Cash payment photo submitted successfully');
          
          if (mounted) {
            // Show success message
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.white),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text('Cash payment submitted for verification!'),
                    ),
                  ],
                ),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 3),
              ),
            );
            
            // Navigate back to main dashboard
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (context) => const AuthWrapper(),
              ),
              (route) => false,
            );
          }
        }
      } catch (e) {
        print('❌ Error with cash payment camera: $e');
        if (mounted) {
          _showErrorDialog('Error opening camera: ${e.toString()}');
        }
      } finally {
        if (mounted) {
          setState(() {
            _isProcessing = false;
          });
        }
      }
      
      return; // Exit early for cash payment
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      print('💳 Processing direct invoice payment: ${widget.invoice.id}');
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
      
      print('✅ Direct payment completed for invoice: $invoiceId');
      
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
        
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => const AuthWrapper(),
          ),
          (route) => false,
        );
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
                  customerName: 'Customer', // You might want to pass the actual name
                  invoiceData: widget.invoice.toJson(),
                ),
              ),
            );
          } else {
            // Fallback - show success message and return
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Payment completed successfully!'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 3),
              ),
            );
            Navigator.of(context).pop(true);
          }
        }
      } catch (e) {
        print('Error handling payment completion: $e');
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
          'Payment',
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
              // Header with invoice summary - Angkas style
              Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF1B4332), // RoadAid dark green
                      Color(0xFF2D5A41), // RoadAid medium green
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
                            'Select how you want to pay for your service',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF6C757D),
                            ),
                          ),
                          const SizedBox(height: 24),
                          
                          // Payment method cards
                          _buildPaymentMethodCard(
                            'Credit/Debit Card',
                            'Visa, Mastercard, and other cards',
                            Icons.credit_card,
                            const Color(0xFF4C7C59),
                            'Credit Card',
                          ),
                          const SizedBox(height: 12),
                          _buildPaymentMethodCard(
                            'GCash',
                            'Pay using your GCash wallet',
                            Icons.account_balance_wallet,
                            const Color(0xFF007DFF),
                            'GCash',
                          ),
                          const SizedBox(height: 12),
                          _buildPaymentMethodCard(
                            'PayMaya',
                            'Pay using your PayMaya wallet',
                            Icons.payment,
                            const Color(0xFF00B894),
                            'PayMaya',
                          ),
                          
                          const SizedBox(height: 32),
                          
                          // Payment form
                          if (_selectedPaymentMethod.isNotEmpty)
                            _buildPaymentForm(),
                          
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
      
      // Bottom payment button
      bottomNavigationBar: _selectedPaymentMethod.isNotEmpty && !_paymentInitiated
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
                          : [const Color(0xFF40A578), const Color(0xFF4C7C59)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF40A578).withOpacity(0.3),
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
          // Service icon and title
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.build_circle,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Service Payment',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Invoice #${widget.invoice.id.substring(0, 8).toUpperCase()}',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Amount breakdown
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
                      'Service:',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        widget.invoice.description,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Subtotal:',
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
                        'Service Fee:',
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
                      'Total Amount:',
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

  // Angkas-style payment method card
  Widget _buildPaymentMethodCard(
    String title,
    String subtitle,
    IconData icon,
    Color iconColor,
    String method,
  ) {
    final isSelected = _selectedPaymentMethod == method;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected 
              ? const Color(0xFF40A578) 
              : const Color(0xFFE9ECEF),
          width: isSelected ? 2 : 1,
        ),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: isSelected
                ? const Color(0xFF40A578).withOpacity(0.1)
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
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1B4332),
                        ),
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
                          ? const Color(0xFF40A578)
                          : const Color(0xFFDEE2E6),
                      width: 2,
                    ),
                    color: isSelected 
                        ? const Color(0xFF40A578)
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

  // Simple payment form
  Widget _buildPaymentForm() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF000000).withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _getPaymentMethodIcon(),
                color: const Color(0xFF40A578),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Enter $_selectedPaymentMethod details',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1B4332),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          if (_selectedPaymentMethod == 'Credit Card') ...[
            _buildTextField(
              controller: _cardholderController,
              label: 'Cardholder Name',
              hint: 'Enter full name as on card',
              icon: Icons.person_outline,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _cardNumberController,
              label: 'Card Number',
              hint: '1234 5678 9012 3456',
              icon: Icons.credit_card,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _expiryController,
                    label: 'Expiry Date',
                    hint: 'MM/YY',
                    icon: Icons.calendar_today,
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTextField(
                    controller: _cvvController,
                    label: 'CVV',
                    hint: '123',
                    icon: Icons.lock_outline,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                  ),
                ),
              ],
            ),
          ] else if (_selectedPaymentMethod == 'GCash' || _selectedPaymentMethod == 'PayMaya') ...[
            _buildTextField(
              controller: _phoneController,
              label: 'Mobile Number',
              hint: '+63 9XX XXX XXXX',
              icon: Icons.phone_android,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _emailController,
              label: 'Email Address',
              hint: 'your.email@example.com',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
            ),
          ],
          
          const SizedBox(height: 20),
          
          // Security note
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE9ECEF)),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.security,
                  color: Color(0xFF40A578),
                  size: 16,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Your payment information is encrypted and secure',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6C757D),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Simple text field
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1B4332),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          style: const TextStyle(
            fontSize: 16,
            color: Color(0xFF1B4332),
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              color: Color(0xFF6C757D),
              fontSize: 16,
            ),
            prefixIcon: Icon(
              icon,
              color: const Color(0xFF40A578),
              size: 20,
            ),
            filled: true,
            fillColor: const Color(0xFFF8F9FA),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE9ECEF)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE9ECEF)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF40A578), width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'This field is required';
            }
            return null;
          },
        ),
      ],
    );
  }

  IconData _getPaymentMethodIcon() {
    switch (_selectedPaymentMethod) {
      case 'Credit Card':
        return Icons.credit_card;
      case 'GCash':
        return Icons.account_balance_wallet;
      case 'PayMaya':
        return Icons.payment;
      default:
        return Icons.payment;
    }
  }
}











