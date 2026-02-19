import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../services/document_verification_service.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class BusinessPermitVerificationScreen extends StatefulWidget {
  final String email;
  final String firstName;
  final String lastName;
  final String phone;
  
  const BusinessPermitVerificationScreen({
    super.key,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.phone,
  });

  @override
  State<BusinessPermitVerificationScreen> createState() => _BusinessPermitVerificationScreenState();
}

class _BusinessPermitVerificationScreenState extends State<BusinessPermitVerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _businessNameController = TextEditingController();
  final TextEditingController _businessAddressController = TextEditingController();
  final TextEditingController _permitNumberController = TextEditingController();
  
  File? _businessPermitImage;
  File? _driversLicenseImage;
  bool _isUploading = false;
  bool _isVerifying = false;
  String _verificationStatus = '';
  
  final ImagePicker _picker = ImagePicker();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 176, 12, 1),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Business Verification',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Card
              _buildHeaderCard(),
              const SizedBox(height: 24),
              
              // Business Information
              _buildSectionTitle('Business Information'),
              const SizedBox(height: 16),
              _buildBusinessInfoForm(),
              const SizedBox(height: 24),
              
              // Document Upload Section
              _buildSectionTitle('Required Documents'),
              const SizedBox(height: 16),
              _buildDocumentUploadSection(),
              const SizedBox(height: 24),
              
              // Verification Status
              if (_verificationStatus.isNotEmpty) ...[
                _buildVerificationStatus(),
                const SizedBox(height: 24),
              ],
              
              // Submit Button
              _buildSubmitButton(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 176, 12, 1).withAlpha(26),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.business,
                  color: Color.fromARGB(255, 176, 12, 1),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Talyer Owner Registration',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      '${widget.firstName} ${widget.lastName}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'To complete your registration as a shop owner, please provide your business permit and driver\'s license for verification.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.black87,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue[600], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Documents will be verified to ensure authenticity',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue[700],
                      fontWeight: FontWeight.w500,
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

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildBusinessInfoForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildTextField(
            controller: _businessNameController,
            label: 'Business/Shop Name',
            hint: 'e.g., Pedro\'s AutoWorks',
            icon: Icons.store,
            validator: (value) => value?.isEmpty == true ? 'Business name is required' : null,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _businessAddressController,
            label: 'Business Address',
            hint: 'Complete business address',
            icon: Icons.location_on,
            maxLines: 2,
            validator: (value) => value?.isEmpty == true ? 'Business address is required' : null,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _permitNumberController,
            label: 'Business Permit Number',
            hint: 'Permit number from DTI/Mayor\'s office',
            icon: Icons.assignment,
            validator: (value) => value?.isEmpty == true ? 'Permit number is required' : null,
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: const Color.fromARGB(255, 176, 12, 1)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color.fromARGB(255, 176, 12, 1)),
        ),
      ),
    );
  }

  Widget _buildDocumentUploadSection() {
    return Column(
      children: [
        // Business Permit Upload
        _buildDocumentUploadCard(
          title: 'Business Permit',
          description: 'Upload a clear photo of your business permit',
          icon: Icons.business_center,
          image: _businessPermitImage,
          onTap: () => _pickImage(true),
          isRequired: true,
        ),
        const SizedBox(height: 16),
        
        // Driver's License Upload
        _buildDocumentUploadCard(
          title: 'Driver\'s License',
          description: 'Upload a clear photo of your driver\'s license',
          icon: Icons.credit_card,
          image: _driversLicenseImage,
          onTap: () => _pickImage(false),
          isRequired: true,
        ),
      ],
    );
  }

  Widget _buildDocumentUploadCard({
    required String title,
    required String description,
    required IconData icon,
    required File? image,
    required VoidCallback onTap,
    required bool isRequired,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: image != null ? Colors.green[300]! : Colors.grey[300]!,
          width: image != null ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                if (image != null) ...[
                  // Show uploaded image
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      image,
                      height: 120,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green[600], size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Document uploaded',
                        style: TextStyle(
                          color: Colors.green[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: onTap,
                        child: const Text('Change'),
                      ),
                    ],
                  ),
                ] else ...[
                  // Show upload prompt
                  Icon(
                    icon,
                    size: 48,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(255, 176, 12, 1).withAlpha(26),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.camera_alt,
                          color: Color.fromARGB(255, 176, 12, 1),
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Tap to upload',
                          style: TextStyle(
                            color: const Color.fromARGB(255, 176, 12, 1),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (isRequired)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Required *',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red[600],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVerificationStatus() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.verified, color: Colors.green[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _verificationStatus,
              style: TextStyle(
                color: Colors.green[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    final bool canSubmit = _businessNameController.text.isNotEmpty &&
        _businessAddressController.text.isNotEmpty &&
        _permitNumberController.text.isNotEmpty &&
        _businessPermitImage != null &&
        _driversLicenseImage != null &&
        !_isUploading &&
        !_isVerifying;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: canSubmit ? _submitVerification : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color.fromARGB(255, 176, 12, 1),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: _isVerifying
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  strokeWidth: 2,
                ),
              )
            : const Text(
                'Submit for Verification',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }

  Future<void> _pickImage(bool isBusinessPermit) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 1200,
        maxHeight: 1200,
      );

      if (pickedFile != null) {
        setState(() {
          if (isBusinessPermit) {
            _businessPermitImage = File(pickedFile.path);
          } else {
            _driversLicenseImage = File(pickedFile.path);
          }
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _submitVerification() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isVerifying = true);

    try {
      // Upload documents and verify
      final verificationResult = await DocumentVerificationService.verifyBusinessDocuments(
        businessName: _businessNameController.text.trim(),
        businessAddress: _businessAddressController.text.trim(),
        permitNumber: _permitNumberController.text.trim(),
        businessPermitImage: _businessPermitImage!,
        driversLicenseImage: _driversLicenseImage!,
        ownerName: '${widget.firstName} ${widget.lastName}',
      );

      if (verificationResult['success'] == true) {
        setState(() {
          _verificationStatus = 'Documents verified successfully! Creating your account...';
        });

        // Now create the actual talyer owner account
        final signupResult = await AuthService.instance.signUp(
          firstName: widget.firstName,
          lastName: widget.lastName,
          email: widget.email,
          phone: widget.phone,
          password: 'temp_password_will_be_reset', // User will reset via email
          userType: 'talyer_owner',
          companyName: _businessNameController.text.trim(),
        );

        if (signupResult.success) {
          // Show success dialog
          _showSuccessDialog();
        } else {
          throw Exception(signupResult.message);
        }
      } else {
        throw Exception(verificationResult['message'] ?? 'Verification failed');
      }
    } catch (e) {
      setState(() => _isVerifying = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Verification failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green[600], size: 28),
            const SizedBox(width: 12),
            const Text('Verification Complete'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your business documents have been verified successfully!',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Next Steps:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green[800],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text('• Check your email for verification link'),
                  const Text('• Click the link to verify your email'),
                  const Text('• Set up your password'),
                  const Text('• Start managing your auto shop!'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromARGB(255, 176, 12, 1),
            ),
            child: const Text(
              'Continue to Login',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _businessAddressController.dispose();
    _permitNumberController.dispose();
    super.dispose();
  }
}










