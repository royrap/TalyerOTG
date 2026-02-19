import '../services/supabase_service.dart';

class ShopNotificationService {
  // Get unread notifications for a specific shop
  static Future<List<Map<String, dynamic>>> getShopNotifications(String shopId) async {
    try {
      final response = await SupabaseService.client
          .from('shop_notifications')
          .select('''
            id,
            notification_type,
            title,
            message,
            data,
            created_at,
            related_request_id,
            is_read
          ''')
          .eq('shop_id', shopId)
          .order('created_at', ascending: false)
          .limit(50);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching shop notifications: $e');
      return [];
    }
  }

  // Get only unread notifications for a shop
  static Future<List<Map<String, dynamic>>> getUnreadShopNotifications(String shopId) async {
    try {
      final response = await SupabaseService.client
          .from('shop_notifications')
          .select('''
            id,
            notification_type,
            title,
            message,
            data,
            created_at,
            related_request_id
          ''')
          .eq('shop_id', shopId)
          .eq('is_read', false)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching unread shop notifications: $e');
      return [];
    }
  }

  // Mark notification as read
  static Future<bool> markNotificationAsRead(String notificationId) async {
    try {
      await SupabaseService.client
          .from('shop_notifications')
          .update({'is_read': true, 'read_at': DateTime.now().toIso8601String()})
          .eq('id', notificationId);
      
      return true;
    } catch (e) {
      print('Error marking notification as read: $e');
      return false;
    }
  }

  // Get service requests for a specific shop
  static Future<List<Map<String, dynamic>>> getShopServiceRequests(String shopId) async {
    try {
      final response = await SupabaseService.client
          .from('service_requests')
          .select('''
            id,
            customer_id,
            title,
            description,
            status,
            pickup_address,
            estimated_price,
            created_at,
            vehicle_info,
            pickup_latitude,
            pickup_longitude,
            user_profiles!customer_id (
              first_name,
              last_name,
              phone_number,
              email
            )
          ''')
          .eq('shop_id', shopId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching shop service requests: $e');
      return [];
    }
  }

  // Create a manual notification (for testing or admin purposes)
  static Future<bool> createShopNotification({
    required String shopId,
    required String shopOwnerId,
    required String notificationType,
    required String title,
    required String message,
    Map<String, dynamic>? data,
    String? relatedRequestId,
  }) async {
    try {
      await SupabaseService.client
          .from('shop_notifications')
          .insert({
            'shop_id': shopId,
            'shop_owner_id': shopOwnerId,
            'notification_type': notificationType,
            'title': title,
            'message': message,
            'data': data ?? {},
            'related_request_id': relatedRequestId,
          });
      
      return true;
    } catch (e) {
      print('Error creating shop notification: $e');
      return false;
    }
  }

  // Subscribe to real-time notifications for a shop
  static Stream<List<Map<String, dynamic>>> subscribeToShopNotifications(String shopId) {
    return SupabaseService.client
        .from('shop_notifications')
        .stream(primaryKey: ['id'])
        .eq('shop_id', shopId)
        .order('created_at', ascending: false)
        .map((data) => List<Map<String, dynamic>>.from(data));
  }

  // Subscribe to real-time service requests for a shop
  static Stream<List<Map<String, dynamic>>> subscribeToShopServiceRequests(String shopId) {
    return SupabaseService.client
        .from('service_requests')
        .stream(primaryKey: ['id'])
        .eq('shop_id', shopId)
        .order('created_at', ascending: false)
        .map((data) => List<Map<String, dynamic>>.from(data));
  }

  // Get notification count for a shop
  static Future<int> getUnreadNotificationCount(String shopId) async {
    try {
      final response = await SupabaseService.client
          .from('shop_notifications')
          .select('id')
          .eq('shop_id', shopId)
          .eq('is_read', false)
          .count();

      return response.count;
    } catch (e) {
      print('Error getting notification count: $e');
      return 0;
    }
  }

  // Validate that shop can access service request
  static Future<bool> validateShopAccess(String shopId, String requestId) async {
    try {
      final response = await SupabaseService.client
          .from('service_requests')
          .select('id')
          .eq('shop_id', shopId)
          .eq('id', requestId)
          .maybeSingle();

      return response != null;
    } catch (e) {
      print('Error validating shop access: $e');
      return false;
    }
  }
}
