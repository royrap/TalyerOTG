import 'package:flutter/material.dart';
import '../services/gemini_support_chatbot_service.dart';

class ChatbotFAQScreen extends StatefulWidget {
  const ChatbotFAQScreen({Key? key}) : super(key: key);

  @override
  _ChatbotFAQScreenState createState() => _ChatbotFAQScreenState();
}

class _ChatbotFAQScreenState extends State<ChatbotFAQScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  final List<Map<String, dynamic>> _messages = [];
  bool _isTyping = false;

  final List<String> _quickReplies = [
    "How do I request service?",
    "How long does it take?",
    "What payment methods?",
    "Can I track mechanic?",
    "Cancellation policy?",
    "Available services?",
  ];

  @override
  void initState() {
    super.initState();
    _addBotMessage("Hello!  I am RoadAid Support Assistant powered by Gemini AI. I am here to help you with questions about our roadside assistance services and app features. How can I help you today?");
    _showQuickReplies();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _addBotMessage(String message) {
    setState(() {
      _messages.add({
        "text": message,
        "isUser": false,
        "timestamp": DateTime.now(),
      });
    });
    _scrollToBottom();
  }

  void _addUserMessage(String message) {
    setState(() {
      _messages.add({
        "text": message,
        "isUser": true,
        "timestamp": DateTime.now(),
      });
    });
    _scrollToBottom();
  }

  void _showQuickReplies() {
    setState(() {
      _messages.add({
        "text": "",
        "isUser": false,
        "showQuickReplies": true,
        "timestamp": DateTime.now(),
      });
    });
    _scrollToBottom();
  }

  Future<void> _sendMessage(String message) async {
    if (message.trim().isEmpty) return;

    _addUserMessage(message);
    _messageController.clear();

    setState(() {
      _isTyping = true;
    });

    try {
      final conversationHistory = _messages
          .where((msg) => msg["text"] != null && msg["text"].toString().isNotEmpty)
          .map((msg) => {
                "role": (msg["isUser"] ?? false) ? "user" : "model",
                "text": msg["text"].toString(),
              })
          .toList();

      final response = await GeminiSupportChatbotService.sendMessage(message, conversationHistory);

      setState(() {
        _isTyping = false;
      });

      _addBotMessage(response);
    } catch (e) {
      setState(() {
        _isTyping = false;
      });

      _addBotMessage("I apologize, but I am having trouble connecting right now. Please try again in a moment.");
    }
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

  Widget _buildTypingIndicator() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildDot(0),
          const SizedBox(width: 4),
          _buildDot(1),
          const SizedBox(width: 4),
          _buildDot(2),
        ],
      ),
    );
  }

  Widget _buildDot(int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 600 + (index * 100)),
      builder: (context, value, child) {
        return Opacity(
          opacity: (value * 2) % 1.0,
          child: Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Colors.grey,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
      onEnd: () {
        if (mounted) {
          setState(() {});
        }
      },
    );
  }

  Widget _buildMessage(Map<String, dynamic> message) {
    final isUser = message["isUser"] ?? false;
    final text = message["text"] ?? "";
    final showQuickReplies = message["showQuickReplies"] ?? false;

    if (showQuickReplies) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _quickReplies
              .map((reply) => ActionChip(
                    label: Text(reply),
                    onPressed: () => _sendMessage(reply),
                    backgroundColor: Colors.blue[50],
                    labelStyle: const TextStyle(color: Colors.blue),
                  ))
              .toList(),
        ),
      );
    }

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isUser ? Colors.blue : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isUser ? Colors.white : Colors.black87,
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Help & Support"),
        backgroundColor: Colors.blue,
        elevation: 0,
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: Colors.blue[50],
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "AI-powered support focused on RoadAid app support only",
                    style: TextStyle(
                      color: Colors.blue[700],
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(vertical: 16),
              itemCount: _messages.length + (_isTyping ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length && _isTyping) {
                  return _buildTypingIndicator();
                }
                return _buildMessage(_messages[index]);
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
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
                      hintText: "Ask me anything about RoadAid...",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey[100],
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                    ),
                    onSubmitted: _sendMessage,
                    enabled: !_isTyping,
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: Colors.blue,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: _isTyping
                        ? null
                        : () => _sendMessage(_messageController.text),
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
