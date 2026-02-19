import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/qr_scanner_widget.dart';
import '../services/qr_code_service.dart';

class ImprovedQRScannerScreen extends StatefulWidget {
  final String serviceRequestId;
  final String serviceTitle;

  const ImprovedQRScannerScreen({
    super.key,
    required this.serviceRequestId,
    required this.serviceTitle,
  });

  @override
  State<ImprovedQRScannerScreen> createState() => _ImprovedQRScannerScreenState();
}

class _ImprovedQRScannerScreenState extends State<ImprovedQRScannerScreen> {
  bool isProcessing = false;

  @override
  Widget build(BuildContext context) {
    return QRScannerWidget(
      title: 'Scan Completion QR',
      description: 'Scan the customer\'s QR code to complete the job: ${widget.serviceTitle}',
      onQRScanned: _onQRScanned,
      showManualEntry: true,
      backgroundColor: const Color.fromARGB(255, 176, 12, 1),
    );
  }

  Future<void> _onQRScanned(String qrCode) async {
    if (isProcessing) return;

    setState(() {
      isProcessing = true;
    });

    try {
      print('🔍 Processing QR code: $qrCode for service request: ${widget.serviceRequestId}');
      
      // Show immediate feedback
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Processing QR code: $qrCode'),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.blue,
        ),
      );
      
      final success = await QRCodeService.instance.verifyAndProcessQRScan(
        qrCode: qrCode,
        serviceRequestId: widget.serviceRequestId,
      );

      if (mounted) {
        if (success) {
          _showSuccessDialog();
        } else {
          _showErrorDialog('QR verification failed. Please check the logs for detailed error information.\n\nCommon issues:\n• QR code is expired or already used\n• QR code is for a different job\n• Mechanic not assigned to this job\n• Customer hasn\'t generated QR after payment');
        }
      }
    } catch (e) {
      print('❌ QR processing error: $e');
      if (mounted) {
        String errorMessage = e.toString();
        // Clean up error message for user display
        if (errorMessage.startsWith('Exception: ')) {
          errorMessage = errorMessage.substring(11);
        }
        
        // Show the specific error message from the service
        _showErrorDialog(errorMessage);
      }
    } finally {
      if (mounted) {
        setState(() {
          isProcessing = false;
        });
      }
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(
          Icons.check_circle,
          color: Colors.green,
          size: 64,
        ),
        title: const Text('Service Completed!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Payment has been released from escrow and sent to your account.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              widget.serviceTitle,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(); // Return to previous screen
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

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(
          Icons.error,
          color: Colors.red,
          size: 48,
        ),
        title: const Text('Verification Failed'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message),
              const SizedBox(height: 16),
              const Text(
                'Troubleshooting Tips:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('• Make sure the QR code is clearly visible'),
              const Text('• Check that the QR code hasn\'t expired'),
              const Text('• Verify you\'re assigned to this job'),
              const Text('• Ensure the customer has paid the invoice'),
              const SizedBox(height: 16),
              const Text(
                'If the issue persists, try entering the completion code manually.',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Try Again'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _showManualEntry();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromARGB(255, 176, 12, 1),
              foregroundColor: Colors.white,
            ),
            child: const Text('Enter Code Manually'),
          ),
        ],
      ),
    );
  }

  void _showManualEntry() {
    final codeController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter Completion Code'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter the completion code shown on the customer\'s device:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: codeController,
              decoration: const InputDecoration(
                hintText: 'e.g., WQ60BGY6-4826',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.qr_code),
              ),
              textCapitalization: TextCapitalization.characters,
              maxLength: 15,
              onChanged: (value) {
                // Auto-format to uppercase
                final selection = codeController.selection;
                codeController.value = TextEditingValue(
                  text: value.toUpperCase(),
                  selection: selection,
                );
              },
            ),
            const SizedBox(height: 8),
            const Text(
              'The completion code is typically 10-15 characters long and contains letters and numbers.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              if (codeController.text.isNotEmpty) {
                _onQRScanned(codeController.text.trim());
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromARGB(255, 176, 12, 1),
              foregroundColor: Colors.white,
            ),
            child: const Text('Verify'),
          ),
        ],
      ),
    );
  }
}










