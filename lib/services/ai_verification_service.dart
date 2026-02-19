import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'supabase_service.dart';

class AIVerificationService {
  static const String _openAiApiKey = 'YOUR_OPENAI_API_KEY'; // Replace with your actual API key
  static const String _baseUrl = 'https://api.openai.com/v1/chat/completions';
  
  static AIVerificationService? _instance;
  static AIVerificationService get instance => _instance ??= AIVerificationService._();
  
  AIVerificationService._();

  /// Main method to verify Talyer Owner documents
  Future<Map<String, dynamic>> verifyTalyerOwnerDocuments({
    required String userId,
    required String businessPermitUrl,
    required String validIdUrl,
    required String businessName,
    required String contactPerson,
  }) async {
    try {
      print('🤖 Starting AI verification for user: $userId');
      
      // Step 1: Download and analyze the documents
      final permitAnalysis = await _analyzeBusinessPermit(businessPermitUrl);
      final idAnalysis = await _analyzeValidId(validIdUrl);
      
      // Step 2: Extract names from both documents
      final String permitName = permitAnalysis['extracted_name'] ?? '';
      final String idName = idAnalysis['extracted_name'] ?? '';
      
      // Step 3: Compare names and validate documents
      final verification = await _compareAndValidateNames(
        permitName: permitName,
        idName: idName,
        providedBusinessName: businessName,
        providedContactPerson: contactPerson,
        permitAnalysis: permitAnalysis,
        idAnalysis: idAnalysis,
      );
      
      // Step 4: Update verification status in database
      if (verification['should_approve'] == true) {
        await _approveVerification(userId, verification);
      } else {
        await _rejectVerification(userId, verification);
      }
      
      return verification;
      
    } catch (e) {
      print('❌ AI Verification Error: $e');
      return {
        'success': false,
        'error': e.toString(),
        'should_approve': false,
        'confidence_score': 0,
      };
    }
  }

  /// Analyze business permit using AI
  Future<Map<String, dynamic>> _analyzeBusinessPermit(String imageUrl) async {
    try {
      print('📄 Analyzing business permit...');
      
      final imageData = await _downloadImage(imageUrl);
      final base64Image = base64Encode(imageData);
      
      final prompt = '''
      Analyze this business permit image and extract the following information:
      1. Business name (exact text as it appears)
      2. Owner/Contact person name
      3. Permit validity (is it expired?)
      4. Document authenticity indicators
      5. Any suspicious elements or tampering signs
      
      Return a JSON response with:
      {
        "extracted_name": "business owner name",
        "business_name": "business name",
        "is_valid": boolean,
        "is_expired": boolean,
        "confidence_score": 0-100,
        "authenticity_score": 0-100,
        "tamper_flags": ["list of concerns"],
        "expiry_date": "date if found"
      }
      ''';
      
      final response = await _callOpenAIVision(prompt, base64Image);
      return _parseAIResponse(response);
      
    } catch (e) {
      print('❌ Error analyzing business permit: $e');
      return {
        'extracted_name': '',
        'is_valid': false,
        'confidence_score': 0,
        'error': e.toString(),
      };
    }
  }

  /// Analyze valid ID using AI
  Future<Map<String, dynamic>> _analyzeValidId(String imageUrl) async {
    try {
      print('🆔 Analyzing valid ID...');
      
      final imageData = await _downloadImage(imageUrl);
      final base64Image = base64Encode(imageData);
      
      final prompt = '''
      Analyze this Philippine ID document and extract the following information:
      1. Full name (exactly as it appears)
      2. ID type (Driver's License, UMID, National ID, etc.)
      3. ID validity (is it expired?)
      4. Document authenticity indicators
      5. Any suspicious elements or tampering signs
      
      Return a JSON response with:
      {
        "extracted_name": "full name from ID",
        "id_type": "type of ID",
        "is_valid": boolean,
        "is_expired": boolean,
        "confidence_score": 0-100,
        "authenticity_score": 0-100,
        "tamper_flags": ["list of concerns"],
        "expiry_date": "date if found"
      }
      ''';
      
      final response = await _callOpenAIVision(prompt, base64Image);
      return _parseAIResponse(response);
      
    } catch (e) {
      print('❌ Error analyzing valid ID: $e');
      return {
        'extracted_name': '',
        'is_valid': false,
        'confidence_score': 0,
        'error': e.toString(),
      };
    }
  }

  /// Compare names and validate documents
  Future<Map<String, dynamic>> _compareAndValidateNames({
    required String permitName,
    required String idName,
    required String providedBusinessName,
    required String providedContactPerson,
    required Map<String, dynamic> permitAnalysis,
    required Map<String, dynamic> idAnalysis,
  }) async {
    try {
      print('🔍 Comparing names and validating documents...');
      
      final prompt = '''
      Compare and validate these document names:
      
      Business Permit Name: "$permitName"
      Valid ID Name: "$idName"
      Provided Business Name: "$providedBusinessName"
      Provided Contact Person: "$providedContactPerson"
      
      Permit Analysis: ${json.encode(permitAnalysis)}
      ID Analysis: ${json.encode(idAnalysis)}
      
      Determine if:
      1. The names match (considering variations, nicknames, middle names)
      2. The documents are authentic
      3. The verification should be approved
      
      Consider these factors:
      - Name similarity score (85%+ match is good)
      - Document authenticity scores
      - Expiry status
      - Tamper detection flags
      - Overall confidence
      
      Return JSON:
      {
        "names_match": boolean,
        "name_similarity_score": 0-100,
        "should_approve": boolean,
        "confidence_score": 0-100,
        "verification_score": 0-100,
        "approval_reason": "explanation",
        "concerns": ["list of any concerns"],
        "recommendation": "approve/reject/manual_review"
      }
      ''';
      
      final response = await _callOpenAI(prompt);
      return _parseAIResponse(response);
      
    } catch (e) {
      print('❌ Error in name comparison: $e');
      return {
        'names_match': false,
        'should_approve': false,
        'confidence_score': 0,
        'error': e.toString(),
      };
    }
  }

  /// Call OpenAI API for text analysis
  Future<String> _callOpenAI(String prompt) async {
    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_openAiApiKey',
      },
      body: json.encode({
        'model': 'gpt-4',
        'messages': [
          {
            'role': 'system',
            'content': 'You are an expert document verification AI. Analyze documents carefully and provide accurate JSON responses.',
          },
          {
            'role': 'user',
            'content': prompt,
          },
        ],
        'max_tokens': 1000,
        'temperature': 0.1,
      }),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['choices'][0]['message']['content'];
    } else {
      throw Exception('OpenAI API Error: ${response.statusCode} - ${response.body}');
    }
  }

  /// Call OpenAI Vision API for image analysis
  Future<String> _callOpenAIVision(String prompt, String base64Image) async {
    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_openAiApiKey',
      },
      body: json.encode({
        'model': 'gpt-4-vision-preview',
        'messages': [
          {
            'role': 'system',
            'content': 'You are an expert document verification AI specialized in analyzing Philippine business permits and identification documents.',
          },
          {
            'role': 'user',
            'content': [
              {
                'type': 'text',
                'text': prompt,
              },
              {
                'type': 'image_url',
                'image_url': {
                  'url': 'data:image/jpeg;base64,$base64Image',
                },
              },
            ],
          },
        ],
        'max_tokens': 1000,
        'temperature': 0.1,
      }),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['choices'][0]['message']['content'];
    } else {
      throw Exception('OpenAI Vision API Error: ${response.statusCode} - ${response.body}');
    }
  }

  /// Download image from URL
  Future<Uint8List> _downloadImage(String url) async {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      return response.bodyBytes;
    } else {
      throw Exception('Failed to download image: ${response.statusCode}');
    }
  }

  /// Parse AI response JSON
  Map<String, dynamic> _parseAIResponse(String response) {
    try {
      // Extract JSON from response (AI might include extra text)
      final jsonStart = response.indexOf('{');
      final jsonEnd = response.lastIndexOf('}') + 1;
      
      if (jsonStart >= 0 && jsonEnd > jsonStart) {
        final jsonString = response.substring(jsonStart, jsonEnd);
        return json.decode(jsonString);
      } else {
        throw Exception('No valid JSON found in AI response');
      }
    } catch (e) {
      print('❌ Error parsing AI response: $e');
      return {
        'success': false,
        'error': 'Failed to parse AI response: $e',
      };
    }
  }

  /// Approve verification in database
  Future<void> _approveVerification(String userId, Map<String, dynamic> verification) async {
    try {
      final updateData = {
        'status': 'approved',
        'verification_score': verification['verification_score'] ?? 0,
        'admin_notes': 'Auto-approved by AI: ${verification['approval_reason'] ?? 'Names match'}',
        'reviewed_at': DateTime.now().toIso8601String(),
        'tamper_flags': json.encode(verification['concerns'] ?? []),
        'updated_at': DateTime.now().toIso8601String(),
      };

      await SupabaseService.client
          .from('talyer_owner_verifications')
          .update(updateData)
          .eq('user_id', userId);

      // Also update user type to talyer_owner
      await SupabaseService.client
          .from('user_profiles')
          .update({'user_type': 'talyer_owner'})
          .eq('user_id', userId);

      print('✅ Verification approved for user: $userId');
      
    } catch (e) {
      print('❌ Error approving verification: $e');
      throw e;
    }
  }

  /// Reject verification in database
  Future<void> _rejectVerification(String userId, Map<String, dynamic> verification) async {
    try {
      final updateData = {
        'status': 'rejected',
        'verification_score': verification['verification_score'] ?? 0,
        'admin_notes': 'Auto-rejected by AI: ${verification['concerns']?.join(', ') ?? 'Names do not match'}',
        'reviewed_at': DateTime.now().toIso8601String(),
        'tamper_flags': json.encode(verification['concerns'] ?? []),
        'updated_at': DateTime.now().toIso8601String(),
      };

      await SupabaseService.client
          .from('talyer_owner_verifications')
          .update(updateData)
          .eq('user_id', userId);

      print('❌ Verification rejected for user: $userId');
      
    } catch (e) {
      print('❌ Error rejecting verification: $e');
      throw e;
    }
  }

  /// Process pending verifications (can be called periodically)
  Future<void> processPendingVerifications() async {
    try {
      print('🔄 Processing pending verifications...');
      
      final pendingVerifications = await SupabaseService.client
          .from('talyer_owner_verifications')
          .select()
          .eq('status', 'pending')
          .order('created_at', ascending: true);

      for (final verification in pendingVerifications) {
        try {
          await verifyTalyerOwnerDocuments(
            userId: verification['user_id'],
            businessPermitUrl: verification['business_permit_url'],
            validIdUrl: verification['valid_id_url'],
            businessName: verification['business_name'],
            contactPerson: verification['contact_person'],
          );
          
          // Add delay to avoid rate limiting
          await Future.delayed(const Duration(seconds: 2));
          
        } catch (e) {
          print('❌ Error processing verification for user ${verification['user_id']}: $e');
          continue;
        }
      }
      
      print('✅ Finished processing pending verifications');
      
    } catch (e) {
      print('❌ Error in processPendingVerifications: $e');
    }
  }

  /// Manual verification for specific users (for the two emails you mentioned)
  Future<Map<String, dynamic>> manuallyApproveUsers({
    required List<String> emails,
  }) async {
    try {
      print('👤 Manually approving users: $emails');
      
      final results = <String, dynamic>{};
      
      for (final email in emails) {
        try {
          // Get user by email
          final userQuery = await SupabaseService.client
              .from('user_profiles')
              .select('user_id, email')
              .eq('email', email)
              .single();
          
          if (userQuery.isEmpty) {
            results[email] = {'success': false, 'error': 'User not found'};
            continue;
          }
          
          final userId = userQuery['user_id'];
          
          // Check if verification exists
          final verificationQuery = await SupabaseService.client
              .from('talyer_owner_verifications')
              .select()
              .eq('user_id', userId);
          
          if (verificationQuery.isEmpty) {
            results[email] = {'success': false, 'error': 'No verification found'};
            continue;
          }
          
          // Approve the verification
          await SupabaseService.client
              .from('talyer_owner_verifications')
              .update({
                'status': 'approved',
                'verification_score': 100,
                'admin_notes': 'Manually approved by admin',
                'reviewed_at': DateTime.now().toIso8601String(),
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('user_id', userId);
          
          // Update user type
          await SupabaseService.client
              .from('user_profiles')
              .update({'user_type': 'talyer_owner'})
              .eq('user_id', userId);
          
          results[email] = {'success': true, 'message': 'Successfully approved'};
          print('✅ Approved user: $email');
          
        } catch (e) {
          results[email] = {'success': false, 'error': e.toString()};
          print('❌ Error approving user $email: $e');
        }
      }
      
      return {
        'success': true,
        'results': results,
      };
      
    } catch (e) {
      print('❌ Error in manual approval: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
}
