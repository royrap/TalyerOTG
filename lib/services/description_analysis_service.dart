import 'dart:math' as math;

class DescriptionAnalysisService {
  // AI-powered analysis patterns for severe issues
  static const Map<String, List<String>> _aiAnalysisPatterns = {
    'critical_engine_failure': [
      'engine failure', 'engine died', 'engine wont start', 'engine not starting',
      'engine completely dead', 'engine seized', 'engine smoking', 'engine overheated',
      'engine blown', 'engine knocking', 'engine rattling', 'engine grinding'
    ],
    'starting_system_failure': [
      'wont start', 'will not start', 'cannot start', 'cant start', 
      'doesnt start', 'not starting', 'dead car', 'car died', 
      'car wont turn on', 'car completely dead', 'no power', 'nothing happens',
      'no response', 'key turns but nothing', 'dashboard lights dead'
    ],
    'mobility_issues': [
      'car broke down', 'broke down', 'breakdown', 'stranded', 'stuck',
      'immobilized', 'inoperable', 'cannot drive', 'cant drive', 'unsafe to drive'
    ],
    'transmission_critical': [
      'transmission failure', 'transmission died', 'transmission problems',
      'gear box failure', 'cant shift', 'transmission fluid leak',
      'slipping gears', 'stuck in gear', 'no reverse', 'no forward'
    ],
    'severe_mechanical': [
      'major mechanical',
      'complete failure',
      'total breakdown',
      'catastrophic failure',
      'car is dead',
      'vehicle inoperable',
      'not drivable',
      'cannot drive',
      'cant drive',
      'unsafe to drive',
      'electrical failure',
      'complete electrical',
      'no electrical power',
      'electrical system dead',
      'coolant leak',
      'radiator burst',
      'overheating severely',
      'steam from engine',
      'fuel pump failure',
      'fuel system failure',
      'no fuel pressure',
      'brake failure',
      'no brakes',
      'brake system failure',
      'brake fluid leak',
      'suspension failure',
      'broken axle',
      'wheel fell off',
      'accident',
      'collision',
      'crashed',
      'hit something',
      'damage from accident',
    ]
  };

  // Keywords that indicate minor issues that can be repaired roadside
  static const List<String> _minorIssueKeywords = [
    'flat tire',
    'tire puncture',
    'battery dead',
    'battery low',
    'jump start',
    'jumpstart',
    'keys locked',
    'locked out',
    'lockout',
    'fuel empty',
    'out of gas',
    'ran out of fuel',
    'minor oil leak',
    'windshield wiper',
    'headlight out',
    'taillight out',
    'fuse blown',
    'minor electrical',
    'radio not working',
    'air conditioning',
    'heater not working',
    'window stuck',
    'door handle',
    'minor noise',
    'squeaking',
    'rattling',
    'vibration',
    'alignment',
    'tire rotation',
    'oil change',
    'fluid top up',
    'belt adjustment',
    'hose loose',
    'minor tune up',
  ];

  /// Advanced AI-powered analysis of problem description
  static SeverityAnalysisResult analyzeDescription(String description) {
    if (description.trim().isEmpty) {
      return SeverityAnalysisResult(
        isSevere: false,
        confidence: 0.0,
        detectedKeywords: [],
        reasoning: 'No description provided',
      );
    }

    final lowercaseDescription = description.toLowerCase();
    
    // AI-powered pattern matching across categories
    final List<String> severeMatches = [];
    final Map<String, int> categoryMatches = ;
    
    // Analyze each severity category
    for (final category in _aiAnalysisPatterns.entries) {
      int matches = 0;
      for (final pattern in category.value) {
        if (lowercaseDescription.contains(pattern.toLowerCase())) {
          severeMatches.add(pattern);
          matches++;
        }
      }
      if (matches > 0) {
        categoryMatches[category.key] = matches;
      }
    }

    // Check for minor issue keywords
    final List<String> minorMatches = [];
    for (final keyword in _minorIssueKeywords) {
      if (lowercaseDescription.contains(keyword.toLowerCase())) {
        minorMatches.add(keyword);
      }
    }

    // AI decision logic with confidence scoring
    double confidence = 0.0;
    bool isSevere = false;
    String reasoning = '';

    if (severeMatches.isNotEmpty && minorMatches.isEmpty) {
      // Only severe patterns detected
      isSevere = true;
      confidence = math.min(0.95, 0.7 + (severeMatches.length * 0.05));
      
      // Determine primary category
      String primaryCategory = _getPrimaryCategory(categoryMatches);
      reasoning = '🤖 AI Analysis: ${_getCategoryDescription(primaryCategory)} detected. Patterns: ${severeMatches.take(3).join(', ')}';
      
    } else if (severeMatches.isNotEmpty && minorMatches.isNotEmpty) {
      // Mixed indicators - AI weighs the evidence
      double severityScore = severeMatches.length * 2.0;
      double minorScore = minorMatches.length * 1.0;
      
      if (severityScore >= minorScore) {
        isSevere = true;
        confidence = 0.75 - (minorScore / (severityScore + minorScore)) * 0.25;
        reasoning = '🤖 AI Analysis: Mixed indicators detected, but severe patterns predominant. Primary concerns: ${severeMatches.take(2).join(', ')}';
      } else {
        isSevere = false;
        confidence = 0.65 + (minorScore / (severityScore + minorScore)) * 0.15;
        reasoning = '🤖 AI Analysis: Mixed indicators, but minor issues appear more prominent. Roadside repair likely possible.';
      }
      
    } else if (minorMatches.isNotEmpty) {
      // Only minor patterns detected
      isSevere = false;
      confidence = math.min(0.9, 0.6 + (minorMatches.length * 0.1));
      reasoning = '🤖 AI Analysis: Minor issue patterns detected. Roadside repair recommended. Issues: ${minorMatches.take(3).join(', ')}';
      
    } else {
      // No specific patterns - use contextual AI analysis
      confidence = 0.4;
      
      // Contextual sentiment analysis
      final urgencyWords = ['emergency', 'urgent', 'critical', 'serious', 'immediate', 'asap'];
      final negativeWords = ['terrible', 'awful', 'horrible', 'disaster', 'nightmare', 'bad', 'worst'];
      final positiveWords = ['minor', 'small', 'little', 'quick', 'simple', 'easy'];
      
      final urgencyMatches = urgencyWords.where((word) => lowercaseDescription.contains(word)).toList();
      final negativeMatches = negativeWords.where((word) => lowercaseDescription.contains(word)).toList();
      final positiveMatches = positiveWords.where((word) => lowercaseDescription.contains(word)).toList();
      
      if (urgencyMatches.isNotEmpty || negativeMatches.length > positiveMatches.length) {
        isSevere = true;
        confidence = 0.5;
        reasoning = '🤖 AI Analysis: Contextual severity indicators detected. Urgency/negative sentiment suggests serious issue.';
      } else {
        isSevere = false;
        confidence = 0.3;
        reasoning = '🤖 AI Analysis: No specific severity indicators found. Assuming manageable issue for roadside assistance.';
      }
    }

    return SeverityAnalysisResult(
      isSevere: isSevere,
      confidence: confidence,
      detectedKeywords: [...severeMatches, ...minorMatches],
      reasoning: reasoning,
    );
  }

  /// Determine primary category from matches
  static String _getPrimaryCategory(Map<String, int> categoryMatches) {
    if (categoryMatches.isEmpty) return 'general';
    
    return categoryMatches.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }

  /// Get user-friendly description for category
  static String _getCategoryDescription(String category) {
    switch (category) {
      case 'critical_engine_failure':
        return 'Critical engine failure';
      case 'starting_system_failure':
        return 'Starting system failure';
      case 'mobility_issues':
        return 'Vehicle mobility issues';
      case 'transmission_critical':
        return 'Transmission problems';
      case 'severe_mechanical':
        return 'Severe mechanical issues';
      default:
        return 'Severe automotive issue';
    }
  }

  /// Gets a user-friendly explanation of why the issue was classified as severe
  static String getSeverityExplanation(SeverityAnalysisResult result) {
    if (result.isSevere) {
      return '🤖 AI Assessment: This appears to be a severe issue requiring professional intervention. '
             'The analysis detected patterns indicating potential engine failure, starting problems, or major mechanical failures. '
             'These typically require specialized tools and expertise that may not be available through standard roadside assistance. '
             'Confidence: ${(result.confidence * 100).toStringAsFixed(1)}%';
    } else {
      return '🤖 AI Assessment: This appears to be an issue that can potentially be repaired roadside. '
             'Our mechanics carry tools and parts for common repairs like battery issues, tire problems, and minor mechanical adjustments. '
             'Confidence: ${(result.confidence * 100).toStringAsFixed(1)}%';
    }
  }
}

/// Result of analyzing a problem description
class SeverityAnalysisResult {
  final bool isSevere;
  final double confidence; // 0.0 to 1.0
  final List<String> detectedKeywords;
  final String reasoning;

  SeverityAnalysisResult({
    required this.isSevere,
    required this.confidence,
    required this.detectedKeywords,
    required this.reasoning,
  });

  @override
  String toString() {
    return 'SeverityAnalysisResult{isSevere: $isSevere, confidence: $confidence, keywords: $detectedKeywords, reasoning: $reasoning}';
  }
}










