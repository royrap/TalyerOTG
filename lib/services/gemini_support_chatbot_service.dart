import 'dart:convert';
import 'package:http/http.dart' as http;

class GeminiSupportChatbotService {
  static const String _apiKey = 'AIzaSyBN8VKuOYcmrdzJ5T3KpkxaCa-PNs3Wk8o';
  static const String _baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-pro:generateContent';

  // System context about RoadAid - para alam ni Gemini ang features
  static const String _systemContext = '''
You are RoadAid Support Assistant, an AI helper EXCLUSIVELY for the RoadAid mobile application - a roadside assistance and auto repair service platform in the Philippines.

CRITICAL RULES - MUST FOLLOW:
1. ⛔ ONLY answer questions about RoadAid system, features, and services
2. ⛔ DO NOT answer questions about: politics, history, general knowledge, math, science, other apps, celebrities, news, weather, recipes, or ANY topic outside RoadAid
3. ⛔ If user asks ANYTHING not related to RoadAid, respond ONLY with: "I apologize, but I can only help with questions about the RoadAid app and its features. Please ask me about our roadside assistance services, how to use the app, payment methods, or any RoadAid-related concerns."
4. ✅ Keep answers clear, concise, and professional
5. ✅ Use Filipino-English mix when appropriate for clarity
6. ✅ Always be helpful and friendly about RoadAid topics

RoadAid SYSTEM INFORMATION:

🚗 MAIN FEATURES:
- Emergency Roadside Assistance (24/7)
- Mobile Mechanic Service
- Towing Service
- Auto Shop/Talyer Booking
- Real-time GPS Tracking
- In-app Payment
- Service History
- Invoice Management

👤 USER TYPES:
1. CUSTOMER - Can request services, track mechanics, make payments
2. MECHANIC - Independent mechanics who respond to service requests
3. TALYER OWNER - Auto shop owners who can receive booking requests
4. ADMIN - System administrators

📱 HOW TO REQUEST SERVICE:
1. Tap "Request Service" on home screen
2. Select service type (Roadside Assistance, Mechanic, Towing, Shop Service)
3. Describe your vehicle issue
4. Confirm your location
5. Wait for mechanic/shop to accept (15-30 minutes average)
6. Track mechanic arrival in real-time
7. Pay through the app after service completion

💰 PAYMENT METHODS:
- Credit/Debit Cards
- GCash
- PayMaya
- Cash (with mechanic)
- All payments are secure and recorded

📍 TRACKING FEATURES:
- Real-time mechanic location tracking
- Estimated arrival time
- Direct messaging with mechanic
- Service status updates
- Photo progress updates

🔧 AVAILABLE SERVICES:
- Flat Tire Change
- Battery Jump Start/Replacement
- Engine Diagnostics
- Brake Service
- Oil Change
- Towing (short and long distance)
- General Auto Repair
- Emergency Roadside Assistance

⏱️ RESPONSE TIME:
- Average: 15-30 minutes
- Depends on location and mechanic availability
- Emergency services prioritized

❌ CANCELLATION POLICY:
- Can cancel before mechanic arrives
- Go to "Active Requests" → tap "Cancel Request"
- May incur cancellation fee if mechanic is already en route

📋 SERVICE HISTORY:
- View all past services
- Download invoices
- Rate and review mechanics
- Track payments

🆘 EMERGENCY FEATURES:
- One-tap emergency assistance
- GPS location automatically sent
- Priority dispatch for emergencies
- 24/7 availability

💳 INVOICE & PAYMENT:
- Detailed invoice after service
- Parts and labor breakdown
- Multiple payment options
- Receipt available in app

⭐ RATINGS & REVIEWS:
- Rate mechanics after service
- Leave reviews and feedback
- Help other users choose quality service
- Mechanics with higher ratings get priority

🔐 ACCOUNT & SECURITY:
- Secure login with email verification
- Profile management
- Change email/password
- Account security logs
- Privacy protection

If question is NOT about RoadAid, respond with:
"I'm here to help with RoadAid app questions only. Please ask me about our roadside assistance services, how to use the app, payment methods, or any other RoadAid features. 😊"
''';

  /// Send message to Gemini AI chatbot with RoadAid context
  static Future<String> sendMessage(String userMessage, List<Map<String, String>> conversationHistory) async {
    try {
      print('🤖 Sending message to RoadAid Support Chatbot...');

      // Build conversation history for context
      String conversationContext = '';
      if (conversationHistory.isNotEmpty) {
        conversationContext = '\n\nPREVIOUS CONVERSATION:\n';
        // Get last 10 messages for context
        final recentMessages = conversationHistory.length > 10
            ? conversationHistory.sublist(conversationHistory.length - 10)
            : conversationHistory;
        for (var msg in recentMessages) {
          conversationContext += '${msg['role']}: ${msg['text']}\n';
        }
      }

      final prompt = '''
$_systemContext

$conversationContext

USER QUESTION: "$userMessage"

⛔⛔⛔ SUPER STRICT INSTRUCTIONS - NO EXCEPTIONS ⛔⛔⛔

STEP 1 - VALIDATE QUESTION:
Check if the question is SPECIFICALLY about:
✅ RoadAid app features (request service, tracking, payment, etc.)
✅ How to use RoadAid system
✅ RoadAid services (mechanic, towing, roadside assistance, shop booking)
✅ RoadAid pricing, payment methods, invoices
✅ RoadAid account, profile, settings
✅ RoadAid technical support or troubleshooting

❌ If question is about ANYTHING ELSE like:
- Politics, government, current events
- Math, science, history, geography
- Other apps (Grab, Angkas, Uber, etc.)
- General knowledge (recipes, sports, celebrities)
- Personal advice not related to RoadAid
- Weather, time, directions (not for RoadAid service)

STEP 2 - RESPOND:
❌ If NOT about RoadAid → Respond with ONLY:
"Sorry po, pero I can only answer questions about the RoadAid app and services. Please ask me about requesting roadside assistance, tracking mechanics, payments, or any RoadAid features. 🚗"

✅ If IS about RoadAid → Answer based on the RoadAid SYSTEM INFORMATION above
- Keep answer under 200 words
- Be friendly and helpful
- Use Filipino-English mix if helpful
- Use emojis (🚗 💰 ⏱️ 📱 ✅ 🔧 etc.)

YOUR RESPONSE (RoadAid TOPICS ONLY):
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
          'temperature': 0.7,
          'topK': 40,
          'topP': 0.95,
          'maxOutputTokens': 500,
        },
        'safetySettings': [
          {
            'category': 'HARM_CATEGORY_HARASSMENT',
            'threshold': 'BLOCK_MEDIUM_AND_ABOVE'
          },
          {
            'category': 'HARM_CATEGORY_HATE_SPEECH',
            'threshold': 'BLOCK_MEDIUM_AND_ABOVE'
          },
          {
            'category': 'HARM_CATEGORY_SEXUALLY_EXPLICIT',
            'threshold': 'BLOCK_MEDIUM_AND_ABOVE'
          },
          {
            'category': 'HARM_CATEGORY_DANGEROUS_CONTENT',
            'threshold': 'BLOCK_MEDIUM_AND_ABOVE'
          }
        ]
      };

      final url = Uri.parse('$_baseUrl?key=$_apiKey');
      print('📡 Calling Gemini API: $url');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['candidates'] != null && data['candidates'].isNotEmpty) {
          final content = data['candidates'][0]['content']['parts'][0]['text'];
          print('✅ Gemini Response received');
          return content.trim();
        } else {
          print('⚠️ No response from Gemini');
          return _getFallbackResponse(userMessage);
        }
      } else {
        print('❌ Gemini API error: ${response.statusCode} - ${response.body}');
        return _getFallbackResponse(userMessage);
      }
    } catch (e) {
      print('❌ Error calling Gemini chatbot: $e');
      return _getFallbackResponse(userMessage);
    }
  }

  /// Fallback response kung may error
  static String _getFallbackResponse(String userMessage) {
    final lowerMessage = userMessage.toLowerCase();
    
    if (lowerMessage.contains('request') || lowerMessage.contains('service') || lowerMessage.contains('paano')) {
      return '''
📱 To request a service in RoadAid:

1. Tap "Request Service" on the home screen
2. Select your service type (Roadside Assistance, Mechanic, Towing, or Shop Service)
3. Describe your vehicle issue
4. Confirm your location
5. Wait for a mechanic/shop to accept (average 15-30 minutes)
6. Track the mechanic's arrival in real-time
7. Pay through the app after service completion

Need help with anything else about RoadAid? 😊
''';
    } else if (lowerMessage.contains('payment') || lowerMessage.contains('pay') || lowerMessage.contains('bayad')) {
      return '''
💰 RoadAid Payment Methods:

We accept:
✅ Credit/Debit Cards
✅ GCash
✅ PayMaya
✅ Cash (with mechanic)

All payments are:
🔒 Secure and encrypted
📝 Automatically recorded
🧾 Receipt available in app

You can view all your payment history in the "Invoices" tab!
''';
    } else if (lowerMessage.contains('track') || lowerMessage.contains('location') || lowerMessage.contains('san')) {
      return '''
📍 Real-Time Tracking in RoadAid:

Once a mechanic accepts your request, you can:
✅ See their exact location on the map
✅ Get estimated arrival time
✅ Message them directly
✅ Receive status updates

The map updates automatically every few seconds so you always know where they are!
''';
    } else if (lowerMessage.contains('cancel') || lowerMessage.contains('tanggalin')) {
      return '''
❌ To cancel a service request:

1. Go to your "Active Requests" or "Home" screen
2. Find your active service request
3. Tap "Cancel Request" button
4. Confirm the cancellation

⚠️ Note: If the mechanic is already on their way, a cancellation fee may apply.

You can cancel anytime before the mechanic arrives at your location.
''';
    } else if (lowerMessage.contains('time') || lowerMessage.contains('gaano') || lowerMessage.contains('tagal')) {
      return '''
⏱️ RoadAid Response Time:

Average waiting time: 15-30 minutes

Response time depends on:
📍 Your location
👨‍🔧 Mechanic availability nearby
🚨 Service urgency (emergencies prioritized)

You can track the mechanic in real-time once they accept your request!
''';
    } else {
      return '''
I'm here to help with RoadAid questions! 😊

I can assist you with:
🚗 How to request services
💰 Payment methods
📍 Tracking mechanics
⏱️ Response times
❌ Cancellation policy
📱 App features
🔧 Available services

What would you like to know about RoadAid?
''';
    }
  }
}
