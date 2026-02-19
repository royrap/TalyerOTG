import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';
import 'qr_code_service.dart';

class CompleteServiceFlowService {
  static final CompleteServiceFlowService _instance = CompleteServiceFlowService._internal();
  static CompleteServiceFlowService get instance => _instance;
  CompleteServiceFlowService._internal();

  final _supabase = Supabase.instance.client;

  /// ========== USER FLOW IMPLEMENTATION ==========
  
  /// Step 1: Create service request with location, car, and service details
  Future<Map<String, dynamic>> createServiceRequest({
    required String issueTitle,
    required String issueDescription,
    required Map<String, dynamic> vehicleData,
    required double latitude,
    required double longitude,
    required String pickupAddress,
    Map<String, dynamic>? selectedShop,
    List<String>? serviceCategories,
  }) async {
    try {
      final userId = AuthService.instance.userId;
      if (userId == null) throw Exception('User not authenticated');

      print('🚀 Creating service request for user: $userId');
      
      // Calculate service fee based on location and service type
      final serviceFee = await _calculateServiceFee(latitude, longitude, serviceCategories);
      
      // Prepare service request data
      final requestData = {
        'customer_id': userId,
        'title': issueTitle,
        'description': issueDescription,
        'pickup_latitude': latitude,
        'pickup_longitude': longitude,
        'pickup_address': pickupAddress,
        'vehicle_id': vehicleData['id'],
        'vehicle_info': vehicleData,
        'service_fee': serviceFee,
        'estimated_price': serviceFee,
        'status': 'pending',
        'payment_status': 'pending',
        'service_type': serviceCategories?.join(', ') ?? issueTitle,
        'created_at': DateTime.now().toIso8601String(),
      };

      // Add shop-specific data if shop was selected
      if (selectedShop != null) {
        requestData['shop_id'] = selectedShop['shop_id'];
        requestData['preferred_shop_id'] = selectedShop['shop_id'];
        requestData['request_type'] = 'shop_based';
      } else {
        requestData['request_type'] = 'broadcast';
        requestData['is_broadcast_request'] = true;
        requestData['broadcast_radius_km'] = 15.0;
      }

      // Insert service request
      final result = await _supabase
          .from('service_requests')
          .insert(requestData)
          .select()
          .single();

      print('✅ Service request created: ${result['id']}');

      return {
        'success': true,
        'service_request_id': result['id'],
        'service_fee': serviceFee,
        'request_data': result,
      };
    } catch (e) {
      print('❌ Error creating service request: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Step 2: Process service fee payment
  Future<Map<String, dynamic>> processServiceFeePayment({
    required String serviceRequestId,
    required String paymentMethod,
    required double amount,
    Map<String, dynamic>? paymentDetails,
  }) async {
    try {
      print('💳 Processing service fee payment: $serviceRequestId');

      final userId = AuthService.instance.userId;
      if (userId == null) throw Exception('User not authenticated');

      // Create payment record
      final paymentData = {
        'request_id': serviceRequestId,
        'customer_id': userId,
        'amount': amount,
        'platform_fee': amount * 0.1, // 10% platform fee
        'provider_amount': amount * 0.9,
        'payment_method': paymentMethod,
        'status': 'completed',
        'processed_at': DateTime.now().toIso8601String(),
        'payment_details': paymentDetails ?? {},
      };

      final paymentResult = await _supabase
          .from('payments')
          .insert(paymentData)
          .select()
          .single();

      // Update service request status to paid
      await _supabase
          .from('service_requests')
          .update({
            'payment_status': 'completed',
            'status': 'paid',
            'payment_completed_at': DateTime.now().toIso8601String(),
          })
          .eq('id', serviceRequestId);

      print('✅ Service fee payment processed successfully');

      return {
        'success': true,
        'payment_id': paymentResult['id'],
        'message': 'Service fee payment completed. Looking for available mechanics...',
      };
    } catch (e) {
      print('❌ Error processing payment: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Step 3: Generate QR code after invoice payment (Customer side)
  Future<Map<String, dynamic>> generateCompletionQR({
    required String serviceRequestId,
  }) async {
    try {
      print('📱 Generating completion QR code for: $serviceRequestId');

      final userId = AuthService.instance.userId;
      if (userId == null) throw Exception('User not authenticated');

      // Use existing QR service to generate completion code
      final qrCode = await QRCodeService.instance.generateJobCompletionQR(serviceRequestId);
      
      if (qrCode != null) {
        print('✅ QR code generated and saved to database: $qrCode');
        
        return {
          'success': true,
          'completion_code': qrCode,
          'qr_data': qrCode,
          'expires_at': DateTime.now().add(const Duration(hours: 24)).toIso8601String(),
          'message': 'QR code generated successfully. Show this to the mechanic when service is complete.',
        };
      } else {
        throw Exception('Failed to generate QR code');
      }
    } catch (e) {
      print('❌ Error generating completion QR: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// ========== MECHANIC FLOW IMPLEMENTATION ==========

  /// Step 1: Accept service request (Mechanic side)
  Future<Map<String, dynamic>> acceptServiceRequest({
    required String serviceRequestId,
    required String mechanicId,
  }) async {
    try {
      print('🔧 Mechanic accepting request: $serviceRequestId');

      // Get mechanic's service provider ID
      final serviceProvider = await _supabase
          .from('service_providers')
          .select('id, user_id')
          .eq('user_id', mechanicId)
          .single();

      // Update service request status
      await _supabase
          .from('service_requests')
          .update({
            'status': 'accepted',
            'provider_id': serviceProvider['id'],
            'assigned_mechanic_id': mechanicId,
            'accepted_at': DateTime.now().toIso8601String(),
            'accepted_by': mechanicId,
          })
          .eq('id', serviceRequestId)
          .eq('status', 'paid'); // Only accept if payment completed

      print('✅ Service request accepted by mechanic');

      return {
        'success': true,
        'message': 'Service request accepted. Waiting for customer payment confirmation.',
      };
    } catch (e) {
      print('❌ Error accepting service request: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Step 2: Get customer location after payment (Mechanic side)
  Future<Map<String, dynamic>> getCustomerLocation({
    required String serviceRequestId,
    required String mechanicId,
  }) async {
    try {
      print('📍 Getting customer location for: $serviceRequestId');

      // Verify mechanic is assigned to this request
      final request = await _supabase
          .from('service_requests')
          .select('*')
          .eq('id', serviceRequestId)
          .eq('assigned_mechanic_id', mechanicId)
          .single();

      if (request['payment_status'] != 'completed') {
        throw Exception('Payment not yet completed');
      }

      return {
        'success': true,
        'customer_location': {
          'latitude': request['pickup_latitude'],
          'longitude': request['pickup_longitude'],
          'address': request['pickup_address'],
        },
        'customer_id': request['customer_id'],
        'service_details': {
          'title': request['title'],
          'description': request['description'],
          'vehicle_info': request['vehicle_info'],
        },
      };
    } catch (e) {
      print('❌ Error getting customer location: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Step 3: Generate invoice (Mechanic side)
  Future<Map<String, dynamic>> generateServiceInvoice({
    required String serviceRequestId,
    required String mechanicId,
    required List<Map<String, dynamic>> serviceItems,
    required double subtotal,
    double? tax,
    String? notes,
  }) async {
    try {
      print('🧾 Generating invoice for: $serviceRequestId');

      final userId = AuthService.instance.userId;
      if (userId == null) throw Exception('User not authenticated');

      // Get service request details
      final request = await _supabase
          .from('service_requests')
          .select('*')
          .eq('id', serviceRequestId)
          .eq('assigned_mechanic_id', mechanicId)
          .single();

      // Calculate totals
      final platformFee = subtotal * 0.1;
      final totalAmount = subtotal + (tax ?? 0.0);
      final providerAmount = subtotal - platformFee;

      // Generate invoice number
      final invoiceNumber = 'INV-${DateTime.now().millisecondsSinceEpoch}';

      // Create invoice
      final invoiceData = {
        'request_id': serviceRequestId,
        'customer_id': request['customer_id'],
        'mechanic_id': mechanicId,
        'invoice_number': invoiceNumber,
        'subtotal': subtotal,
        'tax': tax ?? 0.0,
        'platform_fee': platformFee,
        'total_amount': totalAmount,
        'provider_net_amount': providerAmount,
        'status': 'generated',
        'items': serviceItems,
        'notes': notes,
        'issued_at': DateTime.now().toIso8601String(),
        'due_date': DateTime.now().add(const Duration(days: 1)).toIso8601String(),
      };

      final invoice = await _supabase
          .from('invoices')
          .insert(invoiceData)
          .select()
          .single();

      // Update service request
      await _supabase
          .from('service_requests')
          .update({
            'status': 'invoice_sent',
            'invoice_generated': true,
            'invoice_number': invoiceNumber,
          })
          .eq('id', serviceRequestId);

      print('✅ Invoice generated: ${invoice['id']}');

      return {
        'success': true,
        'invoice_id': invoice['id'],
        'invoice_number': invoiceNumber,
        'total_amount': totalAmount,
        'message': 'Invoice sent to customer for approval.',
      };
    } catch (e) {
      print('❌ Error generating invoice: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Step 4: Scan and verify QR code (Mechanic side)
  Future<Map<String, dynamic>> scanAndVerifyQR({
    required String qrCode,
    required String serviceRequestId,
  }) async {
    try {
      print('📱 Scanning QR code: $qrCode for job: $serviceRequestId');

      // Use existing QR service to verify and process
      final success = await QRCodeService.instance.verifyAndProcessQRScan(
        qrCode: qrCode,
        serviceRequestId: serviceRequestId,
      );

      if (success) {
        print('✅ QR verification successful - job completed');
        return {
          'success': true,
          'message': 'Job completed successfully! Payment has been released.',
        };
      } else {
        throw Exception('QR verification failed');
      }
    } catch (e) {
      print('❌ Error scanning QR code: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// ========== HELPER FUNCTIONS ==========

  /// Calculate service fee based on distance and service type
  Future<double> _calculateServiceFee(
    double latitude,
    double longitude,
    List<String>? serviceCategories,
  ) async {
    try {
      // Get pricing configuration
      final pricingConfig = await _supabase
          .from('distance_pricing_config')
          .select('*')
          .eq('is_active', true)
          .single();

      double baseFee = pricingConfig['minimum_service_fee'] ?? 500.0;
      
      // Add category-specific pricing if available
      if (serviceCategories != null && serviceCategories.isNotEmpty) {
        final categoryPricing = await _supabase
            .from('service_categories')
            .select('base_price')
            .in_('name', serviceCategories);
        
        double categoryTotal = 0.0;
        for (final category in categoryPricing) {
          categoryTotal += category['base_price'] ?? 0.0;
        }
        
        if (categoryTotal > baseFee) {
          baseFee = categoryTotal;
        }
      }

      return baseFee;
    } catch (e) {
      print('⚠️ Error calculating service fee, using default: $e');
      return 500.0; // Default minimum fee
    }
  }

  /// Get service request status for tracking
  Future<Map<String, dynamic>?> getServiceRequestStatus(String serviceRequestId) async {
    try {
      final request = await _supabase
          .from('service_requests')
          .select('''
            *,
            user_profiles!customer_id(first_name, last_name, phone_number),
            service_providers(company_name),
            invoices(*)
          ''')
          .eq('id', serviceRequestId)
          .single();

      return request;
    } catch (e) {
      print('❌ Error getting service request status: $e');
      return null;
    }
  }

  /// Debug function to check flow completeness
  Future<Map<String, dynamic>> debugServiceFlow(String serviceRequestId) async {
    try {
      final debug = <String, dynamic>{};
      
      // Get service request
      final request = await _supabase
          .from('service_requests')
          .select('*')
          .eq('id', serviceRequestId)
          .single();
      debug['service_request'] = request;
      
      // Get payments
      final payments = await _supabase
          .from('payments')
          .select('*')
          .eq('request_id', serviceRequestId);
      debug['payments'] = payments;
      
      // Get invoices
      final invoices = await _supabase
          .from('invoices')
          .select('*')
          .eq('request_id', serviceRequestId);
      debug['invoices'] = invoices;
      
      // Get QR codes
      final qrCodes = await _supabase
          .from('job_completion_codes')
          .select('*')
          .eq('request_id', serviceRequestId);
      debug['qr_codes'] = qrCodes;
      
      // Flow analysis
      debug['flow_status'] = {
        'request_created': request != null,
        'payment_completed': request['payment_status'] == 'completed',
        'mechanic_assigned': request['assigned_mechanic_id'] != null,
        'invoice_generated': invoices.isNotEmpty,
        'qr_generated': qrCodes.isNotEmpty,
        'job_completed': request['status'] == 'completed',
      };
      
      return debug;
    } catch (e) {
      print('❌ Debug error: $e');
      return {'error': e.toString()};
    }
  }
}