import 'package:supabase_flutter/supabase_flutter.dart';

/// Manual verification service for when AI verification fails
/// Allows admins to manually extract and save permit/ID data
class ManualVerificationService {
  static final _supabase = Supabase.instance.client;

  /// Save verification data manually (when AI fails)
  static Future<Map<String, dynamic>> saveManualVerification({
    required String userId,
    required String businessName,
    required String businessPermitUrl,
    required String validIdUrl,
    required String idType,
    required String contactPerson,
    String? businessAddress,
    String? phoneNumber,
    String? email,
    DateTime? permitExpiryDate,
    DateTime? idExpiryDate,
    String status = 'pending',
    String? adminNotes,
    int verificationScore = 50, // Default manual score
    List<String>? tamperFlags,
  }) async {
    try {
      print('📝 Starting manual verification save...');
      print('👤 User ID: $userId');
      print('🏢 Business: $businessName');
      print('👨‍💼 Contact: $contactPerson');

      // Check if verification already exists
      final existingVerification = await _supabase
          .from('talyer_owner_verifications')
          .select('id')
          .eq('user_id', userId)
          .maybeSingle();

      Map<String, dynamic> verificationData = {
        'user_id': userId,
        'business_name': businessName,
        'business_permit_url': businessPermitUrl,
        'valid_id_url': validIdUrl,
        'id_type': idType,
        'contact_person': contactPerson,
        'status': status,
        'verification_score': verificationScore,
        'is_permit_expired': permitExpiryDate != null ? 
            permitExpiryDate.isBefore(DateTime.now()) : false,
        'is_id_expired': idExpiryDate != null ? 
            idExpiryDate.isBefore(DateTime.now()) : false,
        'tamper_flags': tamperFlags ?? [],
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Add optional fields if provided
      if (businessAddress != null) verificationData['business_address'] = businessAddress;
      if (phoneNumber != null) verificationData['phone_number'] = phoneNumber;
      if (email != null) verificationData['email'] = email;
      if (permitExpiryDate != null) verificationData['permit_expiry_date'] = permitExpiryDate.toIso8601String();
      if (idExpiryDate != null) verificationData['id_expiry_date'] = idExpiryDate.toIso8601String();
      if (adminNotes != null) verificationData['admin_notes'] = adminNotes;

      if (existingVerification != null) {
        // Update existing verification
        print('🔄 Updating existing verification...');
        await _supabase
            .from('talyer_owner_verifications')
            .update(verificationData)
            .eq('user_id', userId);
        
        print('✅ Verification updated successfully');
      } else {
        // Create new verification
        print('➕ Creating new verification...');
        verificationData['created_at'] = DateTime.now().toIso8601String();
        
        await _supabase
            .from('talyer_owner_verifications')
            .insert(verificationData);
        
        print('✅ Verification created successfully');
      }

      return {
        'success': true,
        'message': 'Manual verification saved successfully',
        'verification_data': verificationData,
      };

    } catch (e) {
      print('❌ Error saving manual verification: $e');
      return {
        'success': false,
        'message': 'Failed to save manual verification: $e',
        'error': e.toString(),
      };
    }
  }

  /// Extract data from permit image manually
  static Future<Map<String, dynamic>> extractPermitDataManually({
    required String permitUrl,
    required String businessName,
    String? businessAddress,
    String? permitNumber,
    DateTime? expiryDate,
    String? issuingAuthority,
    List<String>? serviceTypes,
  }) async {
    try {
      print('📄 Extracting permit data manually...');
      print('🏢 Business: $businessName');
      print('📋 Permit URL: $permitUrl');

      Map<String, dynamic> permitData = {
        'permit_url': permitUrl,
        'business_name': businessName,
        'extraction_method': 'manual',
        'extracted_at': DateTime.now().toIso8601String(),
        'confidence_score': 100, // Manual extraction has 100% confidence
      };

      // Add optional extracted data
      if (businessAddress != null) permitData['business_address'] = businessAddress;
      if (permitNumber != null) permitData['permit_number'] = permitNumber;
      if (expiryDate != null) {
        permitData['expiry_date'] = expiryDate.toIso8601String();
        permitData['is_expired'] = expiryDate.isBefore(DateTime.now());
      }
      if (issuingAuthority != null) permitData['issuing_authority'] = issuingAuthority;
      if (serviceTypes != null) permitData['service_types'] = serviceTypes;

      print('✅ Permit data extracted manually');
      return {
        'success': true,
        'permit_data': permitData,
        'message': 'Permit data extracted manually',
      };

    } catch (e) {
      print('❌ Error extracting permit data manually: $e');
      return {
        'success': false,
        'message': 'Failed to extract permit data: $e',
        'error': e.toString(),
      };
    }
  }

  /// Extract data from ID image manually
  static Future<Map<String, dynamic>> extractIdDataManually({
    required String idUrl,
    required String idType,
    required String fullName,
    String? idNumber,
    DateTime? expiryDate,
    String? address,
    DateTime? birthDate,
    String? gender,
  }) async {
    try {
      print('🆔 Extracting ID data manually...');
      print('👤 Name: $fullName');
      print('📋 ID Type: $idType');
      print('📷 ID URL: $idUrl');

      Map<String, dynamic> idData = {
        'id_url': idUrl,
        'id_type': idType,
        'full_name': fullName,
        'extraction_method': 'manual',
        'extracted_at': DateTime.now().toIso8601String(),
        'confidence_score': 100, // Manual extraction has 100% confidence
      };

      // Add optional extracted data
      if (idNumber != null) idData['id_number'] = idNumber;
      if (address != null) idData['address'] = address;
      if (gender != null) idData['gender'] = gender;
      if (expiryDate != null) {
        idData['expiry_date'] = expiryDate.toIso8601String();
        idData['is_expired'] = expiryDate.isBefore(DateTime.now());
      }
      if (birthDate != null) {
        idData['birth_date'] = birthDate.toIso8601String();
        // Calculate age
        final age = DateTime.now().difference(birthDate).inDays ~/ 365;
        idData['age'] = age;
      }

      print('✅ ID data extracted manually');
      return {
        'success': true,
        'id_data': idData,
        'message': 'ID data extracted manually',
      };

    } catch (e) {
      print('❌ Error extracting ID data manually: $e');
      return {
        'success': false,
        'message': 'Failed to extract ID data: $e',
        'error': e.toString(),
      };
    }
  }

  /// Get verification by user ID
  static Future<Map<String, dynamic>?> getVerificationByUserId(String userId) async {
    try {
      final verification = await _supabase
          .from('talyer_owner_verifications')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      return verification;
    } catch (e) {
      print('❌ Error getting verification: $e');
      return null;
    }
  }

  /// Update verification status
  static Future<bool> updateVerificationStatus({
    required String userId,
    required String status,
    String? adminNotes,
    String? reviewedBy,
  }) async {
    try {
      Map<String, dynamic> updateData = {
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (adminNotes != null) updateData['admin_notes'] = adminNotes;
      if (reviewedBy != null) {
        updateData['reviewed_by'] = reviewedBy;
        updateData['reviewed_at'] = DateTime.now().toIso8601String();
      }

      await _supabase
          .from('talyer_owner_verifications')
          .update(updateData)
          .eq('user_id', userId);

      print('✅ Verification status updated to: $status');
      return true;
    } catch (e) {
      print('❌ Error updating verification status: $e');
      return false;
    }
  }

  /// Add tamper flags
  static Future<bool> addTamperFlags({
    required String userId,
    required List<String> flags,
  }) async {
    try {
      final existing = await getVerificationByUserId(userId);
      if (existing == null) return false;

      List<String> currentFlags = List<String>.from(existing['tamper_flags'] ?? []);
      currentFlags.addAll(flags);
      currentFlags = currentFlags.toSet().toList(); // Remove duplicates

      await _supabase
          .from('talyer_owner_verifications')
          .update({
            'tamper_flags': currentFlags,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId);

      print('✅ Tamper flags added: $flags');
      return true;
    } catch (e) {
      print('❌ Error adding tamper flags: $e');
      return false;
    }
  }

  /// Complete manual verification process
  static Future<Map<String, dynamic>> completeManualVerification({
    required String userId,
    required String businessName,
    required String businessPermitUrl,
    required String validIdUrl,
    required String idType,
    required String contactPerson,
    required Map<String, dynamic> extractedPermitData,
    required Map<String, dynamic> extractedIdData,
    String? businessAddress,
    String? phoneNumber,
    String? email,
    String? adminNotes,
    String status = 'under_review',
  }) async {
    try {
      print('🔄 Completing manual verification process...');

      // Extract dates from manually extracted data
      DateTime? permitExpiryDate;
      DateTime? idExpiryDate;

      if (extractedPermitData['expiry_date'] != null) {
        permitExpiryDate = DateTime.parse(extractedPermitData['expiry_date']);
      }

      if (extractedIdData['expiry_date'] != null) {
        idExpiryDate = DateTime.parse(extractedIdData['expiry_date']);
      }

      // Calculate verification score based on extracted data
      int verificationScore = _calculateManualVerificationScore(
        extractedPermitData,
        extractedIdData,
        businessName,
        contactPerson,
      );

      // Save the complete verification
      final result = await saveManualVerification(
        userId: userId,
        businessName: businessName,
        businessPermitUrl: businessPermitUrl,
        validIdUrl: validIdUrl,
        idType: idType,
        contactPerson: contactPerson,
        businessAddress: businessAddress,
        phoneNumber: phoneNumber,
        email: email,
        permitExpiryDate: permitExpiryDate,
        idExpiryDate: idExpiryDate,
        status: status,
        adminNotes: adminNotes,
        verificationScore: verificationScore,
      );

      if (result['success']) {
        print('✅ Manual verification completed successfully');
        print('📊 Verification Score: $verificationScore');
      }

      return result;

    } catch (e) {
      print('❌ Error completing manual verification: $e');
      return {
        'success': false,
        'message': 'Failed to complete manual verification: $e',
        'error': e.toString(),
      };
    }
  }

  /// Calculate verification score for manual verification
  static int _calculateManualVerificationScore(
    Map<String, dynamic> permitData,
    Map<String, dynamic> idData,
    String expectedBusinessName,
    String expectedContactPerson,
  ) {
    int score = 0;

    // Base score for manual verification
    score += 30;

    // Check if permit data is complete
    if (permitData['business_name'] != null) score += 15;
    if (permitData['permit_number'] != null) score += 10;
    if (permitData['expiry_date'] != null) score += 10;
    if (permitData['business_address'] != null) score += 5;

    // Check if ID data is complete
    if (idData['full_name'] != null) score += 15;
    if (idData['id_number'] != null) score += 10;
    if (idData['expiry_date'] != null) score += 10;

    // Check for name matching (case-insensitive)
    if (permitData['business_name'] != null) {
      final permitBusinessName = permitData['business_name'].toString().toLowerCase();
      final expectedName = expectedBusinessName.toLowerCase();
      if (permitBusinessName.contains(expectedName) || expectedName.contains(permitBusinessName)) {
        score += 15;
      }
    }

    if (idData['full_name'] != null) {
      final idName = idData['full_name'].toString().toLowerCase();
      final expectedPerson = expectedContactPerson.toLowerCase();
      if (idName.contains(expectedPerson) || expectedPerson.contains(idName)) {
        score += 10;
      }
    }

    // Ensure score is within bounds
    return score.clamp(0, 100);
  }

  /// Get all pending verifications for admin review
  static Future<List<Map<String, dynamic>>> getPendingVerifications() async {
    try {
      final verifications = await _supabase
          .from('talyer_owner_verifications')
          .select('''
            *,
            user:user_id (
              email,
              raw_user_meta_data
            )
          ''')
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(verifications);
    } catch (e) {
      print('❌ Error getting pending verifications: $e');
      return [];
    }
  }
}










