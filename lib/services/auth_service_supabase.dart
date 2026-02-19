import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/auth_result.dart';
import '../models/user_model.dart';
import 'supabase_service.dart';

class AuthService extends ChangeNotifier {
  static final AuthService _instance = AuthService._internal();
  static AuthService get instance => _instance;
  AuthService._internal();

  final SupabaseClient _supabase = SupabaseService.client;

  User? get currentUser => _supabase.auth.currentUser;
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  bool _isAuthenticated = false;
  Map<String, dynamic>? _userProfile;
  bool _isDisposed = false;

  bool get isAuthenticated => _isAuthenticated;
  Map<String, dynamic>? get userProfile => _userProfile;
  String? get userId => _supabase.auth.currentUser?.id;
  String? get userEmail => _supabase.auth.currentUser?.email;

  Future<void> initialize() async {
    try {
      // Check if user is already signed in
      final user = _supabase.auth.currentUser;
      if (user != null) {
        _isAuthenticated = true;
        await _loadUserProfile();
      }
      _safeNotifyListeners();
    } catch (e) {
      print('❌ Error initializing AuthService: $e');
      _isAuthenticated = false;
      _userProfile = null;
      _safeNotifyListeners();
    }
  }

  // Sign up with email and password
  Future<AuthResult> signUp({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    try {
      print('🔄 Starting Supabase signup for: $email');

      // Step 1: Create user with Supabase Auth
      final AuthResponse authResponse = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': name,
          'phone_number': phone,
        },
      );

      final User? user = authResponse.user;
      if (user != null) {
        print('✅ User created successfully with ID: ${user.id}');

        // Step 2: Create user profile in Supabase database
        final userProfileData = {
          'id': user.id, // Use the auth user ID as primary key
          'full_name': name,
          'email': email,
          'phone_number': phone,
          'status': 'active',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        };

        await _supabase
            .from('user_profiles')
            .insert(userProfileData);
        
        print('✅ User profile created in Supabase');

        // Step 3: Set authentication state
        _isAuthenticated = true;

        // Step 4: Load the user profile
        await _loadUserProfile();

        // Step 5: Save login state
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isLoggedIn', true);
        await prefs.setString('userId', user.id);
        await prefs.setString('userEmail', email);

        _safeNotifyListeners();

        return AuthResult(
          success: true,
          message: 'Account created successfully!',
          userId: user.id,
        );
      } else {
        return AuthResult(
          success: false,
          message: 'Failed to create account',
        );
      }
    } on AuthException catch (e) {
      print('❌ Supabase Auth Error: ${e.message}');
      String message;
      switch (e.message.toLowerCase()) {
        case String msg when msg.contains('weak'):
          message = 'The password provided is too weak';
          break;
        case String msg when msg.contains('email') && msg.contains('use'):
          message = 'An account already exists for this email';
          break;
        case String msg when msg.contains('invalid') && msg.contains('email'):
          message = 'The email address is not valid';
          break;
        default:
          message = 'An error occurred: ${e.message}';
      }
      return AuthResult(success: false, message: message);
    } catch (e) {
      print('❌ Unexpected error during signup: $e');
      return AuthResult(success: false, message: 'An unexpected error occurred');
    }
  }

  // Sign in with email and password
  Future<AuthResult> signIn({
    required String email,
    required String password,
  }) async {
    try {
      print('🔄 Attempting Supabase sign in for: $email');

      final AuthResponse authResponse = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (authResponse.user != null) {
        print('✅ Sign in successful');
        _isAuthenticated = true;
        await _loadUserProfile();

        // Save login state
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isLoggedIn', true);
        await prefs.setString('userId', authResponse.user!.id);
        await prefs.setString('userEmail', email);

        _safeNotifyListeners();

        return AuthResult(
          success: true,
          message: 'Signed in successfully!',
          userId: authResponse.user!.id,
        );
      } else {
        return AuthResult(success: false, message: 'Failed to sign in');
      }
    } on AuthException catch (e) {
      print('❌ Supabase Auth Error: ${e.message}');
      String message;
      switch (e.message.toLowerCase()) {
        case String msg when msg.contains('not found'):
          message = 'No user found for this email';
          break;
        case String msg when msg.contains('password'):
          message = 'Wrong password provided';
          break;
        case String msg when msg.contains('invalid') && msg.contains('email'):
          message = 'The email address is not valid';
          break;
        case String msg when msg.contains('disabled'):
          message = 'This user account has been disabled';
          break;
        case String msg when msg.contains('too many'):
          message = 'Too many failed attempts. Please try again later';
          break;
        default:
          message = 'An error occurred: ${e.message}';
      }
      return AuthResult(success: false, message: message);
    } catch (e) {
      print('❌ Unexpected error during signin: $e');
      return AuthResult(success: false, message: 'An unexpected error occurred');
    }
  }

  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
      _isAuthenticated = false;
      _userProfile = null;

      // Clear stored data
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      _safeNotifyListeners();
      print('✅ User signed out successfully');
    } catch (e) {
      print('❌ Error signing out: $e');
      // Still update local state even if clearing preferences fails
      _isAuthenticated = false;
      _userProfile = null;
      _safeNotifyListeners();
    }
  }

  Future<AuthResult> resetPassword(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(email);
      return AuthResult(success: true, message: 'Password reset email sent');
    } on AuthException catch (e) {
      String message;
      switch (e.message.toLowerCase()) {
        case String msg when msg.contains('not found'):
          message = 'No user found for this email';
          break;
        case String msg when msg.contains('invalid') && msg.contains('email'):
          message = 'The email address is not valid';
          break;
        default:
          message = 'An error occurred: ${e.message}';
      }
      return AuthResult(success: false, message: message);
    } catch (e) {
      return AuthResult(success: false, message: 'An unexpected error occurred');
    }
  }

  Future<void> _loadUserProfile() async {
    final currentUserId = userId;
    if (currentUserId == null) {
      print('⚠️ No user ID available for loading profile');
      return;
    }

    try {
      print('🔄 Loading user profile for: $currentUserId');      final response = await _supabase
          .from('user_profiles')
          .select()
          .eq('id', currentUserId)
          .single();
      
      _userProfile = response;
      print('✅ User profile loaded: ${_userProfile?['full_name']}');
      _safeNotifyListeners();
    } catch (e) {
      print('⚠️ Error loading user profile: $e');
      _userProfile = null;
      _safeNotifyListeners();
    }
  }

  Future<void> updateProfile(Map<String, dynamic> data) async {
    final currentUserId = userId;
    if (currentUserId == null) {
      throw Exception('No user logged in');
    }

    try {
      // Add updated_at timestamp
      final updateData = {
        ...data,
        'updated_at': DateTime.now().toIso8601String(),
      };

      await _supabase
          .from('user_profiles')
          .update(updateData)
          .eq('id', currentUserId);
      
      _userProfile = {...?_userProfile, ...updateData};
      _safeNotifyListeners();
      print('✅ Profile updated successfully');
    } catch (e) {
      print('❌ Error updating profile: $e');
      throw e;
    }
  }

  // Get user data from Supabase
  Future<UserModel?> getUserData(String uid) async {
    try {      final response = await _supabase
          .from('user_profiles')
          .select()
          .eq('id', uid)
          .single();
      
      return UserModel.fromMap(response);
    } catch (e) {
      print('❌ Error getting user data: $e');
      return null;
    }
  }

  void _safeNotifyListeners() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}










