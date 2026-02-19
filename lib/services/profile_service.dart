import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'email_service.dart';

class ProfileService {
  static final ProfileService _instance = ProfileService._internal();
  static ProfileService get instance => _instance;
  ProfileService._internal();

  final _supabase = Supabase.instance.client;
  final _imagePicker = ImagePicker();
  // Candidate bucket names (choose the first that exists in Supabase)
  final List<String> _profileBucketCandidates = ['user-profiles', 'profiles', 'profile-images'];

  // Upload profile picture
  Future<String?> uploadProfilePicture({
    required String userId,
    required XFile imageFile,
  }) async {
    try {
      print('📷 Starting profile picture upload for user: $userId');

      // Get file extension from name first, then path as fallback
      String extension = '';
      if (imageFile.name.contains('.')) {
        extension = imageFile.name.split('.').last.toLowerCase();
      } else if (imageFile.path.contains('.')) {
        extension = imageFile.path.split('.').last.toLowerCase();
      } else {
        // Default to jpg if no extension found
        extension = 'jpg';
      }

      print('📷 Detected file extension: $extension');

      // Validate file type
      final supportedFormats = ['jpg', 'jpeg', 'png', 'webp'];
      if (!supportedFormats.contains(extension)) {
        throw Exception('Unsupported image format: $extension. Please use JPG, PNG, or WebP.');
      }

      // Generate unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'profile_${userId}_$timestamp.$extension';
      final filePath = 'profiles/$fileName';

      // Read file bytes
      Uint8List imageBytes;
      if (kIsWeb) {
        imageBytes = await imageFile.readAsBytes();
      } else {
        final file = File(imageFile.path);
        imageBytes = await file.readAsBytes();
      }

      // Validate file size (max 5MB)
      if (imageBytes.length > 5 * 1024 * 1024) {
        throw Exception('Image file is too large. Maximum size is 5MB.');
      }

      // Additional validation: Check if the file is actually an image by looking at the header
      if (!_isValidImageFile(imageBytes)) {
        throw Exception('Invalid image file. Please select a valid JPG, PNG, or WebP image.');
      }

      print('📷 Uploading image: $fileName (${imageBytes.length} bytes)');

      // Try candidate buckets until one succeeds (helps when dev/prod have
      // different bucket names like 'profiles', 'profile-images' or 'user-profiles')
      String? usedBucket;
      dynamic uploadResponse;
      for (final bucket in _profileBucketCandidates) {
        try {
          uploadResponse = await _supabase.storage
              .from(bucket)
              .uploadBinary(filePath, imageBytes, fileOptions: FileOptions(
                contentType: _getContentType(extension),
                upsert: true, // Replace if exists
              ));

          usedBucket = bucket;
          print('✅ Image uploaded successfully to bucket "$bucket": $uploadResponse');
          break;
        } catch (e) {
          final err = e.toString();
          if (err.contains('Bucket not found') || err.contains('404')) {
            print('⚠️ Bucket "$bucket" not found, trying next candidate...');
            continue;
          }
          // Non-bucket error: rethrow
          rethrow;
        }
      }

      if (usedBucket == null) {
        throw Exception('Storage bucket not found. Please create one of: ${_profileBucketCandidates.join(', ')}');
      }

      // Get public URL
      final publicUrl = _supabase.storage
          .from(usedBucket)
          .getPublicUrl(filePath);

      print('✅ Public URL generated: $publicUrl');

      // Update user profile with new image URL
      await updateProfilePicture(userId, publicUrl);

      return publicUrl;
    } catch (e) {
      print('❌ Error uploading profile picture: $e');
      rethrow; // Rethrow the original exception for better error handling
    }
  }

  // Update profile picture URL in database
  Future<void> updateProfilePicture(String userId, String imageUrl) async {
    try {
      print('🔄 Updating profile picture URL in database...');

      // Use the database function for proper logging
      final result = await _supabase.rpc('update_profile_image', params: {
        'p_user_id': userId,
        'p_image_url': imageUrl,
      });

      if (result == true) {
        print('✅ Profile picture URL updated successfully via database function');
      } else {
        throw Exception('Database function returned false');
      }
    } catch (e) {
      print('❌ Error updating profile picture URL: $e');
      
      // Fallback to direct update if function fails
      try {
        print('🔄 Falling back to direct database update...');
        
        await _supabase
            .from('user_profiles')
            .update({
              'profile_image_url': imageUrl,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', userId);

        // Log profile update manually
        await _logProfileUpdate(
          userId: userId,
          fieldName: 'profile_image_url',
          newValue: imageUrl,
          updateType: 'profile_image',
        );

        print('✅ Profile picture URL updated via fallback method');
      } catch (fallbackError) {
        print('❌ Fallback update also failed: $fallbackError');
        throw Exception('Failed to update profile picture: $fallbackError');
      }
    }
  }

  // Pick image from gallery or camera
  Future<XFile?> pickImage({bool fromCamera = false}) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: fromCamera ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      return image;
    } catch (e) {
      print('❌ Error picking image: $e');
      throw Exception('Failed to pick image: $e');
    }
  }

  // Get profile picture URL
  Future<String?> getProfilePicture(String userId) async {
    try {
      final response = await _supabase
          .from('user_profiles')
          .select('profile_image_url')
          .eq('id', userId)
          .single();

      return response['profile_image_url'];
    } catch (e) {
      print('❌ Error getting profile picture: $e');
      return null;
    }
  }

  // Update user email
  Future<bool> updateUserEmail(String userId, String newEmail) async {
    try {
      print('📧 Updating user email: $newEmail');

      // Check if email is already in use
      final existingUser = await _supabase
          .from('user_profiles')
          .select('id, email')
          .eq('email', newEmail)
          .neq('id', userId)
          .maybeSingle();

      if (existingUser != null) {
        throw Exception('This email is already in use by another account.');
      }

      // Get current email for logging
      final currentProfile = await _supabase
          .from('user_profiles')
          .select('email')
          .eq('id', userId)
          .single();

      final oldEmail = currentProfile['email'];

      // Update user profile
      await _supabase
          .from('user_profiles')
          .update({
            'email': newEmail,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', userId);

      // Update auth user email
      try {
        await _supabase.auth.updateUser(UserAttributes(email: newEmail));
        print('✅ Auth email updated successfully');
      } catch (authError) {
        print('⚠️ Warning: Could not update auth email: $authError');
        // Continue execution as profile email is updated
      }

      // Log profile update
      await _logProfileUpdate(
        userId: userId,
        fieldName: 'email',
        oldValue: oldEmail,
        newValue: newEmail,
        updateType: 'user_update',
      );

      // Check if this is a new email to the system and send welcome email
      final emailService = EmailService.instance;
      final isNewEmail = await emailService.isEmailNewToSystem(newEmail);
      
      if (isNewEmail) {
        try {
          // Get user details for welcome email
          final userProfile = await _supabase
              .from('user_profiles')
              .select('first_name, last_name, user_type')
              .eq('id', userId)
              .single();

          await emailService.sendEmailChangeWelcomeEmail(
            userId: userId,
            newEmail: newEmail,
            firstName: userProfile['first_name'] ?? 'User',
            lastName: userProfile['last_name'] ?? '',
            userType: userProfile['user_type'] ?? 'user',
          );
          
          print('✅ Welcome email sent for new email address');
        } catch (emailError) {
          print('⚠️ Warning: Could not send welcome email for new address: $emailError');
        }
      } else {
        // Send regular email update notification for existing emails
        try {
          await _sendEmailUpdateNotification(userId, oldEmail, newEmail);
        } catch (emailError) {
          print('⚠️ Warning: Could not send email update notification: $emailError');
        }
      }

      print('✅ User email updated successfully');
      return true;
    } catch (e) {
      print('❌ Error updating user email: $e');
      throw Exception('Failed to update email: $e');
    }
  }

  // Update user password
  Future<bool> updateUserPassword(String userId, String currentPassword, String newPassword) async {
    try {
      print('🔐 Updating user password...');

      // Validate new password strength
      if (newPassword.length < 8) {
        throw Exception('Password must be at least 8 characters long.');
      }

      if (!RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)').hasMatch(newPassword)) {
        throw Exception('Password must contain at least one uppercase letter, one lowercase letter, and one number.');
      }

      // Update password using Supabase Auth
      await _supabase.auth.updateUser(UserAttributes(password: newPassword));

      // Update password change tracking in user profile
      await _supabase
          .from('user_profiles')
          .update({
            'last_password_change': DateTime.now().toIso8601String(),
            'password_change_required': false,
            'first_login': false,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', userId);

      // Mark any temporary passwords as used
      await _supabase
          .from('temporary_passwords')
          .update({
            'is_used': true,
            'used_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId)
          .eq('is_used', false);

      // Log profile update
      await _logProfileUpdate(
        userId: userId,
        fieldName: 'password',
        oldValue: '[HIDDEN]',
        newValue: '[HIDDEN]',
        updateType: 'user_update',
      );

      print('✅ User password updated successfully');
      return true;
    } catch (e) {
      print('❌ Error updating user password: $e');
      throw Exception('Failed to update password: $e');
    }
  }

  // Update basic profile information
  Future<bool> updateBasicProfile({
    required String userId,
    required String firstName,
    required String lastName,
    required String phoneNumber,
  }) async {
    try {
      print('👤 Updating basic profile information...');

      // Get current profile for logging
      final currentProfile = await _supabase
          .from('user_profiles')
          .select('first_name, last_name, phone_number')
          .eq('id', userId)
          .single();

      // Update profile
      await _supabase
          .from('user_profiles')
          .update({
            'first_name': firstName,
            'last_name': lastName,
            'phone_number': phoneNumber,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', userId);

      // Log each field change
      final changes = <String>[];
      
      if (currentProfile['first_name'] != firstName) {
        await _logProfileUpdate(
          userId: userId,
          fieldName: 'first_name',
          oldValue: currentProfile['first_name'],
          newValue: firstName,
          updateType: 'user_update',
        );
        changes.add('First name: ${currentProfile['first_name']} → $firstName');
      }

      if (currentProfile['last_name'] != lastName) {
        await _logProfileUpdate(
          userId: userId,
          fieldName: 'last_name',
          oldValue: currentProfile['last_name'],
          newValue: lastName,
          updateType: 'user_update',
        );
        changes.add('Last name: ${currentProfile['last_name']} → $lastName');
      }

      if (currentProfile['phone_number'] != phoneNumber) {
        await _logProfileUpdate(
          userId: userId,
          fieldName: 'phone_number',
          oldValue: currentProfile['phone_number'],
          newValue: phoneNumber,
          updateType: 'user_update',
        );
        changes.add('Phone: ${currentProfile['phone_number']} → $phoneNumber');
      }

      print('✅ Basic profile updated successfully');
      return true;
    } catch (e) {
      print('❌ Error updating basic profile: $e');
      throw Exception('Failed to update profile: $e');
    }
  }

  // Get user profile with complete information
  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      final response = await _supabase
          .from('user_profiles')
          .select('''
            *,
            service_provider:service_providers!service_providers_user_id_fkey(
              id,
              company_name,
              rating,
              total_reviews,
              years_experience,
              is_verified,
              status
            )
          ''')
          .eq('id', userId)
          .single();

      // Add computed fields
      response['full_name'] = '${response['first_name']} ${response['last_name']}';
      response['initials'] = '${response['first_name']?.substring(0, 1) ?? ''}${response['last_name']?.substring(0, 1) ?? ''}';
      
      return response;
    } catch (e) {
      print('❌ Error getting user profile: $e');
      return null;
    }
  }

  // Check if password change is required
  Future<bool> isPasswordChangeRequired(String userId) async {
    try {
      final response = await _supabase
          .from('user_profiles')
          .select('password_change_required, first_login')
          .eq('id', userId)
          .single();

      return response['password_change_required'] == true || response['first_login'] == true;
    } catch (e) {
      print('❌ Error checking password change requirement: $e');
      return false;
    }
  }

  // Get profile update history
  Future<List<Map<String, dynamic>>> getProfileUpdateHistory(String userId) async {
    try {
      final response = await _supabase
          .from('profile_updates')
          .select('''
            *,
            updated_by_profile:user_profiles!profile_updates_updated_by_fkey(
              first_name,
              last_name
            )
          ''')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('❌ Error getting profile update history: $e');
      return [];
    }
  }

  // Delete profile picture
  Future<bool> deleteProfilePicture(String userId) async {
    try {
      print('🗑️ Deleting profile picture for user: $userId');

      // Get current profile picture URL
      final currentPicture = await getProfilePicture(userId);
      
      if (currentPicture != null && currentPicture.isNotEmpty) {
        // Extract file path from URL
        final uri = Uri.parse(currentPicture);
        final pathSegments = uri.pathSegments;
        if (pathSegments.length >= 2) {
          final filePath = pathSegments.sublist(pathSegments.length - 2).join('/');
          
          try {
            // Attempt delete across candidate buckets to be robust
            bool deleted = false;
            for (final bucket in _profileBucketCandidates) {
              try {
                await _supabase.storage.from(bucket).remove([filePath]);
                print('✅ Profile picture deleted from storage (bucket: $bucket)');
                deleted = true;
                break;
              } catch (storageError) {
                final msg = storageError.toString();
                if (msg.contains('Bucket not found') || msg.contains('404')) {
                  // try next candidate
                  continue;
                }
                print('⚠️ Warning: Could not delete from storage (bucket: $bucket): $storageError');
              }
            }
            if (!deleted) {
              print('⚠️ Warning: Could not find/delete file in any candidate buckets');
            }
          } catch (storageError) {
            print('⚠️ Warning: Could not delete from storage: $storageError');
          }
        }
      }

      // Use database function to update profile and log deletion
      try {
        final result = await _supabase.rpc('delete_profile_image', params: {
          'p_user_id': userId,
        });

        if (result == true) {
          print('✅ Profile picture deleted successfully via database function');
          return true;
        } else {
          throw Exception('Database function returned false - no image to delete');
        }
      } catch (dbError) {
        print('❌ Database function failed: $dbError');
        
        // Fallback to direct update
        print('🔄 Falling back to direct database update...');
        
        await _supabase
            .from('user_profiles')
            .update({
              'profile_image_url': null,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', userId);

        // Log profile update manually
        await _logProfileUpdate(
          userId: userId,
          fieldName: 'profile_image_url',
          oldValue: currentPicture,
          newValue: null,
          updateType: 'profile_image',
        );

        print('✅ Profile picture deleted via fallback method');
        return true;
      }
    } catch (e) {
      print('❌ Error deleting profile picture: $e');
      throw Exception('Failed to delete profile picture: $e');
    }
  }

  // Helper method to get content type from file extension
  String _getContentType(String extension) {
    switch (extension.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }

  // Helper method to validate image file by checking file headers
  bool _isValidImageFile(Uint8List bytes) {
    if (bytes.length < 4) return false;

    // Check for common image file signatures
    // JPEG: FF D8 FF
    if (bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      return true;
    }

    // PNG: 89 50 4E 47
    if (bytes.length >= 4 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return true;
    }

    // WebP: starts with "RIFF" and contains "WEBP"
    if (bytes.length >= 12) {
      final riff = String.fromCharCodes(bytes.sublist(0, 4));
      final webp = String.fromCharCodes(bytes.sublist(8, 12));
      if (riff == 'RIFF' && webp == 'WEBP') {
        return true;
      }
    }

    return false;
  }

  // Log profile update
  Future<void> _logProfileUpdate({
    required String userId,
    required String fieldName,
    String? oldValue,
    String? newValue,
    required String updateType,
  }) async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) return;

      await _supabase.from('profile_updates').insert({
        'user_id': userId,
        'field_name': fieldName,
        'old_value': oldValue,
        'new_value': newValue,
        'updated_by': currentUser.id,
        'update_type': updateType,
      });

      print('✅ Profile update logged: $fieldName');
    } catch (e) {
      print('⚠️ Warning: Could not log profile update: $e');
      // Don't throw as this is not critical
    }
  }

  // Send email update notification
  Future<void> _sendEmailUpdateNotification(String userId, String oldEmail, String newEmail) async {
    try {
      // This would integrate with the EmailService
      print('📧 Email update notification would be sent here');
      print('   Old email: $oldEmail');
      print('   New email: $newEmail');
      print('   User ID: $userId');
      
      // In a real implementation:
      // await EmailService.instance.sendProfileUpdateNotification(
      //   userId: userId,
      //   email: oldEmail,
      //   changes: 'Email address changed from $oldEmail to $newEmail',
      // );
    } catch (e) {
      print('❌ Error sending email update notification: $e');
    }
  }

  // Validate email format
  bool isValidEmail(String email) {
    return RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$').hasMatch(email);
  }

  // Validate phone number format
  bool isValidPhoneNumber(String phone) {
    // Remove all non-digit characters
    final digitsOnly = phone.replaceAll(RegExp(r'[^\d]'), '');
    
    // Check if it's a valid length (10-15 digits)
    return digitsOnly.length >= 10 && digitsOnly.length <= 15;
  }

  // Get storage usage for user
  Future<Map<String, dynamic>> getStorageUsage(String userId) async {
    try {
      // This would require custom implementation to track storage usage
      // For now, return basic info
      final profilePicture = await getProfilePicture(userId);
      
      return {
        'has_profile_picture': profilePicture != null && profilePicture.isNotEmpty,
        'profile_picture_url': profilePicture,
        'storage_used_mb': profilePicture != null ? 1.0 : 0.0, // Estimated
        'storage_limit_mb': 10.0, // 10MB limit per user
      };
    } catch (e) {
      print('❌ Error getting storage usage: $e');
      return {
        'has_profile_picture': false,
        'profile_picture_url': null,
        'storage_used_mb': 0.0,
        'storage_limit_mb': 10.0,
      };
    }
  }
}










