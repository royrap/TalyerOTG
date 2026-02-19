import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';
import '../services/enhanced_qr_code_service.dart';

class EnhancedServiceRequestService {
  static final supabase = Supabase.instance.client;

  /// Create service request with enhanced status tracking
  static Future<Map<String, dynamic>?> createServiceRequestWithStatus({
    required String vehicleId,
    required String title,
    required String description,
    required String serviceType,
    required double latitude,
    required double longitude,
    required String locationAddress,
    String? shopId,
    String? providerId,
    bool isShopBased = false,
  }) async {
    try {
      print('🔍 Creating enhanced service request...');
      
      final user = await AuthService.getCurrentUser();
      if (user == null) {
        throw Exception('User not authenticated');
      }
      
      // Determine request type and routing
      String requestType = isShopBased ? 'shop_based' : 'broadcast';
      
      // ====================================================================
      // 🔍 DEBUG: Log all parameters
      // ====================================================================
      print('🔍 EnhancedServiceRequestService.createServiceRequestWithStatus():');
      print('  - isShopBased: $isShopBased');
      print('  - shopId: $shopId');
      print('  - providerId: $providerId');
      print('  - requestType: $requestType');
      // ====================================================================
      
      // Create service request with proper status flow
      final requestData = {
        'customer_id': user.id,
        'vehicle_id': vehicleId,
        'title': title,
        'description': description,
        'service_type': serviceType,
        'pickup_latitude': latitude,
        'pickup_longitude': longitude,
        'pickup_address': locationAddress,
        'status': 'pending', // Initial status
        'payment_status': 'pending',
        'request_type': requestType,
        'is_broadcast_request': !isShopBased,
        'can_accept_by_any_mechanic': !isShopBased,
  // Save both preferred_shop_id and shop_id for shop-based requests.
  // Some code paths and listeners rely on `shop_id` to filter visibility,
  // so persist it here to avoid accidentally broadcasting shop-based requests.
  if (isShopBased && shopId != null) 'preferred_shop_id': shopId,
  if (isShopBased && shopId != null) 'shop_id': shopId,
  if (isShopBased && providerId != null) 'provider_id': providerId,
        'broadcast_radius_km': isShopBased ? 5.0 : 50.0,
        'created_at': DateTime.now().toIso8601String(),
      };
      
      print('  - Request type: $requestType');
      print('  - Shop-based: $isShopBased');
      print('  - Shop ID will be saved as: ${isShopBased && shopId != null ? shopId : 'NULL (broadcast mode)'}');
      print('📝 Data to INSERT into database:');
      print('  - preferred_shop_id: ${requestData['preferred_shop_id'] ?? 'NULL'}');
      print('  - request_type: ${requestData['request_type']}');
      print('  - is_broadcast_request: ${requestData['is_broadcast_request']}');
      
      // Insert service request
      final serviceRequest = await supabase
          .from('service_requests')
          .insert(requestData)
          .select()
          .single();
      
      print('✅ Service request created: ${serviceRequest['id']}');
      
      // Create initial status history record
      await _createStatusHistory(
        serviceRequest['id'],
        'pending',
        'Service request created by customer',
        user.id,
      );
      
      return serviceRequest;
      
    } catch (e) {
      print('❌ Error creating service request: $e');
      return null;
    }
  }
  
  /// Update service request status with history tracking
  static Future<bool> updateServiceRequestStatus({
    required String requestId,
    required String newStatus,
    String? notes,
    String? changedBy,
  }) async {
    try {
      // Update service request
      await supabase
          .from('service_requests')
          .update({
            'status': newStatus,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', requestId);
      
      // Create status history
      await _createStatusHistory(requestId, newStatus, notes, changedBy);
      
      print('✅ Status updated to: $newStatus');
      return true;
      
    } catch (e) {
      print('❌ Error updating status: $e');
      return false;
    }
  }
  
  /// Handle mechanic acceptance with FIFO
  static Future<bool> acceptServiceRequest({
    required String requestId,
    required String mechanicId,
  }) async {
    try {
      print('🎯 Mechanic accepting request: $requestId');
      
      // Check if request is still available (FIFO)
      final request = await supabase
          .from('service_requests')
          .select('status')
          .eq('id', requestId)
          .single();
      
      if (request['status'] != 'pending') {
        print('❌ Request no longer available (status: ${request['status']})');
        return false;
      }
      
      // Accept the request
      await supabase
          .from('service_requests')
          .update({
            'status': 'accepted',
            'assigned_mechanic_id': mechanicId,
            'accepted_at': DateTime.now().toIso8601String(),
          })
          .eq('id', requestId);
      
      // Create status history
      await _createStatusHistory(
        requestId,
        'accepted',
        'Request accepted by mechanic',
        mechanicId,
      );
      
      print('✅ Request accepted successfully');
      return true;
      
    } catch (e) {
      print('❌ Error accepting request: $e');
      return false;
    }
  }
  
  /// Handle payment completion
  static Future<bool> markPaymentCompleted({
    required String requestId,
    required String paymentId,
    double? serviceFee,
  }) async {
    try {
      await supabase
          .from('service_requests')
          .update({
            'payment_status': 'completed',
            'status': 'paid',
            'payment_completed_at': DateTime.now().toIso8601String(),
            if (serviceFee != null) 'service_fee': serviceFee,
          })
          .eq('id', requestId);
      
      await _createStatusHistory(
        requestId,
        'paid',
        'Service fee payment completed',
        null,
      );
      
      print('✅ Payment marked as completed');
      return true;
      
    } catch (e) {
      print('❌ Error marking payment as completed: $e');
      return false;
    }
  }
  
  /// Mark mechanic as dispatched
  static Future<bool> dispatchMechanic({
    required String requestId,
    required String mechanicId,
  }) async {
    try {
      await supabase
          .from('service_requests')
          .update({
            'status': 'mechanic_dispatched',
            'mechanic_assigned_at': DateTime.now().toIso8601String(),
          })
          .eq('id', requestId);
      
      await _createStatusHistory(
        requestId,
        'mechanic_dispatched',
        'Mechanic dispatched to customer location',
        mechanicId,
      );
      
      return true;
    } catch (e) {
      print('❌ Error dispatching mechanic: $e');
      return false;
    }
  }
  
  /// Send invoice to customer
  static Future<bool> sendInvoice({
    required String requestId,
    required String invoiceId,
    required String mechanicId,
  }) async {
    try {
      await supabase
          .from('service_requests')
          .update({
            'status': 'invoice_sent',
            'invoice_generated': true,
          })
          .eq('id', requestId);
      
      await _createStatusHistory(
        requestId,
        'invoice_sent',
        'Invoice sent to customer',
        mechanicId,
      );
      
      return true;
    } catch (e) {
      print('❌ Error sending invoice: $e');
      return false;
    }
  }
  
  /// Handle invoice payment and generate QR code
  static Future<Map<String, dynamic>?> completeInvoicePayment({
    required String requestId,
    required String customerId,
    String? mechanicId,
  }) async {
    try {
      // Update request status
      await supabase
          .from('service_requests')
          .update({
            'status': 'invoice_paid',
            'payment_status': 'completed',
            'payment_completed_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', requestId);
      
      // Also update the invoice status to paid
      await supabase
          .from('invoices')
          .update({
            'status': 'paid',
            'paid_at': DateTime.now().toIso8601String(),
          })
          .eq('request_id', requestId);
      
      await _createStatusHistory(
        requestId,
        'invoice_paid',
        'Invoice payment completed',
        customerId,
      );
      
      print('✅ Both service request and invoice statuses updated to paid');
      
      // Generate QR code for service completion
      final qrResult = await EnhancedQRCodeService().generateServiceQRCode(
        serviceRequestId: requestId,
        customerId: customerId,
        mechanicId: mechanicId,
      );
      
      if (qrResult['success'] == true) {
        print('✅ QR code generated for completion');
        return qrResult;
      } else {
        print('❌ Failed to generate QR code: ${qrResult['error']}');
        return null;
      }
      
    } catch (e) {
      print('❌ Error completing invoice payment: $e');
      return null;
    }
  }
  
  /// Complete service via QR scan
  static Future<bool> completeServiceWithQR({
    required String requestId,
    required String mechanicId,
    required String qrData,
  }) async {
    try {
      // Verify QR code
      final qrResult = await EnhancedQRCodeService().verifyQRCodeScan(
        qrData: qrData,
        mechanicId: mechanicId,
      );
      
      if (qrResult['success'] != true) {
        print('❌ QR verification failed: ${qrResult['error']}');
        return false;
      }
      
      // Update request status to completed
      await supabase
          .from('service_requests')
          .update({
            'status': 'completed',
            'completed_at': DateTime.now().toIso8601String(),
            'qr_scanned_at': DateTime.now().toIso8601String(),
            'qr_scanned_by': mechanicId,
          })
          .eq('id', requestId);
      
      await _createStatusHistory(
        requestId,
        'completed',
        'Service completed via QR code verification',
        mechanicId,
      );
      
      print('✅ Service completed successfully');
      return true;
      
    } catch (e) {
      print('❌ Error completing service: $e');
      return false;
    }
  }
  
  /// Get service request status history
  static Future<List<Map<String, dynamic>>> getStatusHistory(String requestId) async {
    try {
      final history = await supabase
          .from('request_status_history')
          .select('*, user_profiles!request_status_history_changed_by_fkey(first_name, last_name)')
          .eq('request_id', requestId)
          .order('created_at', ascending: true);
      
      return List<Map<String, dynamic>>.from(history);
    } catch (e) {
      print('❌ Error getting status history: $e');
      return [];
    }
  }
  
  /// Private helper to create status history
  static Future<void> _createStatusHistory(
    String requestId,
    String status,
    String? notes,
    String? changedBy,
  ) async {
    try {
      await supabase
          .from('request_status_history')
          .insert({
            'request_id': requestId,
            'status': status,
            'notes': notes ?? 'Status changed to $status',
            'changed_by': changedBy,
            'created_at': DateTime.now().toIso8601String(),
          });
    } catch (e) {
      print('❌ Error creating status history: $e');
    }
  }
}

/// Status flow constants
class ServiceRequestStatus {
  static const String pending = 'pending';
  static const String accepted = 'accepted';
  static const String paid = 'paid';
  static const String mechanicDispatched = 'mechanic_dispatched';
  static const String invoiceSent = 'invoice_sent';
  static const String invoicePaid = 'invoice_paid';
  static const String completed = 'completed';
  static const String cancelled = 'cancelled';
  
  /// Get user-friendly status names
  static String getDisplayName(String status) {
    switch (status) {
      case pending:
        return 'Pending';
      case accepted:
        return 'Accepted';
      case paid:
        return 'Service Fee Paid';
      case mechanicDispatched:
        return 'Mechanic Dispatched';
      case invoiceSent:
        return 'Invoice Sent';
      case invoicePaid:
        return 'Invoice Paid';
      case completed:
        return 'Completed';
      case cancelled:
        return 'Cancelled';
      default:
        return status.replaceAll('_', ' ').toUpperCase();
    }
  }
  
  /// Get status color
  static Color getStatusColor(String status) {
    switch (status) {
      case pending:
        return Colors.orange;
      case accepted:
      case paid:
      case mechanicDispatched:
        return Colors.blue;
      case invoiceSent:
      case invoicePaid:
        return Colors.purple;
      case completed:
        return Colors.green;
      case cancelled:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}