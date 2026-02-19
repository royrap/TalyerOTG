import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/invoice_service.dart';

class SecureQRDisplayScreen extends StatefulWidget {
  final String requestId;
  final String jobTitle;
  final double paymentAmount;

  const SecureQRDisplayScreen({
    super.key,
    required this.requestId,
    required this.jobTitle,
    required this.paymentAmount,
  });

  @override
  State<SecureQRDisplayScreen> createState() => _SecureQRDisplayScreenState();
}

class _SecureQRDisplayScreenState extends State<SecureQRDisplayScreen>
    with TickerProviderStateMixin {
  String? qrCode;
  bool isLoading = true;
  String? error;
  DateTime? expiresAt;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 0.95,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    _pulseController.repeat(reverse: true);
    _generateQRCode();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _generateQRCode() async {
    try {
      setState(() {
        isLoading = true;
        error = null;
      });

      final generatedQR = await InvoiceService.instance.generateCompletionQR(widget.requestId);
      
      if (generatedQR != null) {
        setState(() {
          qrCode = generatedQR;
          expiresAt = DateTime.now().add(Duration(minutes: 10)); // QR expires in 10 minutes
          isLoading = false;
        });
      } else {
        setState(() {
          error = 'Failed to generate QR code. Please ensure payment is completed.';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        error = 'Error generating QR code: $e';
        isLoading = false;
      });
    }
  }

  String _getTimeRemaining() {
    if (expiresAt == null) return '';
    
    final now = DateTime.now();
    final difference = expiresAt!.difference(now);
    
    if (difference.isNegative) {
      return 'EXPIRED';
    }
    
    final minutes = difference.inMinutes;
    final seconds = difference.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Job Completion QR'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Job info card
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.build, color: Colors.blue[700], size: 24),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.jobTitle,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.receipt, color: Colors.green[600], size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Payment: ₱${widget.paymentAmount.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.green[700],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'PAID',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green[700],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.confirmation_number, color: Colors.grey[600], size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'ID: ${widget.requestId}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 30),

            if (isLoading) ...[
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              const Text(
                'Generating secure QR code...',
                style: TextStyle(fontSize: 16),
              ),
            ] else if (error != null) ...[
              Card(
                elevation: 2,
                color: Colors.red[50],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Icon(Icons.error, color: Colors.red[600], size: 48),
                      const SizedBox(height: 12),
                      Text(
                        'QR Generation Failed',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.red[700],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        error!,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.red[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _generateQRCode,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ] else if (qrCode != null) ...[
              // QR Code display
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _pulseAnimation.value,
                    child: Card(
                      elevation: 8,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Colors.blue[50]!, Colors.white],
                          ),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black12,
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: QrImageView(
                                data: qrCode!,
                                version: QrVersions.auto,
                                size: 200.0,
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.timer, color: Colors.orange[600], size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Expires in: ${_getTimeRemaining()}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange[700],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 20),

              // Instructions
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info, color: Colors.blue[600]),
                          const SizedBox(width: 8),
                          const Text(
                            'Instructions',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildInstructionStep(
                        '1',
                        'Show this QR code to your mechanic',
                        Icons.qr_code,
                      ),
                      _buildInstructionStep(
                        '2',
                        'The mechanic will scan it to complete the job',
                        Icons.qr_code_scanner,
                      ),
                      _buildInstructionStep(
                        '3',
                        'Payment will be released after successful scan',
                        Icons.payment,
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.amber[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amber[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.warning_amber, color: Colors.amber[700]),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'This QR code expires in 10 minutes for security.',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.amber[800],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _generateQRCode,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Regenerate QR'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.check),
                      label: const Text('Done'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[600],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionStep(String number, String text, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.blue[600],
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
          Icon(icon, color: Colors.blue[600], size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}










