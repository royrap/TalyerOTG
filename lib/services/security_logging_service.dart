import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';

class SecurityLoggingService {
  static final _supabase = Supabase.instance.client;

  /// Log security events like login, logout, password changes, etc.
  static Future<void> logSecurityEvent({
    required String userId,
    required String actionType,
    required bool success,
    String? ipAddress,
    String? userAgent,
    Map<String, dynamic>? details,
    Map<String, dynamic>? locationInfo,
  }) async {
    try {
      await _supabase.from('account_security_logs').insert({
        'user_id': userId,
        'action_type': actionType,
        'success': success,
        'ip_address': ipAddress,
        'user_agent': userAgent ?? Platform.operatingSystem,
        'details': details,
        'location_info': locationInfo,
        'created_at': DateTime.now().toIso8601String(),
      });
      
      print('✅ Security event logged: $actionType for user $userId');
    } catch (e) {
      print('❌ Failed to log security event: $e');
      // Don't throw error - logging failure shouldn't break the app
    }
  }

  /// Log profile updates
  static Future<void> logProfileUpdate({
    required String userId,
    required String fieldName,
    String? oldValue,
    String? newValue,
    required String updateType,
    String? updatedBy,
    String? ipAddress,
    String? userAgent,
  }) async {
    try {
      await _supabase.from('profile_updates').insert({
        'user_id': userId,
        'field_name': fieldName,
        'old_value': oldValue,
        'new_value': newValue,
        'update_type': updateType,
        'updated_by': updatedBy ?? userId,
        'ip_address': ipAddress,
        'user_agent': userAgent ?? Platform.operatingSystem,
        'created_at': DateTime.now().toIso8601String(),
      });
      
      print('✅ Profile update logged: $fieldName for user $userId');
    } catch (e) {
      print('❌ Failed to log profile update: $e');
    }
  }

  /// Log profile image changes
  static Future<void> logProfileImageChange({
    required String userId,
    String? oldImageUrl,
    String? newImageUrl,
    required String uploadStatus,
    int? fileSize,
    String? fileType,
    String uploadSource = 'profile_update',
  }) async {
    try {
      await _supabase.from('profile_image_logs').insert({
        'user_id': userId,
        'old_image_url': oldImageUrl,
        'new_image_url': newImageUrl,
        'upload_status': uploadStatus,
        'file_size': fileSize,
        'file_type': fileType,
        'upload_source': uploadSource,
        'created_at': DateTime.now().toIso8601String(),
      });
      
      print('✅ Profile image change logged for user $userId');
    } catch (e) {
      print('❌ Failed to log profile image change: $e');
    }
  }

  /// Get recent security events for a user
  static Future<List<Map<String, dynamic>>> getUserSecurityLogs({
    required String userId,
    int limit = 50,
  }) async {
    try {
      final response = await _supabase
          .from('account_security_logs')
          .select('*')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(limit);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('❌ Failed to get security logs: $e');
      return [];
    }
  }

  /// Get recent profile updates for a user
  static Future<List<Map<String, dynamic>>> getUserProfileUpdates({
    required String userId,
    int limit = 50,
  }) async {
    try {
      final response = await _supabase
          .from('profile_updates')
          .select('*')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(limit);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('❌ Failed to get profile updates: $e');
      return [];
    }
  }

  /// Log admin activity
  static Future<void> logAdminActivity({
    required String adminId,
    required String actionType,
    required String targetType,
    required String targetId,
    required Map<String, dynamic> actionDetails,
    String? ipAddress,
    String? userAgent,
    String? sessionId,
  }) async {
    try {
      await _supabase.from('admin_activity_logs').insert({
        'admin_id': adminId,
        'action_type': actionType,
        'target_type': targetType,
        'target_id': targetId,
        'action_details': actionDetails,
        'ip_address': ipAddress,
        'user_agent': userAgent ?? Platform.operatingSystem,
        'session_id': sessionId,
        'created_at': DateTime.now().toIso8601String(),
      });
      
      print('✅ Admin activity logged: $actionType by $adminId');
    } catch (e) {
      print('❌ Failed to log admin activity: $e');
    }
  }
}










