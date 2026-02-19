import 'package:supabase_flutter/supabase_flutter.dart';
import 'comprehensive_audit_service.dart';

/// Enhanced authentication service that handles all user roles and verification flows
class EnhancedAuthService {
  static final EnhancedAuthService _instance = EnhancedAuthService._internal();
  static EnhancedAuthService get instance => _instance;
  EnhancedAuthService._internal();

  final _supabase = Supabase.instance.client;
  final _auditService = ComprehensiveAuditService.instance;

  /// Customer registration - simple flow
  Future<Map<String, dynamic>> registerCustomer({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String phoneNumber,
    String? ipAddress,
    String? userAgent,
  }) async {
    try {
      print('👤 Starting customer registration for: $email');

      // Create auth user
      final authResponse = await _supabase.auth.signUp(
        email: email,
        password: password,
      );

      if (authResponse.user == null) {
        throw Exception('Failed to create user account');
      }

      final userId = authResponse.user!.id;

      // Create user profile
      await _supabase.from('user_profiles').insert({
        'id': userId,
        'first_name': firstName,
        'last_name': lastName,
        'email': email,
        'phone_number': phoneNumber,
        'user_type': 'customer',
        'role': 'customer',
        'account_status': 'active',
        'can_login': true,
        'requires_email_verification': true,
        'registration_completed': true,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });

      // Log registration
      await _auditService.logRegistration(
        userId: userId,
        userType: 'customer',
        email: email,
        ipAddress: ipAddress,
        userAgent: userAgent,
        additionalData: {
          'first_name': firstName,
          'last_name': lastName,
          'phone_number': phoneNumber,
        },
      );

      print('✅ Customer registration completed for: $email');
      return {
        'success': true,
        'user_id': userId,
        'user_type': 'customer',
        'requires_verification': false,
        'can_login': true,
      };
    } catch (e) {
      print('❌ Customer registration failed: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Mechanic registration - assigned by talyer owner
  Future<Map<String, dynamic>> registerMechanic({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String phoneNumber,
    required String talyerOwnerId,
    required String shopId,
    String? ipAddress,
    String? userAgent,
  }) async {
    try {
      print('🔧 Starting mechanic registration for: $email');

      // Create auth user
      final authResponse = await _supabase.auth.signUp(
        email: email,
        password: password,
      );

      if (authResponse.user == null) {
        throw Exception('Failed to create user account');
      }

      final userId = authResponse.user!.id;

      // Create user profile
      await _supabase.from('user_profiles').insert({
        'id': userId,
        'first_name': firstName,
        'last_name': lastName,
        'email': email,
        'phone_number': phoneNumber,
        'user_type': 'mechanic',
        'role': 'mechanic',
        'account_status': 'active',
        'can_login': true,
        'shop_id': shopId,
        'registration_completed': true,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });

      // Create service provider record
      await _supabase.from('service_providers').insert({
        'user_id': userId,
        'talyer_owner_id': talyerOwnerId,
        'shop_id': shopId,
        'is_verified': true,
        'is_available': true,
        'status': 'offline',
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });

      // Add to shop mechanics
      await _supabase.from('shop_mechanics').insert({
        'shop_id': shopId,
        'mechanic_id': userId,
        'role': 'mechanic',
        'is_active': true,
        'is_available': true,
        'joined_at': DateTime.now().toUtc().toIso8601String(),
      });

      // Log registration
      await _auditService.logRegistration(
        userId: userId,
        userType: 'mechanic',
        email: email,
        ipAddress: ipAddress,
        userAgent: userAgent,
        additionalData: {
          'first_name': firstName,
          'last_name': lastName,
          'phone_number': phoneNumber,
          'talyer_owner_id': talyerOwnerId,
          'shop_id': shopId,
        },
      );

      print('✅ Mechanic registration completed for: $email');
      return {
        'success': true,
        'user_id': userId,
        'user_type': 'mechanic',
        'shop_id': shopId,
        'can_login': true,
      };
    } catch (e) {
      print('❌ Mechanic registration failed: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Talyer Owner registration - requires verification
  Future<Map<String, dynamic>> registerTalyerOwner({
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
    String? idType = 'national_id',
    String? ipAddress,
    String? userAgent,
  }) async {
    try {
      print('🏪 Starting talyer owner registration for: $email');

      // Create auth user
      final authResponse = await _supabase.auth.signUp(
        email: email,
        password: password,
      );

      if (authResponse.user == null) {
        throw Exception('Failed to create user account');
      }

      final userId = authResponse.user!.id;

      // Create user profile (initially can't login until verified)
      await _supabase.from('user_profiles').insert({
        'id': userId,
        'first_name': firstName,
        'last_name': lastName,
        'email': email,
        'phone_number': phoneNumber,
        'user_type': 'talyer_owner',
        'role': 'talyer_owner',
        'account_status': 'pending_verification',
        'can_login': false, // Can't login until verified
        'requires_email_verification': true,
        'registration_completed': true,
        'profile_image_url': profileImageUrl,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });

      // Create verification record
      final verificationData = {
        'user_id': userId,
        'business_name': businessName,
        'business_permit_url': businessPermitUrl,
        'valid_id_url': validIdUrl,
        'profile_image_url': profileImageUrl,
        'id_type': idType,
        'business_address': businessAddress,
        'email': email,
        'phone_number': phoneNumber,
        'contact_person': '$firstName $lastName',
        'status': 'pending', // Will be processed by AI first
        'verification_score': 0,
        'tamper_flags': [],
        'created_at': DateTime.now().toUtc().toIso8601String(),
      };

      await _supabase.from('talyer_owner_verifications').insert(verificationData);

      // Log registration
      await _auditService.logRegistration(
        userId: userId,
        userType: 'talyer_owner',
        email: email,
        ipAddress: ipAddress,
        userAgent: userAgent,
        additionalData: {
          'first_name': firstName,
          'last_name': lastName,
          'phone_number': phoneNumber,
          'business_name': businessName,
          'business_address': businessAddress,
          'requires_verification': true,
        },
      );

      // Trigger AI verification (in real implementation)
      await _triggerAIVerification(userId, verificationData);

      print('✅ Talyer owner registration completed, pending verification for: $email');
      return {
        'success': true,
        'user_id': userId,
        'user_type': 'talyer_owner',
        'requires_verification': true,
        'can_login': false,
        'message': 'Registration successful. Your documents are being verified.',
      };
    } catch (e) {
      print('❌ Talyer owner registration failed: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Enhanced login with proper role checking
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
    String? ipAddress,
    String? userAgent,
  }) async {
    try {
      print('🔐 Starting login for: $email');

      // Attempt sign in
      final authResponse = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (authResponse.user == null) {
        throw Exception('Invalid credentials');
      }

      final userId = authResponse.user!.id;

      // Get user profile and verification status
      final profileResponse = await _supabase
          .from('user_profiles')
          .select('*, talyer_owner_verifications(*)')
          .eq('id', userId)
          .single();

      final userType = profileResponse['user_type'] as String;
      final canLogin = profileResponse['can_login'] as bool? ?? false;
      final accountStatus = profileResponse['account_status'] as String? ?? 'pending';

      // Check if user can login
      if (!canLogin) {
        // Log failed login
        await _auditService.logLoginLogout(
          userId: userId,
          userType: userType,
          action: 'LOGIN',
          success: false,
          ipAddress: ipAddress,
          userAgent: userAgent,
          failureReason: 'Account not verified or suspended',
        );

        return {
          'success': false,
          'error': 'Account verification required',
          'user_type': userType,
          'account_status': accountStatus,
        };
      }

      // Special check for talyer owners
      if (userType == 'talyer_owner') {
        final verification = profileResponse['talyer_owner_verifications'];
        if (verification != null && verification.isNotEmpty) {
          final verificationStatus = verification[0]['status'] as String;
          if (verificationStatus != 'approved') {
            await _auditService.logLoginLogout(
              userId: userId,
              userType: userType,
              action: 'LOGIN',
              success: false,
              ipAddress: ipAddress,
              userAgent: userAgent,
              failureReason: 'Talyer owner verification pending',
            );

            return {
              'success': false,
              'error': 'Business verification required',
              'user_type': userType,
              'verification_status': verificationStatus,
            };
          }
        }
      }

      // Update login tracking
      await _supabase.from('user_profiles').update({
        'last_login_at': DateTime.now().toUtc().toIso8601String(),
        'login_count': (profileResponse['login_count'] ?? 0) + 1,
        'failed_login_attempts': 0,
      }).eq('id', userId);

      // Log successful login
      await _auditService.logLoginLogout(
        userId: userId,
        userType: userType,
        action: 'LOGIN',
        success: true,
        ipAddress: ipAddress,
        userAgent: userAgent,
      );

      print('✅ Login successful for: $email ($userType)');
      return {
        'success': true,
        'user_id': userId,
        'user_type': userType,
        'user_data': profileResponse,
      };
    } catch (e) {
      print('❌ Login failed for $email: $e');

      // Try to log failed attempt if we can identify the user
      try {
        final userQuery = await _supabase
            .from('user_profiles')
            .select('id, user_type')
            .eq('email', email)
            .maybeSingle();

        if (userQuery != null) {
          await _auditService.logLoginLogout(
            userId: userQuery['id'],
            userType: userQuery['user_type'],
            action: 'LOGIN',
            success: false,
            ipAddress: ipAddress,
            userAgent: userAgent,
            failureReason: e.toString(),
          );
        }
      } catch (auditError) {
        print('❌ Error logging failed login: $auditError');
      }

      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Logout with audit logging
  Future<Map<String, dynamic>> logout({
    String? ipAddress,
    String? userAgent,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        // Get user type for logging
        final profileResponse = await _supabase
            .from('user_profiles')
            .select('user_type')
            .eq('id', user.id)
            .single();

        final userType = profileResponse['user_type'] as String;

        // Log logout
        await _auditService.logLoginLogout(
          userId: user.id,
          userType: userType,
          action: 'LOGOUT',
          success: true,
          ipAddress: ipAddress,
          userAgent: userAgent,
        );
      }

      await _supabase.auth.signOut();
      print('✅ Logout successful');
      return {'success': true};
    } catch (e) {
      print('❌ Logout error: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Simulate AI verification (replace with actual AI service)
  Future<void> _triggerAIVerification(String userId, Map<String, dynamic> verificationData) async {
    try {
      print('🤖 Triggering AI verification for user: $userId');

      // Simulate AI processing delay
      await Future.delayed(Duration(seconds: 2));

      // Simulate AI decision (80% approval rate for demo)
      final random = DateTime.now().millisecondsSinceEpoch % 100;
      final isApproved = random < 80;

      if (isApproved) {
        // AI Approval
        await _supabase.from('talyer_owner_verifications').update({
          'status': 'approved',
          'verification_score': 85 + (random % 15), // 85-100 score
          'reviewed_at': DateTime.now().toUtc().toIso8601String(),
          'admin_notes': 'AI verified: Documents appear authentic and complete',
        }).eq('user_id', userId);

        // Allow login
        await _supabase.from('user_profiles').update({
          'can_login': true,
          'account_status': 'active',
        }).eq('id', userId);

        // Create shop for approved talyer owner
        await _createShopForTalyerOwner(userId, verificationData);

        // Log AI approval
        await _auditService.logTalyerOwnerVerification(
          talyerOwnerId: userId,
          action: 'AI_APPROVAL',
          status: 'approved',
          verificationData: {
            'ai_score': 85 + (random % 15),
            'ai_confidence': 'high',
          },
        );

        print('✅ AI approved talyer owner: $userId');
      } else {
        // AI Rejection - forward to admin
        await _supabase.from('talyer_owner_verifications').update({
          'status': 'under_review',
          'verification_score': 40 + (random % 30), // 40-70 score
          'admin_notes': 'AI flagged for manual review: Document quality or authenticity concerns',
        }).eq('user_id', userId);

        // Log AI rejection
        await _auditService.logTalyerOwnerVerification(
          talyerOwnerId: userId,
          action: 'AI_REJECTION',
          status: 'under_review',
          rejectionReason: 'Document quality or authenticity concerns',
          verificationData: {
            'ai_score': 40 + (random % 30),
            'ai_confidence': 'low',
            'requires_manual_review': true,
          },
        );

        print('⚠️ AI flagged for manual review: $userId');
      }
    } catch (e) {
      print('❌ Error in AI verification: $e');
      // Fallback to manual review
      await _supabase.from('talyer_owner_verifications').update({
        'status': 'under_review',
        'admin_notes': 'AI verification failed, requires manual review',
      }).eq('user_id', userId);
    }
  }

  /// Create shop for approved talyer owner
  Future<void> _createShopForTalyerOwner(String userId, Map<String, dynamic> verificationData) async {
    try {
      final businessName = verificationData['business_name'] as String;
      final businessAddress = verificationData['business_address'] as String?;

      await _supabase.from('shops').insert({
        'owner_id': userId,
        'shop_name': businessName,
        'shop_address': businessAddress,
        'shop_description': 'Auto repair and maintenance services',
        'is_active': true,
        'current_status': 'closed',
        'service_radius': 50.0,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });

      print('✅ Shop created for talyer owner: $userId');
    } catch (e) {
      print('❌ Error creating shop: $e');
    }
  }

  /// Admin override for talyer owner verification
  Future<Map<String, dynamic>> adminOverrideVerification({
    required String adminId,
    required String talyerOwnerId,
    required bool approve,
    String? reason,
    String? ipAddress,
    String? userAgent,
  }) async {
    try {
      print('👨‍💼 Admin override verification for: $talyerOwnerId');

      final newStatus = approve ? 'approved' : 'rejected';
      final action = approve ? 'ADMIN_APPROVAL' : 'ADMIN_REJECTION';

      // Update verification status
      await _supabase.from('talyer_owner_verifications').update({
        'status': newStatus,
        'reviewed_by': adminId,
        'reviewed_at': DateTime.now().toUtc().toIso8601String(),
        'admin_notes': reason ?? (approve ? 'Manually approved by admin' : 'Manually rejected by admin'),
      }).eq('user_id', talyerOwnerId);

      if (approve) {
        // Allow login
        await _supabase.from('user_profiles').update({
          'can_login': true,
          'account_status': 'active',
        }).eq('id', talyerOwnerId);

        // Create shop if approved
        final verificationData = await _supabase
            .from('talyer_owner_verifications')
            .select('*')
            .eq('user_id', talyerOwnerId)
            .single();

        await _createShopForTalyerOwner(talyerOwnerId, verificationData);
      }

      // Log admin action
      await _auditService.logTalyerOwnerVerification(
        talyerOwnerId: talyerOwnerId,
        action: action,
        reviewedBy: adminId,
        status: newStatus,
        rejectionReason: approve ? null : reason,
        verificationData: {
          'admin_override': true,
          'admin_reason': reason,
        },
      );

      await _auditService.logAdminAction(
        adminId: adminId,
        action: 'ADMIN_OVERRIDE',
        targetUserId: talyerOwnerId,
        targetType: 'talyer_owner_verifications',
        targetId: talyerOwnerId,
        newValues: {
          'status': newStatus,
          'approved': approve,
        },
        reason: reason,
        ipAddress: ipAddress,
        userAgent: userAgent,
      );

      print('✅ Admin override completed: ${approve ? 'APPROVED' : 'REJECTED'} $talyerOwnerId');
      return {
        'success': true,
        'action': action,
        'status': newStatus,
      };
    } catch (e) {
      print('❌ Admin override failed: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Get current user with full profile data
  Future<Map<String, dynamic>?> getCurrentUserProfile() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return null;

      final profileResponse = await _supabase
          .from('user_profiles')
          .select('''
            *,
            talyer_owner_verifications(*),
            shops(*),
            service_providers(*)
          ''')
          .eq('id', user.id)
          .single();

      return profileResponse;
    } catch (e) {
      print('❌ Error getting user profile: $e');
      return null;
    }
  }
}










