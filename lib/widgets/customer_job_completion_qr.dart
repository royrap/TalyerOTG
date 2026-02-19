import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/job_completion_qr_service.dart';

class CustomerJobCompletionQR extends StatefulWidget {
  final Map<String, dynamic> serviceRequest;

  const CustomerJobCompletionQR({
    Key? key,
    required this.serviceRequest,
  }) : super(key: key);

  @override
  State<CustomerJobCompletionQR> createState() => _CustomerJobCompletionQRState();
}

class _CustomerJobCompletionQRState extends State<CustomerJobCompletionQR> {
  Map<String, dynamic>? _qrData;
  bool _isLoading = true;
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _loadOrGenerateQR();
  }

  Future<void> _loadOrGenerateQR() async {
    try {
      setState(() => _isLoading = true);

      // First try to get existing QR
      final existingQR = await JobCompletionQRService.instance.getJobCompletionQR(
        widget.serviceRequest['id'],
      );

      if (existingQR != null) {
        setState(() {
          _qrData = existingQR;
          _isLoading = false;
        });
        return;
      }

      // Generate new QR if none exists
      await _generateNewQR();

    } catch (e) {
      print('❌ Error loading QR: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _generateNewQR() async {
    try {
      setState(() => _isGenerating = true);

      final qrData = await JobCompletionQRService.instance.generateJobCompletionQR(
        requestId: widget.serviceRequest['id'],
        customerId: widget.serviceRequest['customer_id'],
      );

      if (qrData != null) {
        setState(() {
          _qrData = qrData;
          _isLoading = false;
          _isGenerating = false;
        });
      } else {
        throw Exception('Failed to generate QR code');
      }

    } catch (e) {
      print('❌ Error generating QR: $e');
      setState(() {
        _isGenerating = false;
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating QR code: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatExpiryTime(String expiresAt) {
    try {
      final expiryDate = DateTime.parse(expiresAt);
      final now = DateTime.now();
      final difference = expiryDate.difference(now);

      if (difference.isNegative) {
        return 'Expired';
      }

      if (difference.inHours > 0) {
        return '${difference.inHours}h ${difference.inMinutes % 60}m remaining';
      } else {
        return '${difference.inMinutes}m remaining';
      }
    } catch (e) {
      return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.qr_code,
                  color: Colors.green,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Job Completion QR',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Show this to mechanic when service is complete',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          if (_isLoading)
            const Column(
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Loading QR code...'),
              ],
            )
          else if (_qrData == null)
            Column(
              children: [
                const Icon(
                  Icons.error,
                  color: Colors.red,
                  size: 48,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Unable to generate QR code',
                  style: TextStyle(color: Colors.red),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _isGenerating ? null : _generateNewQR,
                  child: _isGenerating
                      ? const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 8),
                            Text('Generating...'),
                          ],
                        )
                      : const Text('Retry'),
                ),
              ],
            )
          else
            Column(
              children: [
                // QR Code
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: QrImageView(
                    data: _qrData!['qr_data'],
                    version: QrVersions.auto,
                    size: 200.0,
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    errorCorrectionLevel: QrErrorCorrectLevel.M,
                  ),
                ),
                const SizedBox(height: 16),

                // QR Details
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Completion Code:',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                          Text(
                            _qrData!['completion_code'],
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Valid until:',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                          Text(
                            _formatExpiryTime(_qrData!['expires_at']),
                            style: TextStyle(
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Instructions
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info, color: Colors.blue, size: 16),
                          SizedBox(width: 8),
                          Text(
                            'Instructions:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        '1. Show this QR code to your mechanic\n'
                        '2. Mechanic will scan to complete the job\n'
                        '3. Keep this code until service is finished',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}