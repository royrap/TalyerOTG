import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import 'email_notification_service.dart';
import 'pending_upload_service.dart';
import 'audit_logging_service.dart';

class AuthResult {
  final bool success;
  final String message;
  final String? userId;
  final String? profileImageUrl;
  
  AuthResult({
    required this.success, 
    required this.message, 
    this.userId,
    this.profileImageUrl,
  });
}

class AuthService extends ChangeNotifier {
  static final AuthService _instance = AuthService._internal();
  static AuthService get instance => _instance;
  AuthService._internal();

  bool _isAuthenticated = false;
  String? _userId;
  String? _userEmail;
  Map<String, dynamic>? _userProfile;
  
  bool get isAuthenticated => _isAuthenticated;
  String? get userId => _userId;
  String? get userEmail => _userEmail;
  Map<String, dynamic>? get userProfile => _userProfile;
  
  // Add getter for user type
  String? get userType => _userProfile?['user_type'];

  get currentUser => null;

  Future<void> initialize() async {
    try {
      // Initialize audit logging service
      await AuditLoggingService.initialize();
      
      final prefs = await SharedPreferences.getInstance();
      final savedUserId = prefs.getString('user_id');
      final savedEmail = prefs.getString('user_email');
      
      if (savedUserId != null && savedEmail != null) {
        final session = SupabaseService.client.auth.currentSession;
        if (session != null && session.user.id == savedUserId) {
          _userId = savedUserId;
          _userEmail = savedEmail;
          _isAuthenticated = true;
          await _loadUserProfile();
          
          // Log session restoration
          final auditService = AuditLoggingService();
          await auditService.logAuditAction(
            userId: _userId,
            role: _userProfile?['user_type'] ?? 'unknown',
            action: 'SESSION_RESTORED',
            tableName: 'user_profiles',
            recordId: _userId,
            additionalData: {
              'session_restored_at': DateTime.now().toIso8601String(),
            },
          );
          
          notifyListeners();
        } else {
          await _clearLocalData();
        }
      }
    } catch (e) {
      print('Error initializing auth service: $e');
      await _clearLocalData();
    }
  }
  Future<AuthResult> signIn({
    required String email, 
    required String password
  }) async {
    try {
      print('🔐 Attempting sign in for: $email');
      
      final response = await SupabaseService.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null) {
        print('✅ Sign in response received, user ID: ${response.user!.id}');
        
        // PRODUCTION: Enforce email verification for customers and talyer owners
        if (response.user!.emailConfirmedAt == null) {
          print('❌ Email not verified - blocking login');
          
          // Check if this is an admin user (admins can be created manually)
          final adminCheck = await SupabaseService.client
              .from('user_profiles')
              .select('user_type')
              .eq('id', response.user!.id)
              .maybeSingle();
          
          final userType = adminCheck?['user_type'];
          if (userType != 'admin' && userType != 'super_admin') {
            await SupabaseService.client.auth.signOut(); // Sign out the unverified user
            return AuthResult(
              success: false, 
              message: 'Please verify your email before signing in. Check your inbox for a verification link.'
            );
          }
        }
        
        print('📧 Email verified at: ${response.user!.emailConfirmedAt}');
        
        // Set authentication state
        _userId = response.user!.id;
        _userEmail = response.user!.email;
        _isAuthenticated = true;
        
        print('💾 Saving user session...');
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_id', _userId!);
        await prefs.setString('user_email', _userEmail!);
        
        print('👤 Loading user profile...');
        await _loadUserProfile();
        
        // Check if user has a profile
        if (_userProfile == null) {
          print('⚠️ User authenticated but no profile found');
          
          // Try to create the missing profile using auth user data
          try {
            print('🔧 Attempting to create missing profile...');
            final user = response.user!;
            final metadata = user.userMetadata;
            
            await SupabaseService.client.from('user_profiles').insert({
              'id': user.id,
              'first_name': metadata?['first_name'] ?? '',
              'last_name': metadata?['last_name'] ?? '',
              'email': user.email ?? '',
              'phone_number': metadata?['phone_number'] ?? '',
              'user_type': metadata?['user_type'] ?? 'customer',
              'status': 'active',
              'is_available': true,
            });
            
            print('✅ Missing profile created successfully');
            
            // Reload the profile
            await _loadUserProfile();
            
            // Still allow login but indicate profile was set up
            print('🔔 Notifying listeners... isAuthenticated: $_isAuthenticated (profile created)');
            notifyListeners();
            return AuthResult(
              success: true, 
              message: 'Login successful! Your profile has been set up.'
            );
          } catch (profileCreateError) {
            print('❌ Failed to create missing profile: $profileCreateError');
            
            // Still allow login but indicate profile needs to be created
            print('🔔 Notifying listeners... isAuthenticated: $_isAuthenticated (profile missing)');
            notifyListeners();
            return AuthResult(
              success: true, 
              message: 'Login successful, but profile setup is needed. Please complete your profile.'
            );
          }
        }
        
        // PRODUCTION: Check if Talyer Owner is verified by admin
        if (_userProfile != null && _userProfile!['user_type'] == 'talyer_owner') {
          print('\ud83c\udfea Checking Talyer Owner verification row (direct lookup)...');
          try {
            // Try to get verification row directly (no RPCs/policies)
            final verificationRow = await SupabaseService.client
                .from('talyer_owner_verifications')
                .select('*')
                .eq('user_id', _userId!)
                .maybeSingle();

            if (verificationRow == null) {
              print('\u26a0\ufe0f No verification row found for talyer_owner - creating placeholder');
              // Create a placeholder verification row so admins can see and process it later.
              try {
                final placeholder = {
                  'user_id': _userId!,
                  'business_name': _userProfile?['company_name'] ?? _userProfile?['first_name'] ?? 'Unknown Business',
                  'business_permit_url': '', // placeholder until upload
                  'valid_id_url': '', // placeholder until upload
                  'profile_image_url': _userProfile?['profile_image_url'],
                  'id_type': 'national_id',
                  'status': 'pending',
                  'admin_notes': 'Placeholder created at sign-in; user must upload documents.',
                };

                await SupabaseService.client
                    .from('talyer_owner_verifications')
                    .insert(placeholder);

                print('\u2705 Placeholder verification row created for user: $_userId');
              } catch (createErr) {
                print('\u274c Failed to create placeholder verification row: $createErr');
              }

              // Sign-out and block login until admin reviews / user completes verification
              await SupabaseService.client.auth.signOut();
              await _clearLocalData();
              _isAuthenticated = false;
              _userId = null;
              _userEmail = null;
              _userProfile = null;
              return AuthResult(
                success: false,
                message: 'Your shop registration is incomplete. A verification record has been created. Please complete document upload or contact support.'
              );
            }

            final status = verificationRow['status']?.toString() ?? 'pending';
            if (status == 'pending' || status == 'under_review') {
              await SupabaseService.client.auth.signOut();
              await _clearLocalData();
              _isAuthenticated = false;
              _userId = null;
              _userEmail = null;
              _userProfile = null;
              return AuthResult(
                success: false,
                message: 'Your account is pending verification. Please wait for admin approval before accessing your account.'
              );
            }

            if (status == 'rejected') {
              await SupabaseService.client.auth.signOut();
              await _clearLocalData();
              _isAuthenticated = false;
              _userId = null;
              _userEmail = null;
              _userProfile = null;
              return AuthResult(
                success: false,
                message: 'Your shop verification was rejected. Please contact support or resubmit your documents.'
              );
            }

            if (status != 'approved') {
              await SupabaseService.client.auth.signOut();
              await _clearLocalData();
              _isAuthenticated = false;
              _userId = null;
              _userEmail = null;
              _userProfile = null;
              return AuthResult(
                success: false,
                message: 'Your account verification is under review. Please wait for admin approval.'
              );
            }

            print('\u2705 Talyer Owner verification approved - login allowed');
          } catch (verificationError) {
            print('\u274c Error checking Talyer Owner verification (direct): $verificationError');
            await SupabaseService.client.auth.signOut();
            await _clearLocalData();
            _isAuthenticated = false;
            _userId = null;
            _userEmail = null;
            _userProfile = null;
            return AuthResult(
              success: false,
              message: 'Your account verification is under review. Please wait for admin approval.'
            );
          }
        }
        
        print('🔔 Notifying listeners... isAuthenticated: $_isAuthenticated');
        notifyListeners();
        
        // Add a small delay to ensure the notification is processed
        await Future.delayed(const Duration(milliseconds: 100));

        // Process any pending uploads that were enqueued during signup
        try {
          if (_userId != null) {
            print('⏳ Processing pending uploads for user: $_userId');
            await PendingUploadService.processQueueForUser(_userId!);
          }
        } catch (e) {
          print('⚠️ Error processing pending uploads after sign in: $e');
        }

        // Log successful login
        final auditService = AuditLoggingService();
        await auditService.logUserLogin(
          userId: _userId!,
          role: _userProfile?['user_type'] ?? 'unknown',
          success: true,
        );
        
        print('✅ Login completed successfully');
        return AuthResult(success: true, message: 'Login successful');
      } else {
        print('❌ No user returned from sign in');
        return AuthResult(success: false, message: 'Invalid email or password');
      }
    } catch (e) {
      print('❌ Sign in error: $e');
      
      // Log failed login attempt
      try {
        final auditService = AuditLoggingService();
        await auditService.logAuditAction(
          userId: null, // No user ID for failed attempts
          role: 'unknown',
          action: 'USER_LOGIN_FAILED',
          success: false,
          errorMessage: e.toString(),
        );
      } catch (auditError) {
        print('Failed to log failed login audit: $auditError');
      }
      
      // Handle specific Supabase auth errors
      final errorMessage = e.toString().toLowerCase();
      if (errorMessage.contains('invalid login credentials') || 
          errorMessage.contains('invalid email or password')) {
        return AuthResult(success: false, message: 'Invalid email or password');
      } else if (errorMessage.contains('email not confirmed')) {
        return AuthResult(success: false, message: 'Please verify your email before signing in');
      } else if (errorMessage.contains('too many requests')) {
        return AuthResult(success: false, message: 'Too many login attempts. Please try again later.');
      }
      
      return AuthResult(success: false, message: 'Login failed. Please try again.');
    }
  }  Future<AuthResult> signUp({
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    required String password,
    String userType = 'customer',
    String? companyName, // Add company name parameter
    File? profileImage,
  }) async {
    try {
      print('📝 Starting signup for: $email');
      
      // First check if user already exists
      final existingUser = await SupabaseService.client
          .from('user_profiles')
          .select('email')
          .eq('email', email)
          .maybeSingle();
      
      if (existingUser != null) {
        return AuthResult(
          success: false, 
          message: 'An account with this email already exists. Please sign in instead.'
        );
      }      print('🔐 Creating auth user...');
      final response = await SupabaseService.signUp(
        email: email,
        password: password,
        firstName: firstName,
        lastName: lastName,
        phoneNumber: phone,
        userType: userType,
        companyName: companyName, // Pass company name
      );

      if (response.user != null) {
        print('✅ Auth user created: ${response.user!.id}');

        // Upload profile image
        String? profileImageUrl;
        if (profileImage != null) {
          try {
            final fileName = '${response.user!.id}/profile.${profileImage.path.split('.').last}';
            await SupabaseService.client.storage.from('profile-images').upload(fileName, profileImage);
            profileImageUrl = SupabaseService.client.storage.from('profile-images').getPublicUrl(fileName);
            print('✅ Profile image uploaded: $profileImageUrl');
          } catch (e) {
            print('❌ Error uploading profile image: $e');
            // Continue without profile image if upload fails
          }
        }

          // Wait for database trigger to process
        print('⏳ Waiting for database trigger to process...');
        await Future.delayed(const Duration(seconds: 2));        // Check if profile was created by trigger
        print('👤 Checking if profile was created by trigger...');
        try {
          final existingProfile = await SupabaseService.client
              .from('user_profiles')
              .select('*')
              .eq('id', response.user!.id)
              .maybeSingle();
          
          if (existingProfile != null) {
            print('✅ User profile created by trigger');
            print('👥 Profile user_type: ${existingProfile['user_type']}');
            
            // If trigger created profile but with wrong user_type, update it
            if (existingProfile['user_type'] != userType) {
              print('🔧 Updating user_type from ${existingProfile['user_type']} to $userType');
              await SupabaseService.client
                  .from('user_profiles')
                  .update({'user_type': userType})
                  .eq('id', response.user!.id);
              print('✅ User type updated');
            }
            
            // Create service_providers record if user is talyer_owner
            if (userType == 'talyer_owner') {
              print('🏪 Creating service provider record for talyer_owner...');
              try {
                await SupabaseService.client.from('service_providers').insert({
                  'user_id': response.user!.id,
                  'company_name': companyName ?? 'Unknown Shop',
                  'is_verified': false,
                  'is_available': true,
                  'status': 'offline',
                  'rating': 0.0,
                  'total_reviews': 0,
                  'service_radius': 50.0,
                });
                print('✅ Service provider record created');
                
                // Create shop record using the business name from signup
                print('🏪 Creating shop record for talyer_owner with business name: ${companyName ?? 'Unknown Shop'}');
                try {
                  // Direct shop creation without relying on TalyerOwnerService
                  final shopData = {
                    'owner_id': response.user!.id,
                    'shop_name': companyName ?? 'Unknown Shop',
                    'is_active': true,
                  };

                  final newShop = await SupabaseService.client
                      .from('shops')
                      .insert(shopData)
                      .select('id')
                      .single();
                  
                  print('✅ Shop record created successfully during signup with ID: ${newShop['id']}');
                  
                  // Update user profile with shop_id
                  try {
                    await SupabaseService.client
                        .from('user_profiles')
                        .update({'shop_id': newShop['id']})
                        .eq('id', response.user!.id);
                    print('✅ User profile updated with shop_id');
                  } catch (profileUpdateError) {
                    print('⚠️ Could not update user profile with shop_id: $profileUpdateError');
                  }
                  
                } catch (shopError) {
                  print('❌ Error creating shop record: $shopError');
                  // Continue anyway - shop can be created later
                }
              } catch (providerError) {
                print('❌ Error creating service provider record: $providerError');
                // Continue anyway - this can be created later
              }
            }
            
            // Send welcome email
            try {
              await _sendWelcomeEmail(
                userId: response.user!.id,
                email: email,
                firstName: firstName,
                lastName: lastName,
                userType: userType,
                companyName: companyName,
                phone: phone,
              );
            } catch (emailError) {
              print('⚠️ Warning: Failed to send welcome email: $emailError');
              // Don't fail the signup if email fails
            }
            
            return AuthResult(
              success: true, 
              message: 'Account created successfully! Please check your email for verification.',
              userId: response.user!.id,
              profileImageUrl: profileImageUrl,
            );
          } else {
            print('⚠️ Profile not created by trigger, creating manually...');
            // Trigger didn't work, create manually
            await SupabaseService.client.from('user_profiles').insert({
              'id': response.user!.id,
              'first_name': firstName,
              'last_name': lastName,
              'email': email,
              'phone_number': phone,
              'user_type': userType,
              'status': 'active',
              'is_available': true,
              'profile_image_url': profileImageUrl,
            });
            print('✅ User profile created manually');
            
            // Create service_providers record if user is talyer_owner
            if (userType == 'talyer_owner') {
              print('🏪 Creating service provider record for talyer_owner...');
              try {
                await SupabaseService.client.from('service_providers').insert({
                  'user_id': response.user!.id,
                  'company_name': companyName ?? 'Unknown Shop',
                  'is_verified': false,
                  'is_available': true,
                  'status': 'offline',
                  'rating': 0.0,
                  'total_reviews': 0,
                  'service_radius': 50.0,
                });
                print('✅ Service provider record created');
                
                // Create shop record using the business name from signup
                print('🏪 Creating shop record for talyer_owner with business name: ${companyName ?? 'Unknown Shop'}');
                try {
                  // Direct shop creation without relying on TalyerOwnerService
                  final shopData = {
                    'owner_id': response.user!.id,
                    'shop_name': companyName ?? 'Unknown Shop',
                    'is_active': true,
                  };

                  final newShop = await SupabaseService.client
                      .from('shops')
                      .insert(shopData)
                      .select('id')
                      .single();
                  
                  print('✅ Shop record created successfully during signup with ID: ${newShop['id']}');
                  
                  // Update user profile with shop_id
                  try {
                    await SupabaseService.client
                        .from('user_profiles')
                        .update({'shop_id': newShop['id']})
                        .eq('id', response.user!.id);
                    print('✅ User profile updated with shop_id');
                  } catch (profileUpdateError) {
                    print('⚠️ Could not update user profile with shop_id: $profileUpdateError');
                  }
                  
                } catch (shopError) {
                  print('❌ Error creating shop record: $shopError');
                  // Continue anyway - shop can be created later
                }
              } catch (providerError) {
                print('❌ Error creating service provider record: $providerError');
                // Continue anyway - this can be created later
              }
            }
            
            // Send welcome email
            try {
              await _sendWelcomeEmail(
                userId: response.user!.id,
                email: email,
                firstName: firstName,
                lastName: lastName,
                userType: userType,
                companyName: companyName,
                phone: phone,
              );
            } catch (emailError) {
              print('⚠️ Warning: Failed to send welcome email: $emailError');
              // Don't fail the signup if email fails
            }
            
            return AuthResult(
              success: true, 
              message: 'Account created successfully! Please check your email for verification.',
              userId: response.user!.id,
              profileImageUrl: profileImageUrl,
            );
          }        } catch (profileError) {
          print('❌ Error creating user profile: $profileError');
          
          // Check if this is a foreign key constraint error
          final errorStr = profileError.toString().toLowerCase();
          if (errorStr.contains('foreign key constraint') || 
              errorStr.contains('user_profiles_id_fkey')) {
            print('🔧 Foreign key constraint issue detected');
            
            // Try again after a longer delay - the auth user might need more time
            print('⏳ Waiting longer for auth user to be available...');
            await Future.delayed(const Duration(seconds: 3));
            
            try {
              await SupabaseService.client.from('user_profiles').insert({
                'id': response.user!.id,
                'first_name': firstName,
                'last_name': lastName,
                'email': email,
                'phone_number': phone,
                'user_type': userType,
                'status': 'active',
                'is_available': true,
                'profile_image_url': profileImageUrl,
              });
              
              print('✅ User profile created on retry');
              
              // Create service_providers record if user is talyer_owner
              if (userType == 'talyer_owner') {
                print('🏪 Creating service provider record for talyer_owner...');
                try {
                  await SupabaseService.client.from('service_providers').insert({
                    'user_id': response.user!.id,
                    'company_name': companyName ?? 'Unknown Shop',
                    'is_verified': false,
                    'is_available': true,
                    'status': 'offline',
                    'rating': 0.0,
                    'total_reviews': 0,
                    'service_radius': 50.0,
                  });
                  print('✅ Service provider record created on retry');
                  
                  // Create shop record using the business name from signup
                  print('🏪 Creating shop record for talyer_owner with business name: ${companyName ?? 'Unknown Shop'}');
                  try {
                    // Direct shop creation without relying on TalyerOwnerService
                    final shopData = {
                      'owner_id': response.user!.id,
                      'shop_name': companyName ?? 'Unknown Shop',
                      'is_active': true,
                    };

                    final newShop = await SupabaseService.client
                        .from('shops')
                        .insert(shopData)
                        .select('id')
                        .single();
                    
                    print('✅ Shop record created successfully during signup retry with ID: ${newShop['id']}');
                    
                    // Update user profile with shop_id
                    try {
                      await SupabaseService.client
                          .from('user_profiles')
                          .update({'shop_id': newShop['id']})
                          .eq('id', response.user!.id);
                      print('✅ User profile updated with shop_id on retry');
                    } catch (profileUpdateError) {
                      print('⚠️ Could not update user profile with shop_id on retry: $profileUpdateError');
                    }
                    
                  } catch (shopError) {
                    print('❌ Error creating shop record on retry: $shopError');
                    // Continue anyway - shop can be created later
                  }
                } catch (providerError) {
                  print('❌ Error creating service provider record on retry: $providerError');
                  // Continue anyway - this can be created later
                }
              }
              
              // Send welcome email
              try {
                await _sendWelcomeEmail(
                  userId: response.user!.id,
                  email: email,
                  firstName: firstName,
                  lastName: lastName,
                  userType: userType,
                  companyName: companyName,
                  phone: phone,
                );
              } catch (emailError) {
                print('⚠️ Warning: Failed to send welcome email: $emailError');
                // Don't fail the signup if email fails
              }
              
              return AuthResult(
                success: true, 
                message: 'Account created successfully! Please check your email for verification.',
                userId: response.user!.id,
                profileImageUrl: profileImageUrl,
              );
            } catch (retryError) {
              print('❌ Profile creation failed on retry: $retryError');
              
              // Still return success - the auth user was created successfully
              // The profile can be created later when the user logs in
              return AuthResult(
                success: true,
                message: 'Account created successfully! Please verify your email and try logging in. Your profile will be set up automatically.'
              );
            }
          } else if (errorStr.contains('row level security')) {
            return AuthResult(
              success: false,
              message: 'Account was created but profile setup failed due to permissions. Please contact support with this error code: RLS_ERROR'
            );
          }
          
          // For any other profile creation error, still consider signup successful
          // since the auth user was created - profile can be set up on login
          return AuthResult(
            success: true,
            message: 'Account created successfully! Please verify your email and try logging in. Your profile will be completed automatically.'
          );
        }
      } else {
        print('❌ No user returned from signup');
        return AuthResult(success: false, message: 'Failed to create account');
      }
    } catch (e) {
      print('❌ Signup error: $e');
      
      // Handle specific Supabase auth errors
      final errorMessage = e.toString().toLowerCase();
      if (errorMessage.contains('user already registered')) {
        return AuthResult(success: false, message: 'An account with this email already exists');
      } else if (errorMessage.contains('password')) {
        return AuthResult(success: false, message: 'Password must be at least 6 characters long');
      } else if (errorMessage.contains('email')) {
        return AuthResult(success: false, message: 'Please enter a valid email address');
      }
      
      return AuthResult(success: false, message: 'Failed to create account. Please try again.');
    }
  }
  Future<void> _loadUserProfile() async {
    try {
      if (_userId != null) {
        final response = await SupabaseService.client
            .from('user_profiles')
            .select('*')
            .eq('id', _userId!)
            .maybeSingle();
        
        if (response != null) {
          _userProfile = response;
          print('✅ User profile loaded: ${_userProfile!['first_name']} ${_userProfile!['last_name']}');
          print('👥 User type: ${_userProfile!['user_type']}');
        } else {
          print('⚠️ No user profile found for user ID: $_userId');
          // User exists in auth but no profile - this can happen if profile creation failed during signup
          _userProfile = null;
        }
      }
    } catch (e) {
      print('❌ Error loading user profile: $e');
      _userProfile = null;
    }
  }

  /// Create a user profile for existing auth users who don't have one
  Future<AuthResult> createMissingProfile({
    required String firstName,
    required String lastName,
    required String phone,
    String userType = 'customer',
  }) async {
    try {
      if (_userId == null || _userEmail == null) {
        return AuthResult(success: false, message: 'User not authenticated');
      }
      
      print('👤 Creating missing user profile for: $_userId');
      
      await SupabaseService.client.from('user_profiles').insert({
        'id': _userId!,
        'first_name': firstName,
        'last_name': lastName,
        'email': _userEmail!,
        'phone_number': phone,
        'user_type': userType,
        'status': 'active',
        'is_available': true,
      });
      
      // Reload the profile
      await _loadUserProfile();
      notifyListeners();
      
      return AuthResult(success: true, message: 'Profile created successfully');
    } catch (e) {
      print('❌ Error creating missing profile: $e');
      return AuthResult(success: false, message: 'Failed to create profile: $e');
    }
  }

  Future<void> signOut() async {
    try {
      // ✅ OPTIMIZED: Fire-and-forget audit log (don't wait for it)
      // Customer logout should be instant, audit logging happens in background
      if (_userId != null && _userProfile != null) {
        final userType = _userProfile!['user_type'] ?? 'unknown';
        
        // Only log audit for admin/mechanic/talyer_owner (skip customer for speed)
        if (userType != 'customer') {
          final auditService = AuditLoggingService();
          // Fire-and-forget - don't await
          auditService.logUserLogout(
            userId: _userId!,
            role: userType,
          ).catchError((e) {
            print('⚠️ Audit log failed (non-critical): $e');
          });
        }
      }
      
      // Clear auth session immediately (fast)
      await SupabaseService.client.auth.signOut();
      await _clearLocalData();
      
      _isAuthenticated = false;
      _userId = null;
      _userEmail = null;
      _userProfile = null;
      
      notifyListeners();
      print('✅ User signed out successfully (fast logout)');
    } catch (e) {
      print('❌ Error during sign out: $e');
      await _clearLocalData();
      _isAuthenticated = false;
      _userId = null;
      _userEmail = null;
      _userProfile = null;
      notifyListeners();
    }
  }

  Future<void> _clearLocalData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_id');
      await prefs.remove('user_email');
    } catch (e) {
      print('Error clearing local data: $e');
    }
  }

  Future<bool> resetPassword(String email) async {
    try {
      await SupabaseService.client.auth.resetPasswordForEmail(email);
      return true;
    } catch (e) {
      print('Error resetting password: $e');
      return false;
    }
  }

  static final supabase = Supabase.instance.client;
  
  // Add this method
  static Future<User?> getCurrentUser() async {
    try {
      final user = supabase.auth.currentUser;
      return user;
    } catch (e) {
      print('Error getting current user: $e');
      return null;
    }
  }
  
  // Alternative method to get user profile data
  static Future<Map<String, dynamic>?> getCurrentUserProfile() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return null;
      
      final response = await supabase
          .from('user_profiles')
          .select()
          .eq('id', user.id)
          .single();
      
      return response;
    } catch (e) {
      print('Error getting user profile: $e');
      return null;
    }
  }

  /// Method to update user type (for administrative functions)
  Future<void> updateUserType(String newUserType) async {
    try {
      if (_userId == null) {
        throw Exception('User not authenticated');
      }

      final oldUserType = _userProfile?['user_type'];
      
      await SupabaseService.client
          .from('user_profiles')
          .update({'user_type': newUserType})
          .eq('id', _userId!);

      // Log the user type change
      final auditService = AuditLoggingService();
      await auditService.logProfileUpdate(
        userId: _userId!,
        role: oldUserType ?? 'unknown',
        oldValues: {'user_type': oldUserType},
        newValues: {'user_type': newUserType},
      );

      // Reload user profile to get updated data
      await _loadUserProfile();
      
      print('✅ User type updated to: $newUserType');
      notifyListeners();
    } catch (e) {
      print('❌ Error updating user type: $e');
      throw Exception('Failed to update user type: $e');
    }
  }

  /// Send welcome email after successful registration
  Future<void> _sendWelcomeEmail({
    required String userId,
    required String email,
    required String firstName,
    required String lastName,
    required String userType,
    String? companyName,
    String? phone,
  }) async {
    try {
      print('📧 Sending welcome email to: $email');
      
      // Generate confirmation URL
      // In production, this would be your actual app URL
      final confirmationURL = 'https://your-app.com/confirm-email?token=confirmation_token_here';
      
      // Determine verification status for talyer owners
      String? verificationStatus;
      if (userType == 'talyer_owner') {
        verificationStatus = 'Your documents are being reviewed by our team. You will receive notification once approved.';
      }
      
      await EmailNotificationService.instance.sendWelcomeEmail(
        userId: userId,
        email: email,
        firstName: firstName,
        lastName: lastName,
        userType: userType,
        confirmationURL: confirmationURL,
        businessName: companyName,
        phone: phone,
        verificationStatus: verificationStatus,
      );
      
      print('✅ Welcome email sent successfully');
      
    } catch (e) {
      print('❌ Error sending welcome email: $e');
      // Don't throw error - email failure shouldn't block signup
    }
  }
}