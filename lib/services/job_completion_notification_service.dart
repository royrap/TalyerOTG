import 'package:supabase_flutter/supabase_flutter.dart';

class JobCompletionNotificationService {
  static final JobCompletionNotificationService _instance = JobCompletionNotificationService._internal();
  static JobCompletionNotificationService get instance => _instance;
  JobCompletionNotificationService._internal();

  final _supabase = Supabase.instance.client;

  /// Send completion notification to customer
  Future<void> notifyCustomerJobCompleted({
    required String requestId,
    required String customerId,
    required String mechanicId,
    required String mechanicName,
    required double paymentAmount,
  }) async {
    try {
      print('📱 Sending job completion notification to customer');

      // Insert notification message in chat
      await _supabase.from('messages').insert({
        'request_id': requestId,
        'sender_id': mechanicId,
        'receiver_id': customerId,
  'message': '✅ Job completed successfully! Thank you for using RoadAid. Your payment of ₱${paymentAmount.toStringAsFixed(2)} has been processed and released to $mechanicName. We hope you had a great experience!',
        'sent_at': DateTime.now().toIso8601String(),
        'is_read': false,
        'message_type': 'job_completion',
      });

      // Create in-app notification
      await _supabase.from('notifications').insert({
        'user_id': customerId,
        'title': 'Job Completed Successfully!',
        'message': 'Your roadside assistance service has been completed. Payment has been processed.',
        'type': 'job_completion',
        'related_id': requestId,
        'created_at': DateTime.now().toIso8601String(),
        'is_read': false,
      });

      print('📱 Customer completion notification sent');
    } catch (e) {
      print('❌ Error sending customer completion notification: $e');
    }
  }

  /// Send completion notification to admin dashboard
  Future<void> notifyAdminJobCompleted({
    required String requestId,
    required String customerId,
    required String mechanicId,
    required double paymentAmount,
    required String serviceType,
  }) async {
    try {
      print('📊 Sending job completion notification to admin');

      // Get customer and mechanic details
      final customerData = await _supabase
          .from('user_profiles')
          .select('first_name, last_name, phone_number')
          .eq('id', customerId)
          .single();

      final mechanicData = await _supabase
          .from('user_profiles')
          .select('first_name, last_name, phone_number')
          .eq('id', mechanicId)
          .single();

      final customerName = '${customerData['first_name']} ${customerData['last_name']}';
      final mechanicName = '${mechanicData['first_name']} ${mechanicData['last_name']}';

      // Create admin notification/alert
      await _supabase.from('admin_alerts').insert({
        'alert_type': 'job_completed',
        'title': 'Job Completed - Payment Released',
  'message': 'Job $requestId completed. Customer: $customerName, Mechanic: $mechanicName, Payment: ₱${paymentAmount.toStringAsFixed(2)}',
        'priority': 'info',
        'related_data': {
          'request_id': requestId,
          'customer_id': customerId,
          'mechanic_id': mechanicId,
          'payment_amount': paymentAmount,
          'service_type': serviceType,
          'customer_name': customerName,
          'mechanic_name': mechanicName,
        },
        'created_at': DateTime.now().toIso8601String(),
        'is_resolved': false,
      });

      print('📊 Admin completion notification sent');
    } catch (e) {
      print('❌ Error sending admin completion notification: $e');
    }
  }

  /// Send payment release notification to mechanic
  Future<void> notifyMechanicPaymentReleased({
    required String requestId,
    required String mechanicId,
    required String customerId,
    required double paymentAmount,
  }) async {
    try {
      print('💰 Sending payment release notification to mechanic');

      // Get customer details
      final customerData = await _supabase
          .from('user_profiles')
          .select('first_name, last_name')
          .eq('id', customerId)
          .single();

      final customerName = '${customerData['first_name']} ${customerData['last_name']}';

      // Send chat message to mechanic
      await _supabase.from('messages').insert({
        'request_id': requestId,
        'sender_id': customerId,
        'receiver_id': mechanicId,
  'message': '💰 Payment Released! Job for $customerName has been completed and payment of ₱${paymentAmount.toStringAsFixed(2)} has been released to your account. Great work!',
        'sent_at': DateTime.now().toIso8601String(),
        'is_read': false,
        'message_type': 'payment_release',
      });

      // Create in-app notification for mechanic
      await _supabase.from('notifications').insert({
        'user_id': mechanicId,
        'title': 'Payment Released!',
  'message': 'Payment of ₱${paymentAmount.toStringAsFixed(2)} has been released to your account.',
        'type': 'payment_release',
        'related_id': requestId,
        'created_at': DateTime.now().toIso8601String(),
        'is_read': false,
      });

      print('💰 Mechanic payment notification sent');
    } catch (e) {
      print('❌ Error sending mechanic payment notification: $e');
    }
  }

  /// Send push notification (if push service is implemented)
  Future<void> sendPushNotification({
    required String userId,
    required String title,
    required String message,
    Map<String, dynamic>? data,
  }) async {
    try {
      // This would integrate with your push notification service
      // For now, we'll just log it
      print('📱 Push notification: $title - $message to user $userId');
      
      // You can integrate with Firebase Cloud Messaging, OneSignal, etc.
      // Example implementation would go here
      
    } catch (e) {
      print('❌ Error sending push notification: $e');
    }
  }
}










