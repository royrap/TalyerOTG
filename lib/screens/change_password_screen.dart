import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/profile_service.dart';
import '../services/email_service.dart';

class ChangePasswordScreen extends StatefulWidget {
  final bool isFirstLogin;
  final String? redirectRoute;

  const ChangePasswordScreen({
    super.key,
    this.isFirstLogin = false,
    this.redirectRoute,
  });

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  // Password strength indicators
  bool _hasMinLength = false;
  bool _hasUppercase = false;
  bool _hasLowercase = false;
  bool _hasNumber = false;
  bool _hasSpecialChar = false;

  @override
  void initState() {
    super.initState();
    _newPasswordController.addListener(_checkPasswordStrength);
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _checkPasswordStrength() {
    final password = _newPasswordController.text;
    setState(() {
      _hasMinLength = password.length >= 8;
      _hasUppercase = password.contains(RegExp(r'[A-Z]'));
      _hasLowercase = password.contains(RegExp(r'[a-z]'));
      _hasNumber = password.contains(RegExp(r'[0-9]'));
      _hasSpecialChar = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
    });
  }

  bool get _isPasswordStrong {
    return _hasMinLength && _hasUppercase && _hasLowercase && _hasNumber;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Prevent going back if it's first login
        if (widget.isFirstLogin) {
          _showFirstLoginWarning();
          return false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        appBar: AppBar(
          title: Text(
            widget.isFirstLogin ? 'Set New Password' : 'Change Password',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: const Color(0xFF1B5E20),
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          leading: widget.isFirstLogin 
              ? null 
              : IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.pop(context),
                ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  if (widget.isFirstLogin) ...[
                    _buildWelcomeHeader(),
                    const SizedBox(height: 32),
                  ] else ...[
                    _buildChangePasswordHeader(),
                    const SizedBox(height: 24),
                  ],

                  // Current Password (only if not first login)
                  if (!widget.isFirstLogin) ...[
                    _buildPasswordField(
                      controller: _currentPasswordController,
                      label: 'Current Password',
                      icon: Icons.lock_outline,
                      obscureText: _obscureCurrentPassword,
                      onToggleVisibility: () {
                        setState(() {
                          _obscureCurrentPassword = !_obscureCurrentPassword;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your current password';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                  ],

                  // New Password
                  _buildPasswordField(
                    controller: _newPasswordController,
                    label: 'New Password',
                    icon: Icons.lock,
                    obscureText: _obscureNewPassword,
                    onToggleVisibility: () {
                      setState(() {
                        _obscureNewPassword = !_obscureNewPassword;
                      });
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a new password';
                      }
                      if (!_isPasswordStrong) {
                        return 'Password does not meet security requirements';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  // Password Strength Indicator
                  _buildPasswordStrengthIndicator(),

                  const SizedBox(height: 20),

                  // Confirm Password
                  _buildPasswordField(
                    controller: _confirmPasswordController,
                    label: 'Confirm New Password',
                    icon: Icons.lock_outline,
                    obscureText: _obscureConfirmPassword,
                    onToggleVisibility: () {
                      setState(() {
                        _obscureConfirmPassword = !_obscureConfirmPassword;
                      });
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please confirm your new password';
                      }
                      if (value != _newPasswordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 32),

                  // Change Password Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _changePassword,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1B5E20),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              widget.isFirstLogin ? 'Set Password' : 'Change Password',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),

                  if (widget.isFirstLogin) ...[
                    const SizedBox(height: 24),
                    _buildSecurityNotice(),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(26),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFF1B5E20),
              borderRadius: BorderRadius.circular(40),
            ),
            child: const Icon(
              Icons.security,
              color: Colors.white,
              size: 40,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Welcome to RoadAid!',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1B5E20),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'For security reasons, you must change your temporary password before accessing the app.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChangePasswordHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Change Password',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1B5E20),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Update your password to keep your account secure.',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool obscureText,
    required VoidCallback onToggleVisibility,
    required String? Function(String?) validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(26),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: const Color(0xFF1B5E20)),
          suffixIcon: IconButton(
            icon: Icon(
              obscureText ? Icons.visibility : Icons.visibility_off,
              color: Colors.grey,
            ),
            onPressed: onToggleVisibility,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          labelStyle: const TextStyle(color: Colors.grey),
        ),
      ),
    );
  }

  Widget _buildPasswordStrengthIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isPasswordStrong ? Colors.green : Colors.grey.shade300,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Password Requirements',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: _isPasswordStrong ? Colors.green : Colors.grey[700],
            ),
          ),
          const SizedBox(height: 12),
          _buildRequirementItem('At least 8 characters', _hasMinLength),
          _buildRequirementItem('One uppercase letter', _hasUppercase),
          _buildRequirementItem('One lowercase letter', _hasLowercase),
          _buildRequirementItem('One number', _hasNumber),
          _buildRequirementItem('One special character (recommended)', _hasSpecialChar, isOptional: true),
        ],
      ),
    );
  }

  Widget _buildRequirementItem(String text, bool isValid, {bool isOptional = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            isValid ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 16,
            color: isValid 
                ? Colors.green 
                : (isOptional ? Colors.orange : Colors.grey),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: isValid 
                    ? Colors.green 
                    : (isOptional ? Colors.orange : Colors.grey[600]),
                fontWeight: isValid ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityNotice() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: Colors.blue.shade700,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Your password has been changed successfully. You can now access all app features.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.blue.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showFirstLoginWarning() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Password Change Required'),
          content: const Text(
            'You must change your password before you can access the app. This is required for security purposes.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('I Understand'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) {
        throw Exception('No authenticated user found');
      }

      final userId = currentUser.id;

      // For first login, verify temporary password
      if (widget.isFirstLogin) {
        final isValidTemp = await EmailService.instance.verifyTemporaryPassword(
          userId,
          _currentPasswordController.text.isNotEmpty 
              ? _currentPasswordController.text 
              : 'temp123', // Default temp password check
        );
        
        if (!isValidTemp && _currentPasswordController.text.isNotEmpty) {
          throw Exception('Invalid temporary password');
        }
      }

      // Update password using ProfileService
      final success = await ProfileService.instance.updateUserPassword(
        userId,
        widget.isFirstLogin ? '' : _currentPasswordController.text,
        _newPasswordController.text,
      );

      if (success) {
        // Mark temporary password as used if first login
        if (widget.isFirstLogin) {
          await EmailService.instance.markTemporaryPasswordAsUsed(userId);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                widget.isFirstLogin 
                    ? 'Password set successfully! Welcome to RoadAid.'
                    : 'Password changed successfully.',
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );

          // Navigate based on user type and redirect route
          if (widget.isFirstLogin) {
            await Future.delayed(const Duration(seconds: 1));
            
            if (widget.redirectRoute != null) {
              Navigator.pushReplacementNamed(context, widget.redirectRoute!);
            } else {
              // Get user type and navigate to appropriate home
              final userProfile = await ProfileService.instance.getUserProfile(userId);
              final userType = userProfile?['user_type'] ?? 'customer';
              
              switch (userType) {
                case 'mechanic':
                  Navigator.pushReplacementNamed(context, '/mechanic-home');
                  break;
                case 'talyer_owner':
                  Navigator.pushReplacementNamed(context, '/talyer-home');
                  break;
                case 'customer':
                  Navigator.pushReplacementNamed(context, '/customer-home');
                  break;
                default:
                  Navigator.pushReplacementNamed(context, '/home');
              }
            }
          } else {
            Navigator.pop(context, true);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}










