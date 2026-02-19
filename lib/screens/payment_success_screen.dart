import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import '../main.dart';
import '../services/paymongo_service.dart';
import '../services/auth_service.dart';

class PaymentSuccessScreen extends StatefulWidget {
  final String? serviceRequestId;
  final String? transactionId;
  final double? amount;

  const PaymentSuccessScreen({
    Key? key,
    this.serviceRequestId,
    this.transactionId,
    this.amount,
  }) : super(key: key);

  @override
  State<PaymentSuccessScreen> createState() => _PaymentSuccessScreenState();
}

class _PaymentSuccessScreenState extends State<PaymentSuccessScreen> {
  bool _processingPayment = true;
  String _statusMessage = 'Processing payment...';
  int _countdown = 3;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _processPaymentCompletion();
  }

  Future<void> _processPaymentCompletion() async {
    try {
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Confirming payment...';
      });

      // Get service request ID from URL if provided
      final uri = Uri.base;
      final serviceRequestId = widget.serviceRequestId ?? 
                              uri.queryParameters['request_id'] ?? 
                              uri.queryParameters['service_request_id'] ??
                              uri.queryParameters['invoice_id']; // Also check invoice_id as fallback
      final sessionId = uri.queryParameters['session_id'];
      final urlAmountStr = uri.queryParameters['amount'];
      final parsedAmount = urlAmountStr != null ? double.tryParse(urlAmountStr) : null;
      
      print('🔍 Processing payment completion for request: $serviceRequestId');

      if (serviceRequestId != null) {
        // First try to refresh via PayMongo API for authoritative status
        bool ok = await PayMongoService.instance.refreshCheckoutStatusByRequestId(serviceRequestId);
        if (!ok && sessionId != null) {
          ok = await PayMongoService.instance.refreshCheckoutStatusBySessionId(sessionId);
        }

        if (!ok) {
          // Fallback: directly mark as paid/ready to assign in DB
          await _fallbackMarkPaid(serviceRequestId, parsedAmount ?? widget.amount);
        }
      }

      if (!mounted) return;
      setState(() {
        _processingPayment = false;
        _statusMessage = 'Payment completed successfully!';
      });

      // Start countdown for auto-redirect
      _startCountdown();

    } catch (e) {
      print('❌ Error processing payment completion: $e');
      if (mounted) {
        setState(() {
          _processingPayment = false;
          _statusMessage = 'Payment completed (verification in progress)';
        });
      }

      // Still redirect to dashboard even if status update fails
      _startCountdown();
    }
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      setState(() {
        _countdown--;
      });
      
      if (_countdown <= 0) {
        timer.cancel();
        _navigateToDashboard();
      }
    });
  }

  Future<void> _fallbackMarkPaid(String serviceRequestId, double? amount) async {
    final supabase = Supabase.instance.client;

    if (mounted) {
      setState(() {
        _statusMessage = 'Finalizing payment...';
      });
    }

    // Mark service request as ready_to_assign/completed
    await supabase
        .from('service_requests')
        .update({
          'status': 'ready_to_assign',
          'payment_status': 'completed',
          'payment_completed_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', serviceRequestId);

    // Add entry to request status history
    await supabase
        .from('request_status_history')
        .insert({
          'request_id': serviceRequestId,
          'status': 'ready_to_assign',
          'notes': 'Payment marked complete after return from PayMongo',
          'created_at': DateTime.now().toIso8601String(),
        });

    // Optionally touch payments row if exists
    try {
      final existingPayment = await supabase
          .from('payments')
          .select('id')
          .eq('request_id', serviceRequestId)
          .maybeSingle();

      if (existingPayment != null) {
        await supabase
            .from('payments')
            .update({
              'status': 'completed',
              if (amount != null) 'amount': amount,
              'processed_at': DateTime.now().toIso8601String(),
            })
            .eq('request_id', serviceRequestId);
      }
    } catch (_) {}

    print('✅ Service request set to ready_to_assign (fallback)');
  }

  void _navigateToDashboard() {
    // Get service request ID from URL if provided
    final uri = Uri.base;
    final serviceRequestId = widget.serviceRequestId ?? 
                            uri.queryParameters['request_id'] ?? 
                            uri.queryParameters['service_request_id'] ??
                            uri.queryParameters['invoice_id']; // Also check invoice_id as fallback

    print('🏠 PaymentSuccessScreen: Navigating through AuthWrapper to ensure correct dashboard routing');
    print('🔍 Current user type: ${AuthService.instance.userType}');
    print('🆔 Current user ID: ${AuthService.instance.userId}');

    // 🎯 FIX: Navigate through AuthWrapper instead of directly to RoadAidHomePage
    // This ensures proper authentication context routing (customer → RoadAidHomePage, mechanic → MechanicDashboard)
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => AuthWrapper(
          paymentSuccessData: {
            'success': true,
            'message': 'Payment completed successfully!',
            // RoadAidHomePage expects 'requestId' and 'show_bottom_sheet' keys
            'requestId': serviceRequestId,
            'amount': widget.amount?.toString() ?? '0.00',
            'show_bottom_sheet': true,
          },
        ),
      ),
      (route) => false,
    );
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green.shade50,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Success Icon
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: _processingPayment ? Colors.blue : Colors.green,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: (_processingPayment ? Colors.blue : Colors.green).withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: _processingPayment 
                    ? const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        strokeWidth: 3,
                      )
                    : const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 60,
                      ),
                ),
                
                const SizedBox(height: 32),
                
                // Success Title
                Text(
                  _processingPayment ? 'Processing Payment...' : 'Payment Successful!',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: _processingPayment ? Colors.blue : Colors.green,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 16),
                
                // Status Message
                Text(
                  _statusMessage,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 16),
                
                // Payment Details
                if (widget.amount != null)
                  Text(
                    '₱${widget.amount!.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                
                const SizedBox(height: 8),
                
                if (widget.transactionId != null)
                  Text(
                    'Transaction ID: ${widget.transactionId}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                
                const SizedBox(height: 24),
                
                // Success Message
                if (!_processingPayment)
                  const Text(
                    'Your payment has been processed successfully!\n\nYour QR code for job completion is now ready. Show this to the mechanic when the service is completed.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.black87,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                
                const SizedBox(height: 40),
                
                // Loading Indicator or Navigation Info
                if (_processingPayment) ...[
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Please wait...',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                ] else ...[
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Redirecting to main app in $_countdown second${_countdown == 1 ? '' : 's'}...',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                ],
                
                const SizedBox(height: 32),
                
                // Manual Navigation Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _processingPayment ? null : _navigateToDashboard,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _processingPayment ? Colors.grey : Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      _processingPayment ? 'Processing...' : 'Go to Main App',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
