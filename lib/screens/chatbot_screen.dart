import 'package:flutter/material.dart';

class ChatBotScreen extends StatefulWidget {
  const ChatBotScreen({super.key});

  @override
  State<ChatBotScreen> createState() => _ChatBotScreenState();
}

class _ChatBotScreenState extends State<ChatBotScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];

  // Predefined FAQ responses
  final Map<String, String> _faqResponses = {
    'hello': 'Hello! I\'m here to help you with any questions about RoadAid. What would you like to know?',
    'hi': 'Hi there! How can I assist you today?',
    'help': 'I can help you with questions about:\n• Requesting roadside assistance\n• Payment methods\n• Service costs\n• Vehicle management\n• Account settings\n\nWhat would you like to know more about?',
    'request assistance': 'To request roadside assistance:\n1. Tap the "Request Help" button on the home screen\n2. Select your issue type (tire repair, battery jump-start, etc.)\n3. Confirm your location\n4. A nearby service provider will be dispatched to help you\n\nAverage response time is 15-30 minutes.',
    'payment': 'We accept the following payment methods:\n• Cash\n• GCash\n• PayMaya\n• Major credit/debit cards\n\nYou can manage your payment methods in the Profile section.',
    'cost': 'Service costs are based on:\n• Type of assistance needed\n• Distance traveled by the service provider\n• Time of day\n\nYou\'ll see the estimated cost before confirming your request.',
    'cancel': 'You can cancel a request before the service provider is dispatched. If the provider is already on the way, cancellation fees may apply.',
    'vehicle': 'To add a new vehicle:\n1. Go to "My Vehicles" in your profile\n2. Tap "Add Vehicle"\n3. Enter your vehicle details including make, model, and plate number',
    'services': 'We offer these roadside services:\n• Tire repair and replacement\n• Battery jump-start\n• Fuel delivery\n• Lockout assistance\n• Towing services\n• Minor mechanical repairs',
    'contact': 'You can reach our support team:\n• Through this chat\n• Email: support@RoadAid.com\n• Phone: +63 123 456 7890',
    'time': 'Average response time is 15-30 minutes, depending on your location and the availability of service providers in your area.',
  };

  @override
  void initState() {
    super.initState();
    // Add welcome message
    _messages.add(ChatMessage(
      text: 'Hello! I\'m RoadAid Assistant. I\'m here to help you with any questions about our roadside assistance service. How can I help you today?',
      isUser: false,
      timestamp: DateTime.now(),
    ));
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    // Add user message
    setState(() {
      _messages.add(ChatMessage(
        text: text,
        isUser: true,
        timestamp: DateTime.now(),
      ));
    });

    _messageController.clear();
    _scrollToBottom();

    // Generate bot response
    _generateBotResponse(text);
  }

  void _generateBotResponse(String userMessage) {
    String response = _getBotResponse(userMessage.toLowerCase());
    
    // Simulate typing delay
    Future.delayed(const Duration(milliseconds: 1000), () {
      setState(() {
        _messages.add(ChatMessage(
          text: response,
          isUser: false,
          timestamp: DateTime.now(),
        ));
      });
      _scrollToBottom();
    });
  }

  String _getBotResponse(String message) {
    // Check for exact matches first
    if (_faqResponses.containsKey(message)) {
      return _faqResponses[message]!;
    }

    // Check for partial matches
    for (String key in _faqResponses.keys) {
      if (message.contains(key)) {
        return _faqResponses[key]!;
      }
    }

    // Default response with suggestions
    return 'I\'m not sure about that. Here are some topics I can help you with:\n\n• How to request assistance\n• Payment methods\n• Service costs\n• Adding vehicles\n• Available services\n• Contact support\n\nTry asking about any of these topics!';
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showQuickReplies() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quick Questions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildQuickReplyChip('How to request assistance?'),
                _buildQuickReplyChip('What payment methods?'),
                _buildQuickReplyChip('How much does it cost?'),
                _buildQuickReplyChip('What services available?'),
                _buildQuickReplyChip('How to add vehicle?'),
                _buildQuickReplyChip('Contact support'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickReplyChip(String text) {
    return ActionChip(
      label: Text(text),
      onPressed: () {
        Navigator.pop(context);
        _messageController.text = text;
        _sendMessage();
      },
      backgroundColor: const Color.fromARGB(255, 176, 12, 1).withAlpha(26),
      labelStyle: const TextStyle(color: const Color.fromARGB(255, 176, 12, 1)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: const Color.fromARGB(255, 176, 12, 1).withAlpha(26),
              child: const Icon(Icons.smart_toy, color: const Color.fromARGB(255, 176, 12, 1)),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'RoadAid Assistant',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Online',
                  style: TextStyle(fontSize: 12, color: Colors.green),
                ),
              ],
            ),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: _showQuickReplies,
          ),
        ],
      ),
      body: Column(
        children: [
          // Chat messages
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                return ChatMessageWidget(message: _messages[index]);
              },
            ),
          ),
          
          // Message input
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withAlpha(26),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, -1),
                ),
              ],
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.add, color: Colors.grey),
                  onPressed: _showQuickReplies,
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type your question...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: const Color.fromARGB(255, 176, 12, 1),
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
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}

class ChatMessageWidget extends StatelessWidget {
  final ChatMessage message;

  const ChatMessageWidget({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment:
            message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!message.isUser) ...[
            CircleAvatar(
              backgroundColor: const Color.fromARGB(255, 176, 12, 1).withAlpha(26),
              child: const Icon(Icons.smart_toy, color: const Color.fromARGB(255, 176, 12, 1)),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: message.isUser ? const Color.fromARGB(255, 176, 12, 1) : Colors.grey[100],
                borderRadius: BorderRadius.circular(16).copyWith(
                  bottomLeft: message.isUser ? const Radius.circular(16) : const Radius.circular(4),
                  bottomRight: message.isUser ? const Radius.circular(4) : const Radius.circular(16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.text,
                    style: TextStyle(
                      color: message.isUser ? Colors.white : Colors.black,
                      fontSize: 16,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${message.timestamp.hour.toString().padLeft(2, '0')}:${message.timestamp.minute.toString().padLeft(2, '0')}',
                    style: TextStyle(
                      color: message.isUser ? Colors.white70 : Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (message.isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: const Color.fromARGB(255, 176, 12, 1).withAlpha(26),
              child: const Icon(Icons.person, color: const Color.fromARGB(255, 176, 12, 1), size: 16),
            ),
          ],
        ],
      ),
    );
  }
}










