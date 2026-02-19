import 'package:supabase_flutter/supabase_flutter.dart';
import 'talyer_owner_service.dart';
import 'real_time_tracking_service.dart';
import 'enhanced_qr_code_service_fixed.dart';

/// Simplified System Flow Manager - Fixed version with proper method calls
class SystemFlowManager {
  static final SystemFlowManager _instance = SystemFlowManager._internal();
  static SystemFlowManager get instance => _instance;
  SystemFlowManager._internal();

  final _supabase = Supabase.instance.client;
  final _talyerOwnerService = TalyerOwnerService.instance;
  final _trackingService = RealTimeTrackingService.instance;
  final _qrService = EnhancedQRCodeService();

  /// Basic flow management with working method calls
  Future<Map<String, dynamic>> executeBasicServiceFlow({
    required String serviceRequestId,
  }) async {
    try {
      print('🚀 Starting basic service flow: $serviceRequestId');

      // Get service request details
      final serviceRequest = await _supabase
          .from('service_requests')
          .select('*')
          .eq('id', serviceRequestId)
          .maybeSingle();

      if (serviceRequest == null) {
        return {
          'success': false,
          'error': 'Service request not found',
        };
      }

      // Accept the service request
      await _talyerOwnerService.acceptServiceRequest(serviceRequestId);
      
      // Start location tracking if mechanic is assigned
      if (serviceRequest['status'] == 'accepted') {
        await _trackingService.startMechanicLocationSharing(serviceRequestId);
      }

      // Generate QR code for completion
      final qrResult = await _qrService.generateServiceQRCode(
        serviceRequestId: serviceRequestId,
        customerId: serviceRequest['customer_id'],
        mechanicId: serviceRequest['assigned_mechanic_id'],
      );

      return {
        'success': true,
        'service_request_id': serviceRequestId,
        'qr_code_generated': qrResult.isNotEmpty,
        'tracking_enabled': true,
        'flow_step': 'basic_flow_complete',
      };
    } catch (e) {
      print('❌ Error in basic service flow: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Complete service completion flow
  Future<Map<String, dynamic>> completeServiceFlow({
    required String serviceRequestId,
    required String qrCodeData,
  }) async {
    try {
      print('🏁 Completing service flow: $serviceRequestId');

      // Verify QR code
      final verificationResult = await _qrService.verifyQRCodeScan(
        qrData: qrCodeData,
      );

      if (!verificationResult['success']) {
        return {
          'success': false,
          'error': 'QR code verification failed',
          'details': verificationResult,
        };
      }

      // Stop location tracking
      _trackingService.stopMechanicLocationSharing();

      // Update service request status
      await _supabase
          .from('service_requests')
          .update({
            'status': 'completed',
            'completed_at': DateTime.now().toIso8601String(),
          })
          .eq('id', serviceRequestId);

      return {
        'success': true,
        'service_request_id': serviceRequestId,
        'flow_step': 'service_completed',
        'completion_time': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      print('❌ Error completing service flow: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Get system status
  Future<Map<String, dynamic>> getSystemStatus() async {
    try {
      // Get basic system metrics
      final activeServices = await _supabase
          .from('service_requests')
          .select('id')
          .inFilter('status', ['pending', 'accepted', 'in_progress']);

      final totalUsers = await _supabase
          .from('user_profiles')
          .select('id')
          .limit(1000);

      return {
        'success': true,
        'active_services': activeServices.length,
        'total_users': totalUsers.length,
        'system_status': 'operational',
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      print('❌ Error getting system status: $e');
      return {
        'success': false,
        'error': e.toString(),
        'system_status': 'error',
      };
    }
  }
}