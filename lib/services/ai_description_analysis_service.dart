import 'dart:math' as math;

class AIDescriptionAnalysisService {
  // AI-powered analysis patterns for issue severity detection
  static const Map<String, List<String>> _severityPatterns = {
    'critical_engine_failure': [
      'engine failure', 'engine died', 'engine wont start', 'engine not starting',
      'engine completely dead', 'engine seized', 'engine smoking', 'engine overheated',
      'engine blown', 'engine knocking', 'engine rattling', 'engine grinding',
      'engine fire', 'engine exploded', 'engine making loud noise'
    ],
    'starting_system_failure': [
      'wont start', 'will not start', 'cannot start', 'cant start', 
      'doesnt start', 'not starting', 'dead car', 'car died', 
      'car wont turn on', 'car completely dead', 'no power', 'nothing happens',
      'no response', 'key turns but nothing', 'dashboard lights dead', 'battery dead'
    ],
    'mobility_issues': [
      'need towing', 'needs towing', 'tow truck', 'towing service',
      'car broke down', 'broke down', 'breakdown', 'stranded', 'stuck',
      'immobilized', 'inoperable', 'cannot drive', 'cant drive', 'unsafe to drive',
      'car stopped working', 'vehicle disabled', 'completely broken'
    ],
    'transmission_critical': [
      'transmission failure', 'transmission died', 'transmission problems',
      'gear box failure', 'cant shift', 'transmission fluid leak',
      'slipping gears', 'stuck in gear', 'no reverse', 'no forward',
      'transmission making noise', 'gears grinding'
    ],
    'severe_mechanical': [
      'brake failure', 'brakes not working', 'steering failure', 'steering locked',
      'suspension collapsed', 'axle broken', 'wheel fell off', 'tire blew out',
      'coolant leak', 'oil leak', 'radiator burst', 'alternator died',
      'major mechanical failure', 'catastrophic failure'
    ],
    'electrical_critical': [
      'electrical fire', 'sparks flying', 'burning smell electrical', 'smoke from wires',
      'complete electrical failure', 'all lights dead', 'ignition system failed',
      'starter motor dead', 'alternator failed', 'battery exploded'
    ],
    'safety_hazards': [
      'smoke', 'fire', 'burning', 'sparks', 'explosion', 'gas leak',
      'fuel leak', 'dangerous', 'unsafe', 'hazardous', 'emergency',
      'accident', 'collision', 'crash', 'hit something'
    ]
  };

  // Minor issues that can typically be handled roadside
  static const Map<String, List<String>> _minorIssuePatterns = {
    'battery_issues': [
      'battery low', 'battery weak', 'need jump start', 'jump needed',
      'lights dim', 'slow cranking', 'battery old', 'terminals corroded'
    ],
    'tire_issues': [
      'flat tire', 'tire pressure low', 'tire puncture', 'nail in tire',
      'tire repair', 'spare tire', 'tire change', 'tire inflated'
    ],
    'minor_electrical': [
      'headlight out', 'taillight out', 'fuse blown', 'radio not working',
      'air conditioning', 'heater', 'window wont roll', 'door lock'
    ],
    'fuel_issues': [
      'out of gas', 'fuel gauge', 'gas tank empty', 'fuel pump',
      'carburetor', 'fuel filter', 'fuel line', 'gas cap'
    ],
    'minor_mechanical': [
      'belt squeaking', 'fluid top off', 'hose loose', 'clamp loose',
      'minor adjustment', 'maintenance', 'inspection', 'diagnostic'
    ]
  };

  // Contextual analysis weights
  static const Map<String, double> _contextWeights = {
    'urgency_indicators': 2.0,
    'safety_concerns': 2.5,
    'complete_failure': 2.0,
    'mobility_loss': 1.8,
    'multiple_systems': 1.5,
    'recent_occurrence': 1.2,
    'weather_context': 1.3,
    'location_context': 1.4,
  };

  /// AI-powered analysis of vehicle issue description
  static AIAnalysisResult analyzeDescription(String description) {
    if (description.trim().isEmpty) {
      return AIAnalysisResult(
        isSevere: false,
        confidence: 0.0,
        category: 'unknown',
        reasoning: 'No description provided',
        suggestedAction: 'Please provide more details about your issue',
        estimatedSeverity: 'unknown',
        keyFactors: [],
      );
    }

    final cleanDescription = description.toLowerCase().trim();
    
    // Perform multi-dimensional analysis
    final severityScore = _calculateSeverityScore(cleanDescription);
    final categoryAnalysis = _performCategoryAnalysis(cleanDescription);
    final contextualFactors = _analyzeContextualFactors(cleanDescription);
    final keyFactors = _extractKeyFactors(cleanDescription);
    
    // AI reasoning logic
    final confidence = _calculateConfidence(severityScore, categoryAnalysis, contextualFactors);
    final isSevere = severityScore > 0.65 && confidence > 0.7;
    
    final reasoning = _generateReasoning(severityScore, categoryAnalysis, contextualFactors, keyFactors);
    final suggestedAction = _generateSuggestedAction(isSevere, categoryAnalysis, severityScore);
    final estimatedSeverity = _estimateSeverityLevel(severityScore);

    return AIAnalysisResult(
      isSevere: isSevere,
      confidence: confidence,
      category: categoryAnalysis['primary_category'] ?? 'general',
      reasoning: reasoning,
      suggestedAction: suggestedAction,
      estimatedSeverity: estimatedSeverity,
      keyFactors: keyFactors,
    );
  }

  /// Calculate severity score using pattern matching and contextual analysis
  static double _calculateSeverityScore(String description) {
    double score = 0.0;
    int patternMatches = 0;

    // Check against severe patterns
    for (final category in _severityPatterns.entries) {
      for (final pattern in category.value) {
        if (description.contains(pattern)) {
          score += _getCategoryWeight(category.key);
          patternMatches++;
        }
      }
    }

    // Check against minor patterns (reduces severity)
    for (final category in _minorIssuePatterns.entries) {
      for (final pattern in category.value) {
        if (description.contains(pattern)) {
          score -= 0.2;
          break; // Only reduce once per category
        }
      }
    }

    // Apply contextual multipliers
    score *= _getContextualMultiplier(description);

    // Normalize score based on pattern matches
    if (patternMatches > 0) {
      score = score / math.max(1, patternMatches) * math.min(2, patternMatches);
    }

    return math.max(0.0, math.min(1.0, score));
  }

  /// Get weight for different severity categories
  static double _getCategoryWeight(String category) {
    switch (category) {
      case 'safety_hazards':
        return 1.0;
      case 'critical_engine_failure':
        return 0.9;
      case 'mobility_issues':
        return 0.85;
      case 'transmission_critical':
        return 0.8;
      case 'electrical_critical':
        return 0.75;
      case 'severe_mechanical':
        return 0.7;
      case 'starting_system_failure':
        return 0.65;
      default:
        return 0.5;
    }
  }

  /// Perform category analysis to determine primary issue type
  static Map<String, dynamic> _performCategoryAnalysis(String description) {
    final Map<String, int> categoryScores = {};
    
    // Analyze severe patterns
    for (final category in _severityPatterns.entries) {
      int matches = 0;
      for (final pattern in category.value) {
        if (description.contains(pattern)) {
          matches++;
        }
      }
      if (matches > 0) {
        categoryScores[category.key] = matches;
      }
    }

    // Analyze minor patterns
    for (final category in _minorIssuePatterns.entries) {
      int matches = 0;
      for (final pattern in category.value) {
        if (description.contains(pattern)) {
          matches++;
        }
      }
      if (matches > 0) {
        categoryScores['minor_${category.key}'] = matches;
      }
    }

    // Find primary category
    String primaryCategory = 'general';
    int maxScore = 0;
    
    for (final entry in categoryScores.entries) {
      if (entry.value > maxScore) {
        maxScore = entry.value;
        primaryCategory = entry.key;
      }
    }

    return {
      'primary_category': primaryCategory,
      'category_scores': categoryScores,
      'total_matches': categoryScores.values.fold(0, (a, b) => a + b),
    };
  }

  /// Analyze contextual factors that might affect severity
  static Map<String, dynamic> _analyzeContextualFactors(String description) {
    final factors = <String, bool>{};
    
    // Urgency indicators
    if (description.contains('emergency') || description.contains('urgent') || 
        description.contains('immediately') || description.contains('asap') ||
        description.contains('right now') || description.contains('help')) {
      factors['urgency_high'] = true;
    }

    // Safety concerns
    if (description.contains('dangerous') || description.contains('unsafe') ||
        description.contains('hazardous') || description.contains('risky') ||
        description.contains('scary')) {
      factors['safety_concern'] = true;
    }

    // Complete failure indicators
    if (description.contains('completely') || description.contains('totally') ||
        description.contains('entirely') || description.contains('absolutely') ||
        description.contains('nothing')) {
      factors['complete_failure'] = true;
    }

    // Weather context
    if (description.contains('rain') || description.contains('snow') ||
        description.contains('cold') || description.contains('hot') ||
        description.contains('storm') || description.contains('weather')) {
      factors['weather_related'] = true;
    }

    // Location context
    if (description.contains('highway') || description.contains('freeway') ||
        description.contains('remote') || description.contains('busy') ||
        description.contains('traffic') || description.contains('road')) {
      factors['location_concern'] = true;
    }

    // Time sensitivity
    if (description.contains('late') || description.contains('appointment') ||
        description.contains('work') || description.contains('meeting') ||
        description.contains('important')) {
      factors['time_sensitive'] = true;
    }

    return {
      'factors': factors,
      'factor_count': factors.length,
    };
  }

  /// Extract key factors from the description
  static List<String> _extractKeyFactors(String description) {
    final factors = <String>[];
    
    // Key phrases to look for
    final keyPhrases = [
      'wont start', 'will not start', 'cant start', 'cannot start',
      'engine', 'transmission', 'brake', 'battery', 'tire',
      'smoke', 'fire', 'burning', 'sparks',
      'stuck', 'stranded', 'broke down', 'breakdown',
      'towing', 'tow truck', 'inoperable'
    ];

    for (final phrase in keyPhrases) {
      if (description.contains(phrase)) {
        factors.add(phrase);
      }
    }

    return factors.take(5).toList(); // Limit to top 5 factors
  }

  /// Calculate contextual multiplier based on description context
  static double _getContextualMultiplier(String description) {
    double multiplier = 1.0;
    
    // Apply contextual weights
    if (description.contains('emergency') || description.contains('urgent') || 
        description.contains('immediately')) {
      multiplier *= _contextWeights['urgency_indicators']!;
    }

    if (description.contains('dangerous') || description.contains('unsafe') ||
        description.contains('hazardous')) {
      multiplier *= _contextWeights['safety_concerns']!;
    }

    if (description.contains('completely') || description.contains('totally') ||
        description.contains('entirely')) {
      multiplier *= _contextWeights['complete_failure']!;
    }

    if (description.contains('cant drive') || description.contains('stuck') ||
        description.contains('stranded')) {
      multiplier *= _contextWeights['mobility_loss']!;
    }

    return math.min(3.0, multiplier); // Cap at 3x multiplier
  }

  /// Calculate confidence score based on multiple factors
  static double _calculateConfidence(double severityScore, Map<String, dynamic> categoryAnalysis, Map<String, dynamic> contextualFactors) {
    double confidence = 0.5; // Base confidence
    
    // Higher confidence with more pattern matches
    final totalMatches = categoryAnalysis['total_matches'] ?? 0;
    confidence += math.min(0.3, totalMatches * 0.1);
    
    // Higher confidence with contextual factors
    final factorCount = contextualFactors['factor_count'] ?? 0;
    confidence += math.min(0.2, factorCount * 0.05);
    
    // Adjust confidence based on severity score
    if (severityScore > 0.8) {
      confidence += 0.15;
    } else if (severityScore < 0.3) {
      confidence += 0.1;
    }

    return math.min(1.0, confidence);
  }

  /// Generate AI reasoning for the analysis
  static String _generateReasoning(double severityScore, Map<String, dynamic> categoryAnalysis, Map<String, dynamic> contextualFactors, List<String> keyFactors) {
    final primaryCategory = categoryAnalysis['primary_category'] ?? 'general';
    final factors = contextualFactors['factors'] as Map<String, bool>? ?? {};
    
    String reasoning = '';
    
    if (severityScore > 0.7) {
      reasoning = '🤖 AI Analysis: Major issue detected that cannot be repaired roadside. ';
      
      switch (primaryCategory) {
        case 'critical_engine_failure':
          reasoning += 'Critical engine problems require specialized diagnostic equipment and repair facility.';
          break;
        case 'mobility_issues':
          reasoning += 'Vehicle is immobilized and requires professional towing and facility-based repair.';
          break;
        case 'safety_hazards':
          reasoning += 'Safety-critical issues identified requiring immediate professional assessment.';
          break;
        case 'transmission_critical':
          reasoning += 'Transmission problems require specialized equipment and workshop environment.';
          break;
        case 'electrical_critical':
          reasoning += 'Complex electrical issues require advanced diagnostic tools and repair facility.';
          break;
        case 'severe_mechanical':
          reasoning += 'Major mechanical failure requires workshop-based repair with specialized equipment.';
          break;
        default:
          reasoning += 'Multiple severe indicators suggest comprehensive professional assessment needed.';
      }
    } else if (severityScore > 0.4) {
      reasoning = '🤖 AI Analysis: Moderate issue detected that may require service assessment. ';
      reasoning += 'While some roadside repair might be possible, professional evaluation recommended.';
    } else {
      reasoning = '🤖 AI Analysis: Minor issue detected that can typically be resolved roadside. ';
      reasoning += 'This appears to be within the scope of standard roadside assistance.';
    }

    // Add contextual factors
    if (factors['urgency_high'] == true) {
      reasoning += ' ⚡ Urgency indicators detected.';
    }
    if (factors['safety_concern'] == true) {
      reasoning += ' ⚠️ Safety concerns noted.';
    }
    if (factors['weather_related'] == true) {
      reasoning += ' 🌧️ Weather conditions may affect service.';
    }

    return reasoning;
  }

  /// Generate suggested action based on analysis
  static String _generateSuggestedAction(bool isSevere, Map<String, dynamic> categoryAnalysis, double severityScore) {
    if (isSevere) {
      return '🏥 Professional service assessment required - issue cannot be resolved roadside.';
    } else if (severityScore > 0.4) {
      return '� Service assessment recommended to determine best repair approach.';
    } else {
      return '✅ Standard roadside assistance - our mechanics can resolve this on-site.';
    }
  }

  /// 🚛 NEW: Check if issue requires towing (cannot be repaired roadside)
  static bool requiresTowing(String description) {
    final analysisResult = analyzeDescription(description);
    
    // High confidence severe issues that definitely need towing
    if (analysisResult.isSevere && analysisResult.confidence > 0.8) {
      return true;
    }
    
    // Specific towing-required patterns
    final towingPatterns = [
      // Critical engine failures
      'engine failure', 'engine seized', 'engine blown', 'engine dead',
      'engine smoking', 'engine fire', 'engine exploded', 'engine overheated badly',
      'engine won\'t start', 'engine completely dead', 'engine making loud noise',
      
      // Transmission critical issues
      'transmission failure', 'transmission dead', 'car won\'t move',
      'stuck in gear', 'transmission fluid everywhere', 'gears grinding',
      'no reverse', 'no forward', 'transmission slipping badly',
      
      // Mobility issues
      'car broke down', 'broke down', 'stranded', 'immobilized',
      'car won\'t start', 'completely dead', 'car died', 'breakdown',
      'need towing', 'needs towing', 'tow truck needed',
      
      // Safety hazards
      'accident', 'crash', 'collision', 'fire', 'smoke from engine',
      'unsafe to drive', 'dangerous', 'brakes failed', 'steering failed',
      'wheel fell off', 'tire blowout on highway',
      
      // Electrical critical
      'electrical fire', 'sparks', 'burning smell', 'no power',
      'dashboard dead', 'all lights out', 'electrical failure',
      
      // Severe mechanical
      'axle broken', 'suspension collapsed', 'frame cracked',
      'differential problems', 'driveshaft broken', 'major mechanical failure'
    ];
    
    final lowerDescription = description.toLowerCase();
    for (final pattern in towingPatterns) {
      if (lowerDescription.contains(pattern)) {
        return true;
      }
    }
    
    return false;
  }

  /// Get towing requirement reason
  static String getTowingReason(String description) {
    final analysisResult = analyzeDescription(description);
    
    if (analysisResult.isSevere && analysisResult.confidence > 0.8) {
      return 'AI Analysis indicates this is a severe issue that cannot be safely repaired on the roadside. ${analysisResult.reasoning}';
    }
    
    // Check which specific pattern triggered towing requirement
    final lowerDescription = description.toLowerCase();
    
    if (lowerDescription.contains('engine failure') || lowerDescription.contains('engine seized')) {
      return 'Engine failure detected - vehicle requires professional towing to prevent further damage.';
    }
    
    if (lowerDescription.contains('transmission failure') || lowerDescription.contains('won\'t move')) {
      return 'Transmission issues detected - vehicle cannot be driven safely and needs towing.';
    }
    
    if (lowerDescription.contains('broke down') || lowerDescription.contains('stranded')) {
      return 'Vehicle breakdown detected - towing required to move vehicle to safe location.';
    }
    
    if (lowerDescription.contains('accident') || lowerDescription.contains('crash')) {
      return 'Vehicle accident detected - towing required for safety and legal reasons.';
    }
    
    if (lowerDescription.contains('fire') || lowerDescription.contains('smoke')) {
      return 'Fire/smoke hazard detected - immediate towing required for safety.';
    }
    
    return 'Critical issue detected that requires professional towing for safety and proper repair.';
  }

  /// Estimate severity level
  static String _estimateSeverityLevel(double severityScore) {
    if (severityScore > 0.8) {
      return 'critical';
    } else if (severityScore > 0.6) {
      return 'severe';
    } else if (severityScore > 0.4) {
      return 'moderate';
    } else if (severityScore > 0.2) {
      return 'minor';
    } else {
      return 'minimal';
    }
  }
}

/// Result of AI-powered description analysis
class AIAnalysisResult {
  final bool isSevere;
  final double confidence;
  final String category;
  final String reasoning;
  final String suggestedAction;
  final String estimatedSeverity;
  final List<String> keyFactors;

  const AIAnalysisResult({
    required this.isSevere,
    required this.confidence,
    required this.category,
    required this.reasoning,
    required this.suggestedAction,
    required this.estimatedSeverity,
    required this.keyFactors,
  });

  @override
  String toString() {
    return 'AIAnalysisResult(isSevere: $isSevere, confidence: ${(confidence * 100).toStringAsFixed(1)}%, category: $category, severity: $estimatedSeverity)';
  }
}

// For backwards compatibility with existing code
class DescriptionAnalysisService {
  static AIAnalysisResult analyzeDescription(String description) {
    return AIDescriptionAnalysisService.analyzeDescription(description);
  }
}

class SeverityAnalysisResult {
  final bool isSevere;
  final double confidence;
  final String category;
  final String reasoning;

  const SeverityAnalysisResult({
    required this.isSevere,
    required this.confidence,
    required this.category,
    required this.reasoning,
  });

  @override
  String toString() {
    return 'SeverityAnalysisResult(isSevere: $isSevere, confidence: ${(confidence * 100).toStringAsFixed(1)}%, category: $category)';
  }
}










