import 'package:flutter/material.dart';
import 'dart:async';
import '../services/auth_service.dart';
import '../services/messaging_service.dart';
import '../services/user_data_service.dart';

class ChatScreen extends StatefulWidget {
  final String contactName;
  final String contactAvatar;
  final String lastSeen;
  final String? serviceRequestId;
  final String? mechanicId;

  const ChatScreen({
    super.key,
    required this.contactName,
    required this.contactAvatar,
    required this.lastSeen,
    this.serviceRequestId,
    this.mechanicId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  Map<String, dynamic>? _otherUser;
  late StreamSubscription? _messagesSubscription;

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  @override
  void dispose() {
    _messagesSubscription?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
    Future<void> _initializeChat() async {
    if (widget.serviceRequestId != null) {
      // Load other user info (mechanic or customer)
      await _loadOtherUserInfo();
      
      // Get initial messages
      await _forceRefreshMessages();
      
      // Mark messages as read
      final currentUserId = AuthService.instance.userId;
      if (currentUserId != null) {
        await MessagingService.markMessagesAsRead(widget.serviceRequestId!, currentUserId);
      }
    } else {
      _loadFallbackMessages();
    }
  }

  Future<void> _loadOtherUserInfo() async {
    final currentUserProfile = AuthService.instance.userProfile;
    final currentUserType = currentUserProfile?['user_type'] ?? 'customer';
    
    if (currentUserType == 'customer') {
      // Current user is customer, get mechanic info
      _otherUser = await MessagingService.getMechanicForRequest(widget.serviceRequestId!);
    } else {
      // Current user is mechanic, get customer info
      _otherUser = await MessagingService.getCustomerForRequest(widget.serviceRequestId!);
    }
    
    print('👤 Other user loaded: ${_otherUser?['first_name']} ${_otherUser?['last_name']}');
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

  Future<void> _loadFallbackMessages() async {
    try {
      final authService = AuthService.instance;
      final userId = authService.userId;
      
      if (userId != null && widget.serviceRequestId != null) {
        // Get messages for this specific service request
        final messages = await UserDataService.getServiceRequestMessages(widget.serviceRequestId!);
        
        setState(() {
          _messages = messages;
          _isLoading = false;
        });

        // Mark messages as read for this service request
        await UserDataService.markMessagesAsRead(widget.serviceRequestId!);

        _scrollToBottom();
      } else if (userId != null) {
        // Fallback: Get all user messages and filter by contact/mechanic
        final allMessages = await UserDataService.getUserMessages();
        
        // Filter messages for this specific conversation
        final filteredMessages = allMessages.where((message) {
          // Match by contact name or mechanic ID
          final messageMechanicName = message['service_requests']?['service_providers']?['business_name'] ?? '';
          return messageMechanicName == widget.contactName ||
                 message['sender_id'] == widget.mechanicId ||
                 message['receiver_id'] == widget.mechanicId;
        }).toList();

        setState(() {
          _messages = filteredMessages;
          _isLoading = false;
        });

        // Mark individual messages as read
        for (final message in filteredMessages) {
          if (!(message['is_read'] ?? false) && message['receiver_id'] == userId) {
            await UserDataService.markMessageAsRead(message['id']);
          }
        }

        _scrollToBottom();
      } else {
        // Load dummy messages if not authenticated
        _loadDummyMessages();
      }
    } catch (e) {
      print('Error loading messages: $e');
      // Fallback to dummy messages
      _loadDummyMessages();
    }
  }

  void _loadDummyMessages() {
    setState(() {
      _messages = [
        {
          'id': '1',
          'message': 'Hello! I\'m on my way to your location.',
          'sender_id': 'mechanic_123',
          'recipient_id': 'user_456',
          'created_at': DateTime.now().subtract(const Duration(minutes: 10)).toIso8601String(),
          'is_read': true,
          'sender_name': widget.contactName,
        },
        {
          'id': '2',
          'message': 'Great! How long will it take?',
          'sender_id': 'user_456',
          'recipient_id': 'mechanic_123',
          'created_at': DateTime.now().subtract(const Duration(minutes: 8)).toIso8601String(),
          'is_read': true,
          'sender_name': 'You',
        },
        {
          'id': '3',
          'message': 'Approximately 15 minutes. I have all the tools needed for battery replacement.',
          'sender_id': 'mechanic_123',
          'recipient_id': 'user_456',
          'created_at': DateTime.now().subtract(const Duration(minutes: 5)).toIso8601String(),
          'is_read': true,
          'sender_name': widget.contactName,
        },
        {
          'id': '4',
          'message': 'Perfect! I\'ll be waiting. Thank you!',
          'sender_id': 'user_456',
          'recipient_id': 'mechanic_123',
          'created_at': DateTime.now().subtract(const Duration(minutes: 2)).toIso8601String(),
          'is_read': false,
          'sender_name': 'You',
        },
      ];
      _isLoading = false;
    });
    _scrollToBottom();
  }  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _isSending) return;

    final messageText = _messageController.text.trim();
    _messageController.clear();

    setState(() {
      _isSending = true;
    });

    try {
      if (widget.serviceRequestId != null && _otherUser != null) {
        // Send message through MessagingService
        final result = await MessagingService.sendMessage(
          requestId: widget.serviceRequestId!,
          receiverId: _otherUser!['id'],
          content: messageText,
        );

        if (result['success']) {
          // Force refresh messages to ensure immediate display
          await _forceRefreshMessages();
          
          // Show success feedback
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Message sent'),
                duration: Duration(seconds: 1),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message']),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else if (widget.mechanicId != null && widget.serviceRequestId != null) {
        // Fallback to UserDataService
        await UserDataService.sendMessage(
          serviceRequestId: widget.serviceRequestId!,
          receiverId: widget.mechanicId!,
          message: messageText,
        );
        
        // Force refresh messages
        await _forceRefreshMessages();
      } else {
        // Add message locally for demo
        setState(() {
          _messages.add({
            'id': DateTime.now().millisecondsSinceEpoch.toString(),
            'content': messageText,
            'sender_id': AuthService.instance.userId ?? 'user_456',
            'receiver_id': widget.mechanicId ?? 'mechanic_123',
            'created_at': DateTime.now().toIso8601String(),
            'is_read': false,
          });
        });
        _scrollToBottom();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send message: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isSending = false;
      });
    }}
  /// Force refresh messages to ensure immediate display after sending
  Future<void> _forceRefreshMessages() async {
    if (widget.serviceRequestId == null) return;
    
    try {
      // Cancel the existing subscription temporarily
      _messagesSubscription?.cancel();
      
      // Get fresh messages directly
      final messages = await MessagingService.getMessagesForRequest(widget.serviceRequestId!);
      
      if (mounted) {
        setState(() {
          _messages = messages;
          _isLoading = false;
        });
        _scrollToBottom();
      }
      
      // Restart the real-time listener with better error handling
      _messagesSubscription = MessagingService.listenToMessages(widget.serviceRequestId!).listen(
        (messages) {
          if (mounted) {
            setState(() {
              _messages = messages;
            });
            _scrollToBottom();
          }
        },
        onError: (error) {
          print('❌ Error listening to messages: $error');
          // Try to restart the listener after a delay
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted && widget.serviceRequestId != null) {
              _forceRefreshMessages();
            }
          });
        },
      );
    } catch (e) {
      print('❌ Error force refreshing messages: $e');
      // Fallback to periodic refresh if real-time fails
      if (mounted) {
        Timer.periodic(const Duration(seconds: 3), (timer) {
          if (!mounted) {
            timer.cancel();
            return;
          }
          _refreshMessagesQuietly();
        });
      }
    }
  }
  
  /// Quietly refresh messages without disrupting UI
  Future<void> _refreshMessagesQuietly() async {
    if (widget.serviceRequestId == null || _isSending) return;
    
    try {
      final messages = await MessagingService.getMessagesForRequest(widget.serviceRequestId!);
      
      if (mounted && messages.length != _messages.length) {
        setState(() {
          _messages = messages;
        });
        _scrollToBottom();
      }
    } catch (e) {
      // Ignore errors in quiet refresh
    }
  }

  void _showOptionsMenu() {
    // Check if there's an active service that might be in progress
    // This is a basic check - in a real app you'd have proper service status tracking
    final bool hasActiveService = widget.serviceRequestId != null;
    
    showModalBottomSheet(
      context: context,
      isDismissible: !hasActiveService, // Prevent dismissal if there's an active service
      enableDrag: !hasActiveService, // Prevent drag dismissal if there's an active service
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.location_on, color: Color.fromARGB(255, 176, 12, 1)),
              title: const Text('Share Location'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Location sharing feature coming soon')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color.fromARGB(255, 176, 12, 1)),
              title: const Text('Send Photo'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Photo sharing feature coming soon')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.phone, color: Color.fromARGB(255, 176, 12, 1)),
              title: const Text('Call Mechanic'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Calling feature coming soon')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(String timestamp) {
    try {
      final dateTime = DateTime.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inDays > 0) {
        return '${difference.inDays}d ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours}h ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes}m ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return 'Now';
    }
  }

  bool _isMyMessage(Map<String, dynamic> message) {
    final authService = AuthService.instance;
    final userId = authService.userId;
    
    if (userId != null) {
      return message['sender_id'] == userId;
    }
    
    // Fallback for demo - check if sender_name is "You"
    return message['sender_name'] == 'You';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundImage: AssetImage(widget.contactAvatar),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.contactName,
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    widget.lastSeen,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.black),
            onPressed: _showOptionsMenu,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color.fromARGB(255, 176, 12, 1),
                    ),
                  )
                : _messages.isEmpty
                    ? const Center(
                        child: Text(
                          'No messages yet\nStart a conversation!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 16,
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message = _messages[index];
                          final isMe = _isMyMessage(message);
                            return ChatBubble(                            text: message['message'] ?? '',  // Corrected: use message
                            isMe: isMe,
                            timestamp: _formatTime(message['sent_at'] ?? ''),  // Corrected: use sent_at
                          );
                        },
                      ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: Colors.grey, width: 0.5),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey[100],
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: const BoxDecoration(
                    color: Color.fromARGB(255, 176, 12, 1),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: _isSending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send, color: Colors.white),
                    onPressed: _isSending ? null : _sendMessage,
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

class ChatBubble extends StatelessWidget {
  final String text;
  final bool isMe;
  final String timestamp;

  const ChatBubble({
    super.key,
    required this.text,
    required this.isMe,
    required this.timestamp,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            const CircleAvatar(
              radius: 12,
              backgroundColor: Colors.grey,
              child: Icon(Icons.person, size: 16, color: Colors.white),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? const Color.fromARGB(255, 176, 12, 1) : Colors.grey[200],
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    text,
                    style: TextStyle(
                      color: isMe ? Colors.white : Colors.black,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    timestamp,
                    style: TextStyle(
                      color: isMe ? Colors.white70 : Colors.grey[600],
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: 8),
            const CircleAvatar(
              radius: 12,
              backgroundColor: Color.fromARGB(255, 176, 12, 1),
              child: Icon(Icons.person, size: 16, color: Colors.white),
            ),
          ],
        ],
      ),
    );
  }
}










