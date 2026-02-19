import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/mechanic_request_service.dart';

class QRCompletionScanner extends StatefulWidget {
  final String jobId;

  const QRCompletionScanner({
    super.key,
    required this.jobId,
  });

  @override
  State<QRCompletionScanner> createState() => _QRCompletionScannerState();
}

class _QRCompletionScannerState extends State<QRCompletionScanner> {
  final TextEditingController _qrCodeController = TextEditingController();
  bool _isProcessing = false;

  @override
  void dispose() {
    _qrCodeController.dispose();
    super.dispose();
  }

  Future<void> _processQRCode(String qrCode) async {
    if (_isProcessing) return;

    setState(() => _isProcessing = true);

    try {
      // Simulate QR processing - in real implementation, this would verify the QR code
      // and mark the job as completed
      await Future.delayed(const Duration(seconds: 2));

      // Complete the job and return mechanic to available status
      final success = await MechanicRequestService.instance
          .completeJobAndReturnToAvailable(widget.jobId);

      if (success && mounted) {
        HapticFeedback.heavyImpact();
        
        // Show success dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: Colors.red,
                  size: 32,
                ),
                const SizedBox(width: 12),
                const Text('Job Completed!'),
              ],
            ),
            content: const Text(
              'Payment has been released and you are now available for new jobs.',
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close dialog
                  Navigator.of(context).pop(); // Close scanner
                  Navigator.of(context).pop(); // Close job details
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Continue'),
              ),
            ],
          ),
        );
      } else {
        throw Exception('Failed to complete job');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error processing QR code: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Completion QR'),
        backgroundColor: const Color.fromARGB(255, 176, 12, 1),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Instructions
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blue.withAlpha(26),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue, width: 1),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.qr_code_scanner,
                    size: 48,
                    color: Colors.blue,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Ask the customer to generate a completion QR code and scan it to release payment.',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // QR Code input (for demo purposes)
            const Text(
              'Enter QR Code (for testing):',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _qrCodeController,
              decoration: InputDecoration(
                hintText: 'Enter or paste QR code data',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.qr_code),
              ),
              maxLines: 3,
            ),

            const SizedBox(height: 24),

            // Process button
            ElevatedButton(
              onPressed: _isProcessing 
                  ? null 
                  : () {
                      final qrCode = _qrCodeController.text.trim();
                      if (qrCode.isNotEmpty) {
                        _processQRCode(qrCode);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter a QR code'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 176, 12, 1),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isProcessing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Process QR Code',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),

            const Spacer(),

            // Note
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.withAlpha(26),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.grey[600],
                    size: 24,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'The customer will show you a QR code on their phone after they are satisfied with the work. Scanning this QR code will mark the job as completed and release your payment.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}










