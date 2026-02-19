import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../services/auth_service.dart';
import '../services/security_logging_service.dart';

class CustomerProfileScreen extends StatefulWidget {
  const CustomerProfileScreen({super.key});

  @override
  State<CustomerProfileScreen> createState() => _CustomerProfileScreenState();
}

class _CustomerProfileScreenState extends State<CustomerProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  Map<String, dynamic>? _userProfile;
  bool _isLoading = true;
  bool _isUpdating = false;
  bool _isChangingPassword = false;
  File? _newProfileImage;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    try {
      _userProfile = AuthService.instance.userProfile;
      if (_userProfile != null) {
        _firstNameController.text = _userProfile!['first_name'] ?? '';
        _lastNameController.text = _userProfile!['last_name'] ?? '';
        _emailController.text = _userProfile!['email'] ?? '';
        _phoneController.text = _userProfile!['phone_number'] ?? '';
      }
    } catch (e) {
      print('Error loading user profile: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickProfileImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 800,
        maxHeight: 800,
      );
      
      if (image != null) {
        setState(() {
          _newProfileImage = File(image.path);
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

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isUpdating = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      String? newImageUrl;
      String? oldImageUrl = _userProfile?['profile_image_url'];

      // Upload new profile image if selected
      if (_newProfileImage != null) {
        try {
          final fileName = '${user.id}/profile_${DateTime.now().millisecondsSinceEpoch}.${_newProfileImage!.path.split('.').last}';
          await Supabase.instance.client.storage
              .from('profile-images')
              .upload(fileName, _newProfileImage!);
          
          newImageUrl = Supabase.instance.client.storage
              .from('profile-images')
              .getPublicUrl(fileName);

          // Log profile image change
          await SecurityLoggingService.logProfileImageChange(
            userId: user.id,
            oldImageUrl: oldImageUrl,
            newImageUrl: newImageUrl,
            uploadStatus: 'uploaded',
            fileSize: await _newProfileImage!.length(),
            fileType: _newProfileImage!.path.split('.').last,
          );
        } catch (e) {
          print('Error uploading profile image: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to upload profile image, but other changes will be saved'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }

      // Update profile data
      final updateData = {
        'first_name': _firstNameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        'phone_number': _phoneController.text.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (newImageUrl != null) {
        updateData['profile_image_url'] = newImageUrl;
      }

      // Update email if it changed
      final currentEmail = _userProfile?['email'] ?? '';
      final newEmail = _emailController.text.trim();
      
      if (currentEmail != newEmail) {
        // Show confirmation dialog before changing email
        final bool? confirmChange = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.email, color: Colors.orange),
                SizedBox(width: 8),
                Text('Change Email Address'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('You are about to change your email from:'),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    currentEmail,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 8),
                const Text('To:'),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.red[200]!),
                  ),
                  child: Text(
                    newEmail,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red[700],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'A confirmation link will be sent to your new email address. You must click the link to complete the change.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue[900],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Send Confirmation'),
              ),
            ],
          ),
        );

        if (confirmChange == true) {
          try {
            // Update email in Supabase Auth - this will send confirmation email
            await Supabase.instance.client.auth.updateUser(
              UserAttributes(email: newEmail),
            );
            
            // Log email change attempt
            await SecurityLoggingService.logProfileUpdate(
              userId: user.id,
              fieldName: 'email',
              oldValue: currentEmail,
              newValue: newEmail,
              updateType: 'email',
            );
            
            // Log in account security logs
            await Supabase.instance.client.from('account_security_logs').insert({
              'user_id': user.id,
              'action_type': 'email_change',
              'success': true,
              'details': {
                'old_email': currentEmail,
                'new_email': newEmail,
                'verification_pending': true,
              },
            });
            
            if (mounted) {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Row(
                    children: [
                      Icon(Icons.mark_email_read, color: Colors.green),
                      SizedBox(width: 8),
                      Text('Confirmation Email Sent'),
                    ],
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'We\'ve sent a confirmation email to:',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.red[200]!),
                        ),
                        width: double.infinity,
                        child: Text(
                          newEmail,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red[700],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.info_outline, color: Colors.orange[700], size: 20),
                                const SizedBox(width: 8),
                                const Text(
                                  'Important:',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              '• Check your inbox and spam folder\n'
                              '• Click the confirmation link in the email\n'
                              '• Your email will be updated after confirmation\n'
                              '• You can continue using your current email until then',
                              style: TextStyle(fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Got it'),
                    ),
                  ],
                ),
              );
            }
            
            // Don't update the email in user_profiles yet - wait for confirmation
            // Remove email from updateData
            // Email will be automatically updated by Supabase trigger when confirmed
          } catch (e) {
            print('Error updating email: $e');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to send email confirmation: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
            // Log failed email change
            await Supabase.instance.client.from('account_security_logs').insert({
              'user_id': user.id,
              'action_type': 'email_change',
              'success': false,
              'failure_reason': e.toString(),
              'details': {
                'old_email': currentEmail,
                'new_email': newEmail,
              },
            });
          }
        } else {
          // User cancelled email change, revert the email field
          _emailController.text = currentEmail;
        }
      }

      await Supabase.instance.client
          .from('user_profiles')
          .update(updateData)
          .eq('id', user.id);

      // Log profile updates
      final oldProfile = _userProfile!;
      if (oldProfile['first_name'] != _firstNameController.text.trim()) {
        await SecurityLoggingService.logProfileUpdate(
          userId: user.id,
          fieldName: 'first_name',
          oldValue: oldProfile['first_name'],
          newValue: _firstNameController.text.trim(),
          updateType: 'personal_info',
        );
      }

      if (oldProfile['last_name'] != _lastNameController.text.trim()) {
        await SecurityLoggingService.logProfileUpdate(
          userId: user.id,
          fieldName: 'last_name',
          oldValue: oldProfile['last_name'],
          newValue: _lastNameController.text.trim(),
          updateType: 'personal_info',
        );
      }

      if (oldProfile['phone_number'] != _phoneController.text.trim()) {
        await SecurityLoggingService.logProfileUpdate(
          userId: user.id,
          fieldName: 'phone_number',
          oldValue: oldProfile['phone_number'],
          newValue: _phoneController.text.trim(),
          updateType: 'contact_info',
        );
      }

      // Refresh auth service
      await AuthService.instance.initialize();
      await _loadUserProfile();

      setState(() => _newProfileImage = null);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isUpdating = false);
    }
  }

  Future<void> _changePassword() async {
    if (_currentPasswordController.text.isEmpty ||
        _newPasswordController.text.isEmpty ||
        _confirmPasswordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all password fields'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_newPasswordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('New passwords do not match'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isChangingPassword = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Update password
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: _newPasswordController.text),
      );

      // Update last password change timestamp
      await Supabase.instance.client
          .from('user_profiles')
          .update({
            'last_password_change': DateTime.now().toIso8601String(),
          })
          .eq('id', user.id);

      // Log password change
      await SecurityLoggingService.logSecurityEvent(
        userId: user.id,
        actionType: 'password_change',
        success: true,
        details: {'initiated_by': 'user', 'source': 'profile_screen'},
      );

      // Clear password fields
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password changed successfully!'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        await SecurityLoggingService.logSecurityEvent(
          userId: user.id,
          actionType: 'password_change',
          success: false,
          details: {
            'error': e.toString(),
            'initiated_by': 'user',
            'source': 'profile_screen',
          },
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to change password: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isChangingPassword = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Edit Profile'),
        backgroundColor: Colors.red[700],
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Profile Image Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: _pickProfileImage,
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 60,
                            backgroundColor: Colors.grey[200],
                            backgroundImage: _newProfileImage != null
                                ? FileImage(_newProfileImage!) as ImageProvider
                                : (_userProfile?['profile_image_url'] != null && 
                                   _userProfile!['profile_image_url'].toString().isNotEmpty)
                                    ? NetworkImage(_userProfile!['profile_image_url'].toString()) as ImageProvider
                                    : null,
                            child: (_newProfileImage == null && 
                                   (_userProfile?['profile_image_url'] == null || 
                                    _userProfile!['profile_image_url'].toString().isEmpty))
                                ? Icon(
                                    Icons.person,
                                    size: 60,
                                    color: Colors.grey[600],
                                  )
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.orange[700],
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${_userProfile?['first_name'] ?? ''} ${_userProfile?['last_name'] ?? ''}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _userProfile?['email'] ?? '',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Profile Information Form
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Personal Information',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // First Name
                      TextFormField(
                        controller: _firstNameController,
                        decoration: const InputDecoration(
                          labelText: 'First Name',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your first name';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      // Last Name
                      TextFormField(
                        controller: _lastNameController,
                        decoration: const InputDecoration(
                          labelText: 'Last Name',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your last name';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      // Email
                      TextFormField(
                        controller: _emailController,
                        decoration: InputDecoration(
                          labelText: 'Email *',
                          border: const OutlineInputBorder(),
                          helperText: 'Changing email requires confirmation via link sent to new address',
                          helperMaxLines: 2,
                          helperStyle: TextStyle(
                            color: Colors.orange[700],
                            fontSize: 11,
                          ),
                          suffixIcon: const Icon(Icons.email_outlined),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your email';
                          }
                          if (!value.contains('@') || !value.contains('.')) {
                            return 'Please enter a valid email address';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      // Phone
                      TextFormField(
                        controller: _phoneController,
                        decoration: const InputDecoration(
                          labelText: 'Phone Number',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your phone number';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 24),

                      // Update Profile Button
                      ElevatedButton(
                        onPressed: _isUpdating ? null : _updateProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange[700],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: _isUpdating
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Update Profile'),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Change Password Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Change Password',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Current Password
                    TextFormField(
                      controller: _currentPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Current Password',
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // New Password
                    TextFormField(
                      controller: _newPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'New Password',
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Confirm New Password
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Confirm New Password',
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Change Password Button
                    ElevatedButton(
                      onPressed: _isChangingPassword ? null : _changePassword,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[700],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _isChangingPassword
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text('Change Password'),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}





















