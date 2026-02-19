import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter/services.dart';
import '../services/qr_code_service.dart';
import '../services/complete_service_flow_service.dart';

class EnhancedMechanicQRScanner extends StatefulWidget {
  final String serviceRequestId;
  final String? expectedCustomerId;

  const EnhancedMechanicQRScanner({
    Key? key,
    required this.serviceRequestId,
    this.expectedCustomerId,
  }) : super(key: key);

  @override
  State<EnhancedMechanicQRScanner> createState() => _EnhancedMechanicQRScannerState();
}

class _EnhancedMechanicQRScannerState extends State<EnhancedMechanicQRScanner> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? controller;
  bool _isProcessing = false;
  String? _scannedCode;
  String _scanStatus = 'Position QR code in the frame';

  @override
  void reassemble() {
    super.reassemble();
    if (controller != null) {
      controller!.resumeCamera();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Scan Completion QR Code',
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on, color: Colors.white),
            onPressed: _toggleFlash,
          ),
        ],
      ),
      body: Stack(
        children: [
          // QR Scanner
          QRView(
            key: qrKey,
            onQRViewCreated: _onQRViewCreated,
            overlay: QrScannerOverlayShape(
              borderColor: const Color.fromARGB(255, 176, 12, 1),
              borderRadius: 10,
              borderLength: 30,
              borderWidth: 10,
              cutOutSize: 300,
            ),
          ),
          
          // Top information panel
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.8),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.qr_code_scanner,
                    color: Colors.white,
                    size: 40,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _scanStatus,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Job: ${widget.serviceRequestId.substring(0, 8)}...',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Bottom action panel
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.8),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Manual input option
                  Container(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _showManualInputDialog,
                      icon: const Icon(Icons.keyboard, color: Colors.white),
                      label: const Text(
                        'Enter Code Manually',
                        style: TextStyle(color: Colors.white),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Manual completion option
                  Container(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _showManualCompletionDialog,
                      icon: const Icon(Icons.construction),
                      label: const Text('Manual Job Completion'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromARGB(255, 176, 12, 1),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Instructions
                  const Text(
                    'Ask the customer to show their QR code\nafter they have paid the invoice',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          
          // Processing overlay
          if (_isProcessing)
            Container(
              color: Colors.black.withOpacity(0.7),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      color: Color.fromARGB(255, 176, 12, 1),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Verifying QR Code...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _onQRViewCreated(QRViewController controller) {
    this.controller = controller;
    controller.scannedDataStream.listen((scanData) {
      if (!_isProcessing && scanData.code != null) {
        _processScannedCode(scanData.code!);
      }
    });
  }

  void _processScannedCode(String code) async {
    if (_isProcessing || _scannedCode == code) return;

    setState(() {
      _isProcessing = true;
      _scannedCode = code;
      _scanStatus = 'Verifying QR code...';
    });

    // Vibrate to indicate scan
    HapticFeedback.mediumImpact();

    try {
      // Pause camera
      await controller?.pauseCamera();

      // Verify QR code using the service
      final result = await CompleteServiceFlowService.instance.scanAndVerifyQR(
        qrCode: code,
        serviceRequestId: widget.serviceRequestId,
      );

      if (result['success'] == true) {
        // Success! Show completion dialog
        await _showSuccessDialog(result['message']);
        if (mounted) {
          Navigator.pop(context, {'success': true, 'message': result['message']});
        }
      } else {
        // Error - show details and allow retry
        await _showErrorDialog(result['error']);
        setState(() {
          _isProcessing = false;
          _scanStatus = 'QR verification failed - try again';
        });
        await controller?.resumeCamera();
      }
    } catch (e) {
      await _showErrorDialog(e.toString());
      setState(() {
        _isProcessing = false;
        _scanStatus = 'Error occurred - try again';
      });
      await controller?.resumeCamera();
    }
  }

  void _showManualInputDialog() {
    final codeController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter QR Code'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter the completion code from the customer\'s screen:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: codeController,
              decoration: const InputDecoration(
                labelText: 'Completion Code',
                hintText: 'e.g. ABC12345-6789',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.characters,
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
              final code = codeController.text.trim();
              if (code.isNotEmpty) {
                Navigator.pop(context);
                _processScannedCode(code);
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

  void _showManualCompletionDialog() {
    final reasonController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Manual Job Completion'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Complete this job manually if QR scanning is not working:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason for manual completion',
                hintText: 'e.g. Customer phone battery died',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                border: Border.all(color: Colors.orange[200]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning, color: Colors.orange, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Only use this if QR scanning is impossible',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
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
              final reason = reasonController.text.trim();
              if (reason.isNotEmpty) {
                Navigator.pop(context);
                _processManualCompletion(reason);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Complete Manually'),
          ),
        ],
      ),
    );
  }

  void _processManualCompletion(String reason) async {
    setState(() {
      _isProcessing = true;
      _scanStatus = 'Processing manual completion...';
    });

    try {
      final success = await QRCodeService.instance.manualCompleteJob(
        serviceRequestId: widget.serviceRequestId,
        reason: reason,
      );

      if (success) {
        await _showSuccessDialog('Job completed manually. Payment has been released.');
        if (mounted) {
          Navigator.pop(context, {
            'success': true,
            'message': 'Job completed manually',
            'method': 'manual',
          });
        }
      } else {
        throw Exception('Manual completion failed');
      }
    } catch (e) {
      await _showErrorDialog('Manual completion failed: $e');
      setState(() {
        _isProcessing = false;
        _scanStatus = 'Manual completion failed - try again';
      });
    }
  }

  Future<void> _showSuccessDialog(String message) async {
    HapticFeedback.heavyImpact();
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Text('Job Completed!'),
          ],
        ),
        content: Text(message),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _showErrorDialog(String error) async {
    HapticFeedback.lightImpact();
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Text('Verification Failed'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(error),
            const SizedBox(height: 12),
            const Text(
              'Possible solutions:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('• Ask customer to generate a new QR code'),
            const Text('• Ensure customer has paid the invoice'),
            const Text('• Check that you\'re assigned to this job'),
            const Text('• Use manual completion if necessary'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _toggleFlash() {
    controller?.toggleFlash();
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }
}