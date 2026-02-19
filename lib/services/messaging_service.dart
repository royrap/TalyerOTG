import 'supabase_service.dart';
import 'auth_service.dart';

class MessagingService {
  static final _client = SupabaseService.client;
    /// Send message from customer to mechanic (or vice versa)
  static Future<Map<String, dynamic>> sendMessage({
    required String requestId,
    required String receiverId, 
    required String content,
    String messageType = 'text',
  }) async {
    try {
      final senderId = AuthService.instance.userId;
      if (senderId == null) {
        return {'success': false, 'message': 'User not authenticated'};
      }

      print('📤 Sending message from $senderId to $receiverId for request $requestId');
      print('📝 Message content: "$content"');
      
      await _client.from('messages').insert({
        'request_id': requestId,  // Corrected: use request_id
        'sender_id': senderId,
        'receiver_id': receiverId,
        'message': content,  // Corrected: use message
        'is_read': false,
        'sent_at': DateTime.now().toIso8601String(),  // Corrected: use sent_at
      });

      print('✅ Message sent successfully to database');
      
      // Verify the message was inserted
      final verifyMessage = await _client
          .from('messages')
          .select('*')
          .eq('request_id', requestId)
          .eq('sender_id', senderId)
          .order('sent_at', ascending: false)
          .limit(1)
          .maybeSingle();
          
      if (verifyMessage != null) {
        print('✅ Message verification successful: ${verifyMessage['message']}');
      } else {
        print('⚠️ Message verification failed - message not found in database');
      }
      
      return {'success': true, 'message': 'Message sent successfully'};
    } catch (e) {
      print('❌ Error sending message: $e');
      return {'success': false, 'message': 'Failed to send message: $e'};
    }
  }
  /// Get messages for a specific service request
  static Future<List<Map<String, dynamic>>> getMessagesForRequest(String requestId) async {
    try {
      print('📥 Getting messages for request: $requestId');
      
      final response = await _client
          .from('messages')
          .select('''
            *,
            sender:sender_id!inner(first_name, last_name, user_type),
            receiver:receiver_id!inner(first_name, last_name, user_type)
          ''')
          .eq('request_id', requestId)  // Corrected: use request_id
          .order('sent_at', ascending: true);  // Corrected: use sent_at

      print('✅ Retrieved ${response.length} messages for request $requestId');
      
      // Debug: Print message details
      for (var i = 0; i < response.length && i < 3; i++) {
        final msg = response[i];
        print('  Message ${i + 1}: "${msg['message']}" from ${msg['sender_id']} to ${msg['receiver_id']}');
      }
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('❌ Error getting messages: $e');
      return [];
    }
  }

  /// Mark messages as read
  static Future<bool> markMessagesAsRead(String requestId, String userId) async {
    try {      await _client
          .from('messages')
          .update({'is_read': true})  // Removed unnecessary updated_at
          .eq('request_id', requestId)  // Corrected: use request_id
          .eq('receiver_id', userId);
      
      print('✅ Messages marked as read for user $userId');
      return true;
    } catch (e) {
      print('❌ Error marking messages as read: $e');
      return false;
    }
  }

  /// Get unread message count for a user
  static Future<int> getUnreadMessageCount(String userId) async {
    try {
      final response = await _client
          .from('messages')
          .select('id')
          .eq('receiver_id', userId)
          .eq('is_read', false);
      
      return response.length;
    } catch (e) {
      print('❌ Error getting unread count: $e');
      return 0;
    }
  }
  /// Listen to real-time messages for a request
  static Stream<List<Map<String, dynamic>>> listenToMessages(String requestId) {
    print('🔄 Starting real-time message listener for request: $requestId');
      return _client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('request_id', requestId)  // Corrected: use request_id
        .order('sent_at', ascending: true)  // Corrected: use sent_at
        .map((data) => List<Map<String, dynamic>>.from(data));
  }

  /// Get mechanic info for a service request
  static Future<Map<String, dynamic>?> getMechanicForRequest(String requestId) async {
    try {
      final response = await _client
          .from('service_requests')
          .select('''
            provider_id,
            service_providers!inner(
              user_id,
              user_profiles!service_providers_user_id_fkey!inner(id, first_name, last_name, email, phone_number)
            )
          ''')
          .eq('id', requestId)
          .maybeSingle();

      if (response != null && response['service_providers'] != null) {
        final mechanicData = response['service_providers']['user_profiles'];
        print('✅ Found mechanic: ${mechanicData['first_name']} ${mechanicData['last_name']}');
        return mechanicData;
      }
      
      return null;
    } catch (e) {
      print('❌ Error getting mechanic info: $e');
      return null;
    }
  }

  /// Get customer info for a service request
  static Future<Map<String, dynamic>?> getCustomerForRequest(String requestId) async {
    try {
      final response = await _client
          .from('service_requests')
          .select('''
            user_id,
            user_profiles!inner(id, first_name, last_name, email, phone_number)
          ''')
          .eq('id', requestId)
          .maybeSingle();

      if (response != null && response['user_profiles'] != null) {
        final customerData = response['user_profiles'];
        print('✅ Found customer: ${customerData['first_name']} ${customerData['last_name']}');
        return customerData;
      }
      
      return null;
    } catch (e) {
      print('❌ Error getting customer info: $e');
      return null;
    }
  }

  /// Get all conversations for the current user
  static Future<List<Map<String, dynamic>>> getUserConversations() async {
    try {
      final currentUserId = AuthService.instance.userId;
      if (currentUserId == null) return [];      // Get all service requests where user is involved
      final response = await _client
          .from('service_requests')
          .select('''
            id,
            issue_title,
            status,
            created_at,
            user_id,
            service_provider_id,
            user_profiles!inner(first_name, last_name),
            service_providers!inner(
              user_profiles!service_providers_user_id_fkey!inner(first_name, last_name)
            )
          ''')
          .or('user_id.eq.$currentUserId,service_provider_id.eq.$currentUserId')
          .order('created_at', ascending: false);

      print('✅ Found ${response.length} conversations');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('❌ Error getting conversations: $e');
      return [];
    }
  }
  /// Get last message for a conversation
  static Future<Map<String, dynamic>?> getLastMessage(String requestId) async {
    try {
      print('📨 Getting last message for request: $requestId');
      
      final response = await _client
          .from('messages')
          .select('message, sent_at, sender_id, receiver_id, is_read')  // Added receiver_id for debugging
          .eq('request_id', requestId)  // Corrected: use request_id
          .order('sent_at', ascending: false)  // Corrected: use sent_at
          .limit(1)
          .maybeSingle();

      if (response != null) {
        print('✅ Last message found: "${response['message']}" from ${response['sender_id']} to ${response['receiver_id']}');
      } else {
        print('⚠️ No messages found for request $requestId');
      }
      
      return response;
    } catch (e) {
      print('❌ Error getting last message: $e');
      return null;
    }
  }
}










