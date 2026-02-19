import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter/services.dart';
import '../services/qr_code_service.dart';

class QRCodeDisplayScreen extends StatefulWidget {
  final String serviceRequestId;
  final String serviceTitle;

  const QRCodeDisplayScreen({
    super.key,
    required this.serviceRequestId,
    required this.serviceTitle,
  });

  @override
  State<QRCodeDisplayScreen> createState() => _QRCodeDisplayScreenState();
}

class _QRCodeDisplayScreenState extends State<QRCodeDisplayScreen> {
  Map<String, dynamic>? qrData;
  bool isLoading = true;
  String? error;
  bool isExpired = false;

  @override
  void initState() {
    super.initState();
    _loadQRCode();
    _startExpirationTimer();
  }

  void _loadQRCode() async {
    try {
      final data = await QRCodeService.instance.getQRCodeData(widget.serviceRequestId);
      if (mounted) {
        setState(() {
          qrData = data;
          isLoading = false;
          if (data == null) {
            error = 'No valid QR code found. Please ensure payment is completed.';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = 'Failed to load QR code: $e';
          isLoading = false;
        });
      }
    }
  }

  void _startExpirationTimer() {
    // Check expiration every 30 seconds
    Future.delayed(const Duration(seconds: 30), () {
      if (mounted && qrData != null) {
        final expiresAt = DateTime.parse(qrData!['expires_at']);
        if (DateTime.now().isAfter(expiresAt)) {
          setState(() {
            isExpired = true;
          });
        } else {
          _startExpirationTimer();
        }
      }
    });
  }

  void _copyToClipboard() {
    if (qrData != null) {
      Clipboard.setData(ClipboardData(text: qrData!['completion_code']));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Completion code copied to clipboard'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  String _getTimeRemaining() {
    if (qrData == null) return '';
    
    final expiresAt = DateTime.parse(qrData!['expires_at']);
    final now = DateTime.now();
    final difference = expiresAt.difference(now);
    
    if (difference.isNegative) return 'Expired';
    
    final hours = difference.inHours;
    final minutes = difference.inMinutes % 60;
    
    if (hours > 0) {
      return 'Expires in ${hours}h ${minutes}m';
    } else {
      return 'Expires in ${minutes}m';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Job Completion QR Code'),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1976D2), Color(0xFF1565C0)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                // Header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(26),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.qr_code_2,
                        size: 40,
                        color: Color(0xFF1976D2),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Service Completion',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        widget.serviceTitle,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 30),

                // QR Code Display
                Expanded(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(26),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: _buildQRContent(),
                  ),
                ),

                const SizedBox(height: 20),

                // Instructions
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(230),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.white.withAlpha(77)),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: Color(0xFF1976D2),
                        size: 24,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Show this QR code to your mechanic when the service is completed to release payment.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQRContent() {
    if (isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text(
              'Generating QR code...',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (error != null || qrData == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 60,
              color: Colors.red,
            ),
            const SizedBox(height: 20),
            Text(
              error ?? 'Failed to load QR code',
              style: const TextStyle(
                fontSize: 16,
                color: Colors.red,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Go Back'),
            ),
          ],
        ),
      );
    }

    if (isExpired) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.access_time,
              size: 60,
              color: Colors.orange,
            ),
            const SizedBox(height: 20),
            const Text(
              'QR Code Expired',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'This QR code has expired. Please contact support for assistance.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loadQRCode,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1976D2),
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
        // QR Code
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.grey.shade300, width: 2),
          ),
          child: QrImageView(
            data: qrData!['completion_code'],
            version: QrVersions.auto,
            size: 200.0,
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
          ),
        ),

        const SizedBox(height: 30),

        // Completion Code
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Completion Code:',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    qrData!['completion_code'],
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              IconButton(
                onPressed: _copyToClipboard,
                icon: const Icon(Icons.copy, color: Color(0xFF1976D2)),
                tooltip: 'Copy code',
              ),
            ],
          ),
        ),

        const SizedBox(height: 15),

        // Expiration Timer
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.access_time,
                size: 16,
                color: Colors.orange.shade700,
              ),
              const SizedBox(width: 5),
              Text(
                _getTimeRemaining(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.orange.shade700,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
    );
  }
}










