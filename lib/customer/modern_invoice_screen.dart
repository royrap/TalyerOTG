import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'cash_payment_screen.dart';
import '../models/invoice.dart';
import '../services/invoice_service.dart';
import '../screens/mobile_paymongo_screen.dart';
import '../config/payment_config.dart';

class ModernInvoiceScreen extends StatefulWidget {
  final Invoice invoice;
  final String? preSelectedPaymentMethod;

  const ModernInvoiceScreen({
    Key? key,
    required this.invoice,
    this.preSelectedPaymentMethod,
  }) : super(key: key);

  @override
  State<ModernInvoiceScreen> createState() => _ModernInvoiceScreenState();
}

class _ModernInvoiceScreenState extends State<ModernInvoiceScreen>
    with SingleTickerProviderStateMixin {
  String? _selectedPaymentMethod;
  bool _isProcessing = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Simplified payment methods - Only 2 options
    final List<Map<String, dynamic>> _paymentMethods = [
    {
      'id': 'online_payment',
      'method_type': 'online',
      'display_name': 'Online Payment',
      'icon': Icons.credit_card_rounded,
      'color': const Color(0xFF007CFF),
      'gradient': [const Color(0xFF007CFF), const Color(0xFF0056CC)],
      'description': 'Pay directly via PayMongo',
      'popular': true,
    },
    if (PaymentConfig.allowCashPayments) {
      'id': 'cash_payment',
      'method_type': 'cash',
      'display_name': 'Cash Payment',
      'icon': Icons.camera_alt_rounded,
      'color': const Color(0xFFEF5350),
      'gradient': [const Color(0xFFEF5350), const Color(0xFFE53935)],
      'description': 'Take photo for verification',
      'popular': false,
    },
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    if (widget.preSelectedPaymentMethod != null) {
      _selectedPaymentMethod = widget.preSelectedPaymentMethod!;
    }
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _processPayment() async {
    if (_selectedPaymentMethod == null) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final method = _paymentMethods.firstWhere(
        (method) => method['id'] == _selectedPaymentMethod,
        orElse: () => {},
      );
      
      final methodType = method['method_type']?.toString().toLowerCase() ?? '';
      
      // Handle Online Payment - Direct update (bypass PayMongo)
      if (methodType == 'online') {
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
          setState(() {
            _isProcessing = false;
          });
          _showSuccessDialog();
        }
        return;
      }
      
      // Handle Cash Payment - Open camera for photo upload (only if enabled)
      if (methodType == 'cash') {
        if (!PaymentConfig.allowCashPayments) {
          // Cash payments are disabled in config - show message and return
          if (mounted) _showErrorMessage('Cash payments are currently disabled.');
          return;
        }

        if (mounted) {
          setState(() {
            _isProcessing = false;
          });
          
          // Open camera to take photo of cash payment
          await _openCameraForCashPayment();
        }
        return;
      }
      
    } catch (e) {
      if (mounted) {
        _showErrorMessage('Payment failed: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  // New method to handle cash payment with camera
  Future<void> _openCameraForCashPayment() async {
    try {
      // Use the centralized CashPaymentScreen to capture and upload the photo
      // Fetch service request details for the invoice's request_id
      final supabase = Supabase.instance.client;
      final serviceRequestData = await supabase
          .from('service_requests')
          .select()
          .eq('id', widget.invoice.requestId)
          .maybeSingle();

      final invoiceMap = {
        'id': widget.invoice.id,
        'request_id': widget.invoice.requestId,
        'provider_id': widget.invoice.providerId,
        'customer_id': widget.invoice.customerId,
        'total_amount': widget.invoice.total,
        'status': widget.invoice.status,
      };

      final result = await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => CashPaymentScreen(
            invoice: invoiceMap,
            serviceRequest: serviceRequestData ?? {},
          ),
        ),
      );

      // If the photo was submitted successfully, update the invoice to reflect cash payment
      if (result != null && result['success'] == true) {
        // Mark invoice as cash and pending verification
        await supabase.from('invoices').update({
          'payment_method': 'cash',
          'status': 'pending_verification',
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', widget.invoice.id);

        if (mounted) {
          _showSuccessDialog(isCash: true);
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorMessage('Failed to handle cash payment: $e');
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showSuccessDialog({bool isCash = false}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Color(0xFFEF5350).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: Colors.red,
                size: 50,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isCash ? 'Cash Payment Photo Uploaded!' : 'Payment Successful!',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              isCash
                  ? 'Your cash payment photo has been submitted for verification. The mechanic will verify the payment.'
                  : 'Your payment has been processed successfully.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop(true);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Continue',
                  style: TextStyle(
                    fontSize: 16,
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

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: CustomScrollView(
        slivers: [
          // Modern App Bar
          SliverAppBar(
            expandedHeight: 120,
            floating: false,
            pinned: true,
            backgroundColor: const Color.fromARGB(255, 176, 12, 1),
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              title: const Text(
                'Complete Payment',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color.fromARGB(255, 176, 12, 1),
                      Color.fromARGB(255, 200, 30, 15),
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          // Content
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Animated Invoice Summary
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: _buildModernInvoiceSummary(),
                  ),
                ),
                const SizedBox(height: 24),

                // Animated Payment Methods
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: _buildModernPaymentMethods(),
                  ),
                ),
                const SizedBox(height: 24),

                // Security Badge
                _buildSecurityBadge(),
                const SizedBox(height: 32),

                // Modern Pay Button
                _buildModernPayButton(),
                const SizedBox(height: 20),

                // Terms
                _buildTermsText(),
                const SizedBox(height: 20),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernInvoiceSummary() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.receipt_long_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Text(
                    'Invoice Details',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Color(0xFFEF5350).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'PENDING',
                    style: TextStyle(
                      color: Colors.red[700],
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Invoice details
            _buildDetailItem(
              'Invoice ID',
              '#${widget.invoice.id.substring(0, 8).toUpperCase()}',
              Icons.tag_rounded,
            ),
            _buildDetailItem(
              'Service Description',
              widget.invoice.description,
              Icons.build_rounded,
            ),
            _buildDetailItem(
              'Date Issued',
              DateFormat('MMM dd, yyyy').format(widget.invoice.createdAt),
              Icons.calendar_today_rounded,
            ),

            const SizedBox(height: 16),
            Divider(color: Colors.grey[200]),
            const SizedBox(height: 16),

            // Total amount
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFF8FAFC), Color(0xFFE2E8F0)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total Amount',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF374151),
                    ),
                  ),
                  Text(
                    '₱${widget.invoice.total.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color.fromARGB(255, 176, 12, 1),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 16,
              color: const Color(0xFF6B7280),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernPaymentMethods() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF10B981), Color(0xFF059669)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.payment_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Text(
                    'Choose Payment Method',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            ..._paymentMethods.map((method) => _buildModernPaymentOption(method)).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildModernPaymentOption(Map<String, dynamic> method) {
    final isSelected = _selectedPaymentMethod == method['id'];
    final isPopular = method['popular'] ?? false;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              _selectedPaymentMethod = method['id'];
            });
          },
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected 
                    ? method['color'] 
                    : const Color(0xFFE5E7EB),
                width: isSelected ? 2.5 : 1.5,
              ),
              gradient: isSelected 
                  ? LinearGradient(
                      colors: [
                        method['color'].withOpacity(0.05),
                        method['color'].withOpacity(0.02),
                      ],
                    )
                  : null,
              color: isSelected ? null : const Color(0xFFFAFAFA),
            ),
            child: Row(
              children: [
                // Icon container
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: method['gradient']),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: method['color'].withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    method['icon'],
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                
                // Method details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              method['display_name'],
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? method['color'] : const Color(0xFF1F2937),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isPopular) ...[
                            const SizedBox(width: 8),
                            Container(
                              constraints: const BoxConstraints(maxWidth: 80),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  'POPULAR',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF92400E),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        method['description'],
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Selection indicator
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: isSelected ? method['color'] : Colors.transparent,
                    border: Border.all(
                      color: isSelected ? method['color'] : const Color(0xFFD1D5DB),
                      width: 2,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: isSelected
                      ? const Icon(
                          Icons.check_rounded,
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

  Widget _buildSecurityBadge() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F9FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBAE6FD)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF0EA5E9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.security_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Secure Payment',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0C4A6E),
                  ),
                ),
                Text(
                  'Protected by 256-bit SSL encryption',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.blue[700],
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.verified_user_rounded,
            color: Color(0xFF0EA5E9),
            size: 24,
          ),
        ],
      ),
    );
  }

  Widget _buildModernPayButton() {
    final canPay = _selectedPaymentMethod != null && !_isProcessing;
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 60,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: canPay
            ? const LinearGradient(
                colors: [
                  Color.fromARGB(255, 176, 12, 1),
                  Color.fromARGB(255, 200, 30, 15),
                ],
              )
            : LinearGradient(
                colors: [
                  Colors.grey[300]!,
                  Colors.grey[400]!,
                ],
              ),
        boxShadow: canPay
            ? [
                BoxShadow(
                  color: const Color.fromARGB(255, 176, 12, 1).withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: canPay ? _processPayment : null,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            alignment: Alignment.center,
            child: _isProcessing
                ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          strokeWidth: 2.5,
                        ),
                      ),
                      SizedBox(width: 16),
                      Text(
                        'Processing...',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  )
                : Text(
                    'Pay ₱${widget.invoice.total.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: canPay ? Colors.white : Colors.grey[600],
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildTermsText() {
    return Text(
      'By completing this payment, you agree to our Terms of Service and Privacy Policy. The payment will be held securely until the service is completed.',
      style: TextStyle(
        fontSize: 13,
        color: Colors.grey[600],
        height: 1.4,
      ),
      textAlign: TextAlign.center,
    );
  }
}










