import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:uuid/uuid.dart';
import '../services/auth_service.dart';
import '../services/gemini_ai_verification_service.dart';
import '../services/business_permit_extraction_service.dart';
import '../services/signup_verification_service.dart';
import '../services/supabase_service.dart';
import '../services/pending_upload_service.dart';
import 'login_screen.dart';
import 'email_verification_screen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _companyNameController = TextEditingController(); // Add company name controller
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _agreeToTerms = false;
  String _selectedUserType = 'customer'; // Add this line
  
  File? _profileImageFile; // For profile picture
  // Document upload variables for Talyer Owner
  File? _businessPermitFile;
  File? _validIdFile;
  final ImagePicker _imagePicker = ImagePicker();
  bool _isVerifyingDocuments = false;
  String? _verificationStatus;
  
  // Extracted document data from AI
  Map<String, dynamic>? _extractedBusinessData;
  Map<String, dynamic>? _extractedIdData;

  // User type options
  final List<Map<String, String>> _userTypes = [
    {'value': 'customer', 'label': 'Customer', 'description': 'Request roadside assistance'},
    {'value': 'talyer_owner', 'label': 'Talyer Owner', 'description': 'Manage mechanics and shop'},
    
  ];

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _companyNameController.dispose(); // Add company name controller disposal
    super.dispose();
  }

  // Method to pick profile image with better error handling
  Future<void> _pickProfileImage() async {
    try {
      final ImageSource? source = await _showImageSourceDialog();
      if (source == null) return;

      final XFile? image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 800,
        maxHeight: 800,
      );
      
      if (image != null) {
        // Validate file size (max 5MB)
        final file = File(image.path);
        final fileSize = await file.length();
        if (fileSize > 5 * 1024 * 1024) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Image too large. Please select an image under 5MB.'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        setState(() {
          _profileImageFile = file;
        });
      }
    } catch (e) {
      print('Error picking profile image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error selecting image: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Show dialog to choose image source
  Future<ImageSource?> _showImageSourceDialog() async {
    return showDialog<ImageSource>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Image Source'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Camera'),
                onTap: () => Navigator.of(context).pop(ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Gallery'),
                onTap: () => Navigator.of(context).pop(ImageSource.gallery),
              ),
            ],
          ),
        );
      },
    );
  }

  // Method to pick business permit image with better error handling
  Future<void> _pickBusinessPermit() async {
    try {
      final ImageSource? source = await _showImageSourceDialog();
      if (source == null) return;

      final XFile? image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 90,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      
      if (image != null) {
        // Validate file size (max 10MB for documents)
        final file = File(image.path);
        final fileSize = await file.length();
        if (fileSize > 10 * 1024 * 1024) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Document image too large. Please select an image under 10MB.'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        setState(() {
          _businessPermitFile = file;
          _verificationStatus = null; // Reset verification status
        });
        
        // Auto-verify if both documents are uploaded
        if (_businessPermitFile != null && _validIdFile != null) {
          await _verifyDocuments();
        }
      }
    } catch (e) {
      print('Error picking business permit: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error selecting business permit: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Method to pick valid ID image with better error handling
  Future<void> _pickValidId() async {
    try {
      final ImageSource? source = await _showImageSourceDialog();
      if (source == null) return;

      final XFile? image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 90,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      
      if (image != null) {
        // Validate file size (max 10MB for documents)
        final file = File(image.path);
        final fileSize = await file.length();
        if (fileSize > 10 * 1024 * 1024) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Document image too large. Please select an image under 10MB.'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        setState(() {
          _validIdFile = file;
          _verificationStatus = null; // Reset verification status
        });
        
        // Auto-verify if both documents are uploaded
        if (_businessPermitFile != null && _validIdFile != null) {
          await _verifyDocuments();
        }
      }
    } catch (e) {
      print('Error picking valid ID: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error selecting valid ID: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Method to verify documents using AI with simple auto-approval rules
  Future<void> _verifyDocuments() async {
    if (_businessPermitFile == null || _validIdFile == null) return;
    
    // For signup flow: Allow verification if user exists OR if this is called after signup
    if (!SupabaseService.isSignedIn) {
      setState(() {
        _verificationStatus = '� Documents selected. Will verify after account creation.';
      });
      print('ℹ️ Documents ready for verification after signup');
      return;
    }
    
    setState(() {
      _isVerifyingDocuments = true;
      _verificationStatus = '🤖 AI is extracting data and checking if names match and ID is not expired...';
    });

    String? permitUrl;
    String? idUrl;

    try {
      // Upload documents to storage
      permitUrl = await _uploadDocument(_businessPermitFile!, 'business-permits');
      idUrl = await _uploadDocument(_validIdFile!, 'valid-ids');
      
      print('📄 Business Permit uploaded: $permitUrl');
      print('🆔 Valid ID uploaded: $idUrl');

      // Generate temporary user ID for verification
      const uuid = Uuid();
      final tempUserId = uuid.v4();
      
      // Call the new AI document processing function
      print('🤖 Calling AI document processing function...');
      
      // Make the RPC call to process_talyer_owner_documents_ai using correct parameter names
      final aiResult = await SupabaseService.client.rpc(
        'process_talyer_owner_documents_ai',
        params: {
          'user_id': tempUserId,
          'id_image_url': idUrl,
          'business_permit_url': permitUrl,
          'business_name': _companyNameController.text.trim(),
          'business_address': null,
          'contact_person': '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}',
          'phone_number': _phoneController.text.trim().isNotEmpty ? _phoneController.text.trim() : null,
          'email': _emailController.text.trim(),
        },
      );

      if (aiResult != null && aiResult['success'] == true) {
        final autoApproved = aiResult['auto_approved'] == true;
        final validationResult = aiResult['validation_result'];
        final extractedData = aiResult['extracted_data'];
        
        print('🔍 AI Processing Result:');
        print('✅ Auto Approved: $autoApproved');
        print('📊 Validation Score: ${validationResult?['validation_score'] ?? 0}');
        print('👤 Names Match: ${validationResult?['names_match'] ?? false}');
        print('⏰ ID Not Expired: ${validationResult?['id_not_expired'] ?? false}');
        
        // Store extracted data for later use
        if (extractedData != null) {
          _extractedBusinessData = extractedData['permit_data'];
          _extractedIdData = extractedData['id_data'];
        }
        
        setState(() {
          _isVerifyingDocuments = false;
          
          if (autoApproved) {
            // AUTO-APPROVED: Names match and ID not expired
            final score = validationResult?['validation_score'] ?? 95;
            final idName = validationResult?['id_name'] ?? 'N/A';
            final permitOwnerName = validationResult?['permit_owner_name'] ?? 'N/A';
            final shopId = aiResult['shop_id'];
            
            _verificationStatus = '''✅ DOCUMENTS AUTO-APPROVED! 
            
🎉 AI verification successful:
• Name on ID matches business permit owner ✓
• ID is not expired ✓
• Validation score: $score/100
• Ready for instant approval!

📋 EXTRACTED NAMES:
• ID Name: "$idName"
• Permit Owner: "$permitOwnerName"
${shopId != null ? '\n🏪 Shop automatically created!' : ''}

You can complete your registration!''';
            
          } else {
            // NOT AUTO-APPROVED: Show reason
            final score = validationResult?['validation_score'] ?? 0;
            final namesMatch = validationResult?['names_match'] ?? false;
            final idNotExpired = validationResult?['id_not_expired'] ?? false;
            final idName = validationResult?['id_name'] ?? 'Could not extract';
            final permitOwnerName = validationResult?['permit_owner_name'] ?? 'Could not extract';
            
            String reason = '';
            if (!namesMatch && !idNotExpired) {
              reason = 'Name mismatch AND ID expired';
            } else if (!namesMatch) {
              reason = 'Name mismatch detected';
            } else if (!idNotExpired) {
              reason = 'ID is expired';
            } else {
              reason = 'Low confidence score';
            }
            
            _verificationStatus = '''❌ REQUIRES MANUAL REVIEW: $reason
            
⚠️ AI could not auto-approve your documents:
• Names match: ${namesMatch ? '✓' : '❌'}
• ID not expired: ${idNotExpired ? '✓' : '❌'}
• Validation score: $score/100

📋 EXTRACTED NAMES:
• ID Name: "$idName"
• Permit Owner: "$permitOwnerName"

📝 Your documents have been saved for manual admin review.
📧 You will be notified once approved.

You can continue with registration - verification is in progress.''';
          }
        });
        
      } else {
        // AI processing failed
        print('❌ AI processing failed: ${aiResult?['error'] ?? 'Unknown error'}');
        throw Exception(aiResult?['error'] ?? 'AI processing failed');
      }
      
    } catch (e) {
      print('💥 AI document verification error: $e');
      
      // Fallback: Save documents for manual review
      await _saveDocumentsForManualReview(permitUrl, idUrl, e.toString());
      
      setState(() {
        _isVerifyingDocuments = false;
        _verificationStatus = '''❌ AI PROCESSING FAILED
        
🤖 AI verification encountered an error: ${e.toString()}

✅ Your documents have been saved for manual admin review.
📧 You will receive an email notification once the review is complete.
          
Please continue with your registration - manual verification is in progress.''';
      });
    }
  }

  // Save documents for manual review when AI fails
  Future<void> _saveDocumentsForManualReview(String? permitUrl, String? idUrl, String errorMessage) async {
    if (permitUrl == null || idUrl == null) return;
    
    try {
      print('� Saving documents for manual review...');
      
      // Generate temp user ID
      const uuid = Uuid();
      final tempUserId = uuid.v4();
      
      // Save to talyer_owner_verifications table with pending status
      final result = await SupabaseService.client.from('talyer_owner_verifications').insert({
        'user_id': tempUserId,
        'business_name': _companyNameController.text.trim(),
        'business_permit_url': permitUrl,
        'valid_id_url': idUrl,
        'profile_image_url': null,
        'id_type': 'national_id',
        'status': 'pending',
        'business_address': null,
        'contact_person': '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}',
        'phone_number': _phoneController.text.trim().isNotEmpty ? _phoneController.text.trim() : null,
        'email': _emailController.text.trim(),
        'admin_notes': 'AI verification failed: $errorMessage. Requires manual review.',
        'verification_score': 0,
        'tamper_flags': ['ai_failed'],
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).select().single();
      
      print('✅ Documents saved for manual review with ID: ${result['id']}');
      
    } catch (e) {
      print('❌ Error saving documents for manual review: $e');
    }
  }

  // Upload document to Supabase storage
  Future<String> _uploadDocument(File file, String bucket) async {
    try {
      // Create a unique filename with signup verification prefix
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'signup-verification_${timestamp}_${file.path.split('/').last}';
      
      print('📤 Uploading document to bucket: $bucket');
      print('📁 File name: $fileName');
      
      await SupabaseService.client.storage
          .from(bucket)
          .upload(fileName, file);
      
      final publicUrl = SupabaseService.client.storage
          .from(bucket)
          .getPublicUrl(fileName);
          
      print('✅ Document uploaded successfully: $publicUrl');
      return publicUrl;
          
    } catch (e) {
      print('❌ Storage upload error: $e');
      
      // Check if it's a RLS policy error
      if (e.toString().contains('row-level security policy') || e.toString().contains('Unauthorized')) {
        print('⚠️ RLS policy blocking upload - checking authentication status');
        
        // Check if user is authenticated
        final user = SupabaseService.client.auth.currentUser;
        if (user == null) {
          print('❌ User not authenticated during signup verification');
          // Enqueue the failed upload so it can be retried after the user signs in
          try {
            if (SupabaseService.client.auth.currentUser != null) {
              // user exists - but still blocked; fallthrough to enqueue
            }
            // If we have a local file path, enqueue with a temporary user id if available
            final tempUserId = SupabaseService.client.auth.currentUser?.id ?? 'unknown';
            await PendingUploadService.enqueuePendingUpload(
              userId: tempUserId,
              localPath: file.path,
              bucket: bucket,
              field: bucket == 'business-permits' ? 'business_permit_url' : (bucket == 'valid-ids' ? 'valid_id_url' : 'profile_image_url'),
            );
            print('ℹ️ Enqueued upload for later processing: ${file.path}');
          } catch (enqueueErr) {
            print('⚠️ Failed to enqueue upload: $enqueueErr');
          }

          throw Exception('Authentication required for document upload. Upload queued and will retry after sign in.');
        } else {
          print('✅ User is authenticated: ${user.email}');
          // Re-throw the original error since it's not an auth issue
          // Enqueue the failed upload for later processing
          try {
            final tempUserId = user.id;
            await PendingUploadService.enqueuePendingUpload(
              userId: tempUserId,
              localPath: file.path,
              bucket: bucket,
              field: bucket == 'business-permits' ? 'business_permit_url' : (bucket == 'valid-ids' ? 'valid_id_url' : 'profile_image_url'),
            );
            print('ℹ️ Enqueued upload for later processing: ${file.path}');
          } catch (enqueueErr) {
            print('⚠️ Failed to enqueue upload: $enqueueErr');
          }

          throw Exception('Storage access denied. Upload queued for retry. Please check your permissions or contact support.');
        }
      }
      
      // Check if it's a bucket not found error
      if (e.toString().contains('Bucket not found') || e.toString().contains('404')) {
        throw Exception('Storage bucket "$bucket" not found. Please run the create_storage_buckets.sql script in your Supabase dashboard first.');
      }
      
      throw Exception('Failed to upload document: $e');
    }
  }  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_profileImageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload a profile picture - it\'s mandatory for all users'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!_agreeToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please agree to the Terms of Service'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Enhanced document verification for Talyer Owner
    if (_selectedUserType == 'talyer_owner') {
      if (_businessPermitFile == null || _validIdFile == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please upload both business permit and valid ID'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      // Check if documents are uploaded and ready for verification
      if (_verificationStatus == null || 
          (!_verificationStatus!.contains('✅') && 
           !_verificationStatus!.contains('⚠️') && 
           !_verificationStatus!.contains('Documents selected. Will verify after account creation'))) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please upload and verify your business permit and valid ID first'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      print('🚀 Starting signup process...');
      print('📧 Email: ${_emailController.text.trim()}');
      print('👤 Name: ${_firstNameController.text.trim()} ${_lastNameController.text.trim()}');
      print('👥 User Type: $_selectedUserType');
      
      final result = await AuthService.instance.signUp(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        password: _passwordController.text,
        userType: _selectedUserType,
        companyName: _selectedUserType == 'talyer_owner' ? _companyNameController.text.trim() : null,
        profileImage: _profileImageFile!,
      );

      print('📋 Signup result: ${result.success ? "SUCCESS" : "FAILURE"}');
      print('📋 Message: ${result.message}');

      // SAVE VERIFICATION DATA AFTER SUCCESSFUL USER CREATION
      if (result.success && result.userId != null && _selectedUserType == 'talyer_owner') {
        print('💾 Saving verification data after successful signup...');
        print('🆔 User ID: ${result.userId}');
        // Attempt to sign the user in so subsequent storage uploads are authenticated and allowed by RLS
        try {
          print('🔐 Signing in newly created user to allow uploads...');
          final signInResp = await SupabaseService.signIn(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );

          print('🔐 Sign-in response user id: ${signInResp.user?.id}');
        } catch (e) {
          print('⚠️ Sign-in after signup failed (uploads may be blocked): $e');
        }
        
        try {
          // Upload documents first to get URLs
          String? businessPermitUrl;
          String? validIdUrl;
          
          if (_businessPermitFile != null) {
            try {
              businessPermitUrl = await _uploadDocument(_businessPermitFile!, 'business-permits');
            } catch (uploadErr) {
              print('⚠️ Business permit upload failed during signup: $uploadErr');
              // Enqueue for later retry using actual file path and user id
              try {
                final uid = result.userId ?? SupabaseService.client.auth.currentUser?.id ?? 'unknown';
                await PendingUploadService.enqueuePendingUpload(
                  userId: uid,
                  localPath: _businessPermitFile!.path,
                  bucket: 'business-permits',
                  field: 'business_permit_url',
                );
              } catch (e) {
                print('⚠️ Failed to enqueue business permit upload: $e');
              }
            }
          }
          
          if (_validIdFile != null) {
            try {
              validIdUrl = await _uploadDocument(_validIdFile!, 'valid-ids');
            } catch (uploadErr) {
              print('⚠️ Valid ID upload failed during signup: $uploadErr');
              try {
                final uid = result.userId ?? SupabaseService.client.auth.currentUser?.id ?? 'unknown';
                await PendingUploadService.enqueuePendingUpload(
                  userId: uid,
                  localPath: _validIdFile!.path,
                  bucket: 'valid-ids',
                  field: 'valid_id_url',
                );
              } catch (e) {
                print('⚠️ Failed to enqueue valid id upload: $e');
              }
            }
          }
          
          if (businessPermitUrl != null && validIdUrl != null) {
            // ========== NEW AI VERIFICATION SYSTEM ==========
            print('🤖 Starting AI document verification...');
            try {
              // Call the AI document processing function using correct parameter names
              final aiResult = await SupabaseService.client.rpc(
                'process_talyer_owner_documents_ai',
                params: {
                  'user_id': result.userId!,
                  'id_image_url': validIdUrl,
                  'business_permit_url': businessPermitUrl,
                  'business_name': _companyNameController.text.trim(),
                  'business_address': '', // Use empty string as we don't have business address in signup
                  'contact_person': '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}',
                  'phone_number': _phoneController.text.trim(),
                  'email': _emailController.text.trim(),
                },
              );

              final bool isApproved = aiResult['auto_approved'] ?? false;
              final String message = aiResult['next_steps'] ?? 'Processing completed';
              final String verificationId = aiResult['verification_record_id']?.toString() ?? '';

              setState(() {
                if (isApproved) {
                  // Auto-approved: Names match and ID not expired
                  _verificationStatus = '''✅ DOCUMENTS AUTO-APPROVED! 
                  
🎯 AI verified that names match and ID is not expired.
📋 Verification ID: ${verificationId.substring(0, 8)}...
🏪 Your shop has been created automatically!

Welcome to RoadAid! 🎉''';
                } else {
                  // Needs manual review: Show reason
                  _verificationStatus = '''🔄 MANUAL REVIEW REQUIRED
                  
❌ $message
📋 Verification ID: ${verificationId.substring(0, 8)}...
                  
👨‍💼 An admin will review your documents and contact you via email.
⏱️ Review typically takes 1-2 business days.''';
                }
              });

              print('🔍 AI Processing Result:');
              print('✅ Auto Approved: $isApproved');
              print('📋 Message: $message');
              print('🆔 Verification ID: $verificationId');

              // Continue with success flow
              setState(() => _isLoading = false);
              
              // Show success message and navigate
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(isApproved ? 
                    '✅ Account created and documents auto-approved!' : 
                    '📋 Account created! Documents under review.'),
                  backgroundColor: isApproved ? Colors.green : Colors.orange,
                  duration: Duration(seconds: 4),
                ),
              );
              
              // Navigate to appropriate screen based on user type
              Navigator.of(context).pushReplacementNamed('/auth-wrapper');
              return; // Exit here since AI verification is complete

            } catch (aiError) {
              print('❌ AI verification failed: $aiError');
              // Continue with old verification system as fallback
            }
            // ========== END AI VERIFICATION SYSTEM ==========

            final verificationResult = await SignupVerificationService.saveVerificationData(
              userId: result.userId!,
              businessName: _companyNameController.text.trim(),
              contactPerson: '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}',
              email: _emailController.text.trim(),
              businessPermitUrl: businessPermitUrl,
              validIdUrl: validIdUrl,
              profileImageUrl: result.profileImageUrl, // Add profile image URL
              phoneNumber: _phoneController.text.trim().isNotEmpty ? _phoneController.text.trim() : null,
              businessAddress: null, // Optional field
              idType: 'national_id',
            );
            
            if (verificationResult['success']) {
              print('✅ Verification data saved successfully!');
              print('📊 Status: ${verificationResult['status']}');
                // Ensure the verification row contains all expected columns defined
                // in the database schema. We upsert here to cover any missing fields
                // the service wrapper might not have persisted.
                try {
                  // derive expiry dates and flags from extracted AI data if available
                  DateTime? permitExpiry;
                  DateTime? idExpiry;
                  bool isPermitExpired = false;
                  bool isIdExpired = false;

                  try {
                    final rawPermit = _extractedBusinessData?['expiry_date'];
                    if (rawPermit != null) {
                      permitExpiry = DateTime.tryParse(rawPermit.toString());
                    }
                  } catch (_) {}

                  try {
                    final rawId = _extractedIdData?['expiry_date'];
                    if (rawId != null) {
                      idExpiry = DateTime.tryParse(rawId.toString());
                    }
                  } catch (_) {}

                  try {
                    isPermitExpired = (_extractedBusinessData?['is_expired'] ?? false) == true;
                  } catch (_) {}
                  try {
                    isIdExpired = (_extractedIdData?['is_expired'] ?? false) == true;
                  } catch (_) {}

                  final contactPerson = '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}';
                  final phone = _phoneController.text.trim().isNotEmpty ? _phoneController.text.trim() : null;
                  final email = _emailController.text.trim().isNotEmpty ? _emailController.text.trim() : null;

                  final wasAutoApproved = (_verificationStatus != null && _verificationStatus!.contains('✅')) || (verificationResult['should_approve'] == true);
                  final statusToSave = wasAutoApproved ? 'approved' : (verificationResult['status']?.toString() ?? 'pending');
                  final confidenceScore = wasAutoApproved ? (verificationResult['confidence_score'] ?? 95) : (verificationResult['verification_score'] ?? 0);

                  final upsertRecord = {
                    'user_id': result.userId,
                    'business_name': _companyNameController.text.trim(),
                    'business_permit_url': businessPermitUrl,
                    'valid_id_url': validIdUrl,
                    'profile_image_url': result.profileImageUrl,
                    'id_type': 'national_id',
                    'permit_expiry_date': permitExpiry?.toUtc().toIso8601String(),
                    'id_expiry_date': idExpiry?.toUtc().toIso8601String(),
                    'status': statusToSave,
                    'admin_notes': wasAutoApproved ? 'Auto-approved at signup via deterministic rule' : null,
                    // reviewed_by must be a valid UUID or NULL (schema uses auth.users(id) FK). Use NULL for auto-approvals.
                    'reviewed_by': null,
                    'reviewed_at': wasAutoApproved ? DateTime.now().toUtc().toIso8601String() : null,
                    'business_address': null,
                    'contact_person': contactPerson,
                    'phone_number': phone,
                    'email': email,
                    'is_permit_expired': isPermitExpired,
                    'is_id_expired': isIdExpired,
                    'tamper_flags': [],
                    'verification_score': confidenceScore ?? 0,
                    'updated_at': DateTime.now().toUtc().toIso8601String(),
                  };

                  try {
                    final upsertResp = await SupabaseService.client
                        .from('talyer_owner_verifications')
                        .upsert(upsertRecord)
                        .select()
                        .maybeSingle();

                    if (upsertResp != null) {
                      print('✅ Upserted talyer_owner_verifications record for user: ${result.userId}');
                    } else {
                      print('⚠️ Upsert returned null (unexpected)');
                    }
                  } catch (e) {
                    print('❌ Failed to upsert verification record: $e');
                  }

                  // If the UI/AI flow already marked this as approved (deterministic rule),
                  // persist that approval to the database via RPC (if available) or fallback to update.
                  try {
                    if (wasAutoApproved) {
                      // Try to extract verification id from returned data
                      String? verificationId;
                      final savedData = verificationResult['data'];
                      if (savedData is Map) {
                        verificationId = savedData['id']?.toString() ?? savedData['verification_id']?.toString();
                      } else if (savedData is List && savedData.isNotEmpty) {
                        final first = savedData[0];
                        if (first is Map) verificationId = first['id']?.toString() ?? first['verification_id']?.toString();
                      }
                      verificationId ??= verificationResult['verification_id']?.toString();

                      var persisted = false;
                      if (verificationId != null) {
                        // Pass null for reviewedBy to avoid inserting invalid UUIDs into the reviewed_by FK column.
                        persisted = await SignupVerificationService.updateVerificationStatus(
                          verificationId: verificationId,
                          status: 'approved',
                          adminNotes: 'Auto-approved at signup via deterministic rule',
                          reviewedBy: null,
                        );
                      }

                      // Fallback: update by user_id if verification id not available or RPC failed
                      if (!persisted) {
                        try {
                          final updateResp = await SupabaseService.client
                              .from('talyer_owner_verifications')
                              .update({
                                'status': 'approved',
                                // Keep reviewed_by NULL for auto-approvals (FK requires a real auth.users id or null)
                                'reviewed_by': null,
                                'reviewed_at': DateTime.now().toUtc().toIso8601String(),
                                'admin_notes': 'Auto-approved at signup via deterministic rule',
                              })
                              .eq('user_id', result.userId!)
                              .select()
                              .maybeSingle();

                          if (updateResp != null) {
                            print('✅ Persisted auto-approval by user_id for user: ${result.userId}');
                          } else {
                            print('⚠️ Could not persist auto-approval (no matching verification row found)');
                          }
                        } catch (e) {
                          print('❌ Failed to persist auto-approval fallback: $e');
                        }
                      } else {
                        print('✅ Persisted auto-approval using verification id: $verificationId');
                      }
                    }
                  } catch (e) {
                    print('⚠️ Error while trying to persist auto-approval: $e');
                  }
                } catch (e) {
                  print('⚠️ Error while preparing/upserting verification record: $e');
                }
            } else {
              print('❌ Failed to save verification data: ${verificationResult['message']}');
            }
          } else {
            print('⚠️ Could not upload documents, saving placeholder verification row and continuing');
            // Ensure placeholder verification row exists so admin can review later
            try {
              final upsertRecord = {
                'user_id': result.userId,
                'business_name': _companyNameController.text.trim(),
                'business_permit_url': businessPermitUrl ?? '',
                'valid_id_url': validIdUrl ?? '',
                'profile_image_url': result.profileImageUrl,
                'id_type': 'national_id',
                'status': 'pending',
                'admin_notes': 'Placeholder created at signup; uploads may be pending.',
                'updated_at': DateTime.now().toUtc().toIso8601String(),
              };

              await SupabaseService.client.from('talyer_owner_verifications').upsert(upsertRecord);
              print('✅ Placeholder verification upserted for user ${result.userId}');
            } catch (e) {
              print('⚠️ Failed to upsert placeholder verification row: $e');
            }
          }
        } catch (e) {
          print('❌ Error saving verification data: $e');
        }
      }

      setState(() => _isLoading = false);

      if (mounted) {
        if (result.success) {
          print('✅ Showing success message and navigating...');
          
          // For talyer owners with verified documents, auto-approve them with Gemini AI verification
          if (_selectedUserType == 'talyer_owner' && _verificationStatus!.contains('✅')) {
            // Create Gemini AI verification record and auto-approve
            await _createGeminiVerificationRecord(result.userId!);
            
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('🎉 Account created and verified by Gemini AI! You can now access Talyer Owner features.'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 5),
              ),
            );
            
            // Navigate to email verification
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => EmailVerificationScreen(
                  email: _emailController.text.trim(),
                ),
              ),
            );
          } else {
            // For customers and mechanics, show success and go to email verification
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(result.message),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 3),
              ),
            );
            
            // Navigate to email verification screen
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => EmailVerificationScreen(
                  email: _emailController.text.trim(),
                ),
              ),
            );
          }
        } else {
          print('❌ Showing error message...');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      print('💥 Signup process crashed: $e');
      setState(() => _isLoading = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('An unexpected error occurred: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  // Create Gemini AI verification record for approved Talyer Owner
  Future<void> _createGeminiVerificationRecord(String userId) async {
    try {
      print('🤖 Creating Gemini AI verification record for user: $userId');
      
      // Upload documents and get URLs
      final businessPermitUrl = await _uploadDocument(_businessPermitFile!, 'business-permits');
      final validIdUrl = await _uploadDocument(_validIdFile!, 'valid-ids');
      
      // Get the service provider ID for this user
      print('🔍 Getting service provider ID for user: $userId');
      final serviceProviderData = await SupabaseService.client
          .from('service_providers')
          .select('id')
          .eq('user_id', userId)
          .maybeSingle();
      
      if (serviceProviderData != null) {
        final providerId = serviceProviderData['id'];
        print('✅ Found service provider ID: $providerId');
        
        // Extract business permit data using AI
        print('📄 Starting business permit data extraction...');
        final extractionResult = await BusinessPermitExtractionService.instance
            .extractAndSaveBusinessPermit(
          providerId: providerId,
          businessPermitUrl: businessPermitUrl,
        );
        
        if (extractionResult['success'] == true) {
          print('✅ Business permit data extracted and saved successfully');
          print('📊 Extraction confidence: ${extractionResult['confidence_score']}%');
          print('🆔 Business permit ID: ${extractionResult['permit_id']}');
        } else {
          print('⚠️ Business permit extraction failed: ${extractionResult['error']}');
          // Continue with verification even if extraction fails
        }
      } else {
        print('⚠️ Service provider record not found for user: $userId');
      }
      
      // Continue with existing Gemini AI verification for document matching
      final verificationResult = await GeminiAIVerificationService.instance.verifyTalyerOwnerDocuments(
        userId: userId,
        businessPermitUrl: businessPermitUrl,
        validIdUrl: validIdUrl,
        businessName: _companyNameController.text.trim(),
        contactPerson: '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}',
        permitExpiryDate: DateTime.now().add(const Duration(days: 365)), // Default future date - AI will extract real date
        idExpiryDate: DateTime.now().add(const Duration(days: 365)), // Default future date - AI will extract real date
        idType: 'auto_detect', // Let AI auto-detect the ID type
      );
      
      print('✅ Gemini AI verification record created and stored in database');
      print('📊 Final verification result: ${verificationResult['should_approve']}');
      print('🎯 Confidence score: ${verificationResult['confidence_score']}%');
      
    } catch (e) {
      print('❌ Error creating Gemini verification record: $e');
      // Don't throw error, just log it - signup was already successful
    }
  }

  // Build document upload card widget
  Widget _buildDocumentUploadCard({
    required String title,
    required IconData icon,
    required File? file,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: file != null ? Colors.green[50] : Colors.grey[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: file != null ? Colors.green[300]! : Colors.grey[300]!,
            style: BorderStyle.solid,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 32,
              color: file != null ? Colors.green[600] : Colors.grey[600],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: file != null ? Colors.green[700] : Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    file != null ? 'Uploaded ✓' : 'Tap to upload',
                    style: TextStyle(
                      fontSize: 14,
                      color: file != null ? Colors.green[600] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              file != null ? Icons.check_circle : Icons.upload,
              color: file != null ? Colors.green[600] : Colors.grey[600],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const LoginScreen()),
            );
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Logo and Title
              Column(
                children: [
                  Container(
                    width: 200, // Changed from 100
                    height: 200, // Changed from 100
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withAlpha(26),
                          spreadRadius: 2,
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.asset(
                        'LOGO.png', // Changed from 'assets/images/LOGO.png'
                        width: 200, // Changed from 100
                        height: 200, // Changed from 100
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          // Fallback to icon if image fails to load
                          return Container(
                            width: 120, // Changed from 100
                            height: 120, // Changed from 100
                            decoration: BoxDecoration(
                              color: const Color.fromARGB(255, 176, 12, 1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Icon(
                              Icons.car_repair,
                              color: Colors.white,
                              size: 60, // Increased from 50
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Create Account',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Join RoadAid today',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 32),
              
              // Sign Up Form
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    // First Name and Last Name Row
                    Row(
                      children: [
                        // First Name Field
                        Expanded(
                          child: TextFormField(
                            controller: _firstNameController,
                            textCapitalization: TextCapitalization.words,
                            decoration: InputDecoration(
                              labelText: 'First Name',
                              hintText: 'Enter first name',
                              prefixIcon: const Icon(Icons.person_outlined),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey[300]!),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color.fromARGB(255, 176, 12, 1),
                                ),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your first name';
                              }
                              if (value.length < 2) {
                                return 'Name must be at least 2 characters';
                              }
                              return null;
                            },
                          ),
                        ),
                        
                        const SizedBox(width: 12),
                        
                        // Last Name Field
                        Expanded(
                          child: TextFormField(
                            controller: _lastNameController,
                            textCapitalization: TextCapitalization.words,
                            decoration: InputDecoration(
                              labelText: 'Last Name',
                              hintText: 'Enter last name',
                              prefixIcon: const Icon(Icons.person_outlined),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey[300]!),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color.fromARGB(255, 176, 12, 1),
                                ),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your last name';
                              }
                              if (value.length < 2) {
                                return 'Name must be at least 2 characters';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Email Field
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        hintText: 'Enter your email',
                        prefixIcon: const Icon(Icons.email_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color.fromARGB(255, 176, 12, 1),
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your email';
                        }
                        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Phone Field
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'Phone Number',
                        hintText: 'Enter your phone number',
                        prefixIcon: const Icon(Icons.phone_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color.fromARGB(255, 176, 12, 1),
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your phone number';
                        }
                        if (value.length < 10) {
                          return 'Please enter a valid phone number';
                        }
                        return null;
                      },
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // User Type Dropdown
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: DropdownButtonFormField<String>(
                        value: _selectedUserType,
                        decoration: InputDecoration(
                          labelText: 'Account Type',
                          prefixIcon: const Icon(Icons.person_outline),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color.fromARGB(255, 176, 12, 1),
                            ),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                        items: _userTypes.map((userType) {
                          return DropdownMenuItem<String>(
                            value: userType['value'],
                            child: IntrinsicWidth(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    userType['label']!,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12, // Reduced from 13
                                      height: 1.2, // Reduced line height
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    userType['description']!,
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 9, // Reduced from 10
                                      height: 1.1, // Reduced line height
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedUserType = newValue!;
                          });
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please select an account type';
                          }
                          return null;
                        },
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Company Name Field (only for talyer_owner)
                    if (_selectedUserType == 'talyer_owner') ...[
                      TextFormField(
                        controller: _companyNameController,
                        decoration: InputDecoration(
                          labelText: 'Shop/Company Name',
                          hintText: 'Enter your shop or company name',
                          prefixIcon: const Icon(Icons.store_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color.fromARGB(255, 176, 12, 1),
                            ),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                        validator: (value) {
                          if (_selectedUserType == 'talyer_owner' && (value == null || value.trim().isEmpty)) {
                            return 'Please enter your shop/company name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      
                      // Document Upload Section
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue[200]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.verified_user, color: Colors.blue[700]),
                                const SizedBox(width: 8),
                                Text(
                                  'Document Verification',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue[700],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Upload your business permit and valid ID for instant AI verification. Gemini AI will automatically detect ID type, extract all document information, and verify authenticity in real-time.',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.blue[600],
                              ),
                            ),
                            const SizedBox(height: 16),
                            
                            // Business Permit Upload
                            _buildDocumentUploadCard(
                              title: 'Business Permit',
                              icon: Icons.business,
                              file: _businessPermitFile,
                              onTap: _pickBusinessPermit,
                            ),
                            
                            const SizedBox(height: 12),
                            
                            // Valid ID Upload
                            _buildDocumentUploadCard(
                              title: 'Valid ID',
                              icon: Icons.credit_card,
                              file: _validIdFile,
                              onTap: _pickValidId,
                            ),
                            
                            const SizedBox(height: 16),
                            
                            // Verification Status
                            if (_verificationStatus != null) ...[
                              const SizedBox(height: 16),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: _verificationStatus!.contains('✅') 
                                      ? Colors.green[50] 
                                      : Colors.red[50],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: _verificationStatus!.contains('✅') 
                                        ? Colors.green[300]! 
                                        : Colors.red[300]!,
                                  ),
                                ),
                                child: Text(
                                  _verificationStatus!,
                                  style: TextStyle(
                                    color: _verificationStatus!.contains('✅') 
                                        ? Colors.green[700] 
                                        : Colors.red[700],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                            
                            // Loading indicator for Gemini AI verification
                            if (_isVerifyingDocuments) ...[
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.blue[50],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.blue[200]!),
                                ),
                                child: const Row(
                                  children: [
                                    SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          Color.fromARGB(255, 176, 12, 1),
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '🤖 Gemini AI is extracting data from your documents...',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Color.fromARGB(255, 176, 12, 1),
                                            ),
                                          ),
                                          SizedBox(height: 4),
                                          Text(
                                            'Auto-detecting ID type, extracting text, validating authenticity, and checking expiry dates',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontStyle: FontStyle.italic,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    
                    // Password Field
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        hintText: 'Enter your password',
                        prefixIcon: const Icon(Icons.lock_outlined),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility : Icons.visibility_off,
                          ),
                          onPressed: () {
                            setState(() => _obscurePassword = !_obscurePassword);
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color.fromARGB(255, 176, 12, 1),
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your password';
                        }
                        if (value.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Confirm Password Field
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirmPassword,
                      decoration: InputDecoration(
                        labelText: 'Confirm Password',
                        hintText: 'Confirm your password',
                        prefixIcon: const Icon(Icons.lock_outlined),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
                          ),
                          onPressed: () {
                            setState(() => _obscureConfirmPassword = !_obscureConfirmPassword);
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color.fromARGB(255, 176, 12, 1),
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please confirm your password';
                        }
                        if (value != _passwordController.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),
                    
                    const SizedBox(height: 20),

                    // Profile Image Upload Button
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Profile Picture (Optional)',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _pickProfileImage,
                                icon: const Icon(
                                  Icons.camera_alt,
                                  color: Color.fromARGB(255, 176, 12, 1),
                                ),
                                label: Text(
                                  _profileImageFile != null 
                                      ? 'Change Profile Picture' 
                                      : 'Upload Profile Picture',
                                  style: const TextStyle(
                                    color: Color.fromARGB(255, 176, 12, 1),
                                    fontSize: 16,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                                  side: const BorderSide(
                                    color: Color.fromARGB(255, 176, 12, 1),
                                    width: 2,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                            if (_profileImageFile != null) ...[
                              const SizedBox(width: 12),
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: const Color.fromARGB(255, 176, 12, 1),
                                    width: 2,
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Image.file(
                                    _profileImageFile!,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Terms and Conditions Checkbox
                    Row(
                      children: [
                        Checkbox(
                          value: _agreeToTerms,
                          onChanged: (value) {
                            setState(() => _agreeToTerms = value ?? false);
                          },
                          activeColor: const Color.fromARGB(255, 176, 12, 1),
                        ),
                        Expanded(
                          child: Text(
                            'I agree to the Terms of Service and Privacy Policy',
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Sign Up Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _signUp,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color.fromARGB(255, 176, 12, 1),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Create Account',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Sign In Link
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Already have an account? ',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (context) => const LoginScreen()),
                      );
                    },
                    child: const Text(
                      'Sign In',
                      style: TextStyle(
                        color: Color.fromARGB(255, 176, 12, 1),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

}










