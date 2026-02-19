// Import flutter/material.dart for StatelessWidget
import 'package:flutter/material.dart';

// This is a placeholder file for web compatibility
// When running on web, this file will be used instead of qr_code_scanner

class QRViewController {
  // Placeholder for web compatibility
  void dispose() {}
  void pauseCamera() {}
  void resumeCamera() {}
  
  // Placeholder stream
  Stream<ScanData> get scannedDataStream => const Stream.empty();
}

class ScanData {
  final String? code;
  ScanData(this.code);
}

class QRView extends StatelessWidget {
  final Key? key;
  final Function(QRViewController)? onQRViewCreated;
  final QrScannerOverlayShape? overlay;

  const QRView({
    this.key,
    this.onQRViewCreated,
    this.overlay,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      child: const Center(
        child: Text('QR Scanner not available on web'),
      ),
    );
  }
}

class QrScannerOverlayShape {
  final Color borderColor;
  final double borderRadius;
  final double borderLength;
  final double borderWidth;
  final double cutOutSize;

  QrScannerOverlayShape({
    required this.borderColor,
    required this.borderRadius,
    required this.borderLength,
    required this.borderWidth,
    required this.cutOutSize,
  });
}










