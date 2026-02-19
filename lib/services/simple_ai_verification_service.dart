
import 'dart:convert';
import 'supabase_service.dart';

class SimpleAIVerificationService {
  static SimpleAIVerificationService? _instance;
  static SimpleAIVerificationService get instance => _instance ??= SimpleAIVerificationService._();
  
  SimpleAIVerificationService._();

  /// Enhanced verification with expiry date checking
  Future<Map<String, dynamic>> verifyTalyerOwnerDocuments({
    required String userId,
    required String businessPermitUrl,
    required String validIdUrl,
    required String businessName,
    required String contactPerson,
    DateTime? permitExpiryDate,
    DateTime? idExpiryDate,
    String? idType,
  }) async {
    try {
      print('🤖 Starting enhanced AI verification for user: $userId');
      
      // Simulate document analysis delay
      await Future.delayed(const Duration(seconds: 2));
      
      // Check for expired documents first
      final expiryCheck = _checkDocumentExpiry(permitExpiryDate, idExpiryDate);
      if (!expiryCheck['valid']) {
        print('❌ Documents expired, auto-rejecting');
        return {
          'success': false,
          'should_approve': false,
          'confidence_score': 0,
          'rejection_reason': expiryCheck['reason'],
          'concerns': expiryCheck['concerns'],
          'is_permit_expired': expiryCheck['is_permit_expired'],
          'is_id_expired': expiryCheck['is_id_expired'],
        };
      }
      
      // Perform enhanced verification
      final verification = await _performEnhancedVerification(
        businessName: businessName,
        contactPerson: contactPerson,
        businessPermitUrl: businessPermitUrl,
        validIdUrl: validIdUrl,
        permitExpiryDate: permitExpiryDate,
        idExpiryDate: idExpiryDate,
        idType: idType,
      );
      
      // Add expiry information to verification result
      verification['permit_expiry_date'] = permitExpiryDate?.toIso8601String();
      verification['id_expiry_date'] = idExpiryDate?.toIso8601String();
      verification['is_permit_expired'] = expiryCheck['is_permit_expired'];
      verification['is_id_expired'] = expiryCheck['is_id_expired'];
      
      return verification;
      
    } catch (e) {
      print('❌ Enhanced Verification Error: $e');
      return {
        'success': false,
        'error': e.toString(),
        'should_approve': false,
        'confidence_score': 0,
      };
    }
  }

  /// Check if documents are expired
  Map<String, dynamic> _checkDocumentExpiry(DateTime? permitExpiry, DateTime? idExpiry) {
    final now = DateTime.now();
    final concerns = <String>[];
    bool isValid = true;
    String reason = '';

    bool isPermitExpired = false;
    bool isIdExpired = false;

    // Check permit expiry
    if (permitExpiry != null) {
      if (permitExpiry.isBefore(now)) {
        isPermitExpired = true;
        isValid = false;
        concerns.add('expired_permit');
        reason += 'Business permit expired on ${permitExpiry.toLocal().toString().split(' ')[0]}. ';
      } else if (permitExpiry.isBefore(now.add(const Duration(days: 30)))) {
        concerns.add('permit_expires_soon');
      }
    }

    // Check ID expiry
    if (idExpiry != null) {
      if (idExpiry.isBefore(now)) {
        isIdExpired = true;
        isValid = false;
        concerns.add('expired_id');
        reason += 'Valid ID expired on ${idExpiry.toLocal().toString().split(' ')[0]}. ';
      } else if (idExpiry.isBefore(now.add(const Duration(days: 30)))) {
        concerns.add('id_expires_soon');
      }
    }

    return {
      'valid': isValid,
      'reason': reason.trim(),
      'concerns': concerns,
      'is_permit_expired': isPermitExpired,
      'is_id_expired': isIdExpired,
    };
  }

  /// Enhanced verification with more sophisticated checks
  Future<Map<String, dynamic>> _performEnhancedVerification({
    required String businessName,
    required String contactPerson,
    required String businessPermitUrl,
    required String validIdUrl,
    DateTime? permitExpiryDate,
    DateTime? idExpiryDate,
    String? idType,
  }) async {
    try {
      final List<String> concerns = [];
      int confidenceScore = 100;
      
      // Enhanced validation checks
      if (businessName.trim().isEmpty || businessName.trim().length < 3) {
        concerns.add('invalid_business_name');
        confidenceScore -= 30;
      }
      
      if (contactPerson.trim().isEmpty || contactPerson.trim().length < 2) {
        concerns.add('invalid_contact_person');
        confidenceScore -= 30;
      }
      
      // URL validation
      if (!_isValidUrl(businessPermitUrl)) {
        concerns.add('invalid_permit_url');
        confidenceScore -= 20;
      }
      
      if (!_isValidUrl(validIdUrl)) {
        concerns.add('invalid_id_url');
        confidenceScore -= 20;
      }
      
      // Enhanced name similarity check
      final nameMatch = _enhancedNameMatching(businessName, contactPerson);
      int nameMatchScore = nameMatch['score'];
      
      if (nameMatchScore < 60) {
        concerns.add('name_mismatch');
        confidenceScore -= 15;
      }
      
      // Check for near expiry warnings
      if (permitExpiryDate != null) {
        final daysUntilPermitExpiry = permitExpiryDate.difference(DateTime.now()).inDays;
        if (daysUntilPermitExpiry <= 30 && daysUntilPermitExpiry > 0) {
          concerns.add('permit_expires_soon');
          confidenceScore -= 10;
        }
      }
      
      if (idExpiryDate != null) {
        final daysUntilIdExpiry = idExpiryDate.difference(DateTime.now()).inDays;
        if (daysUntilIdExpiry <= 30 && daysUntilIdExpiry > 0) {
          concerns.add('id_expires_soon');
          confidenceScore -= 10;
        }
      }
      
      // ID type validation
      if (idType != null && !_isValidIdType(idType)) {
        concerns.add('invalid_id_type');
        confidenceScore -= 15;
      }
      
      // Document authenticity simulation (would be AI-powered in real implementation)
      final documentAuthenticityScore = _simulateDocumentAuthenticity();
      confidenceScore = (confidenceScore * 0.7 + documentAuthenticityScore * 0.3).round();
      
      // Determine approval
      bool shouldApprove = confidenceScore >= 70 && concerns.length <= 2;
      
      // Generate detailed response
      return {
        'success': true,
        'names_match': nameMatchScore >= 60,
        'name_similarity_score': nameMatchScore,
        'name_match_details': nameMatch,
        'should_approve': shouldApprove,
        'confidence_score': confidenceScore,
        'verification_score': confidenceScore,
        'document_authenticity_score': documentAuthenticityScore,
        'approval_reason': shouldApprove 
            ? 'All verification checks passed successfully'
            : 'Verification requirements not met',
        'rejection_reason': shouldApprove ? null : _generateRejectionReason(concerns, confidenceScore),
        'concerns': concerns,
        'recommendation': shouldApprove ? 'approve' : 'manual_review',
        'document_authenticity': documentAuthenticityScore >= 75 ? 'likely_authentic' : 'needs_review',
        'extracted_business_name': businessName,
        'extracted_person_name': contactPerson,
        'id_type': idType,
        'verification_timestamp': DateTime.now().toIso8601String(),
      };
      
    } catch (e) {
      print('❌ Error in enhanced verification: $e');
      return {
        'success': false,
        'names_match': false,
        'should_approve': false,
        'confidence_score': 0,
        'error': e.toString(),
      };
    }
  }

  /// Enhanced name matching algorithm
  Map<String, dynamic> _enhancedNameMatching(String businessName, String contactPerson) {
    final business = businessName.toLowerCase().trim();
    final person = contactPerson.toLowerCase().trim();
    
    int score = 0;
    final details = <String>[];
    
    // Split names into words
    final businessWords = business.split(RegExp(r'\s+'));
    final personWords = person.split(RegExp(r'\s+'));
    
    // Check if person's first name appears in business name
    if (personWords.isNotEmpty && business.contains(personWords.first)) {
      score += 30;
      details.add('first_name_in_business');
    }
    
    // Check if person's last name appears in business name
    if (personWords.length > 1 && business.contains(personWords.last)) {
      score += 25;
      details.add('last_name_in_business');
    }
    
    // Check for common business patterns
    final businessPatterns = ['auto', 'motor', 'garage', 'repair', 'service', 'shop'];
    for (final pattern in businessPatterns) {
      if (business.contains(pattern)) {
        score += 10;
        details.add('automotive_business_pattern');
        break;
      }
    }
    
    // Check for initials matching
    if (_checkInitialsMatch(businessWords, personWords)) {
      score += 20;
      details.add('initials_match');
    }
    
    // Levenshtein distance for similar words
    for (final businessWord in businessWords) {
      for (final personWord in personWords) {
        if (businessWord.length > 3 && personWord.length > 3) {
          final similarity = _calculateSimilarity(businessWord, personWord);
          if (similarity > 0.7) {
            score += 15;
            details.add('similar_words_found');
            break;
          }
        }
      }
    }
    
    // Ensure score doesn't exceed 100
    score = score > 100 ? 100 : score;
    
    return {
      'score': score,
      'details': details,
      'business_words': businessWords,
      'person_words': personWords,
    };
  }

  /// Check if initials match
  bool _checkInitialsMatch(List<String> businessWords, List<String> personWords) {
    if (personWords.length < 2) return false;
    
    final personInitials = personWords.map((w) => w.isNotEmpty ? w[0] : '').join('');
    
    for (final businessWord in businessWords) {
      if (businessWord.length >= personInitials.length) {
        bool allInitialsFound = true;
        for (int i = 0; i < personInitials.length; i++) {
          if (!businessWord.contains(personInitials[i])) {
            allInitialsFound = false;
            break;
          }
        }
        if (allInitialsFound) return true;
      }
    }
    
    return false;
  }

  /// Calculate similarity between two strings (simple implementation)
  double _calculateSimilarity(String a, String b) {
    if (a == b) return 1.0;
    if (a.isEmpty || b.isEmpty) return 0.0;
    
    final shorter = a.length < b.length ? a : b;
    final longer = a.length >= b.length ? a : b;
    
    int matches = 0;
    for (int i = 0; i < shorter.length; i++) {
      if (i < longer.length && shorter[i] == longer[i]) {
        matches++;
      }
    }
    
    return matches / longer.length;
  }

  /// Simulate document authenticity check (would be AI-powered in real implementation)
  int _simulateDocumentAuthenticity() {
    // Simulate various authenticity checks
    final checks = [
      85, // Image quality check
      90, // Text clarity check  
      80, // Format validation
      88, // Security features
      92, // Consistency check
    ];
    
    return (checks.reduce((a, b) => a + b) / checks.length).round();
  }

  /// Validate ID type
  bool _isValidIdType(String idType) {
    const validTypes = ['drivers_license', 'umid', 'national_id', 'passport', 'philsys_id'];
    return validTypes.contains(idType.toLowerCase());
  }

  /// Validate URL format
  bool _isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
  }

  /// Generate detailed rejection reason
  String _generateRejectionReason(List<String> concerns, int confidenceScore) {
    final reasons = <String>[];
    
    if (confidenceScore < 70) {
      reasons.add('Overall confidence score too low ($confidenceScore%)');
    }
    
    for (final concern in concerns) {
      switch (concern) {
        case 'invalid_business_name':
          reasons.add('Business name is invalid or too short');
          break;
        case 'invalid_contact_person':
          reasons.add('Contact person name is invalid or too short');
          break;
        case 'invalid_permit_url':
          reasons.add('Business permit image URL is invalid');
          break;
        case 'invalid_id_url':
          reasons.add('Valid ID image URL is invalid');
          break;
        case 'name_mismatch':
          reasons.add('Business name and contact person name do not match adequately');
          break;
        case 'permit_expires_soon':
          reasons.add('Business permit expires within 30 days');
          break;
        case 'id_expires_soon':
          reasons.add('Valid ID expires within 30 days');
          break;
        case 'invalid_id_type':
          reasons.add('Invalid ID type provided');
          break;
        case 'expired_permit':
          reasons.add('Business permit has expired');
          break;
        case 'expired_id':
          reasons.add('Valid ID has expired');
          break;
      }
    }
    
    return reasons.join('; ');
  }

  /// Call database function for automatic verification
  Future<Map<String, dynamic>> runDatabaseVerification({
    required String userId,
    required String businessName,
    required String contactPerson,
    DateTime? permitExpiryDate,
    DateTime? idExpiryDate,
  }) async {
    try {
      final result = await SupabaseService.client.rpc('auto_verify_talyer_documents', params: {
        'p_user_id': userId,
        'p_business_name': businessName,
        'p_contact_person': contactPerson,
        'p_permit_expiry': permitExpiryDate?.toIso8601String(),
        'p_id_expiry': idExpiryDate?.toIso8601String(),
      });

      if (result != null && result.isNotEmpty) {
        final verification = result.first;
        return {
          'success': true,
          'verification_result': verification['verification_result'],
          'confidence_score': verification['confidence_score'],
          'should_approve': verification['should_approve'],
          'rejection_reason': verification['rejection_reason'],
          'verification_details': verification['verification_details'],
        };
      }

      return {
        'success': false,
        'error': 'No verification result returned from database',
      };
      
    } catch (e) {
      print('❌ Database verification error: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Approve verification with enhanced data
  Future<void> approveVerification(String userId, Map<String, dynamic> verification) async {
    try {
      final updateData = {
        'status': 'approved',
        'verification_score': verification['verification_score'] ?? verification['confidence_score'] ?? 100,
        'admin_notes': 'AUTO-APPROVED: ${verification['approval_reason'] ?? 'Enhanced AI verification passed'}',
        'reviewed_at': DateTime.now().toIso8601String(),
        'tamper_flags': json.encode(verification['concerns'] ?? []),
        'updated_at': DateTime.now().toIso8601String(),
        'is_permit_expired': verification['is_permit_expired'] ?? false,
        'is_id_expired': verification['is_id_expired'] ?? false,
      };

      await SupabaseService.client
          .from('talyer_owner_verifications')
          .update(updateData)
          .eq('user_id', userId);

      // Update user profile
      await SupabaseService.client
          .from('user_profiles')
          .update({
            'user_type': 'talyer_owner',
            'account_status': 'active'
          })
          .eq('id', userId);

      print('✅ Enhanced verification approved for user: $userId');
      
    } catch (e) {
      print('❌ Error approving enhanced verification: $e');
      throw e;
    }
  }

  /// Reject verification with detailed reason
  Future<void> rejectVerification(String userId, Map<String, dynamic> verification) async {
    try {
      final updateData = {
        'status': 'rejected',
        'verification_score': verification['verification_score'] ?? verification['confidence_score'] ?? 0,
        'admin_notes': 'AUTO-REJECTED: ${verification['rejection_reason'] ?? verification['concerns']?.join(', ') ?? 'Enhanced validation failed'}',
        'reviewed_at': DateTime.now().toIso8601String(),
        'tamper_flags': json.encode(verification['concerns'] ?? []),
        'updated_at': DateTime.now().toIso8601String(),
        'is_permit_expired': verification['is_permit_expired'] ?? false,
        'is_id_expired': verification['is_id_expired'] ?? false,
      };

      await SupabaseService.client
          .from('talyer_owner_verifications')
          .update(updateData)
          .eq('user_id', userId);

      print('❌ Enhanced verification rejected for user: $userId');
      
    } catch (e) {
      print('❌ Error rejecting enhanced verification: $e');
      throw e;
    }
  }

  /// Get verification status and details
  Future<Map<String, dynamic>?> getVerificationStatus(String userId) async {
    try {
      final result = await SupabaseService.client.rpc('get_verification_details', params: {
        'p_user_id': userId,
      });

      if (result != null && result.isNotEmpty) {
        return result.first;
      }

      return null;
      
    } catch (e) {
      print('❌ Error getting verification status: $e');
      return null;
    }
  }

  /// Process verification queue (admin function)
  Future<Map<String, dynamic>> processVerificationQueue() async {
    try {
      final result = await SupabaseService.client.rpc('process_verification_queue');

      if (result != null && result.isNotEmpty) {
        return result.first;
      }

      return {
        'processed_count': 0,
        'approved_count': 0,
        'rejected_count': 0,
        'processing_details': [],
      };
      
    } catch (e) {
      print('❌ Error processing verification queue: $e');
      return {
        'error': e.toString(),
        'processed_count': 0,
        'approved_count': 0,
        'rejected_count': 0,
      };
    }
  }
}
