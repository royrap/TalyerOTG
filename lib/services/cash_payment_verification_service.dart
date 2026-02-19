import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'supabase_service.dart';

class CashPaymentVerificationService {
  final SupabaseClient _supabase = SupabaseService.client;

  /// Upload cash photo to Supabase Storage
  Future<String?> uploadCashPhoto({
    required File imageFile,
    required String invoiceId,
    required String customerId,
  }) async {
    try {
      print('📸 Uploading cash payment photo...');

      // Create unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'cash_payment_${customerId}_${invoiceId}_$timestamp.jpg';
      final filePath = 'cash-payments/$customerId/$fileName';

      // Upload to Supabase Storage
      await _supabase.storage
          .from('PROOF_OF_PAYMENT')
          .upload(filePath, imageFile);

      // Get public URL
      final publicUrl = _supabase.storage
          .from('PROOF_OF_PAYMENT')
          .getPublicUrl(filePath);

      print('✅ Cash photo uploaded: $publicUrl');
      return publicUrl;
    } catch (e) {
      print('❌ Error uploading cash photo: $e');
      return null;
    }
  }

  /// Upload receipt photo (optional)
  Future<String?> uploadReceiptPhoto({
    required File imageFile,
    required String invoiceId,
    required String customerId,
  }) async {
    try {
      print('📸 Uploading receipt photo...');

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'receipt_${customerId}_${invoiceId}_$timestamp.jpg';
      final filePath = 'receipts/$customerId/$fileName';

      await _supabase.storage
          .from('PROOF_OF_PAYMENT')
          .upload(filePath, imageFile);

      final publicUrl = _supabase.storage
          .from('PROOF_OF_PAYMENT')
          .getPublicUrl(filePath);

      print('✅ Receipt photo uploaded: $publicUrl');
      return publicUrl;
    } catch (e) {
      print('❌ Error uploading receipt photo: $e');
      return null;
    }
  }

  /// Create cash payment verification record
  Future<Map<String, dynamic>?> createVerificationRecord({
    required String invoiceId,
    required String paymentId,
    required String requestId,
    required String customerId,
    required String mechanicId,
    required double cashAmount,
    required String cashPhotoUrl,
    String? receiptPhotoUrl,
  }) async {
    try {
      print('💰 Creating cash payment verification record...');
      print('ℹ️ Input mechanicId: $mechanicId');

      // Get current location
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition();
      } catch (e) {
        print('⚠️ Could not get location: $e');
      }

      // Resolve the actual user_profiles.id for the mechanic
      // The mechanicId could be a service_providers.id, so we need to check
      String actualMechanicUserId = mechanicId;
      String? providerId;
      
      try {
        // First check if mechanicId exists in user_profiles
        final userCheck = await _supabase
            .from('user_profiles')
            .select('id')
            .eq('id', mechanicId)
            .maybeSingle();
        
        if (userCheck != null) {
          // mechanicId is already a valid user_profiles.id
          actualMechanicUserId = mechanicId;
          print('✅ mechanicId is a valid user_profiles.id');
          
          // Get provider_id for this user
          final providerData = await _supabase
              .from('service_providers')
              .select('id')
              .eq('user_id', mechanicId)
              .maybeSingle();
          providerId = providerData?['id'] as String?;
        } else {
          // mechanicId might be a service_providers.id, try to get user_id from it
          final providerData = await _supabase
              .from('service_providers')
              .select('id, user_id')
              .eq('id', mechanicId)
              .maybeSingle();
          
          if (providerData != null && providerData['user_id'] != null) {
            actualMechanicUserId = providerData['user_id'] as String;
            providerId = providerData['id'] as String;
            print('✅ Resolved user_id from service_providers: $actualMechanicUserId');
          } else {
            print('⚠️ Could not resolve mechanicId to user_profiles.id');
          }
        }
      } catch (e) {
        print('⚠️ Error resolving mechanic user: $e');
      }

      // If caller passed a placeholder (e.g. 'pending') create a payments row first
      String? finalPaymentId;
      try {
        // simple check: if paymentId is not a valid UUID or equals 'pending', create a payment record
        final isPlaceholder = paymentId.toLowerCase() == 'pending' || paymentId.isEmpty;
        if (isPlaceholder) {
          // Use provider_id if found, otherwise try to get it
          if (providerId == null) {
            try {
              final providerData = await _supabase
                  .from('service_providers')
                  .select('id')
                  .eq('user_id', actualMechanicUserId)
                  .maybeSingle();
              providerId = providerData?['id'] as String?;
            } catch (e) {
              print('⚠️ Could not find service provider: $e');
            }
          }

          final paymentInsert = {
            'request_id': requestId,
            'invoice_id': invoiceId,
            'customer_id': customerId,
            'provider_id': providerId ?? actualMechanicUserId,
            'amount': cashAmount,
            'platform_fee': 0.0,
            'provider_amount': cashAmount,
            'payment_method': 'cash',
            'payment_gateway': 'cash',
            'status': 'completed',
            'payment_verification_required': false,
            'verification_status': 'verified',
            'created_at': DateTime.now().toIso8601String(),
          };

          final paymentResp = await _supabase
              .from('payments')
              .insert(paymentInsert)
              .select()
              .single();

          if (paymentResp['id'] != null) {
            finalPaymentId = paymentResp['id'] as String;
            print('✅ Created payment record: $finalPaymentId');
          }
        } else {
          finalPaymentId = paymentId;
        }
      } catch (e) {
        print('⚠️ Could not create payment record automatically: $e');
        // Continue without payment_id - we'll create verification record without it
      }

      // Build verification data using the resolved actualMechanicUserId
      final data = <String, dynamic>{
        'invoice_id': invoiceId,
        'request_id': requestId,
        'customer_id': customerId,
        'mechanic_id': actualMechanicUserId, // Use resolved user_profiles.id
        'cash_amount': cashAmount,
        'cash_photo_url': cashPhotoUrl,
        'receipt_photo_url': receiptPhotoUrl ?? cashPhotoUrl, // Use cash photo as receipt if not provided
        'verification_status': 'verified',
        'location_latitude': position?.latitude,
        'location_longitude': position?.longitude,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Only add payment_id if we have a valid one
      if (finalPaymentId != null && finalPaymentId.isNotEmpty) {
        data['payment_id'] = finalPaymentId;
      } else {
        // payment_id is required - we need to throw an error if we couldn't create it
        throw Exception('Failed to create payment record - payment_id is required');
      }

      final response = await _supabase
          .from('cash_payment_verifications')
          .insert(data)
          .select()
          .single();

      print('✅ Verification record created: ${response['id']}');
      return response;
    } catch (e) {
      print('❌ Error creating verification record: $e');
      return null;
    }
  }

  /// Get pending verifications for talyer owner
  Future<List<Map<String, dynamic>>> getPendingVerifications({
    required String talyerOwnerId,
  }) async {
    try {
      print('📋 Loading pending cash verifications for talyer owner...');

      // Get all pending verifications where mechanic belongs to this talyer owner
      final response = await _supabase
          .from('cash_payment_verifications')
          .select('''
            *,
            invoices!inner(
              id,
              invoice_number,
              total_amount,
              talyer_owner_id
            ),
            customer:customer_id(
              id,
              first_name,
              last_name,
              phone_number
            ),
            mechanic:mechanic_id(
              id,
              first_name,
              last_name
            )
          ''')
          .eq('verification_status', 'pending')
          .eq('invoices.talyer_owner_id', talyerOwnerId)
          .order('created_at', ascending: false);

      print('✅ Found ${response.length} pending verifications');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('❌ Error loading pending verifications: $e');
      return [];
    }
  }

  /// Get all verifications (for admin/history)
  Future<List<Map<String, dynamic>>> getAllVerifications({
    required String talyerOwnerId,
    String? status,
  }) async {
    try {
      print('📋 Loading all cash verifications...');

      var query = _supabase
          .from('cash_payment_verifications')
          .select('''
            *,
            invoices!inner(
              id,
              invoice_number,
              total_amount,
              talyer_owner_id
            ),
            customer:customer_id(
              id,
              first_name,
              last_name,
              phone_number
            ),
            mechanic:mechanic_id(
              id,
              first_name,
              last_name
            )
          ''')
          .eq('invoices.talyer_owner_id', talyerOwnerId);

      if (status != null) {
        query = query.eq('verification_status', status);
      }

      final response = await query.order('created_at', ascending: false);

      print('✅ Found ${response.length} verifications');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('❌ Error loading verifications: $e');
      return [];
    }
  }

  /// Verify cash payment (approve)
  Future<bool> verifyCashPayment({
    required String verificationId,
    required String verifiedBy,
    String? notes,
  }) async {
    try {
      print('✅ Verifying cash payment...');

      await _supabase
          .from('cash_payment_verifications')
          .update({
            'verification_status': 'verified',
            'verified_by': verifiedBy,
            'verified_at': DateTime.now().toIso8601String(),
            'verification_notes': notes,
          })
          .eq('id', verificationId);

      print('✅ Cash payment verified');
      return true;
    } catch (e) {
      print('❌ Error verifying payment: $e');
      return false;
    }
  }

  /// Reject cash payment
  Future<bool> rejectCashPayment({
    required String verificationId,
    required String verifiedBy,
    required String reason,
  }) async {
    try {
      print('❌ Rejecting cash payment...');

      await _supabase
          .from('cash_payment_verifications')
          .update({
            'verification_status': 'rejected',
            'verified_by': verifiedBy,
            'verified_at': DateTime.now().toIso8601String(),
            'verification_notes': reason,
          })
          .eq('id', verificationId);

      print('✅ Cash payment rejected');
      return true;
    } catch (e) {
      print('❌ Error rejecting payment: $e');
      return false;
    }
  }

  /// Get verification by invoice ID
  Future<Map<String, dynamic>?> getVerificationByInvoiceId({
    required String invoiceId,
  }) async {
    try {
      final response = await _supabase
          .from('cash_payment_verifications')
          .select('''
            *,
            customer:customer_id(
              id,
              first_name,
              last_name
            ),
            mechanic:mechanic_id(
              id,
              first_name,
              last_name
            )
          ''')
          .eq('invoice_id', invoiceId)
          .maybeSingle();

      return response;
    } catch (e) {
      print('❌ Error getting verification: $e');
      return null;
    }
  }

  /// Stream pending verifications for real-time updates
  Stream<List<Map<String, dynamic>>> streamPendingVerifications({
    required String talyerOwnerId,
  }) {
    return _supabase
        .from('cash_payment_verifications')
        .stream(primaryKey: ['id'])
        .eq('verification_status', 'pending')
        .map((data) => List<Map<String, dynamic>>.from(data));
  }
}
