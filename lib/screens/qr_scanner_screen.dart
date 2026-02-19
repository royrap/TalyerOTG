import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter/foundation.dart';

import '../services/enhanced_qr_code_service.dart';

class QRScannerScreen extends StatefulWidget {
  final String serviceRequestId;
  final String serviceTitle;

  const QRScannerScreen({
    super.key,
    required this.serviceRequestId,
    required this.serviceTitle,
  });

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  MobileScannerController cameraController = MobileScannerController();
  String? scannedCode;
  bool isProcessing = false;
  bool flashOn = false;

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Completion QR'),
        backgroundColor: const Color.fromARGB(255, 176, 12, 1),
        foregroundColor: Colors.white,
        actions: [
          if (!kIsWeb)
            IconButton(
              onPressed: _toggleFlash,
              icon: Icon(flashOn ? Icons.flash_off : Icons.flash_on),
            ),
        ],
      ),
      body: kIsWeb ? _buildWebScanner() : _buildMobileScanner(),
    );
  }

  Widget _buildMobileScanner() {
    return Column(
      children: [
        // Instructions
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          color: const Color.fromARGB(255, 176, 12, 1),
          child: Column(
            children: [
              Text(
                'Scan Customer QR Code',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.serviceTitle,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              const Text(
                'Position the QR code within the frame to complete the service',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),

        // QR Scanner
        Expanded(
          flex: 4,
          child: Stack(
            children: [
              MobileScanner(
                controller: cameraController,
                onDetect: _onQRCodeDetected,
              ),
              if (isProcessing)
                Container(
                  color: Colors.black54,
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                        SizedBox(height: 20),
                        Text(
                          'Processing QR code...',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),

        // Manual Entry Option
        Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Text(
                'Having trouble scanning?',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: _showManualEntry,
                icon: const Icon(Icons.keyboard),
                label: const Text('Enter Code Manually'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 176, 12, 1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWebScanner() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.qr_code_scanner,
            size: 80,
            color: Color.fromARGB(255, 176, 12, 1),
          ),
          const SizedBox(height: 20),
          Text(
            'QR Scanner',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            widget.serviceTitle,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 30),
          const Text(
            'QR code scanning is not available on web. Please enter the completion code manually.',
            style: TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 30),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _showManualEntry,
              icon: const Icon(Icons.keyboard),
              label: const Text('Enter Completion Code'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 176, 12, 1),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onQRCodeDetected(BarcodeCapture capture) {
    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      if (!isProcessing && barcode.rawValue != null) {
        _processQRCode(barcode.rawValue!);
        break; // Process only the first valid QR code
      }
    }
  }

  Future<void> _processQRCode(String qrCode) async {
    if (isProcessing) return;

    setState(() {
      isProcessing = true;
      scannedCode = qrCode;
    });

    try {
      final result = await EnhancedQRCodeService().verifyQRCodeScan(
        qrData: qrCode,
        mechanicId: null, // You might want to get this from auth
      );

      if (mounted) {
        if (result['success'] == true) {
          _showSuccessDialog();
        } else {
          _showErrorDialog(result['error'] ?? 'QR verification failed');
        }
      }
    } catch (e) {
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
                labelText: 'Completion Code',
                hintText: 'XXXXXXXX-XXXX',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.characters,
              onChanged: (value) {
                codeController.value = codeController.value.copyWith(
                  text: value.toUpperCase(),
                  selection: TextSelection.collapsed(offset: value.length),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              final code = codeController.text.trim();
              if (code.isNotEmpty) {
                _processQRCode(code);
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

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 30),
            SizedBox(width: 10),
            Text('Service Completed!'),
          ],
        ),
        content: const Text(
          'The service has been successfully completed and payment has been released to you.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Close scanner
              Navigator.pop(context); // Return to previous screen
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Great!'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error, color: Colors.red, size: 30),
            SizedBox(width: 10),
            Text('Verification Failed'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message),
              const SizedBox(height: 16),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Try Again'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Close scanner
            },
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleFlash() async {
    await cameraController.toggleTorch();
    setState(() {
      flashOn = !flashOn;
    });
  }
}
