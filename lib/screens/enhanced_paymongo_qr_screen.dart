import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:async';
import '../models/invoice.dart';
import '../services/paymongo_service.dart';
import '../services/customer_invoice_service.dart';

class PayMongoQRPaymentScreen extends StatefulWidget {
  final Invoice invoice;
  final String? paymentMethod;

  const PayMongoQRPaymentScreen({
    super.key,
    required this.invoice,
    this.paymentMethod,
  });

  @override
  State<PayMongoQRPaymentScreen> createState() => _PayMongoQRPaymentScreenState();
}

class _PayMongoQRPaymentScreenState extends State<PayMongoQRPaymentScreen>
    with TickerProviderStateMixin {
  
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  
  Timer? _statusCheckTimer;
  Timer? _timeoutTimer;
  
  String? _qrCodeData;
  String _paymentStatus = 'generating';
  String _statusMessage = 'Generating payment QR code...';
  bool _isLoading = true;
  int _timeRemaining = 300; // 5 minutes
  
  @override
  void initState() {
    super.initState();
    
    _setupAnimations();
    _generateQRPayment();
    _startCountdown();
  }

  void _setupAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _pulseController.repeat(reverse: true);
  }

  Future<void> _generateQRPayment() async {
    try {
      setState(() {
        _isLoading = true;
        _statusMessage = 'Creating secure payment link...';
      });

      // Create PayMongo checkout session for QR payment
      final checkoutSession = await PayMongoService.instance.createCheckoutSession(
        invoiceId: widget.invoice.id,
        amount: widget.invoice.totalAmount,
        description: 'RoadAid Service Payment - ${widget.invoice.description}',
        successUrl: 'RoadAid://payment-success?invoice_id=${widget.invoice.id}',
        cancelUrl: 'RoadAid://payment-cancel',
      );

      if (checkoutSession != null) {
        final checkoutUrl = checkoutSession['attributes']['checkout_url'];
        
        setState(() {
          _qrCodeData = checkoutUrl;
          _paymentStatus = 'waiting';
          _statusMessage = 'Scan QR code with ${widget.paymentMethod ?? 'your payment app'}';
          _isLoading = false;
        });

        _startPaymentStatusCheck();
      } else {
        throw Exception('Failed to create payment session');
      }
    } catch (e) {
      setState(() {
        _paymentStatus = 'error';
        _statusMessage = 'Failed to generate payment: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  void _startPaymentStatusCheck() {
    _statusCheckTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      try {
        final status = await CustomerInvoiceService.instance
            .checkPayMongoPaymentStatus(widget.invoice.id);
        
        if (status != null) {
          final paymentStatus = status['status']?.toString().toLowerCase();
          
          if (paymentStatus == 'succeeded' || paymentStatus == 'paid') {
            _handlePaymentSuccess();
            timer.cancel();
          } else if (paymentStatus == 'failed' || paymentStatus == 'cancelled') {
            _handlePaymentFailure('Payment was cancelled or failed');
            timer.cancel();
          }
        }
      } catch (e) {
        print('Error checking payment status: $e');
      }
    });
  }

  void _startCountdown() {
    _timeoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeRemaining > 0) {
        setState(() {
          _timeRemaining--;
        });
      } else {
        _handlePaymentTimeout();
        timer.cancel();
      }
    });
  }

  void _handlePaymentSuccess() {
    _statusCheckTimer?.cancel();
    _timeoutTimer?.cancel();
    
    setState(() {
      _paymentStatus = 'success';
      _statusMessage = 'Payment completed successfully!';
    });

    // Show success animation
    _showSuccessAnimation();
    
    // Return success after delay
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.pop(context, true);
      }
    });
  }

  void _handlePaymentFailure(String reason) {
    _statusCheckTimer?.cancel();
    _timeoutTimer?.cancel();
    
    setState(() {
      _paymentStatus = 'failed';
      _statusMessage = reason;
    });
  }

  void _handlePaymentTimeout() {
    setState(() {
      _paymentStatus = 'timeout';
      _statusMessage = 'Payment session expired. Please try again.';
    });
  }

  void _showSuccessAnimation() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 48,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Payment Successful!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '₱${widget.invoice.totalAmount.toStringAsFixed(2)} paid via ${widget.paymentMethod}',
                style: const TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _statusCheckTimer?.cancel();
    _timeoutTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 176, 12, 1),
        title: Text(
          '${widget.paymentMethod ?? 'QR'} Payment',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context, false),
        ),
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // Header info
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withAlpha(26),
                      spreadRadius: 2,
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color.fromARGB(255, 176, 12, 1).withAlpha(26),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.receipt_long,
                            color: Color.fromARGB(255, 176, 12, 1),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Invoice #${widget.invoice.id.substring(0, 8)}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                widget.invoice.description,
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total Amount:',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '₱${widget.invoice.totalAmount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color.fromARGB(255, 176, 12, 1),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // QR Code Section
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withAlpha(26),
                        spreadRadius: 2,
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_isLoading) ...[
                        const CircularProgressIndicator(
                          color: Color.fromARGB(255, 176, 12, 1),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _statusMessage,
                          style: const TextStyle(fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                      ] else if (_paymentStatus == 'waiting') ...[
                        AnimatedBuilder(
                          animation: _pulseAnimation,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: _pulseAnimation.value,
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: const Color.fromARGB(255, 176, 12, 1),
                                    width: 2,
                                  ),
                                ),
                                child: QrImageView(
                                  data: _qrCodeData!,
                                  size: 200,
                                  version: QrVersions.auto,
                                  backgroundColor: Colors.white,
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 24),
                        Text(
                          _statusMessage,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Open your ${widget.paymentMethod} app and scan the QR code above',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ] else if (_paymentStatus == 'success') ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 48,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _statusMessage,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ] else if (_paymentStatus == 'failed' || _paymentStatus == 'timeout') ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.error,
                            color: Colors.white,
                            size: 48,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _statusMessage,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.red,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _timeRemaining = 300;
                              _paymentStatus = 'generating';
                            });
                            _generateQRPayment();
                            _startCountdown();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color.fromARGB(255, 176, 12, 1),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 12,
                            ),
                          ),
                          child: const Text('Try Again'),
                        ),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.error,
                            color: Colors.white,
                            size: 48,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _statusMessage,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.red,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Timer and status bar
              if (_paymentStatus == 'waiting') ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.timer,
                        color: Colors.blue[700],
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Time remaining: ${_formatTime(_timeRemaining)}',
                        style: TextStyle(
                          color: Colors.blue[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          value: _timeRemaining / 300,
                          strokeWidth: 3,
                          backgroundColor: Colors.blue[200],
                          valueColor: AlwaysStoppedAnimation(Colors.blue[700]),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // Instructions
              if (_paymentStatus == 'waiting') ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.amber[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber[200]!),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info,
                            color: Colors.amber[700],
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Payment Instructions:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '1. Open your ${widget.paymentMethod} app\n'
                        '2. Tap "Scan QR" or camera icon\n'
                        '3. Point camera at the QR code above\n'
                        '4. Confirm payment details\n'
                        '5. Complete the payment',
                        style: TextStyle(
                          color: Colors.amber[800],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }
}










