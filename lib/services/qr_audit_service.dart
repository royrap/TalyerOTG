import 'package:supabase_flutter/supabase_flutter.dart';

class QRAuditService {
  static final QRAuditService _instance = QRAuditService._internal();
  static QRAuditService get instance => _instance;
  QRAuditService._internal();

  final _supabase = Supabase.instance.client;

  /// Log QR scan attempt for audit trail
  Future<void> logQRScanAttempt({
    required String requestId,
    required String mechanicId,
    required String customerId,
    required String qrHash,
    required bool success,
    String? errorReason,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      print('📊 Logging QR scan attempt: success=$success');

      final auditData = {
        'request_id': requestId,
        'mechanic_id': mechanicId,
        'customer_id': customerId,
        'qr_hash': qrHash,
        'scan_success': success,
        'error_reason': errorReason,
        'additional_data': additionalData,
        'scanned_at': DateTime.now().toIso8601String(),
        'user_agent': 'RoadAidApp/1.0', // Could be dynamic
        'ip_address': 'mobile_app', // For mobile apps
      };

      await _supabase
          .from('qr_scan_audit_logs')
          .insert(auditData);

      print('📊 QR scan audit log recorded successfully');
    } catch (e) {
      print('❌ Error logging QR scan audit: $e');
      // Don't throw - audit logging shouldn't break the main flow
    }
  }

  /// Log QR generation for audit trail
  Future<void> logQRGeneration({
    required String requestId,
    required String customerId,
    required String qrHash,
    required DateTime expiresAt,
  }) async {
    try {
      print('📊 Logging QR generation');

      final auditData = {
        'request_id': requestId,
        'customer_id': customerId,
        'qr_hash': qrHash,
        'generated_at': DateTime.now().toIso8601String(),
        'expires_at': expiresAt.toIso8601String(),
        'action_type': 'qr_generated',
      };

      await _supabase
          .from('qr_generation_audit_logs')
          .insert(auditData);

      print('📊 QR generation audit log recorded');
    } catch (e) {
      print('❌ Error logging QR generation audit: $e');
    }
  }

  /// Get audit logs for admin dashboard
  Future<List<Map<String, dynamic>>> getQRAuditLogs({
    String? requestId,
    String? mechanicId,
    String? customerId,
    DateTime? fromDate,
    DateTime? toDate,
    int limit = 100,
  }) async {
    try {
      var query = _supabase
          .from('qr_scan_audit_logs')
          .select('''
            *,
            service_requests!qr_scan_audit_logs_request_id_fkey(
              service_type,
              pickup_address
            ),
            mechanic_profiles:user_profiles!qr_scan_audit_logs_mechanic_id_fkey(
              first_name,
              last_name,
              phone_number
            ),
            customer_profiles:user_profiles!qr_scan_audit_logs_customer_id_fkey(
              first_name,
              last_name,
              phone_number
            )
          ''');

      if (requestId != null) query = query.eq('request_id', requestId);
      if (mechanicId != null) query = query.eq('mechanic_id', mechanicId);
      if (customerId != null) query = query.eq('customer_id', customerId);
      if (fromDate != null) query = query.gte('scanned_at', fromDate.toIso8601String());
      if (toDate != null) query = query.lte('scanned_at', toDate.toIso8601String());

      final result = await query
          .order('scanned_at', ascending: false)
          .limit(limit);

      return result;
    } catch (e) {
      print('❌ Error fetching QR audit logs: $e');
      return [];
    }
  }

  /// Get QR scan statistics for admin dashboard
  Future<Map<String, dynamic>> getQRScanStatistics({
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    try {
      var query = _supabase
          .from('qr_scan_audit_logs')
          .select('scan_success');

      if (fromDate != null) query = query.gte('scanned_at', fromDate.toIso8601String());
      if (toDate != null) query = query.lte('scanned_at', toDate.toIso8601String());

      final result = await query;

      final totalScans = result.length;
      final successfulScans = result.where((log) => log['scan_success'] == true).length;
      final failedScans = totalScans - successfulScans;

      return {
        'total_scans': totalScans,
        'successful_scans': successfulScans,
        'failed_scans': failedScans,
        'success_rate': totalScans > 0 ? (successfulScans / totalScans * 100).toStringAsFixed(2) : '0.00',
      };
    } catch (e) {
      print('❌ Error fetching QR statistics: $e');
      return {
        'total_scans': 0,
        'successful_scans': 0,
        'failed_scans': 0,
        'success_rate': '0.00',
      };
    }
  }
}










