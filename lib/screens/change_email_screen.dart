import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/profile_service.dart';

class ChangeEmailScreen extends StatefulWidget {
  const ChangeEmailScreen({super.key});

  @override
  State<ChangeEmailScreen> createState() => _ChangeEmailScreenState();
}

class _ChangeEmailScreenState extends State<ChangeEmailScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentEmailController = TextEditingController();
  final _newEmailController = TextEditingController();
  final _confirmEmailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    _loadCurrentEmail();
  }

  void _loadCurrentEmail() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user?.email != null) {
      _currentEmailController.text = user!.email!;
    }
  }

  Future<void> _changeEmail() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        throw Exception('No authenticated user found. Please log in again.');
      }

      // Verify current password first
      try {
        await Supabase.instance.client.auth.signInWithPassword(
          email: _currentEmailController.text,
          password: _passwordController.text,
        );
      } catch (authError) {
        throw Exception('Current password is incorrect. Please try again.');
      }

      // Update email using profile service
      final success = await ProfileService.instance.updateUserEmail(
        user.id,
        _newEmailController.text.trim(),
      );

      if (success) {
        setState(() {
          _successMessage = 'Email change initiated! Please check your new email address for a confirmation link.';
          _newEmailController.clear();
          _confirmEmailController.clear();
          _passwordController.clear();
        });

        // Show success dialog
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.email, color: Colors.green),
                SizedBox(width: 8),
                Text('Email Change Initiated'),
              ],
            ),
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('We\'ve sent a confirmation link to your new email address.'),
                SizedBox(height: 8),
                Text('Please:'),
                Text('1. Check your new email inbox'),
                Text('2. Click the confirmation link'),
                Text('3. Your email will be updated once confirmed'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop(); // Go back to profile
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } else {
        throw Exception('Failed to initiate email change. Please try again.');
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Change Email'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Info card
              Card(
                color: Colors.blue[50],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info, color: Colors.blue[700]),
                          const SizedBox(width: 8),
                          Text(
                            'Email Change Process',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text('1. Enter your new email address'),
                      const Text('2. Confirm with your current password'),
                      const Text('3. Check your new email for confirmation'),
                      const Text('4. Click the link to complete the change'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Current email (read-only)
              TextFormField(
                controller: _currentEmailController,
                decoration: const InputDecoration(
                  labelText: 'Current Email',
                  prefixIcon: Icon(Icons.email_outlined),
                  border: OutlineInputBorder(),
                ),
                readOnly: true,
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),

              // New email
              TextFormField(
                controller: _newEmailController,
                decoration: const InputDecoration(
                  labelText: 'New Email Address',
                  prefixIcon: Icon(Icons.email),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your new email address';
                  }
                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                    return 'Please enter a valid email address';
                  }
                  if (value == _currentEmailController.text) {
                    return 'New email must be different from current email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Confirm new email
              TextFormField(
                controller: _confirmEmailController,
                decoration: const InputDecoration(
                  labelText: 'Confirm New Email',
                  prefixIcon: Icon(Icons.email),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please confirm your new email address';
                  }
                  if (value != _newEmailController.text) {
                    return 'Email addresses do not match';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Current password
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'Current Password',
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                  border: const OutlineInputBorder(),
                ),
                obscureText: _obscurePassword,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your current password';
                  }
                  if (value.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Error message
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red[300]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error, color: Colors.red[700]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.red[700]),
                        ),
                      ),
                    ],
                  ),
                ),

              // Success message
              if (_successMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green[300]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green[700]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _successMessage!,
                          style: TextStyle(color: Colors.green[700]),
                        ),
                      ),
                    ],
                  ),
                ),

              // Change email button
              ElevatedButton(
                onPressed: _isLoading ? null : _changeEmail,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
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
                          SizedBox(width: 8),
                          Text('Changing Email...', style: TextStyle(color: Colors.white)),
                        ],
                      )
                    : const Text('Change Email', style: TextStyle(color: Colors.white)),
              ),
              const SizedBox(height: 16),

              // Security note
              Card(
                color: Colors.orange[50],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.security, color: Colors.orange[700]),
                          const SizedBox(width: 8),
                          Text(
                            'Security Notice',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text('• You will need to confirm the change via email'),
                      const Text('• Your current email will remain active until confirmed'),
                      const Text('• Use your new email to log in after confirmation'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _currentEmailController.dispose();
    _newEmailController.dispose();
    _confirmEmailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}










