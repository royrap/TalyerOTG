import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QRScannerWidget extends StatefulWidget {
  final Function(String) onQRScanned;
  final String title;
  final String description;
  final bool showManualEntry;
  final Color backgroundColor;

  const QRScannerWidget({
    super.key,
    required this.onQRScanned,
    this.title = 'Scan QR Code',
    this.description = 'Point camera at QR code to scan',
    this.showManualEntry = false,
    this.backgroundColor = const Color.fromARGB(255, 176, 12, 1),
  });

  @override
  State<QRScannerWidget> createState() => _QRScannerWidgetState();
}

class _QRScannerWidgetState extends State<QRScannerWidget> {
  MobileScannerController cameraController = MobileScannerController();
  bool _isFlashOn = false;
  bool _hasScanned = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    // For web platform, show a different UI
    if (kIsWeb) {
      return _buildWebQRScanner();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: widget.backgroundColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_isFlashOn ? Icons.flash_off : Icons.flash_on),
            onPressed: _toggleFlash,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Text(
              widget.description,
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: 5,
            child: Stack(
              children: [
                MobileScanner(
                  controller: cameraController,
                  onDetect: _onQRCodeDetected,
                ),
                // Overlay for scanning area
                Container(
                  decoration: ShapeDecoration(
                    shape: QrScannerOverlayShape(
                      borderColor: widget.backgroundColor,
                      borderRadius: 10,
                      borderLength: 30,
                      borderWidth: 10,
                      cutOutSize: 300,
                    ),
                  ),
                ),
                if (_hasScanned)
                  Container(
                    color: Colors.black54,
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            color: Colors.white,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Processing QR Code...',
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
          ),
          Expanded(
            flex: 1,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: _toggleFlash,
                    icon: Icon(_isFlashOn ? Icons.flash_off : Icons.flash_on),
                    label: Text(_isFlashOn ? 'Flash Off' : 'Flash On'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[700],
                      foregroundColor: Colors.white,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _resetScanner,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reset'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.backgroundColor,
                      foregroundColor: Colors.white,
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

  Widget _buildWebQRScanner() {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: widget.backgroundColor,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.qr_code_scanner,
                size: 100,
                color: widget.backgroundColor,
              ),
              const SizedBox(height: 24),
              const Text(
                'QR Scanner',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'QR scanning is not available on web platform.\nPlease use the mobile app for QR scanning.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Enter QR Code Manually',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.qr_code),
                ),
                onSubmitted: (value) {
                  if (value.isNotEmpty) {
                    widget.onQRScanned(value.trim());
                    Navigator.pop(context);
                  }
                },
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.backgroundColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 12,
                  ),
                ),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onQRCodeDetected(BarcodeCapture capture) {
    if (!_hasScanned && capture.barcodes.isNotEmpty) {
      final String? code = capture.barcodes.first.rawValue;
      if (code != null) {
        setState(() {
          _hasScanned = true;
        });
        
        // Stop the camera
        cameraController.stop();
        
        // Process the scanned QR code
        widget.onQRScanned(code);
        
        // Close the scanner after a delay
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            Navigator.pop(context);
          }
        });
      }
    }
  }

  void _toggleFlash() async {
    await cameraController.toggleTorch();
    setState(() {
      _isFlashOn = !_isFlashOn;
    });
  }

  void _resetScanner() {
    setState(() {
      _hasScanned = false;
    });
    cameraController.start();
  }

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }
}

// Custom overlay shape for QR scanner
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
    Path getLeftTopPath(double s) {
      return Path()
        ..moveTo(0, borderRadius)
        ..lineTo(0, borderLength)
        ..moveTo(0, 0)
        ..lineTo(borderLength, 0);
    }

    return getLeftTopPath(cutOutSize)
      ..addPath(
          getLeftTopPath(cutOutSize)
            ..transform(Matrix4.rotationZ(1.5708).storage), // 90 degrees
          Offset(cutOutSize, 0))
      ..addPath(
          getLeftTopPath(cutOutSize)
            ..transform(Matrix4.rotationZ(3.1416).storage), // 180 degrees
          Offset(cutOutSize, cutOutSize))
      ..addPath(
          getLeftTopPath(cutOutSize)
            ..transform(Matrix4.rotationZ(4.7124).storage), // 270 degrees
          Offset(0, cutOutSize))
      ..addRect(
        Rect.fromLTWH(rect.width / 2 - cutOutSize / 2,
            rect.height / 2 - cutOutSize / 2, cutOutSize, cutOutSize))
      ..fillType = PathFillType.evenOdd;
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final width = rect.width;
    final borderWidthSize = borderWidth / 2;
    final height = rect.height;
    final borderOffset = borderWidth / 2;
    final mBorderLength = borderLength > cutOutSize / 2 + borderWidth * 2
        ? borderWidthSize + cutOutSize / 2
        : borderLength;

    final backgroundPaint = Paint()
      ..color = overlayColor
      ..style = PaintingStyle.fill;

    final boxPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    final cutOutRect = Rect.fromLTWH(
      width / 2 - cutOutSize / 2,
      height / 2 - cutOutSize / 2,
      cutOutSize,
      cutOutSize,
    );

    canvas
      ..saveLayer(
        rect,
        backgroundPaint,
      )
      ..drawRect(rect, backgroundPaint)
      // Draw the cutout area
      ..drawRRect(
        RRect.fromRectAndCorners(
          cutOutRect,
          topLeft: Radius.circular(borderRadius),
          topRight: Radius.circular(borderRadius),
          bottomLeft: Radius.circular(borderRadius),
          bottomRight: Radius.circular(borderRadius),
        ),
        Paint()..blendMode = BlendMode.clear,
      )
      ..restore();

    // Draw corner borders
    final path = Path()
      // Top left
      ..moveTo(cutOutRect.left - borderOffset, cutOutRect.top + mBorderLength)
      ..lineTo(cutOutRect.left - borderOffset, cutOutRect.top + borderRadius)
      ..quadraticBezierTo(cutOutRect.left - borderOffset,
          cutOutRect.top - borderOffset, cutOutRect.left + borderRadius, cutOutRect.top - borderOffset)
      ..lineTo(cutOutRect.left + mBorderLength, cutOutRect.top - borderOffset)
      // Top right
      ..moveTo(cutOutRect.right - mBorderLength, cutOutRect.top - borderOffset)
      ..lineTo(cutOutRect.right - borderRadius, cutOutRect.top - borderOffset)
      ..quadraticBezierTo(cutOutRect.right + borderOffset,
          cutOutRect.top - borderOffset, cutOutRect.right + borderOffset, cutOutRect.top + borderRadius)
      ..lineTo(cutOutRect.right + borderOffset, cutOutRect.top + mBorderLength)
      // Bottom right
      ..moveTo(cutOutRect.right + borderOffset, cutOutRect.bottom - mBorderLength)
      ..lineTo(cutOutRect.right + borderOffset, cutOutRect.bottom - borderRadius)
      ..quadraticBezierTo(cutOutRect.right + borderOffset,
          cutOutRect.bottom + borderOffset, cutOutRect.right - borderRadius, cutOutRect.bottom + borderOffset)
      ..lineTo(cutOutRect.right - mBorderLength, cutOutRect.bottom + borderOffset)
      // Bottom left
      ..moveTo(cutOutRect.left + mBorderLength, cutOutRect.bottom + borderOffset)
      ..lineTo(cutOutRect.left + borderRadius, cutOutRect.bottom + borderOffset)
      ..quadraticBezierTo(cutOutRect.left - borderOffset,
          cutOutRect.bottom + borderOffset, cutOutRect.left - borderOffset, cutOutRect.bottom - borderRadius)
      ..lineTo(cutOutRect.left - borderOffset, cutOutRect.bottom - mBorderLength);

    canvas.drawPath(path, boxPaint);
  }

  @override
  ShapeBorder scale(double t) {
    return QrScannerOverlayShape(
      borderColor: borderColor,
      borderWidth: borderWidth,
      overlayColor: overlayColor,
    );
  }
}

/// Utility class for launching QR scanner
class QRScannerHelper {
  /// Launch QR scanner and return scanned result
  static Future<String?> scanQR(
    BuildContext context, {
    String title = 'Scan QR Code',
    String description = 'Point camera at QR code to scan',
  }) async {
    String? result;
    
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QRScannerWidget(
          title: title,
          description: description,
          onQRScanned: (qrCode) {
            result = qrCode;
          },
        ),
      ),
    );
    
    return result;
  }

  /// Launch QR scanner for job completion
  static Future<String?> scanJobCompletionQR(BuildContext context) async {
    return await scanQR(
      context,
      title: 'Scan Job Completion QR',
      description: 'Scan the customer\'s QR code to complete the job and release payment',
    );
  }

  /// Launch QR scanner for payment verification
  static Future<String?> scanPaymentQR(BuildContext context) async {
    return await scanQR(
      context,
      title: 'Scan Payment QR',
      description: 'Scan the PayMongo QR code to process payment',
    );
  }

  /// Launch QR scanner for admin verification
  static Future<String?> scanAdminQR(BuildContext context) async {
    return await scanQR(
      context,
      title: 'Admin QR Verification',
      description: 'Scan QR code for admin verification and payment release',
    );
  }
}










