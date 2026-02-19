class GeminiConfig {
  // 🔑 GEMINI AI API CONFIGURATION
  // Gemini API key from Google AI Studio
  // Get your API key here: https://makersuite.google.com/app/apikey
  static const String GEMINI_API_KEY = 'AIzaSyAxOHE4iTaN6zdpCwDCLgJXSwwrSzBuLo0';
  
  // Gemini API settings
  static const String GEMINI_MODEL = 'gemini-1.5-flash';
  static const String GEMINI_API_BASE_URL = 'https://generativelanguage.googleapis.com/v1beta';
  
  // Verification thresholds
  static const int MIN_CONFIDENCE_SCORE = 70;
  static const int HIGH_CONFIDENCE_SCORE = 90;
  static const int MAX_RETRY_ATTEMPTS = 3;
  
  // Image processing settings
  static const int MAX_IMAGE_SIZE_MB = 10;
  static const int IMAGE_QUALITY = 90;
  static const int MAX_IMAGE_WIDTH = 1024;
  static const int MAX_IMAGE_HEIGHT = 1024;
  
  // Document types supported
  static const List<String> SUPPORTED_ID_TYPES = [
    'drivers_license',
    'national_id', 
    'umid',
    'passport',
    'philsys_id'
  ];
  
  // Business document requirements
  static const List<String> REQUIRED_PERMIT_FIELDS = [
    'business_name',
    'permit_number',
    'issue_date',
    'expiry_date',
    'issuing_authority'
  ];
  
  static const List<String> REQUIRED_ID_FIELDS = [
    'full_name',
    'id_number',
    'date_of_birth',
    'issue_date',
    'expiry_date'
  ];
  
  // Validation settings
  static const int DAYS_BEFORE_EXPIRY_WARNING = 30;
  static const int MAX_DOCUMENT_AGE_YEARS = 10;
  
  // Debug mode (set to false in production)
  static const bool DEBUG_MODE = true;
  
  // Mock responses for testing (when API key is not set)
  static const bool USE_MOCK_RESPONSES = false;
  
  /// Check if Gemini API is properly configured
  static bool get isConfigured {
    return GEMINI_API_KEY.isNotEmpty && 
           GEMINI_API_KEY != 'YOUR_ACTUAL_GEMINI_API_KEY_HERE';
  }
  
  /// Get verification requirements message
  static String get requirementsMessage {
    return '''
📋 GEMINI AI VERIFICATION REQUIREMENTS:

✅ Clear, high-quality document photos
✅ All text must be readable
✅ Documents must not be expired
✅ Business name must match registration
✅ ID name must match business owner
✅ Supported ID types: ${SUPPORTED_ID_TYPES.join(', ')}

⚡ AI will automatically verify:
• Document authenticity
• Expiry dates
• Name consistency
• Text clarity
• Official format validation
    ''';
  }
}










