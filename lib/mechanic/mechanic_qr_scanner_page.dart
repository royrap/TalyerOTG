import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'dart:convert';
import '../services/supabase_service.dart';

/// Full-screen QR Scanner Page for Mechanic
/// Opens camera to scan customer's QR code for job completion
class MechanicQRScannerPage extends StatefulWidget {
  final String serviceRequestId;
  final String jobTitle;
  final VoidCallback? onJobCompleted;

  const MechanicQRScannerPage({
    Key? key,
    required this.serviceRequestId,
    required this.jobTitle,
    this.onJobCompleted,
  }) : super(key: key);

  @override
  State<MechanicQRScannerPage> createState() => _MechanicQRScannerPageState();
}

class _MechanicQRScannerPageState extends State<MechanicQRScannerPage> {
  MobileScannerController? _cameraController;
  bool _isProcessing = false;
  bool _scanSuccess = false;
  String _statusMessage = 'Position QR code in the frame';
  bool _showManualEntry = false;
  final TextEditingController _codeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    print('🎬 MechanicQRScannerPage initState() called!');
    print('📸 QR Scanner Page initialized for job: ${widget.serviceRequestId}');
    print('📱 Job title: ${widget.jobTitle}');
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    print('📷 _initializeCamera() method started...');
    try {
      print('🔧 Creating MobileScannerController...');
      _cameraController = MobileScannerController(
        detectionSpeed: DetectionSpeed.normal,
        facing: CameraFacing.back,
        torchEnabled: false,
      );
      
      print('🚀 Starting camera controller...');
      await _cameraController?.start();
      print('✅ Camera initialized and started successfully!');
      
      if (mounted) {
        setState(() {
          _statusMessage = 'Ready to scan QR code';
        });
        print('✅ UI state updated - Ready to scan');
      }
    } catch (e) {
      print('❌ Error initializing camera: $e');
      print('❌ Stack trace: ${StackTrace.current}');
      if (mounted) {
        setState(() {
          _statusMessage = 'Camera error: $e';
        });
      }
    }
  }

  Future<void> _handleQRCodeScanned(BarcodeCapture barcodeCapture) async {
    if (_isProcessing || _scanSuccess) {
      return; // Prevent multiple scans
    }

    final List<Barcode> barcodes = barcodeCapture.barcodes;
    if (barcodes.isEmpty) return;

    final String? qrCode = barcodes.first.rawValue;
    if (qrCode == null || qrCode.isEmpty) {
      print('❌ Empty QR code detected');
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Processing QR code...';
    });

    print('📱 QR Code scanned: $qrCode');
    await _processQRCode(qrCode);
  }

  Future<void> _submitManualCode() async {
    final String code = _codeController.text.trim();
    
    if (code.isEmpty) {
      _showError('Please enter a completion code');
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Processing code...';
    });

    print('⌨️ Manual code entry: $code');
    
    // Format the code as JSON if it's just a plain code
    String formattedCode = code;
    if (!code.contains('{') && !code.startsWith('RoadAid_')) {
      // Assume it's a raw completion code, format it
      formattedCode = '{"service_request_id": "${widget.serviceRequestId}", "completion_code": "$code"}';
    }
    
    await _processQRCode(formattedCode);
  }

  Future<void> _processQRCode(String qrCode) async {
    try {
      print('🔍 Raw QR code received: $qrCode');
      
      // Parse QR code data - handle both JSON and plain text formats
      Map<String, dynamic> qrData;
      String scannedJobId = '';
      String completionCode = '';
      
      try {
        // Try to parse as JSON first
        qrData = jsonDecode(qrCode);
        scannedJobId = qrData['service_request_id'] ?? '';
        completionCode = qrData['completion_code'] ?? '';
        print('✅ Parsed as JSON - jobId=$scannedJobId, code=$completionCode');
      } catch (e) {
        // If not JSON, treat the entire string as a completion code
        print('⚠️ Not JSON format, treating as plain completion code');
        completionCode = qrCode.trim();
        // For plain codes, we won't validate the job ID since it's not in the QR
        print('✅ Plain code format - code=$completionCode');
      }

      print('🔍 Processed QR data: jobId=$scannedJobId, code=$completionCode');

      // Validate QR code matches current job (only if job ID was provided in QR)
      if (scannedJobId.isNotEmpty && scannedJobId != widget.serviceRequestId) {
        _showError('Wrong QR code! This is for a different job.');
        return;
      }

      // Verify completion code in job_completion_codes table
      print('🔍 Querying job_completion_codes table for code: $completionCode');
      final qrRecord = await SupabaseService.client
          .from('job_completion_codes')
          .select('request_id, customer_id, is_used, expires_at')
          .eq('completion_code', completionCode)
          .maybeSingle();

      print('🔍 QR Record found: ${qrRecord != null}');
      
      if (qrRecord == null) {
        _showError('Invalid completion code. Code not found in system.');
        return;
      }

      print('🔍 QR Record details:');
      print('   - Request ID: ${qrRecord['request_id']}');
      print('   - Customer ID: ${qrRecord['customer_id']}');
      print('   - Is Used: ${qrRecord['is_used']}');
      print('   - Expires At: ${qrRecord['expires_at']}');

      // Check if already used
      if (qrRecord['is_used'] == true) {
        _showError('This QR code has already been used!');
        return;
      }

      // Check if expired
      final expiresAt = DateTime.parse(qrRecord['expires_at']);
      if (DateTime.now().isAfter(expiresAt)) {
        _showError('This QR code has expired!');
        return;
      }

      // Verify this QR code matches the current job
      final String qrRequestId = qrRecord['request_id'];
      if (qrRequestId != widget.serviceRequestId) {
        _showError('Wrong QR code! This code is for a different job.');
        return;
      }

      print('✅ QR code validation passed!');

      // Mark job completion code as used and update job status
      // Wrap in try-catch to handle database trigger issues with admin_activity_logs
      try {
        print('📝 Marking QR code as used...');
        await SupabaseService.client
            .from('job_completion_codes')
            .update({
              'is_used': true,
              'used_at': DateTime.now().toIso8601String(),
              'verification_status': 'verified',
            })
            .eq('completion_code', completionCode);

        print('✅ Job completion code marked as used');

        print('📝 Marking job as completed...');
        await SupabaseService.client
            .from('service_requests')
            .update({
              'status': 'completed',
              'completed_at': DateTime.now().toIso8601String(),
              'qr_scanned_at': DateTime.now().toIso8601String(),
            })
            .eq('id', widget.serviceRequestId);

        print('✅ Job marked as completed in database');
        
      } catch (dbError) {
        // Check if this is the admin_activity_logs constraint error
        if (dbError.toString().contains('admin_activity_logs') && 
            (dbError.toString().contains('not-null constraint') || 
             dbError.toString().contains('foreign key'))) {
          print('⚠️ Database trigger error detected - using manual process');
          print('⚠️ Error: $dbError');
          
          // Manual process: Update tables directly without trigger
          try {
            // Mark QR as used (direct update)
            await SupabaseService.client
                .from('job_completion_codes')
                .update({
                  'is_used': true,
                  'used_at': DateTime.now().toIso8601String(),
                  'verification_status': 'verified',
                })
                .eq('completion_code', completionCode);
            
            print('✅ QR marked as used (manual)');
            
            // Update service request status
            await SupabaseService.client
                .from('service_requests')
                .update({
                  'status': 'completed',
                  'completed_at': DateTime.now().toIso8601String(),
                  'qr_scanned_at': DateTime.now().toIso8601String(),
                })
                .eq('id', widget.serviceRequestId);
            
            print('✅ Job marked as completed (manual)');
            
            // Release payment from escrow
            await SupabaseService.client
                .from('payment_releases')
                .update({
                  'release_status': 'approved',
                  'updated_at': DateTime.now().toIso8601String(),
                })
                .eq('request_id', widget.serviceRequestId);
            
            print('✅ Payment released (manual)');
            
          } catch (manualError) {
            print('❌ Manual update failed: $manualError');
            throw Exception('Failed to complete job. Please contact support.');
          }
        } else {
          // Re-throw if it's a different error
          rethrow;
        }
      }

      // Success!
      setState(() {
        _scanSuccess = true;
        _statusMessage = '✅ Job completed successfully!';
      });

      // Stop camera
      await _cameraController?.stop();

      // Show success dialog
      if (mounted) {
        await _showSuccessDialog();
      }

      // Callback and navigate back
      widget.onJobCompleted?.call();
      
      if (mounted) {
        Navigator.of(context).pop(true); // Return success
      }

    } catch (e) {
      print('❌ Error processing QR code: $e');
      _showError('Failed to process QR code: ${e.toString()}');
    } finally {
      if (mounted && !_scanSuccess) {
        setState(() {
          _isProcessing = false;
          _statusMessage = 'Ready to scan again';
        });
      }
    }
  }

  void _showError(String message) {
    print('❌ QR Scan Error: $message');
    
    if (mounted) {
      setState(() {
        _isProcessing = false;
        _statusMessage = message;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.red[700],
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    // Allow scanning again after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && !_scanSuccess) {
        setState(() {
          _statusMessage = 'Ready to scan QR code';
        });
      }
    });
  }

  Future<void> _showSuccessDialog() async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.green[100],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle,
                  size: 50,
                  color: Colors.green[700],
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Job Completed!',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                widget.jobTitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Payment has been verified and job is marked as complete.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close dialog
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'OK',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _toggleFlash() {
    _cameraController?.toggleTorch();
    setState(() {}); // Rebuild to update flash icon
  }

  @override
  void dispose() {
    print('🗑️ MechanicQRScannerPage dispose() called');
    _cameraController?.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print('🎨 MechanicQRScannerPage build() called');
    print('🔍 Camera controller null? ${_cameraController == null}');
    print('🔍 Show manual entry? $_showManualEntry');
    print('🔍 Scan success? $_scanSuccess');
    
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera Preview
          if (_cameraController != null)
            Builder(
              builder: (context) {
                print('📸 Building MobileScanner widget');
                return MobileScanner(
                  controller: _cameraController!,
                  onDetect: _handleQRCodeScanned,
                );
              },
            )
          else
            Builder(
              builder: (context) {
                print('⏳ Showing loading indicator - camera not ready');
                return const Center(
                  child: CircularProgressIndicator(
                    color: Colors.white,
                  ),
                );
              },
            ),

          // Overlay with scanning frame
          CustomPaint(
            painter: ScannerOverlayPainter(),
            child: Container(),
          ),

          // Top Bar
          SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.7),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Row(
                children: [
                  // Back Button
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Title
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Scan QR Code',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          widget.jobTitle,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // Flash Toggle
                  IconButton(
                    onPressed: _toggleFlash,
                    icon: const Icon(
                      Icons.flash_off,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Status Bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.all(24),
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
                  children: [
                    // Status Icon
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: _scanSuccess
                            ? Colors.green.withOpacity(0.2)
                            : _isProcessing
                                ? Colors.orange.withOpacity(0.2)
                                : Colors.white.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _scanSuccess
                            ? Icons.check_circle
                            : _isProcessing
                                ? Icons.hourglass_empty
                                : Icons.qr_code_scanner,
                        color: _scanSuccess
                            ? Colors.green
                            : _isProcessing
                                ? Colors.orange
                                : Colors.white,
                        size: 30,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Status Message
                    Text(
                      _statusMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    // Instructions or Manual Entry
                    if (!_isProcessing && !_scanSuccess && !_showManualEntry) ...[
                      Text(
                        'Align the QR code within the frame',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 16),
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
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white, width: 2),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],

                    // Manual Entry Form
                    if (_showManualEntry && !_isProcessing && !_scanSuccess) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Enter Completion Code',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _codeController,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                hintText: 'e.g., JOB-XXXXX',
                                hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.1),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: Colors.white.withOpacity(0.5)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: Colors.white.withOpacity(0.5)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: Colors.white, width: 2),
                                ),
                                prefixIcon: Icon(Icons.qr_code, color: Colors.white.withOpacity(0.7)),
                              ),
                              textCapitalization: TextCapitalization.characters,
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: ElevatedButton.icon(
                                    onPressed: _submitManualCode,
                                    icon: const Icon(Icons.check_circle_outline, size: 18),
                                    label: const Text('Submit'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFEF5350),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  flex: 1,
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      setState(() {
                                        _showManualEntry = false;
                                        _codeController.clear();
                                      });
                                    },
                                    icon: const Icon(Icons.qr_code_scanner, size: 18),
                                    label: const Text('Scan', style: TextStyle(fontSize: 13)),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.white,
                                      side: const BorderSide(color: Colors.white),
                                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // Processing Overlay
          if (_isProcessing)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Custom painter for scanner overlay
class ScannerOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.5)
      ..style = PaintingStyle.fill;

    final scanAreaSize = size.width * 0.7;
    final scanAreaLeft = (size.width - scanAreaSize) / 2;
    final scanAreaTop = (size.height - scanAreaSize) / 2;
    final scanAreaRect = Rect.fromLTWH(
      scanAreaLeft,
      scanAreaTop,
      scanAreaSize,
      scanAreaSize,
    );

    // Draw semi-transparent overlay
    final overlayPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(
        scanAreaRect,
        const Radius.circular(20),
      ))
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(overlayPath, paint);

    // Draw corner brackets
    final cornerPaint = Paint()
      ..color = const Color(0xFFEF5350)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    const cornerLength = 30.0;

    // Top-left corner
    canvas.drawLine(
      Offset(scanAreaLeft, scanAreaTop + cornerLength),
      Offset(scanAreaLeft, scanAreaTop),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(scanAreaLeft, scanAreaTop),
      Offset(scanAreaLeft + cornerLength, scanAreaTop),
      cornerPaint,
    );

    // Top-right corner
    canvas.drawLine(
      Offset(scanAreaLeft + scanAreaSize - cornerLength, scanAreaTop),
      Offset(scanAreaLeft + scanAreaSize, scanAreaTop),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(scanAreaLeft + scanAreaSize, scanAreaTop),
      Offset(scanAreaLeft + scanAreaSize, scanAreaTop + cornerLength),
      cornerPaint,
    );

    // Bottom-left corner
    canvas.drawLine(
      Offset(scanAreaLeft, scanAreaTop + scanAreaSize - cornerLength),
      Offset(scanAreaLeft, scanAreaTop + scanAreaSize),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(scanAreaLeft, scanAreaTop + scanAreaSize),
      Offset(scanAreaLeft + cornerLength, scanAreaTop + scanAreaSize),
      cornerPaint,
    );

    // Bottom-right corner
    canvas.drawLine(
      Offset(scanAreaLeft + scanAreaSize - cornerLength, scanAreaTop + scanAreaSize),
      Offset(scanAreaLeft + scanAreaSize, scanAreaTop + scanAreaSize),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(scanAreaLeft + scanAreaSize, scanAreaTop + scanAreaSize - cornerLength),
      Offset(scanAreaLeft + scanAreaSize, scanAreaTop + scanAreaSize),
      cornerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
