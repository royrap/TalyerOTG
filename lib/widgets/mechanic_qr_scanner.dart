import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/job_completion_qr_service.dart';

class MechanicQRScanner extends StatefulWidget {
  final String mechanicId;
  final Map<String, dynamic> activeJob;
  final VoidCallback? onJobCompleted;

  const MechanicQRScanner({
    Key? key,
    required this.mechanicId,
    required this.activeJob,
    this.onJobCompleted,
  }) : super(key: key);

  @override
  State<MechanicQRScanner> createState() => _MechanicQRScannerState();
}

class _MechanicQRScannerState extends State<MechanicQRScanner> {
  MobileScannerController cameraController = MobileScannerController();
  bool _isScanning = true;
  bool _isProcessing = false;
  final TextEditingController _codeController = TextEditingController();
  bool _showManualEntry = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Customer QR Code'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: () => cameraController.toggleTorch(),
            icon: const Icon(Icons.flash_on),
          ),
        ],
      ),
      body: Column(
        children: [
          // Info banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              border: Border(bottom: BorderSide(color: Colors.orange.shade200)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.qr_code_scanner, color: Colors.orange.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Scan the customer\'s QR code to complete the job',
                        style: TextStyle(
                          color: Colors.orange.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Service: ${widget.activeJob['title']}',
                  style: TextStyle(
                    color: Colors.orange.shade600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          
          // Camera view
          Expanded(
            child: Stack(
              children: [
                MobileScanner(
                  controller: cameraController,
                  onDetect: _onQRCodeDetected,
                ),
                
                // Scanning overlay
                if (_isScanning)
                  Center(
                    child: Container(
                      width: 250,
                      height: 250,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.orange,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Stack(
                        children: [
                          // Corner decorations
                          Positioned(
                            top: 0,
                            left: 0,
                            child: Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                border: Border(
                                  top: BorderSide(color: Colors.orange, width: 4),
                                  left: BorderSide(color: Colors.orange, width: 4),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 0,
                            right: 0,
                            child: Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                border: Border(
                                  top: BorderSide(color: Colors.orange, width: 4),
                                  right: BorderSide(color: Colors.orange, width: 4),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            left: 0,
                            child: Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(color: Colors.orange, width: 4),
                                  left: BorderSide(color: Colors.orange, width: 4),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(color: Colors.orange, width: 4),
                                  right: BorderSide(color: Colors.orange, width: 4),
                                ),
                              ),
                            ),
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
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Completing job...',
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
          
          // Bottom instructions
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Toggle between camera and manual entry
                if (!_showManualEntry) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.info_outline, color: Colors.grey[600], size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Position the QR code within the frame',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Button to show manual entry
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _showManualEntry = true;
                        });
                      },
                      icon: const Icon(Icons.keyboard),
                      label: const Text('Enter Code Manually'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange,
                        side: const BorderSide(color: Colors.orange),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ] else ...[
                  // Manual code entry form
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.keyboard, color: Colors.orange.shade700, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Manual Code Entry',
                              style: TextStyle(
                                color: Colors.orange.shade700,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _codeController,
                          decoration: InputDecoration(
                            hintText: 'Enter completion code (e.g., JOB-XXXXX)',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.orange.shade300),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.orange.shade300),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.orange, width: 2),
                            ),
                            prefixIcon: Icon(Icons.qr_code, color: Colors.orange.shade700),
                          ),
                          textCapitalization: TextCapitalization.characters,
                          enabled: !_isProcessing,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _isProcessing ? null : _submitManualCode,
                                icon: const Icon(Icons.check_circle_outline),
                                label: const Text('Submit Code'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              onPressed: _isProcessing ? null : () {
                                setState(() {
                                  _showManualEntry = false;
                                  _codeController.clear();
                                });
                              },
                              icon: const Icon(Icons.qr_code_scanner),
                              label: const Text('Scan'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.orange,
                                side: const BorderSide(color: Colors.orange),
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Colors.white),
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

  void _onQRCodeDetected(BarcodeCapture capture) async {
    if (!_isScanning || _isProcessing || capture.barcodes.isEmpty) return;

    final String? scannedData = capture.barcodes.first.rawValue;
    if (scannedData == null) return;

    await _processCode(scannedData);
  }

  Future<void> _submitManualCode() async {
    final String code = _codeController.text.trim();
    
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.warning, color: Colors.white),
              SizedBox(width: 8),
              Text('Please enter a completion code'),
            ],
          ),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    print('⌨️ Manual code entry: $code');
    await _processCode(code);
  }

  Future<void> _processCode(String scannedData) async {
    setState(() {
      _isScanning = false;
      _isProcessing = true;
    });

    try {
      print('🔍 Scanned QR: $scannedData');
      
      String? completionCode;
      
      // Try to parse different QR code formats
      if (scannedData.startsWith('RoadAid_JOB_COMPLETION:')) {
        // New format: RoadAid_JOB_COMPLETION:requestId:completionCode:timestamp
        final parts = scannedData.split(':');
        if (parts.length >= 3) {
          completionCode = parts[2];
        }
      } else if (scannedData.contains('code=') || scannedData.contains('&')) {
        // URL parameter format: code=ABC123&other=value
        try {
          final qrData = Map<String, dynamic>.from(
            Map.fromEntries(
              scannedData.split('&').map((pair) {
                final parts = pair.split('=');
                return MapEntry(parts[0], parts.length > 1 ? parts[1] : '');
              }),
            ),
          );
          completionCode = qrData['code'];
        } catch (parseError) {
          print('⚠️ Failed to parse URL format, trying as direct completion code');
        }
      } 
      
      // If no specific format matched, try using the whole string as completion code
      if (completionCode == null || completionCode.isEmpty) {
        if (scannedData.toUpperCase().startsWith('JOB-') || 
            scannedData.length >= 8) {
          completionCode = scannedData.trim();
        } else {
          throw 'Invalid QR code format. Please scan a valid RoadAid job completion QR code.';
        }
      }
      
      print('🎯 Extracted completion code: $completionCode');
      
      // Verify and complete the job
      final success = await JobCompletionQRService.instance.verifyAndUseQR(
        completionCode: completionCode,
        providerId: widget.mechanicId,
      );

      if (success) {
        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('✅ Job completed successfully!'),
                        Text(
                          'Earnings calculated and added to your history',
                          style: TextStyle(fontSize: 12, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 4),
            ),
          );

          // Call completion callback first to update the parent components
          widget.onJobCompleted?.call();

          // Navigate back after a short delay with completion result
          await Future.delayed(const Duration(seconds: 2));
          if (mounted) {
            // Return true to indicate successful completion
            Navigator.pop(context, true);
          }
        }
      } else {
        // Show error message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.error, color: Colors.white),
                  SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('❌ QR Code Invalid'),
                        Text(
                          'Code may be expired, used, or not for this job',
                          style: TextStyle(fontSize: 12, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 4),
            ),
          );

          // Resume scanning
          setState(() {
            _isScanning = true;
            _isProcessing = false;
          });
        }
      }
    } catch (e) {
      print('❌ Error processing QR: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('❌ Error: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );

        // Resume scanning
        setState(() {
          _isScanning = true;
          _isProcessing = false;
        });
      }
    }
  }

  @override
  void dispose() {
    cameraController.dispose();
    _codeController.dispose();
    super.dispose();
  }
}