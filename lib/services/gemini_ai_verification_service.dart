import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/supabase_service.dart';
import '../config/gemini_config.dart';

class GeminiAIVerificationService {
  static final GeminiAIVerificationService instance = GeminiAIVerificationService._internal();
  GeminiAIVerificationService._internal();

  // Use configuration from GeminiConfig
  static String get GEMINI_API_KEY => GeminiConfig.GEMINI_API_KEY;
  static const String GEMINI_API_URL = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent';

  /// Enhanced document verification focusing on expiry dates and name matching
  Future<Map<String, dynamic>> verifyTalyerOwnerDocuments({
    required String userId,
    required String businessPermitUrl,
    required String validIdUrl,
    required String businessName,
    required String contactPerson,
    required DateTime permitExpiryDate,
    required DateTime idExpiryDate,
    required String idType,
  }) async {
    try {
      // Check if Gemini API is configured
      if (!GeminiConfig.isConfigured) {
        print('⚠️ Gemini API key not configured, using mock verification...');
        return _getMockVerificationResult(
          businessName: businessName,
          contactPerson: contactPerson,
          permitExpiryDate: permitExpiryDate,
          idExpiryDate: idExpiryDate,
        );
      }
      
      print('🤖 Starting ENHANCED Gemini AI verification...');
      print('📋 Business: $businessName');
      print('👤 Contact: $contactPerson');
      print('⏰ Checking expiry dates and name matching...');
      
      // Step 1: Download and convert images to base64
      final businessPermitBase64 = await _downloadAndConvertToBase64(businessPermitUrl);
      final validIdBase64 = await _downloadAndConvertToBase64(validIdUrl);
      
      // Step 2: CRITICAL VERIFICATION - Check expiry dates and extract names
      final permitAnalysis = await _analyzeBusinessPermitEnhanced(
        imageBase64: businessPermitBase64,
        expectedBusinessName: businessName,
      );
      
      // Step 3: CRITICAL VERIFICATION - Check ID expiry and extract name
      final idAnalysis = await _analyzeValidIdEnhanced(
        imageBase64: validIdBase64,
        expectedName: contactPerson,
        idType: idType,
      );
      
      // Step 4: CRITICAL DECISION LOGIC - Apply your rules
      final verificationResult = _applyStrictVerificationRules(
        permitAnalysis: permitAnalysis,
        idAnalysis: idAnalysis,
        expectedBusinessName: businessName,
        expectedPersonName: contactPerson,
        userId: userId,
      );
      
      // Step 5: Store verification in database (only if approved or for record keeping)
      await _storeVerificationResult(
        userId: userId,
        businessName: businessName,
        permitUrl: businessPermitUrl,
        idUrl: validIdUrl,
        idType: idType,
        permitExpiryDate: permitExpiryDate,
        idExpiryDate: idExpiryDate,
        contactPerson: contactPerson,
        verificationResult: verificationResult,
      );
      
      // Step 6: Log final decision
      if (verificationResult['should_approve'] == true) {
        print('✅ APPROVED: Documents valid, not expired, names match');
      } else {
        print('❌ REJECTED: ${verificationResult['rejection_reason']}');
      }
      
      return verificationResult;
      
    } catch (e) {
      print('❌ Error in Gemini AI verification: $e');
      return {
        'should_approve': false,
        'confidence_score': 0,
        'rejection_reason': 'AI verification failed: ${e.toString()}',
        'is_permit_expired': false,
        'is_id_expired': false,
        'concerns': ['verification_error'],
        'ai_analysis': {
          'permit_status': 'error',
          'id_status': 'error',
          'name_match': 'error',
        }
      };
    }
  }

  /// Enhanced business permit analysis focusing on expiry and name extraction
  Future<Map<String, dynamic>> _analyzeBusinessPermitEnhanced({
    required String imageBase64,
    required String expectedBusinessName,
  }) async {
    final currentDate = DateTime.now().toLocal().toString().split(' ')[0];
    
    final prompt = '''
CRITICAL DOCUMENT VERIFICATION - Analyze this business permit image and extract the following information:

REQUIRED INFORMATION:
1. Business Name/Company Name
2. Expiry Date (CRITICAL - check if expired)
3. Business Owner/Authorized Person Name
4. Issue Date
5. Permit Number

Expected Business Name: "$expectedBusinessName"
Current Date: $currentDate

VERIFICATION RULES:
- If document is EXPIRED (expiry date < current date): REJECT
- If business name does NOT match expected name: REJECT  
- If text is unclear or document appears fake: REJECT
- Only APPROVE if document is valid, not expired, and name matches

Provide analysis in JSON format:
{
  "extracted_business_name": "exact business name from document",
  "expiry_date": "YYYY-MM-DD",
  "issue_date": "YYYY-MM-DD",
  "business_owner": "owner/authorized person name",
  "permit_number": "permit number",
  "is_expired": true/false,
  "business_name_matches": true/false,
  "document_quality": "excellent|good|fair|poor",
  "confidence_score": 0-100,
  "verification_status": "valid|expired|invalid|unclear",
  "rejection_reason": "specific reason if invalid",
  "concerns": ["list any issues found"]
}

IMPORTANT: 
- Compare expiry_date with current date ($currentDate)
- Compare extracted_business_name with expected name exactly
- Set is_expired = true if expiry_date is before current date
- Set business_name_matches = true only if names match exactly (case insensitive)

Respond ONLY with valid JSON, no additional text.
''';

    return await _callGeminiAPI(imageBase64, prompt, 'business_permit_enhanced');
  }

  /// Enhanced valid ID analysis focusing on expiry and name extraction
  Future<Map<String, dynamic>> _analyzeValidIdEnhanced({
    required String imageBase64,
    required String expectedName,
    required String idType,
  }) async {
    final currentDate = DateTime.now().toLocal().toString().split(' ')[0];
    
    final prompt = '''
CRITICAL ID VERIFICATION - Analyze this Philippine ID document and extract the following information:

REQUIRED INFORMATION:
1. Full Name (CRITICAL - must match expected name)
2. Expiry Date (CRITICAL - check if expired)
3. ID Number
4. Date of Birth
5. ID Type Detection

Expected Full Name: "$expectedName"
Current Date: $currentDate

VERIFICATION RULES:
- If document is EXPIRED (expiry date < current date): REJECT
- If full name does NOT match expected name: REJECT
- If text is unclear or document appears fake: REJECT
- Only APPROVE if ID is valid, not expired, and name matches

Provide analysis in JSON format:
{
  "extracted_full_name": "exact full name from ID",
  "expiry_date": "YYYY-MM-DD",
  "issue_date": "YYYY-MM-DD",
  "id_number": "ID number",
  "date_of_birth": "YYYY-MM-DD",
  "id_type_detected": "drivers_license|national_id|umid|passport|philsys_id",
  "is_expired": true/false,
  "name_matches": true/false,
  "document_quality": "excellent|good|fair|poor",
  "confidence_score": 0-100,
  "verification_status": "valid|expired|invalid|unclear",
  "rejection_reason": "specific reason if invalid",
  "concerns": ["list any issues found"]
}

IMPORTANT:
- Compare expiry_date with current date ($currentDate)
- Compare extracted_full_name with expected name exactly
- Set is_expired = true if expiry_date is before current date
- Set name_matches = true only if names match exactly (case insensitive)
- Auto-detect ID type from document appearance

NAME MATCHING RULES:
- Ignore case differences
- Ignore extra spaces
- Account for common name variations (Jr., Sr., etc.)
- Focus on first name and last name match

Respond ONLY with valid JSON, no additional text.
''';

    return await _callGeminiAPI(imageBase64, prompt, 'valid_id_enhanced');
  }

  /// Apply strict verification rules based on your requirements
  Map<String, dynamic> _applyStrictVerificationRules({
    required Map<String, dynamic> permitAnalysis,
    required Map<String, dynamic> idAnalysis,
    required String expectedBusinessName,
    required String expectedPersonName,
    required String userId,
  }) {
    final now = DateTime.now();
    
    print('📊 APPLYING STRICT VERIFICATION RULES:');
    print('📄 Permit Status: ${permitAnalysis['verification_status']}');
    print('🆔 ID Status: ${idAnalysis['verification_status']}');
    print('⏰ Permit Expired: ${permitAnalysis['is_expired']}');
    print('⏰ ID Expired: ${idAnalysis['is_expired']}');
    print('📝 Business Name Match: ${permitAnalysis['business_name_matches']}');
    print('👤 Person Name Match: ${idAnalysis['name_matches']}');
    
    // Extract key verification points
    final isPermitExpired = permitAnalysis['is_expired'] == true;
    final isIdExpired = idAnalysis['is_expired'] == true;
    final businessNameMatches = permitAnalysis['business_name_matches'] == true;
    final personNameMatches = idAnalysis['name_matches'] == true;
    final permitValid = permitAnalysis['verification_status'] == 'valid';
    final idValid = idAnalysis['verification_status'] == 'valid';
    
    // Calculate confidence scores
    final permitConfidence = permitAnalysis['confidence_score'] ?? 0;
    final idConfidence = idAnalysis['confidence_score'] ?? 0;
    final overallConfidence = ((permitConfidence + idConfidence) / 2).round();
    
    // STRICT DECISION LOGIC - Your Requirements
    bool shouldApprove = false;
    String rejectionReason = '';
    List<String> concerns = [];
    
    // Rule 1: Check for expired documents
    if (isPermitExpired) {
      shouldApprove = false;
      rejectionReason = 'Business permit is expired';
      concerns.add('permit_expired');
      print('❌ REJECTED: Business permit expired');
    } else if (isIdExpired) {
      shouldApprove = false;
      rejectionReason = 'Valid ID is expired';
      concerns.add('id_expired');
      print('❌ REJECTED: Valid ID expired');
    }
    // Rule 2: Check for name mismatches
    else if (!businessNameMatches) {
      shouldApprove = false;
      rejectionReason = 'Business name does not match: Expected "$expectedBusinessName", Found "${permitAnalysis['extracted_business_name']}"';
      concerns.add('business_name_mismatch');
      print('❌ REJECTED: Business name mismatch');
    } else if (!personNameMatches) {
      shouldApprove = false;
      rejectionReason = 'Person name does not match: Expected "$expectedPersonName", Found "${idAnalysis['extracted_full_name']}"';
      concerns.add('person_name_mismatch');
      print('❌ REJECTED: Person name mismatch');
    }
    // Rule 3: Check document validity
    else if (!permitValid) {
      shouldApprove = false;
      rejectionReason = 'Business permit appears invalid or unclear: ${permitAnalysis['rejection_reason'] ?? 'Document quality issues'}';
      concerns.add('permit_invalid');
      print('❌ REJECTED: Business permit invalid');
    } else if (!idValid) {
      shouldApprove = false;
      rejectionReason = 'Valid ID appears invalid or unclear: ${idAnalysis['rejection_reason'] ?? 'Document quality issues'}';
      concerns.add('id_invalid');
      print('❌ REJECTED: Valid ID invalid');
    }
    // Rule 4: Check confidence level
    else if (overallConfidence < 70) {
      shouldApprove = false;
      rejectionReason = 'Low confidence in document verification (${overallConfidence}%). Documents may be unclear or suspicious';
      concerns.add('low_confidence');
      print('❌ REJECTED: Low confidence score');
    }
    // Rule 5: APPROVE - All checks passed
    else {
      shouldApprove = true;
      rejectionReason = '';
      print('✅ APPROVED: All verification checks passed');
    }
    
    // Add any additional concerns from AI analysis
    if (permitAnalysis['concerns'] != null) {
      concerns.addAll(List<String>.from(permitAnalysis['concerns']));
    }
    if (idAnalysis['concerns'] != null) {
      concerns.addAll(List<String>.from(idAnalysis['concerns']));
    }
    
    return {
      'should_approve': shouldApprove,
      'confidence_score': overallConfidence,
      'rejection_reason': rejectionReason.trim(),
      'is_permit_expired': isPermitExpired,
      'is_id_expired': isIdExpired,
      'business_name_matches': businessNameMatches,
      'person_name_matches': personNameMatches,
      'concerns': concerns,
      'ai_analysis': {
        'permit_analysis': permitAnalysis,
        'id_analysis': idAnalysis,
        'decision_logic': {
          'permit_expired': isPermitExpired,
          'id_expired': isIdExpired,
          'business_name_match': businessNameMatches,
          'person_name_match': personNameMatches,
          'permit_valid': permitValid,
          'id_valid': idValid,
          'overall_confidence': overallConfidence,
        },
        'processed_at': now.toIso8601String(),
        'verification_id': 'GEMINI_ENHANCED_${userId}_${now.millisecondsSinceEpoch}',
      },
      'recommendation': shouldApprove ? 'auto_approve' : 'auto_reject',
      'manual_review_required': false, // Since we're using strict auto-approval/rejection
    };
  }

  /// Download image and convert to base64
  Future<String> _downloadAndConvertToBase64(String imageUrl) async {
    try {
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode == 200) {
        return base64Encode(response.bodyBytes);
      } else {
        throw Exception('Failed to download image: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error downloading image: $e');
    }
  }

  /// Analyze business permit using Gemini AI
  Future<Map<String, dynamic>> _analyzeBusinessPermit({
    required String imageBase64,
    required String expectedBusinessName,
    required DateTime expectedExpiryDate,
  }) async {
    final prompt = '''
Analyze this business permit document image and extract the following information:

1. Business Name/Company Name
2. Permit Number
3. Issue Date
4. Expiry Date
5. Issuing Authority
6. Business Owner/Authorized Person Name
7. Business Address
8. Document Quality Assessment

Expected Information:
- Business Name: $expectedBusinessName
- Expected Expiry: ${expectedExpiryDate.toLocal().toString().split(' ')[0]}

Please provide analysis in JSON format:
{
  "extracted_business_name": "extracted name",
  "permit_number": "permit number",
  "issue_date": "YYYY-MM-DD",
  "expiry_date": "YYYY-MM-DD", 
  "issuing_authority": "authority name",
  "business_owner": "owner name",
  "business_address": "address",
  "document_quality": "excellent|good|fair|poor",
  "is_expired": true/false,
  "name_match": true/false,
  "expiry_match": true/false,
  "confidence_score": 0-100,
  "concerns": ["list of any concerns"],
  "verification_status": "valid|invalid|suspicious"
}

Check if:
- Document appears genuine (not tampered/fake)
- Text is clear and readable
- All required fields are present
- Business name matches expected name
- Document is not expired
- Format appears official

Respond ONLY with valid JSON, no additional text.
''';

    return await _callGeminiAPI(imageBase64, prompt, 'business_permit');
  }

  /// Analyze valid ID using Gemini AI
  Future<Map<String, dynamic>> _analyzeValidId({
    required String imageBase64,
    required String expectedName,
    required DateTime expectedExpiryDate,
    required String idType,
  }) async {
    final idTypeText = idType == 'auto_detect' ? 'any valid Philippine ID' : idType.replaceAll('_', ' ');
    
    final prompt = '''
Analyze this Philippine ID document image and extract the following information:

1. Full Name
2. ID Number
3. Date of Birth
4. Issue Date
5. Expiry Date
6. Address
7. ID Type (automatically detect what type of ID this is)
8. Document Quality Assessment

Expected Information:
- Full Name: $expectedName
- Expected Expiry: ${expectedExpiryDate.toLocal().toString().split(' ')[0]}
- Expected ID Type: $idTypeText

Please provide analysis in JSON format:
{
  "extracted_full_name": "extracted name",
  "id_number": "id number",
  "date_of_birth": "YYYY-MM-DD",
  "issue_date": "YYYY-MM-DD",
  "expiry_date": "YYYY-MM-DD",
  "address": "address",
  "id_type_detected": "drivers_license|national_id|umid|passport|philsys_id|other",
  "document_quality": "excellent|good|fair|poor",
  "is_expired": true/false,
  "name_match": true/false,
  "expiry_match": true/false,
  "confidence_score": 0-100,
  "concerns": ["list of any concerns"],
  "verification_status": "valid|invalid|suspicious",
  "id_type_match": true/false
}

Check if:
- Document appears genuine (not tampered/fake)
- Text is clear and readable
- All required fields are present
- Name matches expected name
- Document is not expired
- ID type can be determined from visual appearance
- Format appears official

IMPORTANT: Auto-detect the ID type from the document appearance:
- Driver's License: Has "DRIVER'S LICENSE" text, vehicle categories
- National ID: Has "REPUBLIC OF THE PHILIPPINES" and "NATIONAL ID"
- UMID: Has "UNIFIED MULTI-PURPOSE ID"
- Passport: Has "PASSPORT" and country coat of arms
- PhilSys ID: Has "PhilSys ID" or national ID system branding

Respond ONLY with valid JSON, no additional text.
''';

    return await _callGeminiAPI(imageBase64, prompt, 'valid_id');
  }

  /// Cross-verify names between documents
  Future<Map<String, dynamic>> _crossVerifyNames({
    required Map<String, dynamic> permitAnalysis,
    required Map<String, dynamic> idAnalysis,
    required String expectedBusinessName,
    required String expectedPersonName,
  }) async {
    final prompt = '''
Cross-verify the names and information from these two documents:

Business Permit Analysis:
${jsonEncode(permitAnalysis)}

Valid ID Analysis:
${jsonEncode(idAnalysis)}

Expected Information:
- Business Name: $expectedBusinessName
- Person Name: $expectedPersonName

Please analyze name consistency and provide verification in JSON format:
{
  "business_name_consistency": true/false,
  "person_name_consistency": true/false,
  "business_owner_match": true/false,
  "overall_consistency": true/false,
  "confidence_score": 0-100,
  "concerns": ["list of any concerns"],
  "recommendation": "approve|reject|manual_review",
  "reason": "explanation of recommendation"
}

Check if:
- Business name in permit matches expected business name
- Person name in ID matches expected person name
- Business owner in permit relates to person in ID
- Names are consistent across documents
- No suspicious variations in names

Respond ONLY with valid JSON, no additional text.
''';

    try {
      final response = await http.post(
        Uri.parse('$GEMINI_API_URL?key=$GEMINI_API_KEY'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [{
            'parts': [{'text': prompt}]
          }],
          'generationConfig': {
            'temperature': 0.1,
            'topK': 1,
            'topP': 1,
            'maxOutputTokens': 1024,
          }
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final generatedText = data['candidates'][0]['content']['parts'][0]['text'];
        return jsonDecode(generatedText);
      } else {
        throw Exception('Gemini API error: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error in name cross-verification: $e');
      return {
        'business_name_consistency': false,
        'person_name_consistency': false,
        'business_owner_match': false,
        'overall_consistency': false,
        'confidence_score': 0,
        'concerns': ['cross_verification_error'],
        'recommendation': 'manual_review',
        'reason': 'Error in cross-verification process'
      };
    }
  }

  /// Call Gemini AI API
  Future<Map<String, dynamic>> _callGeminiAPI(String imageBase64, String prompt, String documentType) async {
    try {
      final response = await http.post(
        Uri.parse('$GEMINI_API_URL?key=$GEMINI_API_KEY'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [{
            'parts': [
              {'text': prompt},
              {
                'inline_data': {
                  'mime_type': 'image/jpeg',
                  'data': imageBase64
                }
              }
            ]
          }],
          'generationConfig': {
            'temperature': 0.1,
            'topK': 1,
            'topP': 1,
            'maxOutputTokens': 2048,
          }
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final generatedText = data['candidates'][0]['content']['parts'][0]['text'];
        
        // Clean up the response and parse JSON
        String cleanJson = generatedText.trim();
        if (cleanJson.startsWith('```json')) {
          cleanJson = cleanJson.substring(7);
        }
        if (cleanJson.endsWith('```')) {
          cleanJson = cleanJson.substring(0, cleanJson.length - 3);
        }
        
        return jsonDecode(cleanJson);
      } else {
        throw Exception('Gemini API error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('❌ Error calling Gemini API for $documentType: $e');
      return {
        'verification_status': 'error',
        'confidence_score': 0,
        'concerns': ['api_error'],
        'is_expired': false,
        'name_match': false,
        'expiry_match': false,
      };
    }
  }

  /// Generate final verification result
  Map<String, dynamic> _generateFinalResult({
    required Map<String, dynamic> permitAnalysis,
    required Map<String, dynamic> idAnalysis,
    required Map<String, dynamic> nameMatchResult,
    required String userId,
  }) {
    final now = DateTime.now();
    
    // Calculate overall confidence score
    final permitConfidence = permitAnalysis['confidence_score'] ?? 0;
    final idConfidence = idAnalysis['confidence_score'] ?? 0;
    final nameConfidence = nameMatchResult['confidence_score'] ?? 0;
    final overallConfidence = ((permitConfidence + idConfidence + nameConfidence) / 3).round();
    
    // Check for critical issues
    final isPermitExpired = permitAnalysis['is_expired'] == true;
    final isIdExpired = idAnalysis['is_expired'] == true;
    final permitValid = permitAnalysis['verification_status'] == 'valid';
    final idValid = idAnalysis['verification_status'] == 'valid';
    final namesConsistent = nameMatchResult['overall_consistency'] == true;
    
    // Collect all concerns
    List<String> allConcerns = [];
    allConcerns.addAll(List<String>.from(permitAnalysis['concerns'] ?? []));
    allConcerns.addAll(List<String>.from(idAnalysis['concerns'] ?? []));
    allConcerns.addAll(List<String>.from(nameMatchResult['concerns'] ?? []));
    
    // Add expiry warnings
    if (isPermitExpired) allConcerns.add('permit_expired');
    if (isIdExpired) allConcerns.add('id_expired');
    
    // Determine if should approve
    bool shouldApprove = false;
    String rejectionReason = '';
    
    if (isPermitExpired || isIdExpired) {
      shouldApprove = false;
      rejectionReason = 'Expired documents detected. ';
      if (isPermitExpired) rejectionReason += 'Business permit is expired. ';
      if (isIdExpired) rejectionReason += 'Valid ID is expired. ';
    } else if (!permitValid || !idValid) {
      shouldApprove = false;
      rejectionReason = 'Invalid or suspicious documents detected. ';
      if (!permitValid) rejectionReason += 'Business permit appears invalid. ';
      if (!idValid) rejectionReason += 'Valid ID appears invalid. ';
    } else if (!namesConsistent) {
      shouldApprove = false;
      rejectionReason = 'Name inconsistency detected between documents. ';
    } else if (overallConfidence < 70) {
      shouldApprove = false;
      rejectionReason = 'Low confidence score in document verification. ';
    } else {
      shouldApprove = true;
      rejectionReason = '';
    }
    
    return {
      'should_approve': shouldApprove,
      'confidence_score': overallConfidence,
      'rejection_reason': rejectionReason,
      'is_permit_expired': isPermitExpired,
      'is_id_expired': isIdExpired,
      'concerns': allConcerns,
      'ai_analysis': {
        'permit_analysis': permitAnalysis,
        'id_analysis': idAnalysis,
        'name_verification': nameMatchResult,
        'processed_at': now.toIso8601String(),
        'verification_id': 'GEMINI_${userId}_${now.millisecondsSinceEpoch}',
      },
      'recommendation': shouldApprove ? 'auto_approve' : 'reject',
      'manual_review_required': !shouldApprove && overallConfidence > 30,
    };
  }

  /// Store verification result in database
  Future<void> _storeVerificationResult({
    required String userId,
    required String businessName,
    required String permitUrl,
    required String idUrl,
    required String idType,
    required DateTime permitExpiryDate,
    required DateTime idExpiryDate,
    required String contactPerson,
    required Map<String, dynamic> verificationResult,
  }) async {
    try {
      final now = DateTime.now();
      final shouldApprove = verificationResult['should_approve'] == true;
      
      // Validate and normalize ID type
      final validIdType = _validateIdType(idType);
      
      // Store in talyer_owner_verifications table
      await SupabaseService.client
          .from('talyer_owner_verifications')
          .upsert({
            'user_id': userId,
            'business_name': businessName,
            'business_permit_url': permitUrl,
            'valid_id_url': idUrl,
            'id_type': validIdType,
            'permit_expiry_date': permitExpiryDate.toIso8601String().split('T')[0],
            'id_expiry_date': idExpiryDate.toIso8601String().split('T')[0],
            'status': shouldApprove ? 'approved' : 'rejected',
            'admin_notes': shouldApprove 
                ? 'AUTO-APPROVED by Gemini AI: ${verificationResult['confidence_score']}% confidence'
                : 'AUTO-REJECTED by Gemini AI: ${verificationResult['rejection_reason']}',
            // The AI acts as the reviewer for auto-decisions. Restore previous
            // behavior: set reviewed_by to the user's id so records show the
            // AI decision maker. Note: ensure user/profile exists to avoid FK errors.
            'reviewed_by': userId,
            'reviewed_at': now.toIso8601String(),
            'contact_person': contactPerson,
            'is_permit_expired': verificationResult['is_permit_expired'],
            'is_id_expired': verificationResult['is_id_expired'],
            'verification_score': verificationResult['confidence_score'],
            'tamper_flags': jsonEncode(verificationResult['concerns']),
            'created_at': now.toIso8601String(),
            'updated_at': now.toIso8601String(),
          }, onConflict: 'user_id');
      
      // Store detailed AI analysis in document_verifications table (if it exists)
      try {
        await SupabaseService.client
            .from('document_verifications')
            .insert([
              {
                'user_id': userId,
                'document_type': 'business_permit',
                'document_url': permitUrl,
                'verification_status': shouldApprove ? 'verified' : 'rejected',
                // AI verified the document; set verified_by to userId (was changed
                // earlier to NULL to avoid FK errors). Restoring original behavior.
                'verified_by': userId,
                'verified_at': now.toIso8601String(),
                'verification_notes': 'Gemini AI Analysis: ${jsonEncode(verificationResult['ai_analysis']['permit_analysis'])}',
                'document_metadata': jsonEncode(verificationResult['ai_analysis']['permit_analysis']),
                'created_at': now.toIso8601String(),
                'updated_at': now.toIso8601String(),
              },
              {
                'user_id': userId,
                'document_type': validIdType,
                'document_url': idUrl,
                'verification_status': shouldApprove ? 'verified' : 'rejected',
                'verified_by': userId,
                'verified_at': now.toIso8601String(),
                'verification_notes': 'Gemini AI Analysis: ${jsonEncode(verificationResult['ai_analysis']['id_analysis'])}',
                'document_metadata': jsonEncode(verificationResult['ai_analysis']['id_analysis']),
                'created_at': now.toIso8601String(),
                'updated_at': now.toIso8601String(),
              }
            ]);
      } catch (docVerificationError) {
        print('⚠️ Document verification table insert failed (table may not exist): $docVerificationError');
      }
      
      // Update user profile verification status (if profiles table exists)
      try {
        if (shouldApprove) {
          await SupabaseService.client
              .from('profiles')
              .update({
                'verification_status': 'verified',
                'updated_at': now.toIso8601String(),
              })
              .eq('user_id', userId);
        }
      } catch (profileUpdateError) {
        print('⚠️ Profile verification status update failed: $profileUpdateError');
      }
      
      print('✅ Verification result stored in database');
      
    } catch (e) {
      print('❌ Error storing verification result: $e');
      throw Exception('Failed to store verification result: $e');
    }
  }
  
  /// Validate and normalize ID type
  String _validateIdType(String idType) {
    const validTypes = [
      'drivers_license',
      'umid',
      'national_id',
      'passport',
      'philsys_id',
      'other'
    ];
    
    // Normalize the input
    final normalized = idType.toLowerCase().replaceAll(' ', '_').replaceAll('-', '_');
    
    if (validTypes.contains(normalized)) {
      return normalized;
    }
    
    // Map common variations
    if (normalized.contains('driver') || normalized.contains('license')) {
      return 'drivers_license';
    }
    if (normalized.contains('national') || normalized.contains('id')) {
      return 'national_id';
    }
    if (normalized.contains('passport')) {
      return 'passport';
    }
    if (normalized.contains('umid')) {
      return 'umid';
    }
    if (normalized.contains('philsys')) {
      return 'philsys_id';
    }
    
    // Default fallback
    return 'other';
  }

  /// Get mock verification result when API key is not configured
  Map<String, dynamic> _getMockVerificationResult({
    required String businessName,
    required String contactPerson,
    required DateTime permitExpiryDate,
    required DateTime idExpiryDate,
  }) {
    final now = DateTime.now();
    final isPermitExpired = permitExpiryDate.isBefore(now);
    final isIdExpired = idExpiryDate.isBefore(now);
    
    // Mock approval if documents are not expired and names are provided
    final shouldApprove = !isPermitExpired && !isIdExpired && 
                         businessName.isNotEmpty && contactPerson.isNotEmpty;
    
    return {
      'should_approve': shouldApprove,
      'confidence_score': shouldApprove ? 85 : 30,
      'rejection_reason': shouldApprove ? '' : 
          (isPermitExpired || isIdExpired ? 'Mock verification: Documents expired' : 'Mock verification: Insufficient information'),
      'is_permit_expired': isPermitExpired,
      'is_id_expired': isIdExpired,
      'concerns': [
        if (isPermitExpired) 'permit_expired',
        if (isIdExpired) 'id_expired',
        'mock_verification_used'
      ],
      'ai_analysis': {
        'permit_status': isPermitExpired ? 'expired' : 'valid',
        'id_status': isIdExpired ? 'expired' : 'valid',
        'name_match': 'mock_result',
        'verification_mode': 'mock_testing',
      },
      'recommendation': shouldApprove ? 'auto_approve' : 'reject',
      'manual_review_required': false,
    };
  }

  /// Get verification status for a user
  Future<Map<String, dynamic>?> getVerificationStatus(String userId) async {
    try {
      final response = await SupabaseService.client
          .from('talyer_owner_verifications')
          .select('*')
          .eq('user_id', userId)
          .maybeSingle();
      
      return response;
    } catch (e) {
      print('❌ Error getting verification status: $e');
      return null;
    }
  }
}










