import 'package:flutter/material.dart';

class FAQAIScreen extends StatefulWidget {
  const FAQAIScreen({super.key});

  @override
  State<FAQAIScreen> createState() => _FAQAIScreenState();
}

class _FAQAIScreenState extends State<FAQAIScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _isTyping = false;

  // FAQ Knowledge Base
  final Map<String, String> _faqKnowledge = {
    'payment': 'RoadAid supports multiple payment methods including cash, credit/debit cards, and digital wallets. Payments are processed securely through our platform.',
    'qr code': 'Use the QR scanner in the app to complete payments. Simply scan the customer\'s payment QR code to process the transaction.',
    'job assignment': 'Jobs are automatically assigned based on your location, availability, and expertise. You\'ll receive notifications for new assignments.',
    'rating': 'Your rating is calculated based on customer feedback. Maintain high service quality to improve your rating and get more job opportunities.',
    'earnings': 'View your earnings in the Earnings section. Payments are processed weekly and deposited to your registered bank account.',
    'profile': 'You can update your profile information, including photo, contact details, and service specializations in the Profile section.',
    'location': 'Keep your location services enabled for accurate job assignments. The app tracks your location to match you with nearby customers.',
    'schedule': 'Set your availability in the app to receive job assignments during your preferred working hours.',
    'emergency': 'For emergency roadside assistance, prioritize safety first. Follow proper safety protocols and contact emergency services if needed.',
    'tools': 'Ensure you have all necessary tools and equipment before accepting jobs. This includes basic repair tools, diagnostic equipment, and safety gear.',
    'customer': 'Maintain professional communication with customers. Explain the issue and repair process clearly. Ask for approval before proceeding with expensive repairs.',
    'support': 'For technical issues or account problems, contact our support team through the app or email support@RoadAid.com.',
  };

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  void _initializeChat() {
    _messages = [
      {
        'text': 'Hello! I\'m your RoadAid AI assistant. I can help you with questions about:\n\n• Payment processing\n• Job assignments\n• QR code scanning\n• Earnings and ratings\n• Profile management\n• App features\n\nWhat would you like to know?',
        'isUser': false,
        'timestamp': DateTime.now(),
      }
    ];
  }

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty) return;

    String userMessage = _messageController.text.trim();
    
    setState(() {
      _messages.add({
        'text': userMessage,
        'isUser': true,
        'timestamp': DateTime.now(),
      });
      _isTyping = true;
    });

    _messageController.clear();
    _scrollToBottom();

    // Simulate AI processing delay
    Future.delayed(const Duration(milliseconds: 1000), () {
      String aiResponse = _generateAIResponse(userMessage);
      
      setState(() {
        _messages.add({
          'text': aiResponse,
          'isUser': false,
          'timestamp': DateTime.now(),
        });
        _isTyping = false;
      });
      
      _scrollToBottom();
    });
  }

  String _generateAIResponse(String userMessage) {
    String message = userMessage.toLowerCase();
    
    // Check for specific keywords and provide relevant responses
    for (String keyword in _faqKnowledge.keys) {
      if (message.contains(keyword)) {
        return _faqKnowledge[keyword]!;
      }
    }

    // Handle greeting
    if (message.contains('hello') || message.contains('hi') || message.contains('hey')) {
      return 'Hello! How can I help you today? I can assist with questions about RoadAid app features, payments, job assignments, and more.';
    }

    // Handle thanks
    if (message.contains('thank') || message.contains('thanks')) {
      return 'You\'re welcome! Is there anything else I can help you with regarding the RoadAid mechanic app?';
    }

    // Handle app-related queries
    if (message.contains('app') || message.contains('how to')) {
      return 'I can help you with various app features:\n\n• Navigation and dashboard\n• Job management\n• Payment processing\n• Profile settings\n• QR code scanning\n\nWhat specific feature would you like to know about?';
    }

    // Handle technical issues
    if (message.contains('problem') || message.contains('issue') || message.contains('error') || message.contains('bug')) {
      return 'For technical issues, try these steps:\n\n1. Restart the app\n2. Check your internet connection\n3. Update to the latest app version\n4. Clear app cache\n\nIf the problem persists, contact our support team at support@RoadAid.com with details about the issue.';
    }

    // Handle contact/support requests
    if (message.contains('contact') || message.contains('support') || message.contains('help')) {
      return 'You can reach our support team:\n\n📧 Email: support@RoadAid.com\n📞 Phone: 1-800-RoadAid\n💬 Live chat: Available 24/7 in the app\n\nFor urgent technical issues, use the live chat feature for immediate assistance.';
    }

    // Default response
    return 'I understand you\'re asking about "${userMessage}". Let me help you with that!\n\nI can provide information about:\n• Payment and earnings\n• Job assignments and ratings\n• App navigation and features\n• QR code scanning\n• Profile management\n• Technical support\n\nCould you be more specific about what you\'d like to know?';
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 176, 12, 1),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(51),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.smart_toy,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'FAQ AI Assistant',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                Text(
                  'Get instant help',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              setState(() {
                _initializeChat();
              });
            },
            tooltip: 'Restart Chat',
          ),
        ],
      ),
      body: Column(
        children: [
          // Chat Messages
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_isTyping ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length && _isTyping) {
                  return _buildTypingIndicator();
                }
                
                return _buildMessageBubble(_messages[index]);
              },
            ),
          ),
          
          // Message Input
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withAlpha(26),
                  spreadRadius: 1,
                  blurRadius: 6,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type your question...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: const BorderSide(
                          color: Color.fromARGB(255, 176, 12, 1),
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                    maxLines: null,
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: const BoxDecoration(
                    color: Color.fromARGB(255, 176, 12, 1),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message) {
    bool isUser = message['isUser'];
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color.fromARGB(255, 176, 12, 1).withAlpha(26),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.smart_toy,
                color: Color.fromARGB(255, 176, 12, 1),
                size: 20,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isUser 
                    ? const Color.fromARGB(255, 176, 12, 1)
                    : Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withAlpha(26),
                    spreadRadius: 1,
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message['text'],
                    style: TextStyle(
                      color: isUser ? Colors.white : Colors.black87,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(message['timestamp']),
                    style: TextStyle(
                      color: isUser ? Colors.white70 : Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.person,
                color: Colors.grey,
                size: 20,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 176, 12, 1).withAlpha(26),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.smart_toy,
              color: Color.fromARGB(255, 176, 12, 1),
              size: 20,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withAlpha(26),
                  spreadRadius: 1,
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTypingDot(0),
                const SizedBox(width: 4),
                _buildTypingDot(1),
                const SizedBox(width: 4),
                _buildTypingDot(2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingDot(int index) {
    return AnimatedContainer(
      duration: Duration(milliseconds: 600 + (index * 200)),
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: Colors.grey[400],
        shape: BoxShape.circle,
      ),
    );
  }

  String _formatTime(DateTime timestamp) {
    return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}










