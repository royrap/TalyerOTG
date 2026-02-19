import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/manual_verification_service.dart';

/// Manual Verification Screen for admins to extract and save permit/ID data
/// when AI verification fails
class ManualVerificationScreen extends StatefulWidget {
  final String userId;
  final String businessPermitUrl;
  final String validIdUrl;
  final String businessName;
  final String contactPerson;
  final String? existingVerificationId;

  const ManualVerificationScreen({
    super.key,
    required this.userId,
    required this.businessPermitUrl,
    required this.validIdUrl,
    required this.businessName,
    required this.contactPerson,
    this.existingVerificationId,
  });

  @override
  State<ManualVerificationScreen> createState() => _ManualVerificationScreenState();
}

class _ManualVerificationScreenState extends State<ManualVerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  
  // Permit Data Controllers
  final _permitBusinessNameController = TextEditingController();
  final _permitNumberController = TextEditingController();
  final _permitAddressController = TextEditingController();
  final _permitIssuingAuthorityController = TextEditingController();
  DateTime? _permitExpiryDate;
  
  // ID Data Controllers
  final _idFullNameController = TextEditingController();
  final _idNumberController = TextEditingController();
  final _idAddressController = TextEditingController();
  final _idGenderController = TextEditingController();
  DateTime? _idExpiryDate;
  DateTime? _idBirthDate;
  String _selectedIdType = 'drivers_license';
  
  // Contact Info Controllers
  final _businessAddressController = TextEditingController();
  final _phoneNumberController = TextEditingController();
  final _emailController = TextEditingController();
  final _adminNotesController = TextEditingController();
  
  // Verification Status
  String _verificationStatus = 'under_review';
  List<String> _tamperFlags = [];

  @override
  void initState() {
    super.initState();
    _permitBusinessNameController.text = widget.businessName;
    _idFullNameController.text = widget.contactPerson;
    _loadExistingVerification();
  }

  Future<void> _loadExistingVerification() async {
    if (widget.existingVerificationId != null) {
      final verification = await ManualVerificationService.getVerificationByUserId(widget.userId);
      if (verification != null && mounted) {
        setState(() {
          _permitBusinessNameController.text = verification['business_name'] ?? '';
          _businessAddressController.text = verification['business_address'] ?? '';
          _phoneNumberController.text = verification['phone_number'] ?? '';
          _emailController.text = verification['email'] ?? '';
          _adminNotesController.text = verification['admin_notes'] ?? '';
          _verificationStatus = verification['status'] ?? 'pending';
          _selectedIdType = verification['id_type'] ?? 'drivers_license';
          
          if (verification['permit_expiry_date'] != null) {
            _permitExpiryDate = DateTime.parse(verification['permit_expiry_date']);
          }
          if (verification['id_expiry_date'] != null) {
            _idExpiryDate = DateTime.parse(verification['id_expiry_date']);
          }
          
          _tamperFlags = List<String>.from(verification['tamper_flags'] ?? []);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manual Verification'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isLoading ? null : _saveVerification,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDocumentPreview(),
                    const SizedBox(height: 24),
                    _buildPermitDataSection(),
                    const SizedBox(height: 24),
                    _buildIdDataSection(),
                    const SizedBox(height: 24),
                    _buildContactInfoSection(),
                    const SizedBox(height: 24),
                    _buildVerificationControls(),
                    const SizedBox(height: 32),
                    _buildActionButtons(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildDocumentPreview() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Document Preview',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      const Text('Business Permit', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Container(
                        height: 150,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Image.network(
                          widget.businessPermitUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const Center(
                            child: Icon(Icons.error, color: Colors.red),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    children: [
                      const Text('Valid ID', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Container(
                        height: 150,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Image.network(
                          widget.validIdUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const Center(
                            child: Icon(Icons.error, color: Colors.red),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermitDataSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Business Permit Data',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.blue[700],
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _permitBusinessNameController,
              decoration: const InputDecoration(
                labelText: 'Business Name *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.business),
              ),
              validator: (value) => value?.isEmpty ?? true ? 'Business name is required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _permitNumberController,
              decoration: const InputDecoration(
                labelText: 'Permit Number',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.numbers),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _permitAddressController,
              decoration: const InputDecoration(
                labelText: 'Business Address',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _permitIssuingAuthorityController,
              decoration: const InputDecoration(
                labelText: 'Issuing Authority',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.account_balance),
              ),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: () => _selectDate(context, isPermit: true),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Permit Expiry Date',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.calendar_today),
                ),
                child: Text(
                  _permitExpiryDate != null
                      ? '${_permitExpiryDate!.day}/${_permitExpiryDate!.month}/${_permitExpiryDate!.year}'
                      : 'Select expiry date',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIdDataSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Valid ID Data',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.green[700],
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedIdType,
              decoration: const InputDecoration(
                labelText: 'ID Type *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.credit_card),
              ),
              items: const [
                DropdownMenuItem(value: 'drivers_license', child: Text('Driver\'s License')),
                DropdownMenuItem(value: 'umid', child: Text('UMID')),
                DropdownMenuItem(value: 'national_id', child: Text('National ID')),
                DropdownMenuItem(value: 'passport', child: Text('Passport')),
                DropdownMenuItem(value: 'philsys_id', child: Text('PhilSys ID')),
              ],
              onChanged: (value) => setState(() => _selectedIdType = value!),
              validator: (value) => value?.isEmpty ?? true ? 'ID type is required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _idFullNameController,
              decoration: const InputDecoration(
                labelText: 'Full Name *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
              validator: (value) => value?.isEmpty ?? true ? 'Full name is required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _idNumberController,
              decoration: const InputDecoration(
                labelText: 'ID Number',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.badge),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _idAddressController,
              decoration: const InputDecoration(
                labelText: 'Address',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.home),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _selectDate(context, isPermit: false),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'ID Expiry Date',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.calendar_today),
                      ),
                      child: Text(
                        _idExpiryDate != null
                            ? '${_idExpiryDate!.day}/${_idExpiryDate!.month}/${_idExpiryDate!.year}'
                            : 'Select expiry date',
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: InkWell(
                    onTap: () => _selectBirthDate(context),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Birth Date',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.cake),
                      ),
                      child: Text(
                        _idBirthDate != null
                            ? '${_idBirthDate!.day}/${_idBirthDate!.month}/${_idBirthDate!.year}'
                            : 'Select birth date',
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _idGenderController,
              decoration: const InputDecoration(
                labelText: 'Gender',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.wc),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactInfoSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Contact Information',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.orange[700],
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _businessAddressController,
              decoration: const InputDecoration(
                labelText: 'Business Address',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.business),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneNumberController,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email Address',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerificationControls() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Verification Controls',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.purple[700],
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _verificationStatus,
              decoration: const InputDecoration(
                labelText: 'Verification Status',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.verified),
              ),
              items: const [
                DropdownMenuItem(value: 'pending', child: Text('Pending')),
                DropdownMenuItem(value: 'under_review', child: Text('Under Review')),
                DropdownMenuItem(value: 'approved', child: Text('Approved')),
                DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
                DropdownMenuItem(value: 'additional_info_required', child: Text('Additional Info Required')),
              ],
              onChanged: (value) => setState(() => _verificationStatus = value!),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _adminNotesController,
              decoration: const InputDecoration(
                labelText: 'Admin Notes',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.note),
                hintText: 'Add any notes about this verification...',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [
                FilterChip(
                  label: const Text('Document Quality Issue'),
                  selected: _tamperFlags.contains('poor_quality'),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _tamperFlags.add('poor_quality');
                      } else {
                        _tamperFlags.remove('poor_quality');
                      }
                    });
                  },
                ),
                FilterChip(
                  label: const Text('Possible Tampering'),
                  selected: _tamperFlags.contains('possible_tampering'),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _tamperFlags.add('possible_tampering');
                      } else {
                        _tamperFlags.remove('possible_tampering');
                      }
                    });
                  },
                ),
                FilterChip(
                  label: const Text('Name Mismatch'),
                  selected: _tamperFlags.contains('name_mismatch'),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _tamperFlags.add('name_mismatch');
                      } else {
                        _tamperFlags.remove('name_mismatch');
                      }
                    });
                  },
                ),
                FilterChip(
                  label: const Text('Expired Document'),
                  selected: _tamperFlags.contains('expired'),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _tamperFlags.add('expired');
                      } else {
                        _tamperFlags.remove('expired');
                      }
                    });
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : _saveVerification,
            icon: const Icon(Icons.save),
            label: const Text('Save Verification'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[600],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : () => _saveAndApprove(),
            icon: const Icon(Icons.check_circle),
            label: const Text('Save & Approve'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[600],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _selectDate(BuildContext context, {required bool isPermit}) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2030),
    );
    
    if (picked != null) {
      setState(() {
        if (isPermit) {
          _permitExpiryDate = picked;
        } else {
          _idExpiryDate = picked;
        }
      });
    }
  }

  Future<void> _selectBirthDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(1990),
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
    );
    
    if (picked != null) {
      setState(() {
        _idBirthDate = picked;
      });
    }
  }

  Future<void> _saveVerification() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Extract permit data manually
      final permitResult = await ManualVerificationService.extractPermitDataManually(
        permitUrl: widget.businessPermitUrl,
        businessName: _permitBusinessNameController.text,
        businessAddress: _permitAddressController.text.isNotEmpty ? _permitAddressController.text : null,
        permitNumber: _permitNumberController.text.isNotEmpty ? _permitNumberController.text : null,
        expiryDate: _permitExpiryDate,
        issuingAuthority: _permitIssuingAuthorityController.text.isNotEmpty ? _permitIssuingAuthorityController.text : null,
      );

      // Extract ID data manually
      final idResult = await ManualVerificationService.extractIdDataManually(
        idUrl: widget.validIdUrl,
        idType: _selectedIdType,
        fullName: _idFullNameController.text,
        idNumber: _idNumberController.text.isNotEmpty ? _idNumberController.text : null,
        expiryDate: _idExpiryDate,
        address: _idAddressController.text.isNotEmpty ? _idAddressController.text : null,
        birthDate: _idBirthDate,
        gender: _idGenderController.text.isNotEmpty ? _idGenderController.text : null,
      );

      if (permitResult['success'] && idResult['success']) {
        // Complete manual verification
        final result = await ManualVerificationService.completeManualVerification(
          userId: widget.userId,
          businessName: _permitBusinessNameController.text,
          businessPermitUrl: widget.businessPermitUrl,
          validIdUrl: widget.validIdUrl,
          idType: _selectedIdType,
          contactPerson: _idFullNameController.text,
          extractedPermitData: permitResult['permit_data'],
          extractedIdData: idResult['id_data'],
          businessAddress: _businessAddressController.text.isNotEmpty ? _businessAddressController.text : null,
          phoneNumber: _phoneNumberController.text.isNotEmpty ? _phoneNumberController.text : null,
          email: _emailController.text.isNotEmpty ? _emailController.text : null,
          adminNotes: _adminNotesController.text.isNotEmpty ? _adminNotesController.text : null,
          status: _verificationStatus,
        );

        // Add tamper flags if any
        if (_tamperFlags.isNotEmpty) {
          await ManualVerificationService.addTamperFlags(
            userId: widget.userId,
            flags: _tamperFlags,
          );
        }

        if (result['success'] && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Manual verification saved successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        } else {
          throw Exception(result['message']);
        }
      } else {
        throw Exception('Failed to extract document data');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error saving verification: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveAndApprove() async {
    _verificationStatus = 'approved';
    await _saveVerification();
  }

  @override
  void dispose() {
    _permitBusinessNameController.dispose();
    _permitNumberController.dispose();
    _permitAddressController.dispose();
    _permitIssuingAuthorityController.dispose();
    _idFullNameController.dispose();
    _idNumberController.dispose();
    _idAddressController.dispose();
    _idGenderController.dispose();
    _businessAddressController.dispose();
    _phoneNumberController.dispose();
    _emailController.dispose();
    _adminNotesController.dispose();
    super.dispose();
  }
}










