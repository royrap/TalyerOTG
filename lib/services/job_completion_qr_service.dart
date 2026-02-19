import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'dart:math';
import 'audit_logging_service.dart';

class JobCompletionQRService {
  static final JobCompletionQRService _instance = JobCompletionQRService._internal();
  static JobCompletionQRService get instance => _instance;
  JobCompletionQRService._internal();

  final _supabase = Supabase.instance.client;

  // Generate QR code for job completion after payment
  Future<Map<String, dynamic>?> generateJobCompletionQR({
    required String requestId,
    required String customerId,
  }) async {
    try {
      print('🎯 Generating job completion QR for request: $requestId');

      // Generate unique completion code
      final completionCode = _generateCompletionCode();
      final expiresAt = DateTime.now().add(const Duration(hours: 24)); // Expires in 24 hours

      // Create completion code record
      final response = await _supabase
          .from('job_completion_codes')
          .insert({
            'request_id': requestId,
            'customer_id': customerId,
            'completion_code': completionCode,
            'is_used': false,
            'created_at': DateTime.now().toIso8601String(),
            'expires_at': expiresAt.toIso8601String(),
            'verification_status': 'pending',
          })
          .select()
          .single();

      print('✅ Job completion QR generated: $completionCode');
      
      // Log QR code generation
      try {
        final auditService = AuditLoggingService();
        await auditService.logQRCodeGenerated(
          customerId: customerId,
          qrCodeId: response['id'],
          completionCode: completionCode,
          serviceRequestId: requestId,
        );
      } catch (auditError) {
        print('Failed to log QR generation audit: $auditError');
      }
      
      return {
        'id': response['id'],
        'completion_code': completionCode,
        'qr_data': _generateQRData(requestId, completionCode),
        'expires_at': expiresAt.toIso8601String(),
        'request_id': requestId,
      };

    } catch (e) {
      print('❌ Error generating job completion QR: $e');
      return null;
    }
  }

  // Get existing QR code for a request
  Future<Map<String, dynamic>?> getJobCompletionQR(String requestId) async {
    try {
      final response = await _supabase
          .from('job_completion_codes')
          .select()
          .eq('request_id', requestId)
          .eq('is_used', false)
          .gte('expires_at', DateTime.now().toIso8601String())
          .maybeSingle();

      if (response != null) {
        return {
          'id': response['id'],
          'completion_code': response['completion_code'],
          'qr_data': _generateQRData(requestId, response['completion_code']),
          'expires_at': response['expires_at'],
          'request_id': requestId,
        };
      }

      return null;
    } catch (e) {
      print('❌ Error getting job completion QR: $e');
      return null;
    }
  }

  // Verify and use QR code (called by mechanic)
  Future<bool> verifyAndUseQR({
    required String completionCode,
    required String providerId,
    double? scanLatitude,
    double? scanLongitude,
  }) async {
    try {
      print('🔍 Verifying completion code: $completionCode');

      // Get the completion code record with related service request info
      final codeRecord = await _supabase
          .from('job_completion_codes')
          .select('''
            *,
            service_requests (
              id,
              customer_id,
              assigned_mechanic_id,
              shop_id,
              title,
              description,
              final_price,
              service_type,
              status
            )
          ''')
          .eq('completion_code', completionCode)
          .eq('is_used', false)
          .gte('expires_at', DateTime.now().toIso8601String())
          .maybeSingle();

      if (codeRecord == null) {
        print('❌ Invalid or expired completion code');
        
        // Log failed QR scan
        try {
          final auditService = AuditLoggingService();
          await auditService.logQRCodeScanned(
            mechanicId: providerId,
            qrCodeId: 'unknown',
            completionCode: completionCode,
            serviceRequestId: 'unknown',
            success: false,
            errorMessage: 'Invalid or expired completion code',
          );
        } catch (auditError) {
          print('Failed to log failed QR scan audit: $auditError');
        }
        
        return false;
      }

      final serviceRequest = codeRecord['service_requests'];
      if (serviceRequest == null) {
        print('❌ Service request not found for completion code');
        return false;
      }

      // Validate that the provider is authorized to complete this job
      final assignedMechanicId = serviceRequest['assigned_mechanic_id'];
      if (assignedMechanicId != null && assignedMechanicId != providerId) {
        // Check if provider is part of the same shop
        final isAuthorized = await _validateProviderAuthorization(providerId, serviceRequest['shop_id']);
        if (!isAuthorized) {
          print('❌ Provider not authorized to complete this job');
          return false;
        }
      }

      // Try using database function first for atomic completion
      try {
        final result = await _supabase.rpc('complete_job_with_qr_scan', params: {
          'p_completion_code_id': codeRecord['id'],
          'p_request_id': codeRecord['request_id'],
          'p_provider_id': providerId,
          'p_completed_at': DateTime.now().toIso8601String(),
          'p_scan_latitude': scanLatitude,
          'p_scan_longitude': scanLongitude,
        });

        if (result != null && result['success'] == true) {
          print('✅ Job completed via database function: ${result['request_id']}');
          print('💰 Earnings: ${result['earnings']}');
          
          // Log successful QR scan and job completion
          try {
            final auditService = AuditLoggingService();
            await auditService.logQRCodeScanned(
              mechanicId: providerId,
              qrCodeId: codeRecord['id'],
              completionCode: completionCode,
              serviceRequestId: codeRecord['request_id'],
              success: true,
            );
            
            // Log earnings calculation
            await auditService.logEarningsCalculated(
              userId: providerId,
              role: 'mechanic',
              serviceRequestId: codeRecord['request_id'],
              amount: (result['earnings']['total_amount'] as num?)?.toDouble() ?? 0.0,
              earningsBreakdown: result['earnings'],
            );
          } catch (auditError) {
            print('Failed to log successful QR scan audit: $auditError');
          }
          
          return true;
        } else {
          print('⚠️ Database function failed, using fallback: ${result?['error']}');
          throw result?['error'] ?? 'Database function failed';
        }
      } catch (rpcError) {
        print('⚠️ RPC function not available, using manual completion: $rpcError');
        
        // Fallback to manual completion
        return await _completeJobWithQRScan(
          codeRecord: codeRecord,
          serviceRequest: serviceRequest,
          providerId: providerId,
          scanLatitude: scanLatitude,
          scanLongitude: scanLongitude,
        );
      }

    } catch (e) {
      print('❌ Error verifying QR code: $e');
      return false;
    }
  }

  // Validate if provider is authorized to complete the job
  Future<bool> _validateProviderAuthorization(String providerId, String? shopId) async {
    try {
      if (shopId == null) return true; // Direct mechanic assignment
      
      // Check if provider belongs to the shop or is the shop owner
      final shopMember = await _supabase
          .from('user_profiles')
          .select('id, user_type, shop_id')
          .eq('id', providerId)
          .maybeSingle();
      
      if (shopMember == null) return false;
      
      // Provider is authorized if they belong to the shop or are a shop owner
      return shopMember['shop_id'] == shopId || 
             shopMember['user_type'] == 'talyer_owner';
    } catch (e) {
      print('❌ Error validating provider authorization: $e');
      return false;
    }
  }

  // Complete job with QR scan and integrate with earnings system
  Future<bool> _completeJobWithQRScan({
    required Map<String, dynamic> codeRecord,
    required Map<String, dynamic> serviceRequest,
    required String providerId,
    double? scanLatitude,
    double? scanLongitude,
  }) async {
    try {
      final completedAt = DateTime.now().toIso8601String();
      final requestId = codeRecord['request_id'];
      final finalPrice = serviceRequest['final_price']?.toDouble() ?? 0.0;
      
      print('💰 Completing job with earnings calculation: Request $requestId, Amount ₱$finalPrice');

      // 1. Mark completion code as used
      await _supabase
          .from('job_completion_codes')
          .update({
            'is_used': true,
            'used_at': completedAt,
            'used_by_provider_id': providerId,
            'verification_status': 'verified',
            'scan_latitude': scanLatitude,
            'scan_longitude': scanLongitude,
          })
          .eq('id', codeRecord['id']);

      // 2. Update service request status to completed
      await _supabase
          .from('service_requests')
          .update({
            'status': 'completed',
            'completed_at': completedAt,
            'qr_scanned_at': completedAt,
            'qr_scanned_by': providerId,
            'service_completion_time': completedAt,
          })
          .eq('id', requestId);

      // 3. Record mechanic job history with earnings calculation
      await _recordMechanicJobHistoryWithEarnings(serviceRequest, providerId, completedAt, finalPrice);

      // 4. Record customer job history
      await _recordCustomerJobHistory(serviceRequest, completedAt);

      // 5. Create service completion record for additional tracking
      await _createServiceCompletionRecord(serviceRequest, providerId, completedAt);

      print('✅ Job completed successfully with earnings integration: $requestId');
      return true;
      
    } catch (e) {
      print('❌ Error completing job with QR scan: $e');
      return false;
    }
  }

  // Create service completion record
  Future<void> _createServiceCompletionRecord(
    Map<String, dynamic> serviceRequest, 
    String mechanicId, 
    String completedAt
  ) async {
    try {
      // Generate completion code for service_completions table if needed
      final completionCode = _generateCompletionCode();
      final qrData = _generateQRData(serviceRequest['id'], completionCode);
      
      await _supabase.from('service_completions').insert({
        'request_id': serviceRequest['id'],
        'mechanic_id': mechanicId,
        'customer_id': serviceRequest['customer_id'],
        'completion_code': completionCode,
        'qr_code_data': qrData,
        'is_scanned': true,
        'scanned_at': completedAt,
        'verification_status': 'verified',
        'created_at': completedAt,
        'expires_at': DateTime.now().add(Duration(hours: 1)).toIso8601String(),
      });
      
      print('✅ Service completion record created');
    } catch (e) {
      print('⚠️ Warning: Could not create service completion record: $e');
      // Don't fail the whole process if this fails
    }
  }

  // Fallback method for job completion without RPC function
  Future<bool> _fallbackJobCompletion(
    String completionCode, 
    String providerId,
    double? scanLatitude,
    double? scanLongitude,
  ) async {
    try {
      // Get the completion code record with service request details
      final codeRecord = await _supabase
          .from('job_completion_codes')
          .select('*, request_id, customer_id')
          .eq('completion_code', completionCode)
          .eq('is_used', false)
          .gte('expires_at', DateTime.now().toIso8601String())
          .single();

      // Get full service request details
      final serviceRequest = await _supabase
          .from('service_requests')
          .select('''
            id,
            customer_id,
            assigned_mechanic_id,
            shop_id,
            title,
            description,
            final_price,
            service_type,
            status
          ''')
          .eq('id', codeRecord['request_id'])
          .single();

      final completedAt = DateTime.now().toIso8601String();

      // 1. Mark completion code as used
      await _supabase
          .from('job_completion_codes')
          .update({
            'is_used': true,
            'used_at': completedAt,
            'used_by_provider_id': providerId,
            'verification_status': 'verified',
            'scan_latitude': scanLatitude,
            'scan_longitude': scanLongitude,
          })
          .eq('id', codeRecord['id']);

      // 2. Update service request status to completed
      await _supabase
          .from('service_requests')
          .update({
            'status': 'completed',
            'completed_at': completedAt,
            'qr_scanned_at': completedAt,
            'qr_scanned_by': providerId,
          })
          .eq('id', codeRecord['request_id']);

      // 3. Record job history for mechanic
      await _recordMechanicJobHistory(serviceRequest, completedAt);

      // 4. Record job history for customer  
      await _recordCustomerJobHistory(serviceRequest, completedAt);

      print('✅ Fallback job completion successful: ${codeRecord['request_id']}');
      return true;

    } catch (e) {
      print('❌ Error in fallback job completion: $e');
      return false;
    }
  }

  // Record job history for mechanic with earnings calculation
  Future<void> _recordMechanicJobHistoryWithEarnings(
    Map<String, dynamic> serviceRequest, 
    String mechanicId, 
    String completedAt,
    double finalPrice
  ) async {
    try {
      // Get mechanic rating/review if exists
      final review = await _supabase
          .from('reviews')
          .select('rating, comment')
          .eq('request_id', serviceRequest['id'])
          .maybeSingle();

      // Calculate Angkas-style earnings (75% mechanic, 20% shop, 5% platform)
      final mechanicEarnings = (finalPrice * 0.75);
      final shopEarnings = (finalPrice * 0.20);
      final platformFee = (finalPrice * 0.05);

      print('💰 Earnings calculation for ₱$finalPrice: Mechanic ₱${mechanicEarnings.toStringAsFixed(2)}, Shop ₱${shopEarnings.toStringAsFixed(2)}, Platform ₱${platformFee.toStringAsFixed(2)}');

      await _supabase.from('mechanic_job_history').insert({
        'mechanic_id': mechanicId,
        'service_request_id': serviceRequest['id'],
        'customer_id': serviceRequest['customer_id'],
        'shop_id': serviceRequest['shop_id'],
        'job_title': serviceRequest['title'] ?? serviceRequest['service_type'] ?? 'Service Request',
        'job_description': serviceRequest['description'],
        'job_status': 'completed',
        'completed_at': completedAt,
        'total_amount': finalPrice,
        'mechanic_earnings': mechanicEarnings,
        'shop_earnings': shopEarnings,
        'platform_fee': platformFee,
        'fee_percentage_mechanic': 75.00,
        'fee_percentage_shop': 20.00,
        'fee_percentage_platform': 5.00,
        'rating': review?['rating'],
        'review_text': review?['comment'],
        'created_at': completedAt,
        'updated_at': completedAt,
      });

      print('✅ Mechanic job history with earnings recorded for: $mechanicId');
    } catch (e) {
      print('❌ Error recording mechanic job history with earnings: $e');
    }
  }

  // Legacy method for backward compatibility
  Future<void> _recordMechanicJobHistory(Map<String, dynamic> serviceRequest, String completedAt) async {
    final mechanicId = serviceRequest['assigned_mechanic_id'];
    if (mechanicId == null) return;
    
    final finalPrice = serviceRequest['final_price']?.toDouble() ?? 0.0;
    await _recordMechanicJobHistoryWithEarnings(serviceRequest, mechanicId, completedAt, finalPrice);
  }

  // Record job history for customer
  Future<void> _recordCustomerJobHistory(Map<String, dynamic> serviceRequest, String completedAt) async {
    try {
      final customerId = serviceRequest['customer_id'];
      if (customerId == null) return;

      // Get customer rating/review if exists
      final review = await _supabase
          .from('reviews')
          .select('rating, comment')
          .eq('request_id', serviceRequest['id'])
          .maybeSingle();

      // Get mechanic and shop names
      final mechanicId = serviceRequest['assigned_mechanic_id'];
      final shopId = serviceRequest['shop_id'];

      String? mechanicName;
      String? shopName;

      if (mechanicId != null) {
        final mechanic = await _supabase
            .from('user_profiles')
            .select('first_name, last_name')
            .eq('id', mechanicId)
            .maybeSingle();
        
        if (mechanic != null) {
          mechanicName = '${mechanic['first_name']} ${mechanic['last_name']}'.trim();
        }
      }

      if (shopId != null) {
        final shop = await _supabase
            .from('shops')
            .select('shop_name')
            .eq('id', shopId)
            .maybeSingle();
        
        shopName = shop?['shop_name'];
      }

      await _supabase.from('customer_job_history').insert({
        'customer_id': customerId,
        'service_request_id': serviceRequest['id'],
        'mechanic_id': mechanicId,
        'shop_id': shopId,
        'job_title': serviceRequest['title'] ?? serviceRequest['service_type'] ?? 'Service Request',
        'job_description': serviceRequest['description'],
        'job_status': 'completed',
        'completed_at': completedAt,
        'total_amount': serviceRequest['final_price'],
        'rating': review?['rating'],
        'review_text': review?['comment'],
        'mechanic_name': mechanicName,
        'shop_name': shopName,
        'created_at': completedAt,
        'updated_at': completedAt,
      });

      print('✅ Customer job history recorded for: $customerId');
    } catch (e) {
      print('❌ Error recording customer job history: $e');
    }
  }

  // Generate unique completion code
  String _generateCompletionCode() {
    const String chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final Random random = Random();
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString().substring(8);
    
    String code = '';
    for (int i = 0; i < 6; i++) {
      code += chars[random.nextInt(chars.length)];
    }
    
    return 'JOB-$code-$timestamp';
  }

  // Generate QR data string
  String _generateQRData(String requestId, String completionCode) {
    return 'RoadAid_JOB_COMPLETION:$requestId:$completionCode:${DateTime.now().millisecondsSinceEpoch}';
  }

  // Parse QR data (for mechanic scanner)
  Map<String, String>? parseQRData(String qrData) {
    try {
      if (!qrData.startsWith('RoadAid_JOB_COMPLETION:')) {
        return null;
      }

      final parts = qrData.split(':');
      if (parts.length != 4) {
        return null;
      }

      return {
        'type': 'job_completion',
        'request_id': parts[1],
        'completion_code': parts[2],
        'timestamp': parts[3],
      };
    } catch (e) {
      print('❌ Error parsing QR data: $e');
      return null;
    }
  }

  // Check if QR code is valid and not expired
  Future<bool> isQRCodeValid(String completionCode) async {
    try {
      final response = await _supabase
          .from('job_completion_codes')
          .select('id')
          .eq('completion_code', completionCode)
          .eq('is_used', false)
          .gte('expires_at', DateTime.now().toIso8601String())
          .maybeSingle();

      return response != null;
    } catch (e) {
      print('❌ Error checking QR code validity: $e');
      return false;
    }
  }

  // Get completion status for a request
  Future<String?> getJobCompletionStatus(String requestId) async {
    try {
      final response = await _supabase
          .from('service_requests')
          .select('status')
          .eq('id', requestId)
          .single();

      return response['status'];
    } catch (e) {
      print('❌ Error getting job completion status: $e');
      return null;
    }
  }
}