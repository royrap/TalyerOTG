import 'dart:convert';
import 'package:http/http.dart' as http;

class GeminiIssueAnalysisService {
  static const String _apiKey = 'AIzaSyBN8VKuOYcmrdzJ5T3KpkxaCa-PNs3Wk8o';
  static const String _baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent';

  /// Analyze customer's issue description using Gemini AI
  /// Returns analysis with towing recommendation and severity assessment
  static Future<Map<String, dynamic>> analyzeIssueDescription(String description) async {
    try {
      print('🤖 Analyzing issue with Gemini AI: $description');

      final prompt = '''
You are an automotive expert AI assistant for a roadside assistance service. Analyze this customer's vehicle issue description and provide a structured assessment.

Customer Description: "$description"

Analyze and respond in this EXACT JSON format:
{
  "needs_towing": true/false,
  "severity": "minor/moderate/severe/critical",
  "primary_issue": "brief description of main problem",
  "recommended_services": ["service1", "service2"],
  "estimated_time": "time estimate in minutes",
  "safety_concerns": "any immediate safety issues or null",
  "can_drive": true/false,
  "explanation": "brief explanation of the assessment"
}

Guidelines:
- needs_towing = true if: engine won't start, transmission failure, severe accident damage, wheel/axle damage, complete electrical failure, major mechanical breakdown
- needs_towing = false if: flat tire only, minor battery issue (jumpstart possible), fuel issue, lockout, minor repairs
- severity: minor (simple fixes), moderate (standard repairs), severe (major issues), critical (immediate danger)
- can_drive: false if vehicle is immobile or unsafe to drive
- Keep all text concise and professional

Respond ONLY with the JSON, no additional text.
''';

      final requestBody = {
        'contents': [
          {
            'parts': [
              {'text': prompt}
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.3,
          'topK': 40,
          'topP': 0.95,
          'maxOutputTokens': 500,
        }
      };

      final url = Uri.parse('$_baseUrl?key=$_apiKey');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['candidates'] != null && data['candidates'].isNotEmpty) {
          final content = data['candidates'][0]['content']['parts'][0]['text'];
          print('📊 Gemini AI Response: $content');
          
          // Extract JSON from response (handle potential markdown wrapping)
          String jsonText = content.trim();
          if (jsonText.startsWith('```json')) {
            jsonText = jsonText.substring(7);
          }
          if (jsonText.startsWith('```')) {
            jsonText = jsonText.substring(3);
          }
          if (jsonText.endsWith('```')) {
            jsonText = jsonText.substring(0, jsonText.length - 3);
          }
          jsonText = jsonText.trim();
          
          final analysis = json.decode(jsonText);
          
          print('✅ Analysis complete: Towing needed: ${analysis['needs_towing']}, Severity: ${analysis['severity']}');
          
          return {
            'success': true,
            'needs_towing': analysis['needs_towing'] ?? false,
            'severity': analysis['severity'] ?? 'moderate',
            'primary_issue': analysis['primary_issue'] ?? 'Vehicle issue',
            'recommended_services': analysis['recommended_services'] ?? [],
            'estimated_time': analysis['estimated_time'] ?? 'Unknown',
            'safety_concerns': analysis['safety_concerns'],
            'can_drive': analysis['can_drive'] ?? true,
            'explanation': analysis['explanation'] ?? 'Issue analysis completed',
            'raw_response': content,
          };
        }
      }

      print('❌ Gemini API error: ${response.statusCode} - ${response.body}');
      return _getFallbackAnalysis(description);
      
    } catch (e) {
      print('❌ Error analyzing issue with Gemini AI: $e');
      return _getFallbackAnalysis(description);
    }
  }

  /// Fallback analysis using keyword matching if AI fails
  static Map<String, dynamic> _getFallbackAnalysis(String description) {
    final lowerDesc = description.toLowerCase();
    
    // Keywords that suggest towing is needed
    final towingKeywords = [
      'won\'t start',
      'can\'t start',
      'engine dead',
      'transmission',
      'accident',
      'crashed',
      'wheel broke',
      'axle',
      'can\'t move',
      'stuck',
      'major damage',
      'complete failure',
      'seized',
      'won\'t run',
    ];

    // Keywords for issues that don't need towing
    final noTowingKeywords = [
      'flat tire',
      'puncture',
      'dead battery',
      'locked out',
      'out of fuel',
      'keys locked',
      'battery jump',
    ];

    bool needsTowing = false;
    String severity = 'moderate';
    String primaryIssue = 'Vehicle assistance needed';
    bool canDrive = true;

    // Check for towing keywords
    for (final keyword in towingKeywords) {
      if (lowerDesc.contains(keyword)) {
        needsTowing = true;
        severity = 'severe';
        canDrive = false;
        primaryIssue = 'Vehicle requires towing';
        break;
      }
    }

    // Check for non-towing keywords
    if (!needsTowing) {
      for (final keyword in noTowingKeywords) {
        if (lowerDesc.contains(keyword)) {
          needsTowing = false;
          severity = 'minor';
          canDrive = true;
          primaryIssue = 'Roadside assistance available';
          break;
        }
      }
    }

    return {
      'success': true,
      'needs_towing': needsTowing,
      'severity': severity,
      'primary_issue': primaryIssue,
      'recommended_services': needsTowing 
          ? ['Towing Service', 'Diagnostic Check']
          : ['Roadside Assistance'],
      'estimated_time': needsTowing ? '45-60 minutes' : '20-30 minutes',
      'safety_concerns': canDrive ? null : 'Vehicle may not be safe to drive',
      'can_drive': canDrive,
      'explanation': 'Analysis based on keyword detection (AI unavailable)',
      'fallback': true,
    };
  }

  /// Quick check if description suggests towing is needed
  static Future<bool> quickCheckNeedsTowing(String description) async {
    if (description.trim().isEmpty) return false;
    
    final analysis = await analyzeIssueDescription(description);
    return analysis['needs_towing'] == true;
  }

  /// Get severity level from description
  static Future<String> getSeverityLevel(String description) async {
    if (description.trim().isEmpty) return 'minor';
    
    final analysis = await analyzeIssueDescription(description);
    return analysis['severity'] ?? 'moderate';
  }

  /// Get recommended services based on description
  static Future<List<String>> getRecommendedServices(String description) async {
    if (description.trim().isEmpty) return [];
    
    final analysis = await analyzeIssueDescription(description);
    return List<String>.from(analysis['recommended_services'] ?? []);
  }
}
