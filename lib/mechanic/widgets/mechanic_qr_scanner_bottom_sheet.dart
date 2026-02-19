import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/job_completion_qr_service.dart';
import '../../services/auth_service.dart';

class MechanicQRScannerBottomSheet extends StatefulWidget {
  final String jobId;
  final VoidCallback? onSuccess;
  final VoidCallback? onClose;

  const MechanicQRScannerBottomSheet({
    Key? key,
    required this.jobId,
    this.onSuccess,
    this.onClose,
  }) : super(key: key);

  @override
  State<MechanicQRScannerBottomSheet> createState() => _MechanicQRScannerBottomSheetState();
}

class _MechanicQRScannerBottomSheetState extends State<MechanicQRScannerBottomSheet>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late Animation<double> _slideAnimation;
  
  MobileScannerController? _cameraController;
  bool _isScanning = false;
  bool _isProcessing = false;
  String? _scanResult;
  String? _errorMessage;
  bool _scanningEnabled = true;
  
  // Manual QR code entry
  final TextEditingController _manualQRController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeInOut,
    ));
    
    // Start the slide animation
    _slideController.forward();
    
    // Initialize camera
    _initializeCamera();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _slideController.dispose();
    _manualQRController.dispose();
    super.dispose();
  }

  void _initializeCamera() {
    try {
      _cameraController = MobileScannerController(
        detectionSpeed: DetectionSpeed.noDuplicates,
        returnImage: false,
      );
      
      // Explicitly start the camera
      _cameraController?.start().then((_) {
        print('📸 Camera started successfully');
        if (mounted) {
          setState(() {
            _isScanning = true;
            _errorMessage = null;
          });
        }
      }).catchError((error) {
        print('❌ Error starting camera: $error');
        if (mounted) {
          setState(() {
            _errorMessage = 'Failed to start camera: $error';
            _isScanning = false;
          });
        }
      });
    } catch (e) {
      print('❌ Error initializing camera: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Camera initialization error: $e';
          _isScanning = false;
        });
      }
    }
  }

  void _onQRDetected(BarcodeCapture capture) async {
    if (_isProcessing || !_scanningEnabled) return;
    
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;
    
    final String? scannedData = barcodes.first.rawValue;
    if (scannedData == null || scannedData.isEmpty) return;
    
    print('� QR Code detected by camera: $scannedData');
    
    // Use the shared processing method
    await _processQRCode(scannedData);
  }

  // Get current mechanic ID from authentication service
  String? _getCurrentMechanicId() {
    try {
      // Try to get from AuthService first
      final authService = AuthService.instance;
      if (authService.currentUser?.id != null) {
        return authService.currentUser!.id;
      }
      
      // Fallback to Supabase auth
      final supabase = Supabase.instance.client;
      return supabase.auth.currentUser?.id;
    } catch (e) {
      print('❌ Error getting mechanic ID: $e');
      return null;
    }
  }
  
  void _restartScanning() {
    setState(() {
      _isProcessing = false;
      _scanningEnabled = true;
      _errorMessage = null;
      _scanResult = null;
      _manualQRController.clear();
    });
  }
  
  // Build manual QR code input field
  Widget _buildManualQRInput() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _manualQRController,
            decoration: InputDecoration(
              hintText: 'Enter QR code (e.g., JOB-XXXXX)',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            style: const TextStyle(fontSize: 14),
            enabled: !_isProcessing,
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: _isProcessing ? null : _verifyManualQRCode,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color.fromARGB(255, 176, 12, 1),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          child: const Text('Verify'),
        ),
      ],
    );
  }
  
  // Verify manually entered QR code
  Future<void> _verifyManualQRCode() async {
    final qrCode = _manualQRController.text.trim();
    
    if (qrCode.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a QR code';
      });
      return;
    }
    
    print('📝 Manually entered QR code: $qrCode');
    
    // Use the shared processing method
    await _processQRCode(qrCode);
  }
  
  // Process QR code (used by both camera and manual entry)
  Future<void> _processQRCode(String scannedData) async {
    if (_isProcessing) return;
    
    setState(() {
      _isProcessing = true;
      _scanningEnabled = false;
      _scanResult = scannedData;
      _errorMessage = null;
    });
    
    print('🔍 Processing QR Code: $scannedData');
    
    try {
      // Get current mechanic ID from auth service
      final mechanicId = _getCurrentMechanicId();
      if (mechanicId == null) {
        throw 'Unable to identify mechanic. Please login again.';
      }
      
      // Parse completion code from QR data
      String? completionCode;
      
      if (scannedData.startsWith('RoadAid_JOB_COMPLETION:')) {
        // New format: RoadAid_JOB_COMPLETION:requestId:completionCode:timestamp
        final parts = scannedData.split(':');
        if (parts.length >= 3) {
          completionCode = parts[2];
        }
      } else if (scannedData.contains('code=') || scannedData.contains('&')) {
        // URL parameter format
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
        } catch (e) {
          print('⚠️ Failed to parse URL format: $e');
        }
      }
      
      // If no specific format, try using whole string
      if (completionCode == null || completionCode.isEmpty) {
        if (scannedData.toUpperCase().startsWith('JOB-') || 
            scannedData.length >= 8) {
          completionCode = scannedData.trim();
        } else {
          throw 'Invalid QR code format. Please enter a valid RoadAid completion code.';
        }
      }
      
      print('🎯 Extracted completion code: $completionCode');
      
      // Verify and use QR code
      final result = await JobCompletionQRService.instance.verifyAndUseQR(
        completionCode: completionCode,
        providerId: mechanicId,
      );
      
      if (result == true) {
        print('✅ QR verification successful!');
        
        setState(() {
          _errorMessage = null;
        });
        
        // Show enhanced success message with earnings info
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.white),
                      SizedBox(width: 8),
                      Text('✅ Job Completed Successfully!'),
                    ],
                  ),
                  SizedBox(height: 4),
                  Text(
                    '💰 Your earnings have been calculated and added to history',
                    style: TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ],
              ),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 4),
            ),
          );
        }
        
        // Call success callback
        if (widget.onSuccess != null) {
          widget.onSuccess!();
        }
        
        // Close bottom sheet after success
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          Navigator.of(context).pop();
        }
      } else {
        print('❌ QR verification failed');
        
        setState(() {
          _errorMessage = 'QR verification failed. Please check the code and try again.';
        });
        
        // Re-enable scanning after error
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          setState(() {
            _isProcessing = false;
            _scanningEnabled = true;
          });
        }
      }
    } catch (e) {
      print('❌ Error during QR verification: $e');
      
      setState(() {
        _errorMessage = 'Error: ${e.toString()}';
      });
      
      // Re-enable scanning after error
      await Future.delayed(const Duration(seconds: 3));
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _scanningEnabled = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation.drive(
        Tween<Offset>(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ),
      ),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 10,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // QR scanner icon
                  Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: Color.fromARGB(255, 176, 12, 1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.qr_code_scanner,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  
                  // Header text
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Scan Completion QR',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Scan the customer\'s QR code to complete the job',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Close button
                  IconButton(
                    onPressed: () {
                      if (widget.onClose != null) {
                        widget.onClose!();
                      }
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.close, color: Colors.grey),
                  ),
                ],
              ),
            ),
            
            const Divider(height: 1),
            
            // Camera scanner
            Expanded(
              child: _buildScannerContent(),
            ),
            
            // Bottom info/controls
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                border: Border(
                  top: BorderSide(color: Colors.grey[300]!),
                ),
              ),
              child: Column(
                children: [
                  if (_isProcessing) ...[
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 12),
                        Text('Verifying QR code...'),
                      ],
                    ),
                  ] else if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red[200]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error, color: Colors.red[700], size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(
                                color: Colors.red[700],
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _restartScanning,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color.fromARGB(255, 176, 12, 1),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Try Again'),
                      ),
                    ),
                  ] else if (_scanResult != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red[200]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.red[700], size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'QR Code scanned: ${_scanResult!}',
                              style: TextStyle(
                                color: Colors.red[700],
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    const Text(
                      '📱 Point camera at customer\'s QR code',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Job ID: ${widget.jobId}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    const Text(
                      'Camera not working? Enter QR code manually:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildManualQRInput(),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScannerContent() {
    if (!_isScanning || _cameraController == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.camera_alt,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              'Initializing camera...',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }
    
    return Stack(
      children: [
        // Camera preview
        MobileScanner(
          controller: _cameraController,
          onDetect: _onQRDetected,
        ),
        
        // Overlay with scanning frame
        Container(
          decoration: ShapeDecoration(
            shape: QrScannerOverlayShape(
              borderColor: const Color.fromARGB(255, 176, 12, 1),
              borderRadius: 10,
              borderLength: 30,
              borderWidth: 4,
              cutOutSize: MediaQuery.of(context).size.width * 0.7,
            ),
          ),
        ),
        
        // Scanning line animation (if not processing)
        if (!_isProcessing && _scanningEnabled)
          Center(
            child: Container(
              width: MediaQuery.of(context).size.width * 0.7,
              height: MediaQuery.of(context).size.width * 0.7,
              child: const ScanningLineAnimation(),
            ),
          ),
      ],
    );
  }
}

class QrScannerOverlayShape extends ShapeBorder {
  final Color borderColor;
  final double borderWidth;
  final Color overlayColor;
  final double borderRadius;
  final double borderLength;
  final double cutOutSize;

  const QrScannerOverlayShape({
    this.borderColor = Colors.red,
    this.borderWidth = 3.0,
    this.overlayColor = const Color.fromRGBO(0, 0, 0, 80),
    this.borderRadius = 0,
    this.borderLength = 40,
    this.cutOutSize = 250,
  });

  @override
  EdgeInsetsGeometry get dimensions => const EdgeInsets.all(10);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return Path()
      ..fillType = PathFillType.evenOdd
      ..addPath(getOuterPath(rect), Offset.zero);
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    Path path = Path()..addRect(rect);
    Path cutOutPath = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: rect.center,
          width: cutOutSize,
          height: cutOutSize,
        ),
        Radius.circular(borderRadius),
      ));
    return Path.combine(PathOperation.difference, path, cutOutPath);
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final Paint paint = Paint()
      ..color = overlayColor
      ..style = PaintingStyle.fill;

    canvas.drawPath(getOuterPath(rect), paint);

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    final Rect cutOutRect = Rect.fromCenter(
      center: rect.center,
      width: cutOutSize,
      height: cutOutSize,
    );

    // Draw corner borders
    final Path borderPath = Path();

    // Top left corner
    borderPath.moveTo(cutOutRect.left - borderWidth / 2, cutOutRect.top + borderLength);
    borderPath.lineTo(cutOutRect.left - borderWidth / 2, cutOutRect.top + borderRadius);
    borderPath.arcToPoint(
      Offset(cutOutRect.left + borderRadius, cutOutRect.top - borderWidth / 2),
      radius: Radius.circular(borderRadius),
    );
    borderPath.lineTo(cutOutRect.left + borderLength, cutOutRect.top - borderWidth / 2);

    // Top right corner
    borderPath.moveTo(cutOutRect.right - borderLength, cutOutRect.top - borderWidth / 2);
    borderPath.lineTo(cutOutRect.right - borderRadius, cutOutRect.top - borderWidth / 2);
    borderPath.arcToPoint(
      Offset(cutOutRect.right + borderWidth / 2, cutOutRect.top + borderRadius),
      radius: Radius.circular(borderRadius),
    );
    borderPath.lineTo(cutOutRect.right + borderWidth / 2, cutOutRect.top + borderLength);

    // Bottom right corner
    borderPath.moveTo(cutOutRect.right + borderWidth / 2, cutOutRect.bottom - borderLength);
    borderPath.lineTo(cutOutRect.right + borderWidth / 2, cutOutRect.bottom - borderRadius);
    borderPath.arcToPoint(
      Offset(cutOutRect.right - borderRadius, cutOutRect.bottom + borderWidth / 2),
      radius: Radius.circular(borderRadius),
    );
    borderPath.lineTo(cutOutRect.right - borderLength, cutOutRect.bottom + borderWidth / 2);

    // Bottom left corner
    borderPath.moveTo(cutOutRect.left + borderLength, cutOutRect.bottom + borderWidth / 2);
    borderPath.lineTo(cutOutRect.left + borderRadius, cutOutRect.bottom + borderWidth / 2);
    borderPath.arcToPoint(
      Offset(cutOutRect.left - borderWidth / 2, cutOutRect.bottom - borderRadius),
      radius: Radius.circular(borderRadius),
    );
    borderPath.lineTo(cutOutRect.left - borderWidth / 2, cutOutRect.bottom - borderLength);

    canvas.drawPath(borderPath, borderPaint);
  }

  @override
  ShapeBorder scale(double t) {
    return QrScannerOverlayShape(
      borderColor: borderColor,
      borderWidth: borderWidth * t,
      overlayColor: overlayColor,
      borderRadius: borderRadius * t,
      borderLength: borderLength * t,
      cutOutSize: cutOutSize * t,
    );
  }
}

class ScanningLineAnimation extends StatefulWidget {
  const ScanningLineAnimation({Key? key}) : super(key: key);

  @override
  State<ScanningLineAnimation> createState() => _ScanningLineAnimationState();
}

class _ScanningLineAnimationState extends State<ScanningLineAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(_animationController);
    _animationController.repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return CustomPaint(
          painter: ScanningLinePainter(_animation.value),
        );
      },
    );
  }
}

class ScanningLinePainter extends CustomPainter {
  final double animationValue;

  ScanningLinePainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = const Color.fromARGB(255, 176, 12, 1).withOpacity(0.8)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final double lineY = size.height * animationValue;
    
    canvas.drawLine(
      Offset(0, lineY),
      Offset(size.width, lineY),
      paint,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true;
  }
}