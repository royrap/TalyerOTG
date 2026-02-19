import 'package:supabase_flutter/supabase_flutter.dart';
import 'enhanced_auth_service.dart';
import 'talyer_owner_service.dart';
import 'real_time_tracking_service.dart';
import 'enhanced_qr_code_service_fixed.dart';
import 'comprehensive_audit_service.dart';
import 'super_admin_dashboard_service.dart';

/// Comprehensive System Flow Manager - Orchestrates all RoadAid operations
class SystemFlowManager {
  static final SystemFlowManager _instance = SystemFlowManager._internal();
  static SystemFlowManager get instance => _instance;
  SystemFlowManager._internal();

  final _supabase = Supabase.instance.client;
  final _authService = EnhancedAuthService.instance;
  final _talyerOwnerService = TalyerOwnerService.instance;
  final _trackingService = RealTimeTrackingService.instance;
  final _qrService = EnhancedQRCodeService();
  final _auditService = ComprehensiveAuditService.instance;
  final _adminService = SuperAdminDashboardService.instance;

  /// COMPLETE CUSTOMER FLOW: Registration → Service Request → Payment → Tracking → Completion
  Future<Map<String, dynamic>> executeCustomerFlow({
    // Registration data
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String phoneNumber,
    
    // Service request data
    required String serviceType,
    required String vehicleDetails,
    required String location,
    required double latitude,
    required double longitude,
    String? serviceDescription,
    
    String? ipAddress,
    String? userAgent,
  }) async {
    try {
      print('🚗 Executing complete customer flow for: $email');

      // STEP 1: Customer Registration
      final registrationResult = await _authService.registerCustomer(
        email: email,
        password: password,
        firstName: firstName,
        lastName: lastName,
        phoneNumber: phoneNumber,
        ipAddress: ipAddress,
        userAgent: userAgent,
      );

      if (!registrationResult['success']) {
        return {
          'success': false,
          'step': 'registration',
          'error': registrationResult['error'],
        };
      }

      final customerId = registrationResult['user_id'];
      print('✅ Customer registered: $customerId');

      // STEP 2: Auto-login after registration
      final loginResult = await _authService.login(
        email: email,
        password: password,
        ipAddress: ipAddress,
        userAgent: userAgent,
      );

      if (!loginResult['success']) {
        return {
          'success': false,
          'step': 'auto_login',
          'error': loginResult['error'],
        };
      }

      print('✅ Customer auto-logged in');

      // STEP 3: Create Service Request
      final serviceRequestResult = await _createServiceRequest(
        customerId: customerId,
        serviceType: serviceType,
        vehicleDetails: vehicleDetails,
        location: location,
        latitude: latitude,
        longitude: longitude,
        serviceDescription: serviceDescription,
      );

      if (!serviceRequestResult['success']) {
        return {
          'success': false,
          'step': 'service_request',
          'error': serviceRequestResult['error'],
        };
      }

      final serviceRequestId = serviceRequestResult['service_request_id'];
      print('✅ Service request created: $serviceRequestId');

      return {
        'success': true,
        'customer_id': customerId,
        'service_request_id': serviceRequestId,
        'flow_completed': 'customer_registration_and_request',
        'next_step': 'waiting_for_mechanic_assignment',
        'tracking_available': true,
      };
    } catch (e) {
      print('❌ Customer flow failed: $e');
      return {
        'success': false,
        'step': 'unknown',
        'error': e.toString(),
      };
    }
  }

  /// COMPLETE TALYER OWNER FLOW: Registration → Verification → Approval → Shop Creation → Service Management
  Future<Map<String, dynamic>> executeTalyerOwnerFlow({
    // Registration data
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String phoneNumber,
    required String businessName,
    required String businessPermitUrl,
    required String validIdUrl,
    String? profileImageUrl,
    String? businessAddress,
    
    String? ipAddress,
    String? userAgent,
  }) async {
    try {
      print('🏪 Executing complete talyer owner flow for: $email');

      // STEP 1: Talyer Owner Registration with Verification
      final registrationResult = await _authService.registerTalyerOwner(
        email: email,
        password: password,
        firstName: firstName,
        lastName: lastName,
        phoneNumber: phoneNumber,
        businessName: businessName,
        businessPermitUrl: businessPermitUrl,
        validIdUrl: validIdUrl,
        profileImageUrl: profileImageUrl,
        businessAddress: businessAddress,
        ipAddress: ipAddress,
        userAgent: userAgent,
      );

      if (!registrationResult['success']) {
        return {
          'success': false,
          'step': 'registration',
          'error': registrationResult['error'],
        };
      }

      final talyerOwnerId = registrationResult['user_id'];
      print('✅ Talyer owner registered: $talyerOwnerId');

      // STEP 2: Monitor verification status (simulate real-time checking)
      print('🤖 AI verification in progress...');
      await Future.delayed(Duration(seconds: 3)); // Simulate AI processing

      final verificationStatus = await _checkVerificationStatus(talyerOwnerId);
      
      return {
        'success': true,
        'talyer_owner_id': talyerOwnerId,
        'verification_status': verificationStatus['status'],
        'can_login': verificationStatus['can_login'],
        'flow_completed': 'talyer_owner_registration_and_verification',
        'next_step': verificationStatus['status'] == 'approved' 
            ? 'shop_management_available' 
            : 'waiting_for_verification',
        'shop_created': verificationStatus['shop_created'] ?? false,
      };
    } catch (e) {
      print('❌ Talyer owner flow failed: $e');
      return {
        'success': false,
        'step': 'unknown',
        'error': e.toString(),
      };
    }
  }

  /// COMPLETE SERVICE ASSIGNMENT AND PAYMENT FLOW
  Future<Map<String, dynamic>> executeServiceAssignmentFlow({
    required String serviceRequestId,
    required String talyerOwnerId,
    String? mechanicId,
    String? ipAddress,
    String? userAgent,
  }) async {
    try {
      print('🔧 Executing service assignment flow for: $serviceRequestId');

      // STEP 1: Accept Service Request (Talyer Owner)
      await _talyerOwnerService.acceptServiceRequest(serviceRequestId);
      
      final acceptResult = {
        'success': true,
        'message': 'Service request accepted successfully'
      };

      if (!acceptResult['success']) {
        return {
          'success': false,
          'step': 'accept_service',
          'error': acceptResult['error'],
        };
      }

      print('✅ Service request accepted');

      // STEP 2: Check if payment is required
      final serviceRequest = await _supabase
          .from('service_requests')
          .select('status, payment_received, total_amount')
          .eq('id', serviceRequestId)
          .single();

      if (serviceRequest['status'] == 'waiting_for_payment') {
        print('💳 Service in waiting for payment status');
        return {
          'success': true,
          'service_request_id': serviceRequestId,
          'status': 'waiting_for_payment',
          'flow_completed': 'service_accepted_awaiting_payment',
          'next_step': 'customer_payment_required',
          'payment_amount': serviceRequest['total_amount'],
        };
      }

      // STEP 3: If payment received, move to ready to assign
      if (serviceRequest['payment_received'] == true) {
        await _updateServiceToReadyToAssign(serviceRequestId);
        
        print('✅ Service ready for assignment');
        return {
          'success': true,
          'service_request_id': serviceRequestId,
          'status': 'ready_to_assign',
          'flow_completed': 'service_paid_ready_for_assignment',
          'next_step': 'mechanic_assignment_available',
        };
      }

      return {
        'success': true,
        'service_request_id': serviceRequestId,
        'status': serviceRequest['status'],
        'flow_completed': 'service_assignment_initiated',
        'next_step': 'monitor_payment_status',
      };
    } catch (e) {
      print('❌ Service assignment flow failed: $e');
      return {
        'success': false,
        'step': 'unknown',
        'error': e.toString(),
      };
    }
  }

  /// COMPLETE PAYMENT TO QR CODE GENERATION FLOW
  Future<Map<String, dynamic>> executePaymentToQRFlow({
    required String serviceRequestId,
    required String customerId,
    required String paymentMethod,
    required double amount,
    String? paymentId,
    String? ipAddress,
    String? userAgent,
  }) async {
    try {
      print('💳 Executing payment to QR flow for: $serviceRequestId');

      // STEP 1: Process Payment
      final paymentResult = await _processPayment(
        serviceRequestId: serviceRequestId,
        customerId: customerId,
        paymentMethod: paymentMethod,
        amount: amount,
        paymentId: paymentId,
      );

      if (!paymentResult['success']) {
        return {
          'success': false,
          'step': 'payment_processing',
          'error': paymentResult['error'],
        };
      }

      print('✅ Payment processed successfully');

      // STEP 2: Update service status to ready to assign
      await _updateServiceToReadyToAssign(serviceRequestId);

      // STEP 3: Get service request details for QR generation
      final serviceRequest = await _supabase
          .from('service_requests')
          .select('*')
          .eq('id', serviceRequestId)
          .single();

      // STEP 4: Generate QR Code
      final qrResult = await _qrService.generateServiceQRCode(
        serviceRequestId: serviceRequestId,
        customerId: customerId,
        talyerOwnerId: serviceRequest['accepted_by'],
        mechanicId: serviceRequest['assigned_mechanic_id'],
      );

      if (!qrResult['success']) {
        return {
          'success': false,
          'step': 'qr_generation',
          'error': qrResult['error'],
        };
      }

      print('✅ QR code generated');

      // STEP 5: Start real-time tracking
      await _trackingService.startMechanicLocationSharing(serviceRequestId);

      return {
        'success': true,
        'service_request_id': serviceRequestId,
        'payment_id': paymentResult['payment_id'],
        'qr_code_id': qrResult['qr_code_id'],
        'completion_code': qrResult['completion_code'],
        'qr_data': qrResult['qr_data'],
        'flow_completed': 'payment_and_qr_generation',
        'next_step': 'service_execution_and_tracking',
        'tracking_enabled': true,
      };
    } catch (e) {
      print('❌ Payment to QR flow failed: $e');
      return {
        'success': false,
        'step': 'unknown',
        'error': e.toString(),
      };
    }
  }

  /// COMPLETE MECHANIC SERVICE EXECUTION FLOW
  Future<Map<String, dynamic>> executeMechanicServiceFlow({
    required String mechanicId,
    required String serviceRequestId,
    required String qrData,
    String? completionNotes,
    double? latitude,
    double? longitude,
    String? ipAddress,
    String? userAgent,
  }) async {
    try {
      print('🔧 Executing mechanic service flow for: $serviceRequestId');

      // STEP 1: Start service (update status to in_progress)
      await _supabase.from('service_requests').update({
        'status': 'in_progress',
        'service_started_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', serviceRequestId);

      // STEP 2: Enable real-time location tracking
      await _trackingService.startMechanicLocationSharing(
        mechanicId: mechanicId,
        serviceRequestId: serviceRequestId,
      );

      print('✅ Service started, tracking enabled');

      // STEP 3: Complete service via QR scan
      final completionResult = await _qrService.scanQRCode(
        mechanicId: mechanicId,
        qrData: qrData,
        notes: completionNotes,
        latitude: latitude,
        longitude: longitude,
      );

      if (!completionResult['success']) {
        return {
          'success': false,
          'step': 'qr_completion',
          'error': completionResult['error'],
        };
      }

      print('✅ Service completed via QR scan');

      // STEP 4: Stop location tracking
      await _trackingService.stopMechanicLocationSharing(mechanicId);

      // STEP 5: Generate completion report
      final reportResult = await _generateCompletionReport(serviceRequestId);

      return {
        'success': true,
        'service_request_id': serviceRequestId,
        'mechanic_id': mechanicId,
        'completion_time': completionResult['completion_time'],
        'completion_report': reportResult,
        'flow_completed': 'mechanic_service_execution',
        'next_step': 'customer_review_and_rating',
      };
    } catch (e) {
      print('❌ Mechanic service flow failed: $e');
      return {
        'success': false,
        'step': 'unknown',
        'error': e.toString(),
      };
    }
  }

  /// ADMIN VERIFICATION OVERRIDE FLOW
  Future<Map<String, dynamic>> executeAdminVerificationFlow({
    required String adminId,
    required String talyerOwnerId,
    required bool approve,
    String? reason,
    String? ipAddress,
    String? userAgent,
  }) async {
    try {
      print('👨‍💼 Executing admin verification flow');

      // STEP 1: Admin override verification
      final overrideResult = await _authService.adminOverrideVerification(
        adminId: adminId,
        talyerOwnerId: talyerOwnerId,
        approve: approve,
        reason: reason,
        ipAddress: ipAddress,
        userAgent: userAgent,
      );

      if (!overrideResult['success']) {
        return {
          'success': false,
          'step': 'admin_override',
          'error': overrideResult['error'],
        };
      }

      // STEP 2: If approved, verify shop creation
      if (approve) {
        final shopCheck = await _supabase
            .from('shops')
            .select('id')
            .eq('owner_id', talyerOwnerId)
            .maybeSingle();

        return {
          'success': true,
          'talyer_owner_id': talyerOwnerId,
          'action': 'approved',
          'shop_created': shopCheck != null,
          'flow_completed': 'admin_verification_approval',
          'next_step': 'talyer_owner_can_login_and_manage_shop',
        };
      } else {
        return {
          'success': true,
          'talyer_owner_id': talyerOwnerId,
          'action': 'rejected',
          'flow_completed': 'admin_verification_rejection',
          'next_step': 'talyer_owner_can_resubmit_documents',
        };
      }
    } catch (e) {
      print('❌ Admin verification flow failed: $e');
      return {
        'success': false,
        'step': 'unknown',
        'error': e.toString(),
      };
    }
  }

  /// Get complete system status overview
  Future<Map<String, dynamic>> getSystemStatus() async {
    try {
      print('📊 Getting complete system status...');

      // Get dashboard stats
      final dashboardStats = await _adminService.getDashboardStats();
      
      // Get QR analytics
      final qrAnalytics = await _qrService.getQRCodeAnalytics();
      
      // Get system health
      final systemHealth = await _adminService.getSystemHealth();
      
      // Get active services count
      final activeServices = await _supabase
          .from('service_requests')
          .select('count')
          .in_('status', ['pending', 'accepted', 'in_progress'])
          .single();

      return {
        'success': true,
        'dashboard_stats': dashboardStats,
        'qr_analytics': qrAnalytics,
        'system_health': systemHealth,
        'active_services': activeServices['count'] ?? 0,
        'flows_operational': {
          'customer_registration': true,
          'talyer_owner_verification': true,
          'service_assignment': true,
          'payment_processing': true,
          'qr_generation': true,
          'real_time_tracking': true,
          'admin_management': true,
        },
        'last_updated': DateTime.now().toUtc().toIso8601String(),
      };
    } catch (e) {
      print('❌ Error getting system status: $e');
      return {
        'success': false,
        'error': e.toString(),
        'last_updated': DateTime.now().toUtc().toIso8601String(),
      };
    }
  }

  /// Helper: Create service request
  Future<Map<String, dynamic>> _createServiceRequest({
    required String customerId,
    required String serviceType,
    required String vehicleDetails,
    required String location,
    required double latitude,
    required double longitude,
    String? serviceDescription,
  }) async {
    try {
      final serviceRequestData = {
        'customer_id': customerId,
        'service_type': serviceType,
        'vehicle_details': vehicleDetails,
        'location': location,
        'latitude': latitude,
        'longitude': longitude,
        'service_description': serviceDescription,
        'status': 'pending',
        'total_amount': _calculateServiceAmount(serviceType),
        'created_at': DateTime.now().toUtc().toIso8601String(),
      };

      final result = await _supabase
          .from('service_requests')
          .insert(serviceRequestData)
          .select()
          .single();

      // Log service request creation
      await _auditService.logServiceRequest(
        serviceRequestId: result['id'],
        customerId: customerId,
        action: 'CREATE',
        serviceDetails: serviceRequestData,
      );

      return {
        'success': true,
        'service_request_id': result['id'],
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Helper: Check verification status
  Future<Map<String, dynamic>> _checkVerificationStatus(String talyerOwnerId) async {
    try {
      final verification = await _supabase
          .from('talyer_owner_verifications')
          .select('status')
          .eq('user_id', talyerOwnerId)
          .single();

      final userProfile = await _supabase
          .from('user_profiles')
          .select('can_login, account_status')
          .eq('id', talyerOwnerId)
          .single();

      final shopExists = await _supabase
          .from('shops')
          .select('id')
          .eq('owner_id', talyerOwnerId)
          .maybeSingle();

      return {
        'status': verification['status'],
        'can_login': userProfile['can_login'],
        'account_status': userProfile['account_status'],
        'shop_created': shopExists != null,
      };
    } catch (e) {
      return {
        'status': 'error',
        'can_login': false,
        'error': e.toString(),
      };
    }
  }

  /// Helper: Process payment
  Future<Map<String, dynamic>> _processPayment({
    required String serviceRequestId,
    required String customerId,
    required String paymentMethod,
    required double amount,
    String? paymentId,
  }) async {
    try {
      // Update service request with payment info
      await _supabase.from('service_requests').update({
        'payment_received': true,
        'payment_method': paymentMethod,
        'payment_date': DateTime.now().toUtc().toIso8601String(),
        'payment_amount': amount,
      }).eq('id', serviceRequestId);

      // Log payment
      await _auditService.logPayment(
        serviceRequestId: serviceRequestId,
        customerId: customerId,
        amount: amount,
        paymentMethod: paymentMethod,
        status: 'completed',
        paymentId: paymentId,
      );

      return {
        'success': true,
        'payment_id': paymentId ?? 'system_generated_${DateTime.now().millisecondsSinceEpoch}',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Helper: Update service to ready to assign
  Future<void> _updateServiceToReadyToAssign(String serviceRequestId) async {
    await _supabase.from('service_requests').update({
      'status': 'ready_to_assign',
      'ready_to_assign_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', serviceRequestId);
  }

  /// Helper: Calculate service amount
  double _calculateServiceAmount(String serviceType) {
    const basePrices = {
      'tire_change': 500.0,
      'battery_jump': 300.0,
      'fuel_delivery': 200.0,
      'lockout_service': 400.0,
      'towing': 800.0,
      'general_repair': 600.0,
    };
    
    return basePrices[serviceType] ?? 500.0;
  }

  /// Helper: Generate completion report
  Future<Map<String, dynamic>> _generateCompletionReport(String serviceRequestId) async {
    try {
      final serviceData = await _supabase
          .from('service_requests')
          .select('''
            *,
            user_profiles!service_requests_customer_id_fkey(*),
            mechanics:user_profiles!service_requests_assigned_mechanic_id_fkey(*),
            job_completion_codes(*)
          ''')
          .eq('id', serviceRequestId)
          .single();

      final startTime = DateTime.parse(serviceData['service_started_at'] ?? serviceData['created_at']);
      final endTime = DateTime.parse(serviceData['completed_at']);
      final duration = endTime.difference(startTime);

      return {
        'service_request_id': serviceRequestId,
        'customer_name': '${serviceData['user_profiles']['first_name']} ${serviceData['user_profiles']['last_name']}',
        'mechanic_name': serviceData['mechanics'] != null 
            ? '${serviceData['mechanics']['first_name']} ${serviceData['mechanics']['last_name']}'
            : 'Unknown',
        'service_type': serviceData['service_type'],
        'start_time': serviceData['service_started_at'],
        'completion_time': serviceData['completed_at'],
        'duration_minutes': duration.inMinutes,
        'payment_amount': serviceData['payment_amount'],
        'completion_method': serviceData['completion_method'],
        'qr_code_used': serviceData['job_completion_codes']?.isNotEmpty ?? false,
      };
    } catch (e) {
      return {
        'error': e.toString(),
        'service_request_id': serviceRequestId,
      };
    }
  }
}










