import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import '../services/qr_code_service.dart';
import '../services/auth_service.dart';
import '../services/user_data_service.dart';
import '../widgets/review_dialog.dart';

class JobCompletionQRScreen extends StatefulWidget {
  final String serviceRequestId;
  final Map<String, dynamic> jobDetails;

  const JobCompletionQRScreen({
    Key? key,
    required this.serviceRequestId,
    required this.jobDetails,
  }) : super(key: key);

  @override
  State<JobCompletionQRScreen> createState() => _JobCompletionQRScreenState();
}

class _JobCompletionQRScreenState extends State<JobCompletionQRScreen> {
  String? _qrCode;
  bool _isLoading = true;
  String _error = '';
  bool _isPaymentCompleted = false;
  StreamSubscription? _statusSubscription;
  bool _dialogShown = false;

  @override
  void initState() {
    super.initState();
    _checkPaymentAndGenerateQR();
    _setupStatusListener();
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    super.dispose();
  }

  void _setupStatusListener() {
    // Listen for service request status changes (when mechanic scans QR)
    _statusSubscription = Supabase.instance.client
        .from('service_requests')
        .stream(primaryKey: ['id'])
        .eq('id', widget.serviceRequestId)
        .listen((data) {
          if (data.isNotEmpty && mounted && !_dialogShown) {
            final status = data.first['status'] as String?;
            print('📡 QR Screen - Service status update: $status');
            
            if (status == 'completed') {
              _dialogShown = true;
              _showCompletionDialog();
            }
          }
        });
  }

  Future<void> _showCompletionDialog() async {
    if (!mounted) return;
    
    try {
      // Get mechanic details
      final serviceRequest = await Supabase.instance.client
          .from('service_requests')
          .select('assigned_mechanic_id, title, service_type')
          .eq('id', widget.serviceRequestId)
          .maybeSingle();
      
      final mechanicId = serviceRequest?['assigned_mechanic_id'] as String?;
      final serviceTitle = serviceRequest?['title'] ?? serviceRequest?['service_type'] ?? 'Service';
      
      // Check if already reviewed
      final hasReviewed = await UserDataService.hasUserReviewed(widget.serviceRequestId);
      
      if (!mounted) return;
      
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => WillPopScope(
          onWillPop: () async => false,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green[700],
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    color: Colors.white,
                    size: 36,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Text(
                    'Job Completed!',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color.fromARGB(255, 27, 94, 32),
                    ),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your service has been completed successfully.',
                  style: TextStyle(fontSize: 17, height: 1.5),
                ),
                const SizedBox(height: 16),
                if (!hasReviewed && mechanicId != null) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green[200]!, width: 2),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.stars, color: Colors.green[700], size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Would you like to rate your mechanic?',
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.green[900],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  'Thank you for using RoadAid!',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
            actions: [
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  Navigator.of(context).pop(true); // Back to home with completed flag
                },
                icon: const Icon(Icons.close, size: 20),
                label: const Text('Close', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.grey[700],
                  side: BorderSide(color: Colors.grey[400]!, width: 2),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              if (!hasReviewed && mechanicId != null)
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    _showRatingDialog(mechanicId, serviceTitle);
                  },
                  icon: const Icon(Icons.star_rate, size: 22),
                  label: const Text('Rate Mechanic', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 176, 12, 1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
            ],
            actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          ),
        ),
      );
    } catch (e) {
      print('❌ Error showing completion dialog: $e');
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  void _showRatingDialog(String mechanicId, String serviceTitle) {
    showDialog(
      context: context,
      builder: (dialogContext) => ReviewDialog(
        requestId: widget.serviceRequestId,
        providerId: mechanicId,
        serviceTitle: serviceTitle,
        onReviewSubmitted: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Thank you for your review!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop(true); // Back to home with completed flag
        },
      ),
    );
  }

  Future<void> _checkPaymentAndGenerateQR() async {
    try {
      setState(() {
        _isLoading = true;
        _error = '';
      });

      // First check if payment is completed
      final paymentCompleted = await _checkPaymentStatus();
      
      if (!paymentCompleted) {
        setState(() {
          _isLoading = false;
          _isPaymentCompleted = false;
          _error = 'Payment must be completed before QR code can be generated';
        });
        return;
      }

      // Generate QR code only if payment is completed
      final qrCode = await QRCodeService.instance.showCustomerQRCode(widget.serviceRequestId);
      
      if (qrCode != null) {
        setState(() {
          _qrCode = qrCode;
          _isLoading = false;
          _isPaymentCompleted = true;
        });
      } else {
        setState(() {
          _error = 'Failed to generate QR code. Please try again.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  Future<bool> _checkPaymentStatus() async {
    try {
      // Check if payment is completed for this service request
      final userId = AuthService.instance.userId;
      if (userId == null) return false;

      print('🔍 Checking payment status for request: ${widget.serviceRequestId}, user: $userId');

      // Check invoice payment status first
      final invoice = await Supabase.instance.client
          .from('invoices')
          .select('paid_at, status, total_amount, id')
          .eq('request_id', widget.serviceRequestId)
          .eq('customer_id', userId)
          .maybeSingle();

      print('🧾 Invoice found: ${invoice != null}');
      if (invoice != null) {
        print('   - Status: ${invoice['status']}');
        print('   - Paid at: ${invoice['paid_at']}');
        print('   - Amount: ${invoice['total_amount']}');
        
        // Check if invoice is marked as paid
        if (invoice['paid_at'] != null || 
            invoice['status'] == 'paid' || 
            invoice['status'] == 'completed') {
          print('✅ Payment confirmed via invoice');
          return true;
        }
      }

      // Also check direct payment records
      final directPayment = await Supabase.instance.client
          .from('payments')
          .select('status, processed_at, payment_method, amount')
          .eq('request_id', widget.serviceRequestId)
          .eq('customer_id', userId)
          .maybeSingle();

      print('💳 Direct payment found: ${directPayment != null}');
      if (directPayment != null) {
        print('   - Status: ${directPayment['status']}');
        print('   - Processed at: ${directPayment['processed_at']}');
        print('   - Method: ${directPayment['payment_method']}');
        
        if (directPayment['status'] == 'completed' || 
            directPayment['status'] == 'paid' ||
            directPayment['processed_at'] != null) {
          print('✅ Payment confirmed via direct payment');
          return true;
        }
      }

      print('❌ No valid payment found');
      return false;
    } catch (e) {
      print('❌ Error checking payment status: $e');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 176, 12, 1),
        title: const Text(
          'Completion QR Code',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        elevation: 0,
      ),
      body: _buildQRSection(),
    );
  }

  Widget _buildQRSection() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color.fromARGB(255, 176, 12, 1),
        ),
      );
    }

    if (_error.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isPaymentCompleted ? Icons.error_outline : Icons.payment,
              size: 80,
              color: _isPaymentCompleted ? Colors.red : Colors.orange,
            ),
            const SizedBox(height: 24),
            Text(
              _isPaymentCompleted ? 'QR Generation Failed' : 'Payment Required',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: _isPaymentCompleted ? Colors.red : Colors.orange[700],
              ),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: _isPaymentCompleted ? _checkPaymentAndGenerateQR : () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 176, 12, 1),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(_isPaymentCompleted ? 'Retry' : 'Go Back'),
            ),
          ],
        ),
      );
    }

    if (_qrCode != null && _isPaymentCompleted) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Large QR Code - the main focus
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    spreadRadius: 0,
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: QrImageView(
                data: _qrCode!,
                version: QrVersions.auto,
                size: 280.0,
                backgroundColor: Colors.white,
                errorCorrectionLevel: QrErrorCorrectLevel.M,
              ),
            ),
            
            const SizedBox(height: 40),
            
            // Simple instruction
            Text(
              'Show this QR code to your mechanic',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 16),
            
            // QR Code ID for reference
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Code: ${_qrCode!.split('-').first}',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }
}











