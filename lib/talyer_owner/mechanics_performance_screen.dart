import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'talyer_owner_api_service.dart';

class MechanicsPerformanceScreen extends StatefulWidget {
  final String shopId;

  const MechanicsPerformanceScreen({Key? key, required this.shopId}) : super(key: key);

  @override
  State<MechanicsPerformanceScreen> createState() => _MechanicsPerformanceScreenState();
}

class _MechanicsPerformanceScreenState extends State<MechanicsPerformanceScreen> {
  final TalyerOwnerApiService _apiService = TalyerOwnerApiService();
  
  List<Map<String, dynamic>> _mechanics = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMechanics();
  }

  Future<void> _loadMechanics() async {
    setState(() => _isLoading = true);
    
    try {
      final mechanics = await _apiService.getMechanicsPerformance(widget.shopId);
      
      setState(() {
        _mechanics = mechanics;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading mechanics: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mechanics Performance'),
        backgroundColor: Colors.red,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMechanics,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _mechanics.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.engineering, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No mechanics found',
                        style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadMechanics,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _mechanics.length,
                    itemBuilder: (context, index) {
                      return _buildMechanicCard(_mechanics[index]);
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddMechanicDialog(context),
        backgroundColor: Colors.orange,
        icon: const Icon(Icons.person_add),
        label: const Text('Add Mechanic'),
      ),
    );
  }

  Widget _buildMechanicCard(Map<String, dynamic> mechanic) {
    final name = mechanic['name'] as String;
    final profileImage = mechanic['profileImage'] as String?;
    final rating = mechanic['rating'] as num;
    final totalJobs = mechanic['totalJobs'] as int;
    final completedJobs = mechanic['completedJobs'] as int;
    final cancelledJobs = mechanic['cancelledJobs'] as int;
    final totalEarnings = mechanic['totalEarnings'] as num;

    final completionRate = totalJobs > 0 
        ? (completedJobs / totalJobs * 100).toStringAsFixed(1)
        : '0.0';

    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showMechanicDetails(mechanic),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundImage: profileImage != null && profileImage.isNotEmpty
                        ? NetworkImage(profileImage)
                        : null,
                    child: profileImage == null || profileImage.isEmpty
                        ? const Icon(Icons.person, size: 30)
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.star, size: 16, color: Colors.amber[700]),
                            const SizedBox(width: 4),
                            Text(
                              rating.toStringAsFixed(1),
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[700],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Text(
                              '$completionRate% completion',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _buildStatColumn('Total Jobs', '$totalJobs', Icons.work, Colors.blue),
                  ),
                  Expanded(
                    child: _buildStatColumn('Completed', '$completedJobs', Icons.check_circle, Colors.green),
                  ),
                  Expanded(
                    child: _buildStatColumn('Cancelled', '$cancelledJobs', Icons.cancel, Colors.red),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total Earnings:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '₱${totalEarnings.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatColumn(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, size: 24, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  void _showMechanicDetails(Map<String, dynamic> mechanic) {
    final name = mechanic['name'] as String;
    final email = mechanic['email'] as String?;
    final phone = mechanic['phone'] as String?;
    final totalJobs = mechanic['totalJobs'] as int;
    final completedJobs = mechanic['completedJobs'] as int;
    final cancelledJobs = mechanic['cancelledJobs'] as int;
    final totalEarnings = mechanic['totalEarnings'] as num;
    final rating = mechanic['rating'] as num;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(name),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Email', email ?? 'N/A'),
              _buildDetailRow('Phone', phone ?? 'N/A'),
              _buildDetailRow('Rating', '${rating.toStringAsFixed(1)} ⭐'),
              const Divider(),
              const Text('Performance Metrics', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _buildDetailRow('Total Jobs', '$totalJobs'),
              _buildDetailRow('Completed Jobs', '$completedJobs'),
              _buildDetailRow('Cancelled Jobs', '$cancelledJobs'),
              _buildDetailRow('Completion Rate', '${totalJobs > 0 ? (completedJobs / totalJobs * 100).toStringAsFixed(1) : 0}%'),
              _buildDetailRow('Total Earnings', '₱${totalEarnings.toStringAsFixed(2)}'),
              _buildDetailRow('Avg. Earnings per Job', totalJobs > 0 ? '₱${(totalEarnings / totalJobs).toStringAsFixed(2)}' : '₱0.00'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Navigate to mechanic job history or detailed performance
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
            child: const Text('View Job History'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddMechanicDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AddMechanicDialog(
        shopId: widget.shopId,
        onMechanicAdded: () {
          _loadMechanics(); // Refresh the list
        },
      ),
    );
  }
}

class AddMechanicDialog extends StatefulWidget {
  final String shopId;
  final VoidCallback onMechanicAdded;

  const AddMechanicDialog({
    Key? key,
    required this.shopId,
    required this.onMechanicAdded,
  }) : super(key: key);

  @override
  State<AddMechanicDialog> createState() => _AddMechanicDialogState();
}

class _AddMechanicDialogState extends State<AddMechanicDialog> {
  final _formKey = GlobalKey<FormState>();
  final TalyerOwnerApiService _apiService = TalyerOwnerApiService();
  final ImagePicker _imagePicker = ImagePicker();
  
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _specializationController = TextEditingController();
  final TextEditingController _yearsExperienceController = TextEditingController();
  
  File? _profileImage;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _specializationController.dispose();
    _yearsExperienceController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _profileImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_profileImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a profile picture'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await _apiService.addMechanic(
        email: _emailController.text.trim(),
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        phone: _phoneController.text.trim(),
        profileImage: _profileImage!,
        specialization: _specializationController.text.trim(),
        yearsExperience: int.parse(_yearsExperienceController.text.trim()),
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mechanic added successfully! A welcome email with login credentials has been sent.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 5),
          ),
        );
        widget.onMechanicAdded();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Add New Mechanic',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // Profile Picture Section
                Center(
                  child: GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.grey[200],
                        border: Border.all(color: Colors.orange, width: 3),
                      ),
                      child: _profileImage != null
                          ? ClipOval(
                              child: Image.file(
                                _profileImage!,
                                fit: BoxFit.cover,
                              ),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.camera_alt, size: 40, color: Colors.grey[600]),
                                const SizedBox(height: 8),
                                Text(
                                  'Add Photo',
                                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Center(
                  child: Text(
                    'Required *',
                    style: TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
                const SizedBox(height: 24),
                
                // Email Field
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Email is required';
                    }
                    if (!value.contains('@')) {
                      return 'Enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                // First Name Field
                TextFormField(
                  controller: _firstNameController,
                  decoration: const InputDecoration(
                    labelText: 'First Name *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'First name is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                // Last Name Field
                TextFormField(
                  controller: _lastNameController,
                  decoration: const InputDecoration(
                    labelText: 'Last Name *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Last name is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                // Phone Field
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone),
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Phone number is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                // Specialization Field
                TextFormField(
                  controller: _specializationController,
                  decoration: const InputDecoration(
                    labelText: 'Specialization *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.build),
                    hintText: 'e.g., Engine Repair, Electrical, Brakes',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Specialization is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                // Years of Experience Field
                TextFormField(
                  controller: _yearsExperienceController,
                  decoration: const InputDecoration(
                    labelText: 'Years of Experience *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.work),
                    hintText: 'e.g., 5',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Years of experience is required';
                    }
                    final years = int.tryParse(value);
                    if (years == null || years < 0) {
                      return 'Enter a valid number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                
                // Info Box
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info, color: Colors.blue[700], size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'A welcome email with a temporary password will be sent to the mechanic. They must verify their email and change their password on first login.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue[900],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                
                // Submit Button
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Add Mechanic',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
