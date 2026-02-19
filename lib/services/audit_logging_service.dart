import 'dart:convert';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

/// Comprehensive audit logging service for tracking all user activities
/// Supports mechanics, customers, and shop owners (talyer_owner)
class AuditLoggingService {
  final SupabaseClient _supabase = Supabase.instance.client;
  static String? _deviceInfo;
  static String? _sessionId;

  // Initialize device info and session
  static Future<void> initialize() async {
    try {
      final deviceInfoPlugin = DeviceInfoPlugin();
      
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfoPlugin.androidInfo;
        _deviceInfo = '${androidInfo.brand} ${androidInfo.model} (Android ${androidInfo.version.release})';
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfoPlugin.iosInfo;
        _deviceInfo = '${iosInfo.name} ${iosInfo.model} (iOS ${iosInfo.systemVersion})';
      } else {
        _deviceInfo = 'Unknown Device';
      }
      
      _sessionId = _generateSessionId();
    } catch (e) {
      _deviceInfo = 'Device Info Error';
      _sessionId = _generateSessionId();
    }
  }

  static String _generateSessionId() {
    return 'session_${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecond}';
  }

  /// Core audit logging method
  Future<String?> logAuditAction({
    required String? userId,
    required String role,
    required String action,
    String? tableName,
    String? recordId,
    String? ipAddress,
    Map<String, dynamic>? oldValues,
    Map<String, dynamic>? newValues,
    Map<String, dynamic>? additionalData,
    bool success = true,
    String? errorMessage,
  }) async {
    try {
      final response = await _supabase.rpc('log_audit_action', params: {
        'p_user_id': userId,
        'p_role': role,
        'p_action': action,
        'p_table_name': tableName,
        'p_record_id': recordId,
        'p_ip_address': ipAddress,
        'p_user_agent': _deviceInfo,
        'p_session_id': _sessionId,
        'p_old_values': oldValues != null ? jsonEncode(oldValues) : null,
        'p_new_values': newValues != null ? jsonEncode(newValues) : null,
        'p_additional_data': additionalData != null ? jsonEncode(additionalData) : '{}',
        'p_success': success,
        'p_error_message': errorMessage,
      });

      if (kDebugMode) {
        print('✅ Audit Log: [$role] $action - Success: $success');
      }

      return response as String?;
    } catch (e) {
      // Silently fail if audit function doesn't exist - non-critical
      // Only log in debug mode to avoid console spam
      if (kDebugMode && e.toString().contains('PGRST202')) {
        print('⚠️ Audit function not deployed - skipping audit log (non-critical)');
      } else if (kDebugMode) {
        print('❌ Audit logging error: $e');
      }
      return null;
    }
  }

  // ========================================
  // AUTHENTICATION AUDIT METHODS
  // ========================================

  /// Log user login
  Future<void> logUserLogin({
    required String userId,
    required String role,
    String? ipAddress,
    bool success = true,
    String? errorMessage,
  }) async {
    try {
      await _supabase.rpc('log_user_login', params: {
        'p_user_id': userId,
        'p_role': role,
        'p_ip_address': ipAddress,
        'p_user_agent': _deviceInfo,
        'p_session_id': _sessionId,
        'p_success': success,
        'p_error_message': errorMessage,
      });
    } catch (e) {
      if (kDebugMode) print('Login audit error: $e');
    }
  }

  /// Log user logout
  Future<void> logUserLogout({
    required String userId,
    required String role,
  }) async {
    try {
      await _supabase.rpc('log_user_logout', params: {
        'p_user_id': userId,
        'p_role': role,
        'p_session_id': _sessionId,
      });
    } catch (e) {
      if (kDebugMode) print('Logout audit error: $e');
    }
  }

  /// Log registration attempt
  Future<void> logUserRegistration({
    String? userId,
    required String role,
    required String email,
    bool success = true,
    String? errorMessage,
  }) async {
    await logAuditAction(
      userId: userId,
      role: role,
      action: 'USER_REGISTRATION',
      tableName: 'user_profiles',
      recordId: userId,
      newValues: {'email': email},
      additionalData: {
        'registration_timestamp': DateTime.now().toIso8601String(),
      },
      success: success,
      errorMessage: errorMessage,
    );
  }

  // ========================================
  // SERVICE REQUEST AUDIT METHODS
  // ========================================

  /// Log service request creation
  Future<void> logServiceRequestCreated({
    required String customerId,
    required String requestId,
    required Map<String, dynamic> requestData,
  }) async {
    try {
      await _supabase.rpc('log_service_request_action', params: {
        'p_user_id': customerId,
        'p_role': 'customer',
        'p_action': 'SERVICE_REQUEST_CREATED',
        'p_request_id': requestId,
        'p_old_values': null,
        'p_new_values': jsonEncode(requestData),
        'p_additional_data': jsonEncode({
          'service_type': requestData['service_type'] ?? 'unknown',
          'location': {
            'lat': requestData['pickup_latitude'],
            'lng': requestData['pickup_longitude'],
          }
        }),
      });
    } catch (e) {
      if (kDebugMode) print('Service request creation audit error: $e');
    }
  }

  /// Log service request assignment
  Future<void> logServiceRequestAssigned({
    required String mechanicId,
    required String requestId,
    required Map<String, dynamic> assignmentData,
  }) async {
    await logAuditAction(
      userId: mechanicId,
      role: 'mechanic',
      action: 'SERVICE_REQUEST_ASSIGNED',
      tableName: 'service_requests',
      recordId: requestId,
      newValues: assignmentData,
      additionalData: {
        'assignment_timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  /// Log service request completion
  Future<void> logServiceRequestCompleted({
    required String mechanicId,
    required String requestId,
    required Map<String, dynamic> completionData,
  }) async {
    try {
      await _supabase.rpc('log_service_request_action', params: {
        'p_user_id': mechanicId,
        'p_role': 'mechanic',
        'p_action': 'SERVICE_REQUEST_COMPLETED',
        'p_request_id': requestId,
        'p_old_values': null,
        'p_new_values': jsonEncode(completionData),
        'p_additional_data': jsonEncode({
          'completion_timestamp': DateTime.now().toIso8601String(),
          'earnings_calculated': true,
        }),
      });
    } catch (e) {
      if (kDebugMode) print('Service request completion audit error: $e');
    }
  }

  // ========================================
  // QR CODE AUDIT METHODS
  // ========================================

  /// Log QR code generation
  Future<void> logQRCodeGenerated({
    required String customerId,
    required String qrCodeId,
    required String completionCode,
    required String serviceRequestId,
  }) async {
    try {
      await _supabase.rpc('log_qr_code_action', params: {
        'p_user_id': customerId,
        'p_role': 'customer',
        'p_action': 'QR_CODE_GENERATED',
        'p_qr_code_id': qrCodeId,
        'p_completion_code': completionCode,
        'p_service_request_id': serviceRequestId,
        'p_additional_data': jsonEncode({
          'generation_timestamp': DateTime.now().toIso8601String(),
        }),
      });
    } catch (e) {
      if (kDebugMode) print('QR code generation audit error: $e');
    }
  }

  /// Log QR code scanning
  Future<void> logQRCodeScanned({
    required String mechanicId,
    required String qrCodeId,
    required String completionCode,
    required String serviceRequestId,
    required bool success,
    String? errorMessage,
  }) async {
    try {
      await _supabase.rpc('log_qr_code_action', params: {
        'p_user_id': mechanicId,
        'p_role': 'mechanic',
        'p_action': success ? 'QR_CODE_SCANNED_SUCCESS' : 'QR_CODE_SCAN_FAILED',
        'p_qr_code_id': qrCodeId,
        'p_completion_code': completionCode,
        'p_service_request_id': serviceRequestId,
        'p_additional_data': jsonEncode({
          'scan_timestamp': DateTime.now().toIso8601String(),
          'success': success,
          'error_message': errorMessage,
        }),
      });
    } catch (e) {
      if (kDebugMode) print('QR code scanning audit error: $e');
    }
  }

  // ========================================
  // LOCATION TRACKING AUDIT METHODS
  // ========================================

  /// Log location updates
  Future<void> logLocationUpdate({
    required String userId,
    required String role,
    required double latitude,
    required double longitude,
    String? activity,
  }) async {
    try {
      await _supabase.rpc('log_location_update', params: {
        'p_user_id': userId,
        'p_role': role,
        'p_latitude': latitude,
        'p_longitude': longitude,
        'p_activity': activity,
      });
    } catch (e) {
      if (kDebugMode) print('Location update audit error: $e');
    }
  }

  // ========================================
  // EARNINGS AUDIT METHODS
  // ========================================

  /// Log earnings calculation
  Future<void> logEarningsCalculated({
    required String userId,
    required String role,
    required String serviceRequestId,
    required double amount,
    Map<String, dynamic>? earningsBreakdown,
  }) async {
    try {
      await _supabase.rpc('log_earnings_action', params: {
        'p_user_id': userId,
        'p_role': role,
        'p_action': 'EARNINGS_CALCULATED',
        'p_service_request_id': serviceRequestId,
        'p_amount': amount,
        'p_earnings_breakdown': earningsBreakdown != null ? jsonEncode(earningsBreakdown) : null,
      });
    } catch (e) {
      if (kDebugMode) print('Earnings audit error: $e');
    }
  }

  // ========================================
  // SHOP MANAGEMENT AUDIT METHODS
  // ========================================

  /// Log shop-related actions
  Future<void> logShopAction({
    required String ownerId,
    required String action,
    required String shopId,
    Map<String, dynamic>? oldValues,
    Map<String, dynamic>? newValues,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      await _supabase.rpc('log_shop_action', params: {
        'p_user_id': ownerId,
        'p_role': 'talyer_owner',
        'p_action': action,
        'p_shop_id': shopId,
        'p_old_values': oldValues != null ? jsonEncode(oldValues) : null,
        'p_new_values': newValues != null ? jsonEncode(newValues) : null,
        'p_additional_data': additionalData != null ? jsonEncode(additionalData) : '{}',
      });
    } catch (e) {
      if (kDebugMode) print('Shop action audit error: $e');
    }
  }

  // ========================================
  // PROFILE UPDATE AUDIT METHODS
  // ========================================

  /// Log profile updates
  Future<void> logProfileUpdate({
    required String userId,
    required String role,
    required Map<String, dynamic> oldValues,
    required Map<String, dynamic> newValues,
  }) async {
    try {
      await _supabase.rpc('log_profile_update', params: {
        'p_user_id': userId,
        'p_role': role,
        'p_old_values': jsonEncode(oldValues),
        'p_new_values': jsonEncode(newValues),
      });
    } catch (e) {
      if (kDebugMode) print('Profile update audit error: $e');
    }
  }

  // ========================================
  // GENERAL ACTION AUDIT METHODS
  // ========================================

  /// Log mechanic-specific actions
  Future<void> logMechanicAction({
    required String mechanicId,
    required String action,
    Map<String, dynamic>? data,
    String? recordId,
    String? tableName,
  }) async {
    await logAuditAction(
      userId: mechanicId,
      role: 'mechanic',
      action: action,
      tableName: tableName,
      recordId: recordId,
      newValues: data,
      additionalData: {
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  /// Log customer-specific actions
  Future<void> logCustomerAction({
    required String customerId,
    required String action,
    Map<String, dynamic>? data,
    String? recordId,
    String? tableName,
  }) async {
    await logAuditAction(
      userId: customerId,
      role: 'customer',
      action: action,
      tableName: tableName,
      recordId: recordId,
      newValues: data,
      additionalData: {
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  /// Log shop owner-specific actions
  Future<void> logShopOwnerAction({
    required String ownerId,
    required String action,
    Map<String, dynamic>? data,
    String? recordId,
    String? tableName,
  }) async {
    await logAuditAction(
      userId: ownerId,
      role: 'talyer_owner',
      action: action,
      tableName: tableName,
      recordId: recordId,
      newValues: data,
      additionalData: {
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  // ========================================
  // AUDIT REPORTS METHODS
  // ========================================

  /// Get user activity report
  Future<List<Map<String, dynamic>>> getUserActivityReport({
    required String userId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final response = await _supabase.rpc('get_user_activity_report', params: {
        'p_user_id': userId,
        'p_start_date': startDate?.toIso8601String(),
        'p_end_date': endDate?.toIso8601String(),
      });

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      if (kDebugMode) print('User activity report error: $e');
      return [];
    }
  }

  /// Get system activity summary
  Future<List<Map<String, dynamic>>> getSystemActivitySummary({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final response = await _supabase.rpc('get_system_activity_summary', params: {
        'p_start_date': startDate?.toIso8601String() ?? DateTime.now().subtract(const Duration(days: 7)).toIso8601String(),
        'p_end_date': endDate?.toIso8601String() ?? DateTime.now().toIso8601String(),
      });

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      if (kDebugMode) print('System activity summary error: $e');
      return [];
    }
  }

  // ========================================
  // UTILITY METHODS
  // ========================================

  /// Get current session ID
  String? get sessionId => _sessionId;

  /// Get current device info
  String? get deviceInfo => _deviceInfo;

  /// Refresh session ID
  void refreshSession() {
    _sessionId = _generateSessionId();
  }
}