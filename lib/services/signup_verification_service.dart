import 'package:supabase_flutter/supabase_flutter.dart';

/// Service to save verification data immediately during signup
/// Saves data to talyer_owner_verifications table with status 'pending'
class SignupVerificationService {
  static final _supabase = Supabase.instance.client;

  /// Save signup verification data immediately to talyer_owner_verifications table
  /// Uses the actual authenticated user ID from signup process
  static Future<Map<String, dynamic>> saveVerificationData({
    required String userId, // Use the actual user ID from signup
    required String businessName,
    required String contactPerson,
    required String email,
    required String businessPermitUrl,
    required String validIdUrl,
    String? phoneNumber,
    String? businessAddress,
    String? profileImageUrl, // Add profile image URL
    String idType = 'national_id',
  }) async {
    try {
      print('💾 Saving verification data for user: $userId');
      print('🏢 Business: $businessName');
      print('👤 Contact: $contactPerson');
      print('📧 Email: $email');
      if (profileImageUrl != null) {
        print('📸 Profile Image: $profileImageUrl');
      }

  // NOTE: RPC / DB policies are intentionally NOT used here (policies disabled).
  // Perform direct upsert into the `talyer_owner_verifications` table.

      // Fallback to direct insert with proper ID type
      final verificationData = {
        'user_id': userId,
        'business_name': businessName,
        'contact_person': contactPerson,
        'email': email,
        'business_permit_url': businessPermitUrl,
        'valid_id_url': validIdUrl,
        'id_type': _validateIdType(idType), // Ensure valid ID type
        'status': 'pending',
        'admin_notes': 'Data saved during signup. Pending admin verification.',
        'verification_score': 0,
        'tamper_flags': [],
        'is_permit_expired': false,
        'is_id_expired': false,
      };

      // Add optional fields if provided
      if (phoneNumber != null && phoneNumber.isNotEmpty) {
        verificationData['phone_number'] = phoneNumber;
      }
      
      if (businessAddress != null && businessAddress.isNotEmpty) {
        verificationData['business_address'] = businessAddress;
      }

      if (profileImageUrl != null && profileImageUrl.isNotEmpty) {
        verificationData['profile_image_url'] = profileImageUrl;
      }

      print('💾 Inserting/upserting data into talyer_owner_verifications table...');

      // Use upsert to handle potential duplicates by user_id
    final dynamic response = await _supabase
      .from('talyer_owner_verifications')
      .upsert(verificationData, onConflict: 'user_id')
      .select();

    // Supabase select typically returns a List for select(); get first element if present
    dynamic returnedData;
    try {
      final List respList = response as List;
      if (respList.isNotEmpty) returnedData = respList[0];
      else returnedData = null;
    } catch (_) {
      returnedData = response;
    }

      print('✅ Verification data saved successfully!');
      print('📊 Status: pending (awaiting admin review)');

      return {
        'success': true,
        'user_id': userId,
        'message': 'Verification data saved successfully',
        'status': 'pending',
        'data': returnedData,
      };

    } catch (e) {
      print('❌ Error saving verification data: $e');
      
      // Final fallback with absolutely minimal data
      try {
        print('🔄 Attempting minimal data save...');
        
        final minimalData = {
          'user_id': userId,
          'business_name': businessName.isNotEmpty ? businessName : 'Unknown Business',
          'contact_person': contactPerson.isNotEmpty ? contactPerson : 'Unknown Contact',
          'email': email,
          'business_permit_url': businessPermitUrl,
          'valid_id_url': validIdUrl,
          'id_type': 'other', // Use 'other' as safest fallback
          'status': 'pending',
        };

        // Add profile image if available
        if (profileImageUrl != null && profileImageUrl.isNotEmpty) {
          minimalData['profile_image_url'] = profileImageUrl;
        }

        final response = await _supabase
            .from('talyer_owner_verifications')
            .insert(minimalData)
            .select()
            .single();

        print('✅ Minimal verification data saved successfully!');
        
        return {
          'success': true,
          'user_id': userId,
          'message': 'Minimal verification data saved successfully',
          'status': 'pending',
          'data': response,
        };
        
      } catch (fallbackError) {
        print('❌ Fallback save also failed: $fallbackError');
        
        // Log the error but don't fail the signup process
        return {
          'success': false,
          'error': e.toString(),
          'fallback_error': fallbackError.toString(),
          'message': 'Verification data will be processed manually',
          'user_id': userId,
        };
      }
    }
  }

  /// Validate and normalize ID type
  static String _validateIdType(String idType) {
    const validTypes = [
      'drivers_license',
      'umid',
      'national_id',
      'passport',
      'philsys_id',
      'other'
    ];
    
    // Normalize the input
    final normalized = idType.toLowerCase().replaceAll(' ', '_');
    
    if (validTypes.contains(normalized)) {
      return normalized;
    }
    
    // Default fallback
    return 'other';
  }

  /// Get verification status for a user
  static Future<Map<String, dynamic>?> getVerificationStatus(String userId) async {
    try {
      final result = await _supabase
          .from('talyer_owner_verifications')
          .select('*')
          .eq('user_id', userId)
          .maybeSingle();

      return result;
    } catch (e) {
      print('❌ Error getting verification status: $e');
      return null;
    }
  }

  /// Check if user has pending verification
  static Future<bool> hasPendingVerification(String userId) async {
    try {
      final result = await _supabase
          .from('talyer_owner_verifications')
          .select('status')
          .eq('user_id', userId)
          .eq('status', 'pending')
          .maybeSingle();

      return result != null;
    } catch (e) {
      print('❌ Error checking pending verification: $e');
      return false;
    }
  }

  /// Get all verifications for admin review
  static Future<List<Map<String, dynamic>>> getAllVerifications() async {
    try {
      // Direct select from verification table (no RPC/policy usage)
    final dynamic response = await _supabase
      .from('talyer_owner_verifications')
      .select('*')
      .order('created_at', ascending: false);

    // Cast to List and convert elements to Map<String, dynamic>
    final List respList = response as List;
    return respList.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e) {
      print('❌ Error getting all verifications: $e');
      return [];
    }
  }

  /// Update verification status (admin function)
  static Future<bool> updateVerificationStatus({
    required String verificationId,
    required String status,
    String? adminNotes,
    String? reviewedBy,
  }) async {
    try {
      // Direct update into the table (no RPC/policy usage)
      final updatePayload = {
        'status': status,
        'admin_notes': adminNotes,
        'reviewed_by': reviewedBy,
        'reviewed_at': DateTime.now().toUtc().toIso8601String(),
      };

      // Remove null keys to avoid overwriting with null unintentionally
      updatePayload.removeWhere((key, value) => value == null && key == 'admin_notes');

      final response = await _supabase
          .from('talyer_owner_verifications')
          .update(updatePayload)
          .eq('id', verificationId)
          .select()
          .maybeSingle();

      if (response != null) {
        print('✅ Verification status updated to: $status');
        return true;
      }

      print('❌ Error updating verification: no rows updated');
      return false;
    } catch (e) {
      print('❌ Error updating verification status: $e');
      return false;
    }
  }
}










