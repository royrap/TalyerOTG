import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import '../services/cash_payment_verification_service.dart';

class CashPaymentScreen extends StatefulWidget {
  final Map<String, dynamic> invoice;
  final Map<String, dynamic> serviceRequest;

  const CashPaymentScreen({
    Key? key,
    required this.invoice,
    required this.serviceRequest,
  }) : super(key: key);

  @override
  State<CashPaymentScreen> createState() => _CashPaymentScreenState();
}

class _CashPaymentScreenState extends State<CashPaymentScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  final CashPaymentVerificationService _verificationService = CashPaymentVerificationService();
  
  File? _cashPaymentPhoto;
  bool _isUploading = false;
  bool _photoTaken = false;

  @override
  void initState() {
    super.initState();
    // Automatically open camera when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _openCamera();
    });
  }

  Future<void> _openCamera() async {
    try {
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        preferredCameraDevice: CameraDevice.rear,
      );

      if (photo != null) {
        setState(() {
          _cashPaymentPhoto = File(photo.path);
          _photoTaken = true;
        });
      } else {
        // User cancelled camera
        if (mounted) {
          _showCancelConfirmation();
        }
      }
    } catch (e) {
      print('❌ Error opening camera: $e');
      if (mounted) {
        _showErrorDialog('Failed to open camera. Please try again.');
      }
    }
  }

  void _showCancelConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Payment?'),
        content: const Text('You need to take a photo of your cash payment to continue. Do you want to cancel this payment?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              _openCamera(); // Try again
            },
            child: const Text('Take Photo'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Go back to previous screen
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Cancel Payment'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _retakePhoto() async {
    setState(() {
      _cashPaymentPhoto = null;
      _photoTaken = false;
    });
    await _openCamera();
  }

  Future<void> _submitPayment() async {
    if (_cashPaymentPhoto == null) {
      _showErrorDialog('Please take a photo of your cash payment first.');
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      final invoiceId = widget.invoice['id'];
      final customerId = widget.serviceRequest['customer_id'];
      final mechanicId = widget.serviceRequest['provider_id'];
      final requestId = widget.serviceRequest['id'];
      final totalAmount = widget.invoice['total_amount'] ?? 0.0;

      print('📸 Uploading cash payment photo...');

      // 1. Upload photo to Supabase Storage
      final photoUrl = await _verificationService.uploadCashPhoto(
        imageFile: _cashPaymentPhoto!,
        invoiceId: invoiceId,
        customerId: customerId,
      );

      if (photoUrl == null) {
        throw Exception('Failed to upload photo');
      }

      print('✅ Photo uploaded: $photoUrl');

      // 2. Create verification record (no payment_id yet, will be updated later)
      final verification = await _verificationService.createVerificationRecord(
        invoiceId: invoiceId,
        paymentId: 'pending', // Temporary, will be updated when payment is processed
        requestId: requestId,
        customerId: customerId,
        mechanicId: mechanicId,
        cashAmount: totalAmount.toDouble(),
        cashPhotoUrl: photoUrl,
      );

      if (verification == null) {
        throw Exception('Failed to create verification record');
      }

      print('✅ Verification record created: ${verification['id']}');

      // 3. Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Text('✅ Cash payment photo submitted! Waiting for verification...'),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );

        // 4. Go back to bottom sheet with success flag
        Navigator.pop(context, {
          'success': true,
          'verification_id': verification['id'],
          'photo_url': photoUrl,
        });
      }
    } catch (e) {
      print('❌ Error submitting payment: $e');
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
        _showErrorDialog('Failed to submit payment. Please try again.\n\nError: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'en_PH', symbol: '₱');

    return WillPopScope(
      onWillPop: () async {
        if (_isUploading) {
          return false; // Prevent back navigation while uploading
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          elevation: 0,
          leading: _isUploading
              ? null
              : IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
          title: const Text(
            'Cash Payment Proof',
            style: TextStyle(color: Colors.white),
          ),
        ),
        body: Column(
          children: [
            // Invoice Info Card
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.receipt_long, color: Colors.blue),
                      const SizedBox(width: 8),
                      Text(
                        'Invoice #${widget.invoice['invoice_number']}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Service:',
                        style: TextStyle(color: Colors.grey),
                      ),
                      Text(
                        widget.serviceRequest['title'] ?? 'Service',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Amount:',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        currencyFormat.format(widget.invoice['total_amount']),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Instructions Card
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: Colors.orange[700]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Payment Instructions',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange[900],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '1. Take a clear photo of your cash payment\n'
                          '2. Make sure the amount is visible\n'
                          '3. Submit the photo for verification\n'
                          '4. Wait for mechanic/shop owner to verify',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.orange[800],
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Photo Preview or Camera Button
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[700]!, width: 2),
                ),
                child: _photoTaken && _cashPaymentPhoto != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          _cashPaymentPhoto!,
                          fit: BoxFit.contain,
                        ),
                      )
                    : Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.camera_alt,
                              size: 80,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Opening camera...',
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ),

            // Action Buttons
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  if (_photoTaken && !_isUploading)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _retakePhoto,
                          icon: const Icon(Icons.camera_alt),
                          label: const Text('Retake Photo'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: (_photoTaken && !_isUploading) ? _submitPayment : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        disabledBackgroundColor: Colors.grey[700],
                      ),
                      child: _isUploading
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                ),
                                SizedBox(width: 12),
                                Text('Uploading...'),
                              ],
                            )
                          : const Text(
                              'Submit Payment Proof',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}











