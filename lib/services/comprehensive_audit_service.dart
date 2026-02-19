import 'package:supabase_flutter/supabase_flutter.dart';

/// Comprehensive audit logging service for all system actions
/// Tracks: registration, login, approvals, payments, service requests, invoice actions, reviews
class ComprehensiveAuditService {
  static final ComprehensiveAuditService _instance = ComprehensiveAuditService._internal();
  static ComprehensiveAuditService get instance => _instance;
  ComprehensiveAuditService._internal();

  final _supabase = Supabase.instance.client;

  /// Log user registration actions
  Future<void> logRegistration({
    required String userId,
    required String userType,
    required String email,
    String? ipAddress,
    String? userAgent,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      await _logAuditAction(
        userId: userId,
        role: userType,
        action: 'USER_REGISTRATION',
        tableName: 'user_profiles',
        recordId: userId,
        ipAddress: ipAddress,
        userAgent: userAgent,
        newValues: {
          'email': email,
          'user_type': userType,
          'registration_timestamp': DateTime.now().toUtc().toIso8601String(),
        },
        additionalData: additionalData ?? {},
      );
      print('📋 Registration audit logged for user: $email');
    } catch (e) {
      print('❌ Error logging registration audit: $e');
    }
  }

  /// Log login/logout actions
  Future<void> logLoginLogout({
    required String userId,
    required String userType,
    required String action, // 'LOGIN' or 'LOGOUT'
    required bool success,
    String? ipAddress,
    String? userAgent,
    String? failureReason,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      await _logAuditAction(
        userId: userId,
        role: userType,
        action: action,
        tableName: 'user_profiles',
        recordId: userId,
        ipAddress: ipAddress,
        userAgent: userAgent,
        success: success,
        errorMessage: failureReason,
        newValues: {
          'action_timestamp': DateTime.now().toUtc().toIso8601String(),
          'login_status': success ? 'successful' : 'failed',
        },
        additionalData: additionalData ?? {},
      );
      print('📋 $action audit logged for user: $userId, Success: $success');
    } catch (e) {
      print('❌ Error logging $action audit: $e');
    }
  }

  /// Log talyer owner verification actions (AI + Admin)
  Future<void> logTalyerOwnerVerification({
    required String talyerOwnerId,
    required String action, // 'AI_APPROVAL', 'AI_REJECTION', 'ADMIN_REVIEW', 'ADMIN_APPROVAL', 'ADMIN_REJECTION'
    String? reviewedBy, // Admin ID for manual reviews
    required String status, // 'approved', 'rejected', 'under_review'
    String? rejectionReason,
    Map<String, dynamic>? verificationData,
    String? ipAddress,
    String? userAgent,
  }) async {
    try {
      await _logAuditAction(
        userId: talyerOwnerId,
        role: 'talyer_owner',
        action: action,
        tableName: 'talyer_owner_verifications',
        recordId: talyerOwnerId,
        ipAddress: ipAddress,
        userAgent: userAgent,
        newValues: {
          'verification_status': status,
          'reviewed_by': reviewedBy,
          'rejection_reason': rejectionReason,
          'verification_timestamp': DateTime.now().toUtc().toIso8601String(),
        },
        additionalData: verificationData ?? {},
      );
      print('📋 Talyer owner verification audit logged: $action for $talyerOwnerId');
    } catch (e) {
      print('❌ Error logging verification audit: $e');
    }
  }

  /// Log service request actions
  Future<void> logServiceRequest({
    required String customerId,
    required String action, // 'CREATE', 'ACCEPT', 'REJECT', 'ASSIGN_MECHANIC', 'COMPLETE', 'CANCEL'
    required String requestId,
    String? talyerOwnerId,
    String? mechanicId,
    String? previousStatus,
    String? newStatus,
    Map<String, dynamic>? requestData,
    String? ipAddress,
    String? userAgent,
  }) async {
    try {
      await _logAuditAction(
        userId: customerId,
        role: 'customer',
        action: 'SERVICE_REQUEST_$action',
        tableName: 'service_requests',
        recordId: requestId,
        ipAddress: ipAddress,
        userAgent: userAgent,
        oldValues: previousStatus != null ? {'status': previousStatus} : null,
        newValues: {
          'status': newStatus,
          'talyer_owner_id': talyerOwnerId,
          'mechanic_id': mechanicId,
          'action_timestamp': DateTime.now().toUtc().toIso8601String(),
        },
        additionalData: requestData ?? {},
      );
      print('📋 Service request audit logged: $action for request $requestId');
    } catch (e) {
      print('❌ Error logging service request audit: $e');
    }
  }

  /// Log payment actions (PayMongo integration)
  Future<void> logPayment({
    required String userId,
    required String userType,
    required String action, // 'PAYMENT_INITIATED', 'PAYMENT_COMPLETED', 'PAYMENT_FAILED', 'PAYMENT_REFUNDED'
    required String paymentId,
    String? requestId,
    String? invoiceId,
    double? amount,
    String? paymentMethod,
    String? transactionId,
    String? gatewayResponse,
    Map<String, dynamic>? paymentData,
    String? ipAddress,
    String? userAgent,
  }) async {
    try {
      await _logAuditAction(
        userId: userId,
        role: userType,
        action: action,
        tableName: 'payments',
        recordId: paymentId,
        ipAddress: ipAddress,
        userAgent: userAgent,
        newValues: {
          'request_id': requestId,
          'invoice_id': invoiceId,
          'amount': amount,
          'payment_method': paymentMethod,
          'transaction_id': transactionId,
          'gateway_response': gatewayResponse,
          'payment_timestamp': DateTime.now().toUtc().toIso8601String(),
        },
        additionalData: paymentData ?? {},
      );
      print('📋 Payment audit logged: $action for payment $paymentId');
    } catch (e) {
      print('❌ Error logging payment audit: $e');
    }
  }

  /// Log invoice actions
  Future<void> logInvoice({
    required String userId,
    required String userType,
    required String action, // 'INVOICE_GENERATED', 'INVOICE_SENT', 'INVOICE_ACCEPTED', 'INVOICE_REJECTED', 'INVOICE_PAID'
    required String invoiceId,
    String? requestId,
    String? customerId,
    String? mechanicId,
    double? amount,
    String? previousStatus,
    String? newStatus,
    Map<String, dynamic>? invoiceData,
    String? ipAddress,
    String? userAgent,
  }) async {
    try {
      await _logAuditAction(
        userId: userId,
        role: userType,
        action: action,
        tableName: 'invoices',
        recordId: invoiceId,
        ipAddress: ipAddress,
        userAgent: userAgent,
        oldValues: previousStatus != null ? {'status': previousStatus} : null,
        newValues: {
          'status': newStatus,
          'request_id': requestId,
          'customer_id': customerId,
          'mechanic_id': mechanicId,
          'amount': amount,
          'action_timestamp': DateTime.now().toUtc().toIso8601String(),
        },
        additionalData: invoiceData ?? {},
      );
      print('📋 Invoice audit logged: $action for invoice $invoiceId');
    } catch (e) {
      print('❌ Error logging invoice audit: $e');
    }
  }

  /// Log QR code generation and scanning
  Future<void> logQRCodeAction({
    required String userId,
    required String userType,
    required String action, // 'QR_GENERATED', 'QR_SCANNED', 'QR_VERIFIED'
    required String requestId,
    String? qrCode,
    String? mechanicId,
    String? customerId,
    double? scanLat,
    double? scanLng,
    Map<String, dynamic>? qrData,
    String? ipAddress,
    String? userAgent,
  }) async {
    try {
      await _logAuditAction(
        userId: userId,
        role: userType,
        action: action,
        tableName: 'job_completion_codes',
        recordId: requestId,
        ipAddress: ipAddress,
        userAgent: userAgent,
        newValues: {
          'request_id': requestId,
          'qr_code': qrCode,
          'mechanic_id': mechanicId,
          'customer_id': customerId,
          'scan_latitude': scanLat,
          'scan_longitude': scanLng,
          'action_timestamp': DateTime.now().toUtc().toIso8601String(),
        },
        additionalData: qrData ?? {},
      );
      print('📋 QR code audit logged: $action for request $requestId');
    } catch (e) {
      print('❌ Error logging QR code audit: $e');
    }
  }

  /// Log review/feedback actions
  Future<void> logReview({
    required String customerId,
    required String action, // 'REVIEW_CREATED', 'REVIEW_UPDATED', 'REVIEW_RESPONDED'
    required String reviewId,
    String? requestId,
    String? providerId,
    int? rating,
    String? comment,
    String? response,
    Map<String, dynamic>? reviewData,
    String? ipAddress,
    String? userAgent,
  }) async {
    try {
      await _logAuditAction(
        userId: customerId,
        role: 'customer',
        action: action,
        tableName: 'reviews',
        recordId: reviewId,
        ipAddress: ipAddress,
        userAgent: userAgent,
        newValues: {
          'request_id': requestId,
          'provider_id': providerId,
          'rating': rating,
          'comment': comment,
          'response': response,
          'review_timestamp': DateTime.now().toUtc().toIso8601String(),
        },
        additionalData: reviewData ?? {},
      );
      print('📋 Review audit logged: $action for review $reviewId');
    } catch (e) {
      print('❌ Error logging review audit: $e');
    }
  }

  /// Log admin actions (super admin overrides)
  Future<void> logAdminAction({
    required String adminId,
    required String action, // 'ADMIN_OVERRIDE', 'ADMIN_APPROVAL', 'ADMIN_REJECTION', 'AUDIT_VIEW'
    String? targetUserId,
    String? targetType, // 'talyer_owner', 'payment', 'service_request', etc.
    String? targetId,
    Map<String, dynamic>? oldValues,
    Map<String, dynamic>? newValues,
    String? reason,
    String? ipAddress,
    String? userAgent,
  }) async {
    try {
      await _logAuditAction(
        userId: adminId,
        role: 'super_admin',
        action: action,
        tableName: targetType,
        recordId: targetId,
        ipAddress: ipAddress,
        userAgent: userAgent,
        oldValues: oldValues,
        newValues: {
          ...?newValues,
          'admin_action_reason': reason,
          'target_user_id': targetUserId,
          'admin_action_timestamp': DateTime.now().toUtc().toIso8601String(),
        },
      );
      print('📋 Admin action audit logged: $action by $adminId');
    } catch (e) {
      print('❌ Error logging admin action audit: $e');
    }
  }

  /// Core audit logging method
  Future<void> _logAuditAction({
    required String userId,
    required String role,
    required String action,
    String? tableName,
    String? recordId,
    String? ipAddress,
    String? userAgent,
    String? sessionId,
    Map<String, dynamic>? oldValues,
    Map<String, dynamic>? newValues,
    Map<String, dynamic>? additionalData,
    bool success = true,
    String? errorMessage,
  }) async {
    try {
      final auditData = {
        'user_id': userId,
        'role': role,
        'action': action,
        'table_name': tableName,
        'record_id': recordId,
        'ip_address': ipAddress,
        'user_agent': userAgent,
        'session_id': sessionId,
        'old_values': oldValues,
        'new_values': newValues,
        'additional_data': additionalData,
        'success': success,
        'error_message': errorMessage,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      };

      await _supabase.from('audit_logs').insert(auditData);
    } catch (e) {
      print('❌ Critical error in audit logging: $e');
      // Don't throw - audit logging should never break the main flow
    }
  }

  /// Get audit logs for admin dashboard
  Future<List<Map<String, dynamic>>> getAuditLogs({
    String? userId,
    String? action,
    String? tableName,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 100,
    int offset = 0,
  }) async {
    try {
      var query = _supabase
          .from('audit_logs')
          .select('''
            id,
            user_id,
            role,
            action,
            table_name,
            record_id,
            ip_address,
            success,
            error_message,
            created_at,
            additional_data,
            user_profiles!audit_logs_user_id_fkey(
              first_name,
              last_name,
              email
            )
          ''');

      if (userId != null) query = query.eq('user_id', userId);
      if (action != null) query = query.eq('action', action);
      if (tableName != null) query = query.eq('table_name', tableName);
      if (startDate != null) query = query.gte('created_at', startDate.toUtc().toIso8601String());
      if (endDate != null) query = query.lte('created_at', endDate.toUtc().toIso8601String());

      final response = await query
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('❌ Error fetching audit logs: $e');
      return [];
    }
  }

  /// Get system statistics from audit logs
  Future<Map<String, dynamic>> getAuditStatistics({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final start = startDate ?? DateTime.now().subtract(Duration(days: 30));
      final end = endDate ?? DateTime.now();

      final response = await _supabase
          .from('audit_logs')
          .select('action, role, success, created_at')
          .gte('created_at', start.toUtc().toIso8601String())
          .lte('created_at', end.toUtc().toIso8601String());

      final logs = List<Map<String, dynamic>>.from(response);
      
      // Calculate statistics
      final stats = {
        'total_actions': logs.length,
        'successful_actions': logs.where((log) => log['success'] == true).length,
        'failed_actions': logs.where((log) => log['success'] == false).length,
        'registrations': logs.where((log) => log['action'] == 'USER_REGISTRATION').length,
        'logins': logs.where((log) => log['action'] == 'LOGIN').length,
        'payments': logs.where((log) => log['action'].toString().contains('PAYMENT')).length,
        'service_requests': logs.where((log) => log['action'].toString().contains('SERVICE_REQUEST')).length,
        'verifications': logs.where((log) => log['action'].toString().contains('VERIFICATION')).length,
        'reviews': logs.where((log) => log['action'].toString().contains('REVIEW')).length,
        'by_role': <String, int>{},
        'by_action': <String, int>{},
      };

      // Group by role
      for (final log in logs) {
        final role = log['role'] as String? ?? 'unknown';
        final byRole = stats['by_role'] as Map<String, dynamic>? ?? <String, dynamic>{};
        byRole[role] = (byRole[role] ?? 0) + 1;
        stats['by_role'] = byRole;
      }

      // Group by action
      for (final log in logs) {
        final action = log['action'] as String? ?? 'unknown';
        final byAction = stats['by_action'] as Map<String, dynamic>? ?? <String, dynamic>{};
        byAction[action] = (byAction[action] ?? 0) + 1;
        stats['by_action'] = byAction;
      }

      return stats;
    } catch (e) {
      print('❌ Error calculating audit statistics: $e');
      return {};
    }
  }
}
