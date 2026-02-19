import 'package:flutter/material.dart';
import 'chat_screen.dart';
import '../services/auth_service.dart';
import '../services/messaging_service.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key}));

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  String _selectedFilter = 'all'; // 'all', 'unread', 'mechanics'
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _conversations = [];
  List<Map<String, dynamic>> _mechanicConversations = [];

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadConversations() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final authService = AuthService.instance;
      final userId = authService.userId;
      
      print('🔍 Loading conversations for user: $userId');
      
      if (userId != null) {
        // Load regular conversations
        await _loadRegularConversations(userId);
        
        // Load mechanic conversations
        await _loadMechanicConversations();
        
        print('📊 Loaded ${_conversations.length} regular conversations');
        print('🔧 Loaded ${_mechanicConversations.length} mechanic conversations');
        
        setState(() {
          _isLoading = false;
        });
      } else {
        print('⚠️ No authenticated user, loading dummy data');
        _loadDummyConversations();
      }
    } catch (e) {
      print('❌ Error loading conversations: $e');
      _loadDummyConversations();
    }
  }
  Future<void> _loadRegularConversations(String userId) async {
    try {
      print('🔍 Starting to load regular conversations for user: $userId');
      
      // Use the MessagingService to get conversations
      final conversations = await MessagingService.getUserConversations();
      print('📥 MessagingService returned ${conversations.length} conversations');
      print('📋 Raw conversations data: $conversations');
      
      // Build conversation list with last messages
      final List<Map<String, dynamic>> conversationList = [];
      
      for (final conversation in conversations) {
        final requestId = conversation['id'];
        final issueTitle = conversation['issue_title'] ?? 'Service Request';
        final status = conversation['status'] ?? 'pending';
        
        print('🔍 Processing conversation: $requestId - $issueTitle');

        // Get last message for this conversation
        final lastMessage = await MessagingService.getLastMessage(requestId);
        print('📨 Last message for $requestId: $lastMessage');
        
        // Check if the current user can see this message
        bool canSeeMessage = true;
        if (lastMessage != null) {
          final receiverId = lastMessage['receiver_id'];
          final senderId = lastMessage['sender_id'];
          
          // User can see the message if they are receiver OR sender
          canSeeMessage = (receiverId == userId || senderId == userId);
          print('📨 Message visibility for request $requestId: $canSeeMessage (receiver: $receiverId, sender: $senderId, user: $userId)');
        }
        
        // Determine the other party (mechanic or customer)
        String otherPartyName = 'Unknown';
        String otherPartyId = '';
        
        if (conversation['customer_id'] == userId) {
          // Current user is customer, other party is mechanic
          final serviceProvider = conversation['service_providers'];
          if (serviceProvider != null && serviceProvider['user_profiles'] != null) {
            final mechanicProfile = serviceProvider['user_profiles'];
            otherPartyName = '${mechanicProfile['first_name'] ?? ''} ${mechanicProfile['last_name'] ?? ''}';
            otherPartyId = mechanicProfile['id'];
          }
        } else {
          // Current user is mechanic, other party is customer
          final customerProfile = conversation['user_profiles'];
          if (customerProfile != null) {
            otherPartyName = '${customerProfile['first_name'] ?? ''} ${customerProfile['last_name'] ?? ''}';
            otherPartyId = customerProfile['id'];
          }
        }
        
        print('👤 Other party: $otherPartyName (ID: $otherPartyId)');
        
        // Only add conversation if user can see the last message
        if (canSeeMessage || lastMessage == null) {  // Modified: Allow conversations without messages
          conversationList.add({
            'id': requestId,
            'name': otherPartyName.trim().isNotEmpty ? otherPartyName.trim() : 'Unknown User',
            'otherPartyId': otherPartyId,
            'lastMessage': lastMessage?['message'] ?? 'No messages yet',
            'timestamp': lastMessage?['sent_at'] ?? conversation['created_at'],
            'isUnread': lastMessage != null && 
                       !(lastMessage['is_read'] ?? false) && 
                       lastMessage['receiver_id'] == userId, // Only unread if current user is receiver
            'issueTitle': issueTitle,
            'status': status,
            'avatar': otherPartyName.trim().isNotEmpty ? otherPartyName.trim()[0].toUpperCase() : 'U',
          });
          
          print('✅ Added conversation with ${otherPartyName}');
        } else {
          print('❌ Skipped conversation - user cannot see message');
        }
      }

      print('📊 Final conversation list: ${conversationList.length} conversations');
      _conversations = conversationList;
    } catch (e) {
      print('❌ Error loading regular conversations: $e');
      print('📊 Stack trace: $e');
      _conversations = [];
    }
  }

  Future<void> _loadMechanicConversations() async {
    try {
      final conversations = await MessagingService.getUserConversations();
      final List<Map<String, dynamic>> mechanicConversationList = [];
      
      for (final conversation in conversations) {
        final requestId = conversation['id'];
        final issueTitle = conversation['issue_title'] ?? 'Service Request';
        final status = conversation['status'] ?? 'pending';

        // Get last message for this conversation
        final lastMessage = await MessagingService.getLastMessage(requestId);
        
        final currentUserId = AuthService.instance.userId;
        bool canSeeMessage = true;
        bool isUnread = false;
        
        if (lastMessage != null && currentUserId != null) {
          final receiverId = lastMessage['receiver_id'];
          final senderId = lastMessage['sender_id'];
          
          canSeeMessage = (receiverId == currentUserId || senderId == currentUserId);
          isUnread = (receiverId == currentUserId && !(lastMessage['is_read'] ?? false));
        }
        
        // Determine the other party (mechanic)
        String mechanicName = 'Unknown Mechanic';
        String mechanicId = '';
        
        final serviceProvider = conversation['service_providers'];
        if (serviceProvider != null && serviceProvider['user_profiles'] != null) {
          final mechanicProfile = serviceProvider['user_profiles'];
          mechanicName = '${mechanicProfile['first_name'] ?? ''} ${mechanicProfile['last_name'] ?? ''}';
          mechanicId = mechanicProfile['id'];
        }
        
        if (canSeeMessage) {
          mechanicConversationList.add({
            'id': requestId,
            'name': mechanicName.trim().isNotEmpty ? mechanicName.trim() : 'Unknown Mechanic',
            'otherPartyId': mechanicId,
            'lastMessage': lastMessage?['message'] ?? 'No messages yet',
            'timestamp': lastMessage?['sent_at'] ?? conversation['created_at'],
            'isUnread': isUnread,
            'issueTitle': issueTitle,
            'status': status,
            'avatar': mechanicName.trim().isNotEmpty ? mechanicName.trim()[0].toUpperCase() : 'M',
            'userType': 'mechanic',
          });
        }
      }

      _mechanicConversations = mechanicConversationList;
    } catch (e) {
      print('❌ Error loading mechanic conversations: $e');
      _mechanicConversations = [];
    }
  }

  void _loadDummyConversations() {
    setState(() {
      _conversations = [
        {
          'id': 'service_001',
          'name': 'Pedro\'s Auto Repair',
          'otherPartyId': 'mechanic_001',
          'lastMessage': 'I\'m on my way to your location.',
          'timestamp': DateTime.now().subtract(const Duration(minutes: 5)).toIso8601String(),
          'isUnread': true,
          'issueTitle': 'Battery Replacement',
          'status': 'in_progress',
          'avatar': 'P',
        },
        {
          'id': 'service_002',
          'name': 'QuickFix Motors',
          'otherPartyId': 'mechanic_002',
          'lastMessage': 'Service completed. Thank you!',
          'timestamp': DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
          'isUnread': false,
          'issueTitle': 'Tire Change',
          'status': 'completed',
          'avatar': 'Q',
        },
      ];
      
      _mechanicConversations = _conversations;
      _isLoading = false;
    });
  }

  Future<void> _markConversationAsRead(String conversationId) async {
    try {
      final authService = AuthService.instance;
      final userId = authService.userId;
      
      if (userId != null) {
        await MessagingService.markMessagesAsRead(conversationId, userId);
        
        // Update local state
        setState(() {
          final conversationIndex = _conversations.indexWhere((c) => c['id'] == conversationId);
          if (conversationIndex != -1) {
            _conversations[conversationIndex]['isUnread'] = false;
          }
          
          final mechanicConversationIndex = _mechanicConversations.indexWhere((c) => c['id'] == conversationId);
          if (mechanicConversationIndex != -1) {
            _mechanicConversations[mechanicConversationIndex]['isUnread'] = false;
          }
        });
      }
    } catch (e) {
      print('Error marking conversation as read: $e');
    }
  }

  List<Map<String, dynamic>> get _filteredConversations {
    List<Map<String, dynamic>> sourceList = _selectedFilter == 'mechanics' 
        ? _mechanicConversations 
        : _conversations;
    
    switch (_selectedFilter) {
      case 'unread':
        return sourceList.where((c) => c['isUnread'] == true).toList();
      case 'mechanics':
        return _mechanicConversations;
      default:
        return sourceList;
    }
  }

  String _getLastSeen(String timestamp) {
    try {
      final messageTime = DateTime.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(messageTime);
      
      if (difference.inMinutes < 1) {
        return 'Just now';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}h ago';
      } else {
        return '${difference.inDays}d ago';
      }
    } catch (e) {
      return 'Now';
    }
  }

  String _formatTime(String timestamp) {
    try {
      final messageTime = DateTime.parse(timestamp);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final messageDate = DateTime(messageTime.year, messageTime.month, messageTime.day);
      
      if (messageDate == today) {
        return '${messageTime.hour.toString().padLeft(2, '0')}:${messageTime.minute.toString().padLeft(2, '0')}';
      } else {
        return '${messageTime.day}/${messageTime.month}';
      }
    } catch (e) {
      return 'Now';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Messages',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black),
            onPressed: () {
              print('🔄 Refreshing conversations...');
              _loadConversations();
            },
          ),
          IconButton(
            icon: const Icon(Icons.search, color: Colors.black),
            onPressed: () {
              // Implement search functionality
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search conversations...',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
          
          // Filter tabs
          Container(
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedFilter = 'all';
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: _selectedFilter == 'all' ? Colors.black : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        color: _selectedFilter == 'all' ? Colors.white : Colors.grey[100],
                      ),
                      child: Text(
                        'All',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _selectedFilter == 'all' ? Colors.black : Colors.grey,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedFilter = 'unread';
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: _selectedFilter == 'unread' ? Colors.black : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        color: _selectedFilter == 'unread' ? Colors.white : Colors.grey[100],
                      ),
                      child: Text(
                        'Unread',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _selectedFilter == 'unread' ? Colors.black : Colors.grey,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedFilter = 'mechanics';
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: _selectedFilter == 'mechanics' ? Colors.black : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        color: _selectedFilter == 'mechanics' ? Colors.white : Colors.grey[100],
                      ),
                      child: Text(
                        'Mechanics',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _selectedFilter == 'mechanics' ? Colors.black : Colors.grey,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Conversations list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredConversations.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.message, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text(
                              _selectedFilter == 'mechanics' 
                                  ? 'No messages from mechanics'
                                  : _selectedFilter == 'unread'
                                      ? 'No unread messages'
                                      : 'No conversations found',
                              style: TextStyle(fontSize: 18, color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _filteredConversations.length,
                        itemBuilder: (context, index) {
                          final conversation = _filteredConversations[index];
                          return ConversationListItem(
                            name: conversation['name'],
                            lastMessage: conversation['lastMessage'],
                            time: _formatTime(conversation['timestamp']),
                            isUnread: conversation['isUnread'],
                            avatar: conversation['avatar'],
                            lastSeen: _getLastSeen(conversation['timestamp']),
                            issueTitle: conversation['issueTitle'],
                            status: conversation['status'],
                            onTap: () {
                              // Navigate to chat screen
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ChatScreen(
                                    contactName: conversation['name'],
                                    contactAvatar: conversation['avatar'],
                                    lastSeen: _getLastSeen(conversation['timestamp']),
                                    serviceRequestId: conversation['id'],
                                    mechanicId: conversation['otherPartyId'],
                                  ),
                                ),
                              ).then((_) {
                                // Mark as read when returning from chat and reload conversations
                                if (conversation['isUnread']) {
                                  _markConversationAsRead(conversation['id']);
                                }
                                _loadConversations();
                              });
                            },
                            onMarkRead: () {
                              _markConversationAsRead(conversation['id']);
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class ConversationListItem extends StatelessWidget {
  final String name;
  final String lastMessage;
  final String time;
  final bool isUnread;
  final String avatar;
  final String lastSeen;
  final String issueTitle;
  final String status;
  final VoidCallback onTap;
  final VoidCallback onMarkRead;

  const ConversationListItem({
    super.key,
    required this.name,
    required this.lastMessage,
    required this.time,
    required this.isUnread,
    required this.avatar,
    required this.lastSeen,
    required this.issueTitle,
    required this.status,
    required this.onTap,
    required this.onMarkRead,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: isUnread ? Colors.blue[50] : Colors.white,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: const Color.fromARGB(255, 176, 12, 1),
          child: Text(
            avatar,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                  fontSize: 16,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              time,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              issueTitle,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Expanded(
                  child: Text(
                    lastMessage,
                    style: TextStyle(
                      color: isUnread ? Colors.black87 : Colors.grey[600],
                      fontWeight: isUnread ? FontWeight.w500 : FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isUnread)
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                    ),
                    margin: const EdgeInsets.only(left: 4),
                  ),
              ],
            ),
          ],
        ),
        trailing: status == 'in_progress'
            ? const Icon(Icons.radio_button_checked, color: Colors.green, size: 16)
            : status == 'completed'
                ? const Icon(Icons.check_circle, color: Colors.grey, size: 16)
                : const Icon(Icons.schedule, color: Colors.orange, size: 16),
        onTap: onTap,
      ),
    );
  }
}










