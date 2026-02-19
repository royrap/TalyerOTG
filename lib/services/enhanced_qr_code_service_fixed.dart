import 'dart:convert';
import 'dart:math';
import '../services/supabase_service.dart';
import '../services/qr_encryption_service.dart';
import '../services/comprehensive_audit_service.dart';

class EnhancedQRCodeService {
  static final EnhancedQRCodeService _instance = EnhancedQRCodeService._internal();
  factory EnhancedQRCodeService() => _instance;
  EnhancedQRCodeService._internal();

  final QREncryptionService _encryptionService = QREncryptionService();
  final ComprehensiveAuditService _auditService = ComprehensiveAuditService();

  /// Generate a secure QR code for service completion
  Future<Map<String, dynamic>> generateServiceQRCode({
    required String serviceRequestId,
    required String customerId,
    String? mechanicId,
  }) async {
    try {
      print('🔐 Generating QR code for service request: $serviceRequestId');

      // Generate completion code
      final completionCode = _generateCompletionCode();
      final qrCodeId = _generateUniqueId();

      // Create job completion record
      final jobCompletionData = await SupabaseService.client
          .from('job_completion_codes')
          .insert({
            'id': qrCodeId,
            'request_id': serviceRequestId,
            'customer_id': customerId,
            'completion_code': completionCode,
            'expires_at': DateTime.now()
                .add(const Duration(hours: 24))
                .toUtc()
                .toIso8601String(),
          })
          .select()
          .single();

      // Update service request with QR data
      await SupabaseService.client.from('service_requests').update({
        'qr_code_data': _buildQRData(qrCodeId, completionCode, serviceRequestId),
        'qr_generated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', serviceRequestId);

      // Log QR code generation
      await _auditService.logQRCodeAction(
        userId: mechanicId ?? customerId,
        userType: mechanicId != null ? 'mechanic' : 'customer',
        action: 'QR_GENERATED',
        requestId: serviceRequestId,
        qrCode: completionCode,
        mechanicId: mechanicId,
        customerId: customerId,
      );

      print('✅ QR code generated successfully: $completionCode');
      return {
        'success': true,
        'qr_code_id': qrCodeId,
        'completion_code': completionCode,
        'qr_data': _buildQRData(qrCodeId, completionCode, serviceRequestId),
        'expires_at': jobCompletionData['expires_at'],
      };

    } catch (e) {
      print('❌ Error generating QR code: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Verify and process QR code scan
  Future<Map<String, dynamic>> verifyQRCodeScan({
    required String qrData,
    String? mechanicId,
    double? latitude,
    double? longitude,
    String? notes,
  }) async {
    try {
      print('🔍 Verifying QR code scan...');

      // Parse QR data
      final qrInfo = _parseQRData(qrData);
      if (qrInfo == null) {
        throw Exception('Invalid QR code format');
      }

      final qrCodeId = qrInfo['qr_code_id']!;
      final serviceRequestId = qrInfo['service_request_id']!;
      final completionCode = qrInfo['completion_code']!;

      // Verify completion code
      final qrRecord = await SupabaseService.client
          .from('job_completion_codes')
          .select()
          .eq('id', qrCodeId)
          .eq('completion_code', completionCode)
          .maybeSingle();

      if (qrRecord == null) {
        throw Exception('Invalid or expired QR code');
      }

      if (qrRecord['is_used'] == true) {
        throw Exception('QR code has already been used');
      }

      // Check expiration
      final expiresAt = DateTime.parse(qrRecord['expires_at']);
      if (DateTime.now().isAfter(expiresAt)) {
        throw Exception('QR code has expired');
      }

      // Mark as used
      await SupabaseService.client
          .from('job_completion_codes')
          .update({
            'is_used': true,
            'used_at': DateTime.now().toUtc().toIso8601String(),
            'used_by_provider_id': mechanicId,
            'scan_latitude': latitude,
            'scan_longitude': longitude,
          })
          .eq('id', qrCodeId);

      // Update service request status
      await SupabaseService.client
          .from('service_requests')
          .update({
            'status': 'completed',
            'completed_at': DateTime.now().toUtc().toIso8601String(),
            'qr_scanned_at': DateTime.now().toUtc().toIso8601String(),
            'qr_scanned_by': mechanicId,
          })
          .eq('id', serviceRequestId);

      // Log QR code scan
      await _auditService.logQRCodeAction(
        userId: mechanicId ?? qrRecord['customer_id'] ?? 'unknown',
        userType: 'mechanic',
        action: 'QR_SCANNED',
        requestId: serviceRequestId,
        qrCode: completionCode,
        mechanicId: mechanicId,
        customerId: qrRecord['customer_id'],
        scanLat: latitude,
        scanLng: longitude,
      );

      // Log service request completion
      await _auditService.logServiceRequest(
        customerId: qrRecord['customer_id'],
        action: 'COMPLETE',
        requestId: serviceRequestId,
        mechanicId: mechanicId,
      );

      print('✅ QR code verified successfully');
      return {
        'success': true,
        'service_request_id': serviceRequestId,
        'customer_id': qrRecord['customer_id'],
        'completion_time': DateTime.now().toUtc().toIso8601String(),
      };

    } catch (e) {
      print('❌ QR verification failed: $e');

      // Try to log failed scan attempt
      try {
        final qrInfo = _parseQRData(qrData);
        if (qrInfo != null) {
          await _auditService.logQRCodeAction(
            userId: mechanicId ?? 'unknown',
            userType: 'mechanic',
            action: 'QR_SCAN_FAILED',
            requestId: qrInfo['service_request_id']!,
            qrCode: qrInfo['completion_code']!,
            mechanicId: mechanicId,
            customerId: '', // Will be filled if possible
          );
        }
      } catch (auditError) {
        print('❌ Failed to log scan attempt: $auditError');
      }

      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Get QR code information without verification
  Future<Map<String, dynamic>?> getQRCodeInfo(String qrData) async {
    try {
      final qrInfo = _parseQRData(qrData);
      if (qrInfo == null) return null;

      final qrRecord = await SupabaseService.client
          .from('job_completion_codes')
          .select('*, service_requests!inner(*)')
          .eq('id', qrInfo['qr_code_id']!)
          .eq('completion_code', qrInfo['completion_code']!)
          .maybeSingle();

      return qrRecord;
    } catch (e) {
      print('❌ Error getting QR info: $e');
      return null;
    }
  }

  /// Invalidate QR code
  Future<bool> invalidateQRCode(String qrCodeId) async {
    try {
      await SupabaseService.client
          .from('job_completion_codes')
          .update({'is_used': true, 'used_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', qrCodeId);
      return true;
    } catch (e) {
      print('❌ Error invalidating QR code: $e');
      return false;
    }
  }

  /// Generate unique completion code
  String _generateCompletionCode() {
    const chars = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    final random = Random();
    return List.generate(8, (index) => chars[random.nextInt(chars.length)]).join();
  }

  /// Generate unique ID
  String _generateUniqueId() {
    return DateTime.now().millisecondsSinceEpoch.toString() + 
           Random().nextInt(1000).toString().padLeft(3, '0');
  }

  /// Build QR data string
  String _buildQRData(String qrCodeId, String completionCode, String serviceRequestId) {
    final data = {
      'qr_code_id': qrCodeId,
      'completion_code': completionCode,
      'service_request_id': serviceRequestId,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    
    // Encrypt the data
    final encrypted = _encryptionService.encryptQRData(jsonEncode(data));
    return encrypted;
  }

  /// Parse QR data string
  Map<String, String>? _parseQRData(String qrData) {
    try {
      // Decrypt the data
      final decrypted = _encryptionService.decryptQRData(qrData);
      final data = jsonDecode(decrypted) as Map<String, dynamic>;
      
      return {
        'qr_code_id': data['qr_code_id'].toString(),
        'completion_code': data['completion_code'].toString(),
        'service_request_id': data['service_request_id'].toString(),
      };
    } catch (e) {
      print('❌ Error parsing QR data: $e');
      return null;
    }
  }

  /// Generate QR code data for display
  Future<String?> generateQRCodeData(String serviceRequestId) async {
    try {
      final request = await SupabaseService.client
          .from('service_requests')
          .select('qr_code_data')
          .eq('id', serviceRequestId)
          .maybeSingle();

      return request?['qr_code_data'];
    } catch (e) {
      print('❌ Error getting QR code data: $e');
      return null;
    }
  }

  /// Validate QR code format
  bool isValidQRFormat(String qrData) {
    try {
      final parsed = _parseQRData(qrData);
      return parsed != null && 
             parsed.containsKey('qr_code_id') &&
             parsed.containsKey('completion_code') &&
             parsed.containsKey('service_request_id');
    } catch (e) {
      return false;
    }
  }
}