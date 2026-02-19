import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/// Service to extract permit and ID data and save to talyer_owner_verifications table
/// Status will be 'pending' for admin review
class DataExtractionService {
  static final _supabase = Supabase.instance.client;
  static const _uuid = Uuid();

  /// Extract and save permit/ID data to talyer_owner_verifications table
  /// Status: 'pending' for admin review
  static Future<Map<String, dynamic>> extractAndSaveData({
    required String businessPermitUrl,
    required String validIdUrl,
    required String businessName,
    required String contactPerson,
    required String email,
    String? phoneNumber,
    String? businessAddress,
    String idType = 'drivers_license', // Default to drivers license
  }) async {
    try {
      print('📋 Starting data extraction and save to talyer_owner_verifications...');
      print('🏢 Business: $businessName');
      print('👤 Contact: $contactPerson');
      print('📧 Email: $email');

      // Generate user ID for verification record
      final userId = _uuid.v4();
      
      // Prepare data for talyer_owner_verifications table
      final verificationData = {
        'user_id': userId,
        'business_name': businessName,
        'business_permit_url': businessPermitUrl,
        'valid_id_url': validIdUrl,
        'id_type': idType,
        'status': 'pending', // Always pending for admin review
        'contact_person': contactPerson,
        'email': email,
        'admin_notes': 'Data extracted during signup. Pending admin verification.',
        'verification_score': 0, // Will be scored during admin review
        'tamper_flags': [], // Will be updated during admin review
        'is_permit_expired': false, // Will be determined during admin review
        'is_id_expired': false, // Will be determined during admin review
      };

      // Add optional fields
      if (phoneNumber != null && phoneNumber.isNotEmpty) {
        verificationData['phone_number'] = phoneNumber;
      }
      
      if (businessAddress != null && businessAddress.isNotEmpty) {
        verificationData['business_address'] = businessAddress;
      }

      // Save to talyer_owner_verifications table
      print('💾 Saving data to talyer_owner_verifications table...');
      await _supabase
          .from('talyer_owner_verifications')
          .insert(verificationData);

      print('✅ Data successfully saved to talyer_owner_verifications');
      print('🆔 User ID: $userId');
      print('📊 Status: pending');

      return {
        'success': true,
        'user_id': userId,
        'message': 'Data extracted and saved successfully',
        'status': 'pending',
        'verification_data': verificationData,
      };

    } catch (e) {
      print('❌ Error extracting and saving data: $e');
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to extract and save data: $e',
      };
    }
  }

  /// Extract basic permit information from URL/form data
  static Map<String, dynamic> extractPermitInfo({
    required String businessName,
    required String permitUrl,
    String? businessAddress,
    String? permitNumber,
    DateTime? expiryDate,
  }) {
    return {
      'business_name': businessName,
      'permit_url': permitUrl,
      'business_address': businessAddress,
      'permit_number': permitNumber,
      'expiry_date': expiryDate?.toIso8601String(),
      'is_expired': expiryDate != null ? expiryDate.isBefore(DateTime.now()) : false,
      'extracted_at': DateTime.now().toIso8601String(),
      'extraction_method': 'form_data',
    };
  }

  /// Extract basic ID information from URL/form data
  static Map<String, dynamic> extractIdInfo({
    required String fullName,
    required String idUrl,
    required String idType,
    String? idNumber,
    DateTime? expiryDate,
    DateTime? birthDate,
  }) {
    return {
      'full_name': fullName,
      'id_url': idUrl,
      'id_type': idType,
      'id_number': idNumber,
      'expiry_date': expiryDate?.toIso8601String(),
      'birth_date': birthDate?.toIso8601String(),
      'is_expired': expiryDate != null ? expiryDate.isBefore(DateTime.now()) : false,
      'extracted_at': DateTime.now().toIso8601String(),
      'extraction_method': 'form_data',
    };
  }

  /// Get verification record by user ID
  static Future<Map<String, dynamic>?> getVerificationByUserId(String userId) async {
    try {
      final result = await _supabase
          .from('talyer_owner_verifications')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      
      return result;
    } catch (e) {
      print('❌ Error getting verification: $e');
      return null;
    }
  }

  /// Get all pending verifications
  static Future<List<Map<String, dynamic>>> getAllPendingVerifications() async {
    try {
      final result = await _supabase
          .from('talyer_owner_verifications')
          .select()
          .eq('status', 'pending')
          .order('created_at', ascending: false);
      
      return List<Map<String, dynamic>>.from(result);
    } catch (e) {
      print('❌ Error getting pending verifications: $e');
      return [];
    }
  }

  /// Update verification status
  static Future<bool> updateVerificationStatus({
    required String userId,
    required String status,
    String? adminNotes,
    String? reviewedBy,
    int? verificationScore,
    List<String>? tamperFlags,
    DateTime? permitExpiryDate,
    DateTime? idExpiryDate,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (adminNotes != null) updateData['admin_notes'] = adminNotes;
      if (reviewedBy != null) {
        updateData['reviewed_by'] = reviewedBy;
        updateData['reviewed_at'] = DateTime.now().toIso8601String();
      }
      if (verificationScore != null) updateData['verification_score'] = verificationScore;
      if (tamperFlags != null) updateData['tamper_flags'] = tamperFlags;
      if (permitExpiryDate != null) {
        updateData['permit_expiry_date'] = permitExpiryDate.toIso8601String();
        updateData['is_permit_expired'] = permitExpiryDate.isBefore(DateTime.now());
      }
      if (idExpiryDate != null) {
        updateData['id_expiry_date'] = idExpiryDate.toIso8601String();
        updateData['is_id_expired'] = idExpiryDate.isBefore(DateTime.now());
      }

      await _supabase
          .from('talyer_owner_verifications')
          .update(updateData)
          .eq('user_id', userId);

      print('✅ Verification status updated: $status');
      return true;
    } catch (e) {
      print('❌ Error updating verification status: $e');
      return false;
    }
  }

  /// Save data immediately during signup (main function)
  static Future<Map<String, dynamic>> saveSignupDataForVerification({
    required String businessPermitUrl,
    required String validIdUrl,
    required String businessName,
    required String firstName,
    required String lastName,
    required String email,
    String? phoneNumber,
    String? companyAddress,
  }) async {
    try {
      print('📝 Saving signup data for verification...');
      
      final contactPerson = '$firstName $lastName'.trim();
      
      // Extract and save data with status 'pending'
      final result = await extractAndSaveData(
        businessPermitUrl: businessPermitUrl,
        validIdUrl: validIdUrl,
        businessName: businessName,
        contactPerson: contactPerson,
        email: email,
        phoneNumber: phoneNumber,
        businessAddress: companyAddress,
        idType: 'drivers_license', // Default, admin can change during review
      );

      if (result['success']) {
        print('✅ Signup data saved to talyer_owner_verifications table');
        print('📋 Status: pending');
        print('🔍 Ready for admin verification');
      }

      return result;

    } catch (e) {
      print('❌ Error saving signup data: $e');
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to save signup data for verification',
      };
    }
  }

  /// Check if user already has a verification record
  static Future<bool> hasExistingVerification(String email) async {
    try {
      final result = await _supabase
          .from('talyer_owner_verifications')
          .select('id')
          .eq('email', email)
          .maybeSingle();
      
      return result != null;
    } catch (e) {
      print('❌ Error checking existing verification: $e');
      return false;
    }
  }
}










