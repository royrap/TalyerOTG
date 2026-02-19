import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/supabase_service.dart';
import '../config/gemini_config.dart';

class BusinessPermitExtractionService {
  static final BusinessPermitExtractionService instance = BusinessPermitExtractionService._internal();
  BusinessPermitExtractionService._internal();

  static String get GEMINI_API_KEY => GeminiConfig.GEMINI_API_KEY;
  static const String GEMINI_API_URL = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent';

  /// Extract business permit data and save to database
  Future<Map<String, dynamic>> extractAndSaveBusinessPermit({
    required String providerId,
    required String businessPermitUrl,
  }) async {
    try {
      print('📄 Starting business permit extraction for provider: $providerId');
      
      // Check if Gemini API is configured
      if (!GeminiConfig.isConfigured) {
        print('⚠️ Gemini API key not configured, using mock data...');
        return _getMockExtractionResult(providerId, businessPermitUrl);
      }

      // Download and convert business permit to base64
      final businessPermitBase64 = await _downloadAndConvertToBase64(businessPermitUrl);
      
      // Extract business permit data using Gemini AI
      final extractionResult = await _extractBusinessPermitData(businessPermitBase64);
      
      if (extractionResult['success'] == true) {
        // Save extracted data to business_permits table
        final savedData = await _saveBusinessPermitData(
          providerId: providerId,
          permitDocumentUrl: businessPermitUrl,
          extractedData: extractionResult['data'],
          confidenceScore: extractionResult['confidence'] ?? 0.0,
        );
        
        return {
          'success': true,
          'permit_id': savedData['id'],
          'extracted_data': extractionResult['data'],
          'confidence_score': extractionResult['confidence'],
          'message': 'Business permit data extracted and saved successfully'
        };
      } else {
        return {
          'success': false,
          'error': extractionResult['error'] ?? 'Failed to extract business permit data',
          'message': 'Could not extract data from business permit'
        };
      }
    } catch (e) {
      print('❌ Error in business permit extraction: $e');
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Error processing business permit'
      };
    }
  }

  /// Extract business permit data using Gemini AI based on your Next.js code
  Future<Map<String, dynamic>> _extractBusinessPermitData(String imageBase64) async {
    final prompt = '''
You are an expert document scanner specialized in Philippine business permits. Extract the following exact fields from this business permit image/PDF.

EXTRACTION REQUIREMENTS:
Return ONLY a valid JSON object with these exact keys:
- "business_permit": The permit title (e.g., "MAYOR'S PERMIT", "BUSINESS PERMIT")
- "registered_trade_name": The registered business/trade name (THIS IS THE MAIN BUSINESS NAME - clean text, no headers)
- "owners_address": The owner's complete residential address
- "nature_of_business": The type/nature of business (e.g., "VETERINARY CLINIC", "GENERAL MERCHANDISE")
- "business_address": The business establishment address
- "receipt_no": Official receipt or OR number (digits/alphanumeric only)
- "issued_on": Date when permit was issued (keep original format)
- "issued_at": Place of issuance (e.g., "City of Manila", "Municipality of Quezon")

EXTRACTION GUIDELINES:
1. For business_permit: Look for document title at top (MAYOR'S PERMIT, BUSINESS PERMIT, etc.)
2. For registered_trade_name: This is the MOST IMPORTANT field - find the actual registered business/trade name that appears after headers like "REGISTERED TRADE NAME:", "BUSINESS NAME:", or "NAME OF BUSINESS:". Extract ONLY the business name, remove all headers/labels.
3. For owners_address: Find complete residential address of permit holder
4. For nature_of_business: Extract business type/activity, remove amounts/fees
5. For business_address: Find where business operates, different from owner's address
6. For receipt_no: Extract only the receipt number, no "OR No:" prefix
7. For issued_on: Find issue date, keep original format
8. For issued_at: Find issuing location/office

QUALITY STANDARDS:
- PRIORITY: registered_trade_name is the most critical field - this should be the main business name from the permit
- If field cannot be found confidently, use empty string ""
- Remove field labels/headers from extracted values (e.g., remove "REGISTERED TRADE NAME:" and keep only the business name)
- Clean up OCR artifacts but preserve original text structure
- For addresses: include complete information (street, barangay, city)
- For business names: extract the official registered trade name, avoid personal names unless they are the registered trade name
- Be precise - only extract what you can clearly see in the document

Return ONLY the JSON object, no additional text or formatting.
''';

    try {
      final response = await _callGeminiAPI(imageBase64, prompt);
      
      if (response['success'] == true) {
        final rawData = response['data'];
        
        // Normalize keys to match database schema
        final normalizedData = {
          'business_permit_name': rawData['registered_trade_name'] ?? rawData['business_permit'] ?? '',
          'registered_address': rawData['owners_address'] ?? '',
          'nature_of_business': rawData['nature_of_business'] ?? '',
          'business_address': rawData['business_address'] ?? '',
          'receipt_no': rawData['receipt_no'] ?? '',
          'issued_on': rawData['issued_on'] ?? '',
          'issued_at': rawData['issued_at'] ?? ''
        };
        
        // Calculate confidence score
        final confidence = _calculateConfidence(normalizedData);
        
        return {
          'success': true,
          'data': normalizedData,
          'confidence': confidence,
          'raw_gemini_data': rawData
        };
      } else {
        return {
          'success': false,
          'error': response['error'] ?? 'Failed to extract data'
        };
      }
    } catch (e) {
      print('❌ Error calling Gemini API: $e');
      return {
        'success': false,
        'error': 'AI extraction service error: $e'
      };
    }
  }

  /// Call Gemini AI API
  Future<Map<String, dynamic>> _callGeminiAPI(String imageBase64, String prompt) async {
    try {
      final requestBody = {
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
        }]
      };

      final response = await http.post(
        Uri.parse('$GEMINI_API_URL?key=$GEMINI_API_KEY'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final text = responseData['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? '';
        
        print('🤖 Gemini AI Response: $text');
        
        // Extract JSON from response
        final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(text);
        if (jsonMatch != null) {
          try {
            final extractedData = jsonDecode(jsonMatch.group(0)!);
            return {
              'success': true,
              'data': extractedData,
              'raw_response': text
            };
          } catch (e) {
            print('❌ Error parsing JSON: $e');
            return {
              'success': false,
              'error': 'Invalid JSON response from AI',
              'raw_response': text
            };
          }
        } else {
          return {
            'success': false,
            'error': 'No JSON found in AI response',
            'raw_response': text
          };
        }
      } else {
        throw Exception('Gemini API error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('❌ Gemini API call failed: $e');
      return {
        'success': false,
        'error': 'API call failed: $e'
      };
    }
  }

  /// Save business permit data to database
  Future<Map<String, dynamic>> _saveBusinessPermitData({
    required String providerId,
    required String permitDocumentUrl,
    required Map<String, dynamic> extractedData,
    required double confidenceScore,
  }) async {
    try {
      print('💾 Saving business permit data to database...');
      
      final permitData = {
        'provider_id': providerId,
        'business_permit_name': extractedData['business_permit_name'] ?? '',
        'registered_address': extractedData['registered_address'] ?? '',
        'nature_of_business': extractedData['nature_of_business'] ?? '',
        'business_address': extractedData['business_address'] ?? '',
        'receipt_no': extractedData['receipt_no'] ?? '',
        'issued_on': extractedData['issued_on'] ?? '',
        'issued_at': extractedData['issued_at'] ?? '',
        'permit_document_url': permitDocumentUrl,
        'extraction_confidence_score': confidenceScore,
        'is_verified': confidenceScore >= 70.0, // Auto-verify if confidence is high
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      final result = await SupabaseService.client
          .from('business_permits')
          .insert(permitData)
          .select()
          .single();

      print('✅ Business permit data saved successfully with ID: ${result['id']}');
      return result;
    } catch (e) {
      print('❌ Error saving business permit data: $e');
      throw Exception('Failed to save business permit data: $e');
    }
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

  /// Calculate extraction confidence based on filled fields (same logic as your Next.js code)
  double _calculateConfidence(Map<String, dynamic> data) {
    final weights = {
      'business_permit_name': 25,
      'registered_address': 15,
      'nature_of_business': 20,
      'business_address': 15,
      'receipt_no': 10,
      'issued_on': 10,
      'issued_at': 5
    };
    
    double score = 0;
    weights.forEach((key, weight) {
      final value = data[key]?.toString() ?? '';
      if (value.trim().length > 2) {
        score += weight;
      }
    });
    
    return score;
  }

  /// Mock extraction result for testing when Gemini API is not configured
  Map<String, dynamic> _getMockExtractionResult(String providerId, String permitUrl) {
    print('🧪 Using mock business permit extraction data...');
    
    return {
      'success': true,
      'permit_id': 'mock-permit-id',
      'extracted_data': {
        'business_permit_name': 'Sample Auto Repair Shop',
        'registered_address': '123 Sample Street, Barangay Sample, Sample City',
        'nature_of_business': 'AUTOMOTIVE REPAIR SERVICES',
        'business_address': '456 Business Avenue, Sample City',
        'receipt_no': 'OR2024001234',
        'issued_on': '2024-01-15',
        'issued_at': 'City of Sample'
      },
      'confidence_score': 85.0,
      'message': 'Mock business permit data extracted successfully'
    };
  }

  /// Get business permit data by provider ID
  Future<Map<String, dynamic>?> getBusinessPermitByProviderId(String providerId) async {
    try {
      final result = await SupabaseService.client
          .from('business_permits')
          .select()
          .eq('provider_id', providerId)
          .maybeSingle();

      return result;
    } catch (e) {
      print('❌ Error fetching business permit: $e');
      return null;
    }
  }

  /// Update business permit verification status
  Future<bool> updateVerificationStatus({
    required String permitId,
    required bool isVerified,
    String? verificationNotes,
    String? verifiedBy,
  }) async {
    try {
      await SupabaseService.client
          .from('business_permits')
          .update({
            'is_verified': isVerified,
            'verification_notes': verificationNotes,
            'verified_by': verifiedBy,
            'verified_at': isVerified ? DateTime.now().toIso8601String() : null,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', permitId);

      return true;
    } catch (e) {
      print('❌ Error updating verification status: $e');
      return false;
    }
  }
}










