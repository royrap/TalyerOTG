import 'package:flutter_test/flutter_test.dart';
import 'package:roadaidapp/services/supabase_service.dart';
import 'package:roadaidapp/services/auth_service.dart';
import 'package:roadaidapp/services/messaging_service.dart';

void main() {
  test('Messaging System Diagnosis', () async {
    print('🔍 STARTING MESSAGING SYSTEM DIAGNOSIS');
    print('=' * 50);
    
    try {
      // Initialize Supabase
      await SupabaseService.initialize();
      print('✅ Supabase initialized');
      
      // Check current user
      final authService = AuthService.instance;
      final currentUser = authService.currentUser;
      final userId = authService.userId;
      
      print('👤 Current User: ${currentUser?.email ?? 'None'}');
      print('🆔 User ID: $userId');
      
      if (userId == null) {
        print('❌ No authenticated user found!');
        return;
      }
      
      print('\n📊 CHECKING MESSAGES TABLE');
      print('-' * 30);
      
      // Check all messages for this user
      final supabase = SupabaseService.client;
      
      // Messages where user is sender
      final sentMessages = await supabase
          .from('messages')
          .select('*')
          .eq('sender_id', userId)
          .order('sent_at', ascending: false);
      
      print('📤 Messages sent by user: ${sentMessages.length}');
      for (var msg in sentMessages) {
        print('  - To: ${msg['receiver_id']}, Request: ${msg['request_id']}, Message: "${msg['message']}"');
      }
      
      // Messages where user is receiver
      final receivedMessages = await supabase
          .from('messages')
          .select('*')
          .eq('receiver_id', userId)
          .order('sent_at', ascending: false);
      
      print('📥 Messages received by user: ${receivedMessages.length}');
      for (var msg in receivedMessages) {
        print('  - From: ${msg['sender_id']}, Request: ${msg['request_id']}, Message: "${msg['message']}"');
      }
      
      print('\n🔧 CHECKING SERVICE REQUESTS');
      print('-' * 30);
      
      // Check service requests where user is customer
      final customerRequests = await supabase
          .from('service_requests')
          .select('*')
          .eq('customer_id', userId);
      
      print('👤 Service requests as customer: ${customerRequests.length}');
      for (var req in customerRequests) {
        print('  - Request ${req['id']}: ${req['issue_title']} (Status: ${req['status']})');
      }
      
      // Check service requests where user is mechanic
      final mechanicRequests = await supabase
          .from('service_requests')
          .select('*')
          .eq('service_provider_id', userId);
      
      print('🔧 Service requests as mechanic: ${mechanicRequests.length}');
      for (var req in mechanicRequests) {
        print('  - Request ${req['id']}: ${req['issue_title']} (Status: ${req['status']})');
      }
      
      print('\n📋 TESTING MESSAGING SERVICE');
      print('-' * 30);
      
      // Test getUserConversations
      try {
        final conversations = await MessagingService.getUserConversations();
        print('✅ MessagingService.getUserConversations() returned ${conversations.length} conversations');
        
        for (var conv in conversations) {
          print('  - Conversation ${conv['id']}: ${conv['issue_title']} (Customer: ${conv['customer_id']}, Provider: ${conv['service_provider_id']})');
          
          // Get last message for this conversation
          final lastMessage = await MessagingService.getLastMessage(conv['id']);
          if (lastMessage != null) {
            print('    Last message: "${lastMessage['message']}" (From: ${lastMessage['sender_id']} to ${lastMessage['receiver_id']})');
          } else {
            print('    No messages found');
          }
        }
      } catch (e) {
        print('❌ Error in getUserConversations: $e');
      }
      
      print('\n🎯 DIAGNOSIS COMPLETE');
      print('=' * 50);
      
    } catch (e) {
      print('❌ Error during diagnosis: $e');
    }
  });
}
