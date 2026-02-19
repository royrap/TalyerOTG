import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math' as math;

/// Comprehensive data service to handle all database operations
/// Supports the complete schema including admin_activity_logs, app_settings,
/// inspection_reports, job_completion_codes, payment_releases, and more
class ComprehensiveDataService {
  static final ComprehensiveDataService _instance = ComprehensiveDataService._internal();
  static ComprehensiveDataService get instance => _instance;
  ComprehensiveDataService._internal();
  final SupabaseClient _supabase = Supabase.instance.client;
  // =======================================================
  // ADMIN ACTIVITY LOGS
  // =======================================================

  /// Log admin activity
  Future<String> logAdminActivity({
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
      final result = await _supabase
          .from('admin_activity_logs')
          .insert({
            'admin_id': adminId,
            'action_type': actionType,
            'target_type': targetType,
            'target_id': targetId,
            'action_details': actionDetails,
            'ip_address': ipAddress,
            'user_agent': userAgent,
            'session_id': sessionId,
          })
          .select('id')
          .single();

      return result['id'];
    } catch (e) {
      print('❌ Error logging admin activity: $e');
      throw Exception('Failed to log admin activity: $e');
    }
  }

  /// Get admin activity logs
  Future<List<Map<String, dynamic>>> getAdminActivityLogs({
    String? adminId,
    String? actionType,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 100,
  }) async {
    try {
  dynamic query = _supabase.from('admin_activity_logs').select('*');

  if (adminId != null) query = query.eq('admin_id', adminId);
  if (actionType != null) query = query.eq('action_type', actionType);
  if (startDate != null) query = query.gte('created_at', startDate.toIso8601String());
  if (endDate != null) query = query.lte('created_at', endDate.toIso8601String());

  query = query.order('created_at', ascending: false).limit(limit);
  final result = await query;
      return List<Map<String, dynamic>>.from(result);
    } catch (e) {
      print('❌ Error getting admin activity logs: $e');
      return [];
    }
  }

  // =======================================================
  // APP SETTINGS
  // =======================================================

  /// Set app setting
  Future<void> setAppSetting({
    required String key,
    required String value,
    String? description,
    bool isPublic = false,
  }) async {
    try {
      await _supabase
          .from('app_settings')
          .upsert({
            'key': key,
            'value': value,
            'description': description,
            'is_public': isPublic,
          }, onConflict: 'key');
    } catch (e) {
      print('❌ Error setting app setting: $e');
      throw Exception('Failed to set app setting: $e');
    }
  }

  /// Get app setting
  Future<String?> getAppSetting(String key) async {
    try {
      final result = await _supabase
          .from('app_settings')
          .select('value')
          .eq('key', key)
          .maybeSingle();

      return result?['value'];
    } catch (e) {
      print('❌ Error getting app setting: $e');
      return null;
    }
  }

  /// Get all public app settings
  Future<Map<String, dynamic>> getPublicAppSettings() async {
    try {
      final result = await _supabase
          .from('app_settings')
          .select('key, value')
          .eq('is_public', true);

      return Map.fromEntries(
        result.map((setting) => MapEntry(setting['key'], setting['value']))
      );
    } catch (e) {
      print('❌ Error getting public app settings: $e');
      return {};
    }
  }

  // =======================================================
  // INSPECTION REPORTS
  // =======================================================

  /// Create inspection report
  Future<String> createInspectionReport({
    required String requestId,
    required String providerId,
    required Map<String, dynamic> reportData,
  }) async {
    try {
      final result = await _supabase
          .from('inspection_reports')
          .insert({
            'request_id': requestId,
            'provider_id': providerId,
            'report_data': reportData,
          })
          .select('id')
          .single();

      return result['id'];
    } catch (e) {
      print('❌ Error creating inspection report: $e');
      throw Exception('Failed to create inspection report: $e');
    }
  }

  /// Get inspection report by request ID
  Future<Map<String, dynamic>?> getInspectionReport(String requestId) async {
    try {
      final result = await _supabase
          .from('inspection_reports')
          .select('*')
          .eq('request_id', requestId)
          .maybeSingle();

      return result;
    } catch (e) {
      print('❌ Error getting inspection report: $e');
      return null;
    }
  }

  /// Get inspection reports by provider
  Future<List<Map<String, dynamic>>> getInspectionReportsByProvider(String providerId) async {
    try {
      final result = await _supabase
          .from('inspection_reports')
          .select('*')
          .eq('provider_id', providerId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(result);
    } catch (e) {
      print('❌ Error getting inspection reports by provider: $e');
      return [];
    }
  }

  // =======================================================
  // JOB COMPLETION CODES (QR CODES)
  // =======================================================

  /// Generate job completion code
  Future<Map<String, dynamic>> generateJobCompletionCode({
    required String requestId,
    required String customerId,
    Duration validity = const Duration(hours: 24),
  }) async {
    try {
      // Generate unique completion code
      final completionCode = _generateUniqueCode();
      final expiresAt = DateTime.now().add(validity);

      final result = await _supabase
          .from('job_completion_codes')
          .insert({
            'request_id': requestId,
            'customer_id': customerId,
            'completion_code': completionCode,
            'expires_at': expiresAt.toIso8601String(),
          })
          .select('*')
          .single();

      return result;
    } catch (e) {
      print('❌ Error generating job completion code: $e');
      throw Exception('Failed to generate job completion code: $e');
    }
  }

  /// Verify and use job completion code
  Future<Map<String, dynamic>?> verifyJobCompletionCode({
    required String completionCode,
    required String providerId,
    double? scanLatitude,
    double? scanLongitude,
    String? scanIpAddress,
    String? deviceFingerprint,
  }) async {
    try {
      // First, get the code details
      final codeRecord = await _supabase
          .from('job_completion_codes')
          .select('*')
          .eq('completion_code', completionCode)
          .eq('is_used', false)
          .maybeSingle();

      if (codeRecord == null) {
        return {'success': false, 'error': 'Invalid or already used code'};
      }

      // Check if expired
      final expiresAt = DateTime.parse(codeRecord['expires_at']);
      if (DateTime.now().isAfter(expiresAt)) {
        await _supabase
            .from('job_completion_codes')
            .update({'verification_status': 'expired'})
            .eq('id', codeRecord['id']);
        return {'success': false, 'error': 'Code has expired'};
      }

      // Calculate distance if coordinates provided
      double? distance;
      if (scanLatitude != null && scanLongitude != null) {
        // Get service request location
        final serviceRequest = await _supabase
            .from('service_requests')
            .select('pickup_latitude, pickup_longitude')
            .eq('id', codeRecord['request_id'])
            .single();

        if (serviceRequest['pickup_latitude'] != null && serviceRequest['pickup_longitude'] != null) {
          distance = _calculateDistance(
            scanLatitude, scanLongitude,
            serviceRequest['pickup_latitude'], serviceRequest['pickup_longitude']
          );
        }
      }

      // Mark code as used
      await _supabase
          .from('job_completion_codes')
          .update({
            'is_used': true,
            'used_at': DateTime.now().toIso8601String(),
            'used_by_provider_id': providerId,
            'verification_status': 'verified',
            'scan_latitude': scanLatitude,
            'scan_longitude': scanLongitude,
            'scan_distance_meters': distance,
            'scan_ip_address': scanIpAddress,
            'device_fingerprint': deviceFingerprint,
          })
          .eq('id', codeRecord['id']);

      return {
        'success': true,
        'request_id': codeRecord['request_id'],
        'customer_id': codeRecord['customer_id'],
        'distance_meters': distance,
      };
    } catch (e) {
      print('❌ Error verifying job completion code: $e');
      return {'success': false, 'error': 'Verification failed'};
    }
  }

  /// Get job completion code for request
  Future<Map<String, dynamic>?> getJobCompletionCode(String requestId) async {
    try {
      final result = await _supabase
          .from('job_completion_codes')
          .select('*')
          .eq('request_id', requestId)
          .order('created_at', ascending: false)
          .maybeSingle();

      return result;
    } catch (e) {
      print('❌ Error getting job completion code: $e');
      return null;
    }
  }

  // =======================================================
  // PAYMENT RELEASES
  // =======================================================

  /// Create payment release request
  Future<String> createPaymentRelease({
    required String paymentId,
    required String requestId,
    required String providerId,
    required String customerId,
    required double totalAmount,
    required double platformFee,
    required double providerAmount,
    String releaseMethod = 'bank_transfer',
  }) async {
    try {
      final result = await _supabase
          .from('payment_releases')
          .insert({
            'payment_id': paymentId,
            'request_id': requestId,
            'provider_id': providerId,
            'customer_id': customerId,
            'total_amount': totalAmount,
            'platform_fee': platformFee,
            'provider_amount': providerAmount,
            'release_method': releaseMethod,
            'release_status': 'pending',
          })
          .select('id')
          .single();

      return result['id'];
    } catch (e) {
      print('❌ Error creating payment release: $e');
      throw Exception('Failed to create payment release: $e');
    }
  }

  /// Approve payment release (Admin only)
  Future<void> approvePaymentRelease({
    required String releaseId,
    required String adminId,
    String? adminNotes,
  }) async {
    try {
      await _supabase
          .from('payment_releases')
          .update({
            'release_status': 'approved',
            'admin_id': adminId,
            'approved_at': DateTime.now().toIso8601String(),
            'admin_notes': adminNotes,
          })
          .eq('id', releaseId);
    } catch (e) {
      print('❌ Error approving payment release: $e');
      throw Exception('Failed to approve payment release: $e');
    }
  }

  /// Mark payment as released
  Future<void> markPaymentReleased({
    required String releaseId,
    required String referenceNumber,
  }) async {
    try {
      await _supabase
          .from('payment_releases')
          .update({
            'release_status': 'released',
            'released_at': DateTime.now().toIso8601String(),
            'release_reference_number': referenceNumber,
          })
          .eq('id', releaseId);
    } catch (e) {
      print('❌ Error marking payment as released: $e');
      throw Exception('Failed to mark payment as released: $e');
    }
  }

  /// Get payment releases by status
  Future<List<Map<String, dynamic>>> getPaymentReleases({
    String? status,
    String? providerId,
    int limit = 100,
  }) async {
    try {
  dynamic query = _supabase.from('payment_releases').select('*');

  if (status != null) query = query.eq('release_status', status);
  if (providerId != null) query = query.eq('provider_id', providerId);

  query = query.order('created_at', ascending: false).limit(limit);
  final result = await query;
      return List<Map<String, dynamic>>.from(result);
    } catch (e) {
      print('❌ Error getting payment releases: $e');
      return [];
    }
  }

  // =======================================================
  // PROVIDER SERVICES
  // =======================================================

  /// Add service to provider
  Future<String> addProviderService({
    required String providerId,
    required String categoryId,
    double? customPrice,
  }) async {
    try {
      final result = await _supabase
          .from('provider_services')
          .insert({
            'provider_id': providerId,
            'category_id': categoryId,
            'custom_price': customPrice,
          })
          .select('id')
          .single();

      return result['id'];
    } catch (e) {
      print('❌ Error adding provider service: $e');
      throw Exception('Failed to add provider service: $e');
    }
  }

  /// Get provider services
  Future<List<Map<String, dynamic>>> getProviderServices(String providerId) async {
    try {
      final result = await _supabase
          .from('provider_services')
          .select('''
            *,
            service_categories (
              name,
              description,
              icon_name,
              base_price,
              estimated_duration
            )
          ''')
          .eq('provider_id', providerId);

      return List<Map<String, dynamic>>.from(result);
    } catch (e) {
      print('❌ Error getting provider services: $e');
      return [];
    }
  }

  /// Remove provider service
  Future<void> removeProviderService({
    required String providerId,
    required String categoryId,
  }) async {
    try {
      await _supabase
          .from('provider_services')
          .delete()
          .eq('provider_id', providerId)
          .eq('category_id', categoryId);
    } catch (e) {
      print('❌ Error removing provider service: $e');
      throw Exception('Failed to remove provider service: $e');
    }
  }

  // =======================================================
  // SYSTEM STATISTICS
  // =======================================================

  /// Record system statistic
  Future<void> recordSystemStatistic({
    required DateTime date,
    required String statType,
    required double statValue,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await _supabase
          .from('system_statistics')
          .upsert({
            'stat_date': date.toIso8601String().split('T')[0], // Date only
            'stat_type': statType,
            'stat_value': statValue,
            'stat_metadata': metadata,
          }, onConflict: 'stat_date,stat_type');
    } catch (e) {
      print('❌ Error recording system statistic: $e');
      throw Exception('Failed to record system statistic: $e');
    }
  }

  /// Get system statistics
  Future<List<Map<String, dynamic>>> getSystemStatistics({
    String? statType,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 100,
  }) async {
    try {
  dynamic query = _supabase.from('system_statistics').select('*');

      if (statType != null) query = query.eq('stat_type', statType);
      if (startDate != null) {
        query = query.gte('stat_date', startDate.toIso8601String().split('T')[0]);
      }
      if (endDate != null) {
        query = query.lte('stat_date', endDate.toIso8601String().split('T')[0]);
      }

      query = query.order('stat_date', ascending: false).limit(limit);
      final result = await query;
      return List<Map<String, dynamic>>.from(result);
    } catch (e) {
      print('❌ Error getting system statistics: $e');
      return [];
    }
  }

  // =======================================================
  // TALYER OWNER VERIFICATIONS
  // =======================================================

  /// Submit talyer owner verification
  Future<String> submitTalyerOwnerVerification({
    required String userId,
    required String businessName,
    required String businessPermitUrl,
    required String validIdUrl,
    required String idType,
    DateTime? permitExpiryDate,
    DateTime? idExpiryDate,
    String? businessAddress,
    String? contactPerson,
    String? phoneNumber,
    String? email,
  }) async {
    try {
      final result = await _supabase
          .from('talyer_owner_verifications')
          .insert({
            'user_id': userId,
            'business_name': businessName,
            'business_permit_url': businessPermitUrl,
            'valid_id_url': validIdUrl,
            'id_type': idType,
            'permit_expiry_date': permitExpiryDate?.toIso8601String().split('T')[0],
            'id_expiry_date': idExpiryDate?.toIso8601String().split('T')[0],
            'business_address': businessAddress,
            'contact_person': contactPerson,
            'phone_number': phoneNumber,
            'email': email,
            'status': 'pending',
          })
          .select('id')
          .single();

      return result['id'];
    } catch (e) {
      print('❌ Error submitting talyer owner verification: $e');
      throw Exception('Failed to submit verification: $e');
    }
  }

  /// Get talyer owner verification status
  Future<Map<String, dynamic>?> getTalyerOwnerVerification(String userId) async {
    try {
      final result = await _supabase
          .from('talyer_owner_verifications')
          .select('*')
          .eq('user_id', userId)
          .maybeSingle();

      return result;
    } catch (e) {
      print('❌ Error getting talyer owner verification: $e');
      return null;
    }
  }

  /// Review talyer owner verification (Admin only)
  Future<void> reviewTalyerOwnerVerification({
    required String verificationId,
    required String reviewerId,
    required String status, // 'approved', 'rejected', 'additional_info_required'
    String? adminNotes,
    int? verificationScore,
    List<String>? tamperFlags,
  }) async {
    try {
      await _supabase
          .from('talyer_owner_verifications')
          .update({
            'status': status,
            'reviewed_by': reviewerId,
            'reviewed_at': DateTime.now().toIso8601String(),
            'admin_notes': adminNotes,
            'verification_score': verificationScore,
            'tamper_flags': tamperFlags,
          })
          .eq('id', verificationId);
    } catch (e) {
      print('❌ Error reviewing talyer owner verification: $e');
      throw Exception('Failed to review verification: $e');
    }
  }

  // =======================================================
  // HELPER METHODS
  // =======================================================

  /// Generate unique completion code
  String _generateUniqueCode() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = (timestamp % 10000).toString().padLeft(4, '0');
    return 'JOB$random';
  }

  /// Calculate distance between two points using Haversine formula
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000; // Earth radius in meters
    final double dLat = _degreesToRadians(lat2 - lat1);
    final double dLon = _degreesToRadians(lon2 - lon1);
    
    final double a = 
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(lat1)) * math.cos(_degreesToRadians(lat2)) *
        math.sin(dLon / 2) * math.sin(dLon / 2);
    
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) => degrees * (math.pi / 180);
}










