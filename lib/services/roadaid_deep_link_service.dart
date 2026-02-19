import 'dart:async';
import 'dart:math';
import 'package:app_links/app_links.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'navigation_service.dart';

class RoadAidDeepLinkService {
  static final RoadAidDeepLinkService _instance = RoadAidDeepLinkService._internal();
  factory RoadAidDeepLinkService() => _instance;
  RoadAidDeepLinkService._internal();

  StreamSubscription? _linkSubscription;
  BuildContext? _context;
  late AppLinks _appLinks;

  void initialize(BuildContext context) {
    _context = context;
    _appLinks = AppLinks();
    print('🔗 Initializing RoadAid Deep Link Service...');
    
    // Handle initial link (app opened via link)
    _handleInitialLink();
    
    // Handle incoming links (app already running)
    _linkSubscription = _appLinks.uriLinkStream.listen(
      _handleIncomingUri,
      onError: (err) {
        print('❌ Deep link error: $err');
      },
    );
  }

  Future<void> _handleInitialLink() async {
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        print('🎯 Initial deep link: $initialUri');
        _handleIncomingUri(initialUri);
      } else {
        print('ℹ️ No initial deep link found');
      }
    } catch (e) {
      print('❌ Error handling initial link: $e');
    }
  }

  void _handleIncomingUri(Uri uri) {
    final link = uri.toString();
    print('🔗 Processing deep link: $link');
    print('📋 Link details:');
    print('   Scheme: ${uri.scheme}');
    print('   Host: ${uri.host}');
    print('   Path: ${uri.path}');
    print('   Query: ${uri.query}');
    
    // Handle different auth callbacks
    switch (uri.host) {
      case 'confirm-signup':
        _handleSignupConfirmation(uri);
        break;
      case 'confirm-email':
        _handleEmailConfirmation(uri);
        break;
      case 'reset-password':
        _handlePasswordReset(uri);
        break;
      case 'email-change':
        _handleEmailChange(uri);
        break;
      case 'magic-link':
        _handleMagicLink(uri);
        break;
      case 'auth-callback':
        _handleAuthCallback(uri);
        break;
      case 'invite-accept':
        _handleInviteAcceptance(uri);
        break;
      default:
        print('⚠️ Unknown deep link host: ${uri.host}');
        _handleDefaultCallback(uri);
    }
  }

  void _handleSignupConfirmation(Uri uri) {
    print('✅ Handling signup confirmation');
    
    final token = uri.queryParameters['token'];
    
    if (token != null) {
      print('🎫 Confirmation token found: ${token.substring(0, 20)}...');
      
      // Show success message
      _showSuccessDialog(
        title: '🎉 Account Confirmed!',
        message: 'Your RoadAid account has been successfully confirmed. You can now log in and start using the app.',
        actionText: 'Get Started',
        onAction: () => _navigateToLogin(),
      );
    } else {
      print('❌ No confirmation token found');
      _showErrorDialog('Invalid confirmation link');
    }
  }

  void _handleEmailConfirmation(Uri uri) async {
    print('📧 Handling email confirmation');
    print('🔗 Full URI: $uri');
    
    final accessToken = uri.queryParameters['access_token'];
    final refreshToken = uri.queryParameters['refresh_token'];
    final code = uri.queryParameters['code'];
    final type = uri.queryParameters['type'];
    
    print('📋 Email confirmation parameters:');
    print('   Access Token: ${accessToken != null ? '${accessToken.substring(0, min(20, accessToken.length))}...' : 'null'}');
    print('   Refresh Token: ${refreshToken != null ? '${refreshToken.substring(0, min(20, refreshToken.length))}...' : 'null'}');
    print('   Code: ${code != null ? '${code.substring(0, min(20, code.length))}...' : 'null'}');
    print('   Type: $type');
    
    // Handle code parameter (PKCE flow for email confirmation)
    if (code != null) {
      print('🔄 Code found - attempting email confirmation');
      
      try {
        // For email confirmation, we need to use exchangeCodeForSession
        final response = await Supabase.instance.client.auth.exchangeCodeForSession(code);
        
        print('✅ Email confirmation successful - user confirmed');
        print('👤 User ID: ${response.session.user.id}');
        print('📧 Email: ${response.session.user.email}');
        print('✅ Email confirmed at: ${response.session.user.emailConfirmedAt}');
        
        // Show success message and navigate to login
        _showSuccessDialog(
          title: '🎉 Email Confirmed!',
          message: 'Your email has been successfully confirmed. You can now log in and start using RoadAid.',
          actionText: 'Sign In',
          onAction: () => _navigateToLogin(),
        );
      } catch (e) {
        print('❌ Email confirmation failed: $e');
        
        if (e.toString().contains('expired') || e.toString().contains('invalid')) {
          _showErrorDialog(
            'Email Confirmation Link Expired\n\nThis email confirmation link has expired or is invalid. Please request a new confirmation email or contact support.',
          );
        } else {
          _showErrorDialog(
            'Email Confirmation Error\n\nUnable to confirm your email. Please try again or contact support.',
          );
        }
      }
    } else if (accessToken != null && refreshToken != null) {
      print('🔑 Using access token for email confirmation');
      
      try {
        // Set the session with tokens
        await Supabase.instance.client.auth.setSession(refreshToken);
        
        print('✅ Email confirmation successful with tokens');
        
        // Show success message
        _showSuccessDialog(
          title: '🎉 Email Confirmed!',
          message: 'Your email has been successfully confirmed. You can now log in and start using RoadAid.',
          actionText: 'Sign In',
          onAction: () => _navigateToLogin(),
        );
      } catch (e) {
        print('❌ Email confirmation with tokens failed: $e');
        _showErrorDialog(
          'Email Confirmation Error\n\nUnable to confirm your email. Please try again or contact support.',
        );
      }
    } else {
      print('❌ No valid email confirmation tokens found');
      _showErrorDialog('Invalid email confirmation link - no authentication tokens found.\n\nPlease make sure you clicked the link from your email.');
    }
  }

  void _handlePasswordReset(Uri uri) async {
    print('🔑 Handling password reset');
    print('🔗 Full URI: $uri');
    
    final accessToken = uri.queryParameters['access_token'];
    final refreshToken = uri.queryParameters['refresh_token'];
    final code = uri.queryParameters['code'];
    final type = uri.queryParameters['type'];
    
    print('📋 Password reset parameters:');
    print('   Access Token: ${accessToken != null ? '${accessToken.substring(0, min(20, accessToken.length))}...' : 'null'}');
    print('   Refresh Token: ${refreshToken != null ? '${refreshToken.substring(0, min(20, refreshToken.length))}...' : 'null'}');
    print('   Code: ${code != null ? '${code.substring(0, min(20, code.length))}...' : 'null'}');
    print('   Type: $type');
    print('   All query params: ${uri.queryParameters}');
    
    // Handle code parameter (PKCE flow) - PREFERRED METHOD
    if (code != null) {
      print('🔄 Code found - attempting password reset code exchange');
      
      try {
        // For password reset, we need to use exchangeCodeForSession
        await Supabase.instance.client.auth.exchangeCodeForSession(code);
        
        print('✅ Code exchange successful - session created');
        print('   Session: Valid');
        
        // Navigate to password reset screen - session is already set
        _navigateToPasswordReset();
        return; // Exit early - code flow is complete
      } catch (codeError) {
        print('❌ Error exchanging code: $codeError');
        
        // Check if it's a flow state error (link expired/invalid)
        if (codeError.toString().contains('flow_state_not_found') || 
            codeError.toString().contains('invalid flow state')) {
          print('⚠️ Password reset link expired or invalid');
          _showErrorDialog(
            'Password Reset Link Expired\n\nThis password reset link has expired or is invalid. Please request a new password reset from the login screen.',
          );
          _navigateToLogin();
          return;
        }
        
        // For other errors, show a generic error and navigate to login
        print('🔄 Attempting navigation to login due to code exchange failure');
        _showErrorDialog(
          'Password Reset Error\n\nUnable to process password reset link. Please try requesting a new password reset.',
        );
        _navigateToLogin();
        return;
      }
    }
    
    // Fallback: Handle legacy access_token flow (older Supabase versions)
    if (accessToken != null && refreshToken != null) {
      print('🎫 Reset tokens found - setting Supabase session');
      
      try {
        // For password reset, tokens are usually in the URL fragment for newer Supabase versions
        // Let's try to recover the session with the access token
        await Supabase.instance.client.auth.recoverSession(accessToken);
        print('✅ Supabase session recovered successfully');
        
        // Small delay to ensure session is set
        Future.delayed(const Duration(milliseconds: 500), () {
          // Navigate directly to password reset screen
          _navigateToPasswordReset();
        });
      } catch (e) {
        print('❌ Error setting Supabase session: $e');
        _showErrorDialog('Failed to initialize password reset: $e');
      }
    } 
    
    // Check URL fragment for tokens (sometimes Supabase puts them there)
    else if (uri.fragment.isNotEmpty) {
      print('🔍 Checking URL fragment for tokens');
      final fragmentParams = Uri.splitQueryString(uri.fragment);
      print('🔍 Fragment parameters: $fragmentParams');
      
      final fragmentAccessToken = fragmentParams['access_token'];
      final fragmentRefreshToken = fragmentParams['refresh_token'];
      
      if (fragmentAccessToken != null && fragmentRefreshToken != null) {
        print('🎫 Found tokens in fragment - setting session');
        try {
          await Supabase.instance.client.auth.recoverSession(fragmentAccessToken);
          Future.delayed(const Duration(milliseconds: 500), () {
            _navigateToPasswordReset();
          });
          return;
        } catch (e) {
          print('❌ Error setting session from fragment: $e');
        }
      }
    }
    
    // If we reach here, no valid auth parameters were found
    print('❌ No valid authentication parameters found');
    print('🔍 Available query parameters: ${uri.queryParameters.keys.toList()}');
    _showErrorDialog('Invalid password reset link - no authentication code or tokens found.\n\nPlease make sure you clicked the link from your email.');
  }

  void _handleEmailChange(Uri uri) async {
    print('📧 Handling email change confirmation');
    print('🔗 Full URI: $uri');
    
    final accessToken = uri.queryParameters['access_token'];
    final refreshToken = uri.queryParameters['refresh_token'];
    final code = uri.queryParameters['code'];
    final type = uri.queryParameters['type'];
    
    print('📋 Email change parameters:');
    print('   Access Token: ${accessToken != null ? '${accessToken.substring(0, min(20, accessToken.length))}...' : 'null'}');
    print('   Refresh Token: ${refreshToken != null ? '${refreshToken.substring(0, min(20, refreshToken.length))}...' : 'null'}');
    print('   Code: ${code != null ? '${code.substring(0, min(20, code.length))}...' : 'null'}');
    print('   Type: $type');
    
    // Handle code parameter (PKCE flow for email change)
    if (code != null) {
      print('🔄 Code found - attempting email change confirmation');
      
      try {
        // For email change, we need to use exchangeCodeForSession
        await Supabase.instance.client.auth.exchangeCodeForSession(code);
        
        print('✅ Email change code exchange successful');
        print('   Session updated with new email');
        
        // Show success message and navigate
        _showSuccessDialog(
          title: '📧 Email Changed Successfully!',
          message: 'Your email address has been updated. You can now use your new email to log in.',
          actionText: 'Continue',
          onAction: () => _navigateToDashboard(),
        );
      } catch (codeError) {
        print('❌ Error exchanging email change code: $codeError');
        
        // Check if it's a flow state error (link expired/invalid)
        if (codeError.toString().contains('flow_state_not_found') || 
            codeError.toString().contains('invalid flow state')) {
          print('⚠️ Email change link expired or invalid');
          _showErrorDialog(
            'Email Change Link Expired\n\nThis email change confirmation link has expired or is invalid. Please request a new email change from your profile settings.',
          );
        } else {
          _showErrorDialog(
            'Email Change Error\n\nUnable to confirm email change. Please try again or contact support.',
          );
        }
        _navigateToDashboard();
        return;
      }
    }
    
    // Handle access token and refresh token (legacy flow)
    if (accessToken != null && refreshToken != null) {
      print('🎫 Email change tokens found - setting Supabase session');
      
      try {
        // Recover session with the new email
        await Supabase.instance.client.auth.recoverSession(accessToken);
        print('✅ Email change session recovered successfully');
        
        // Show success message
        _showSuccessDialog(
          title: '📧 Email Changed Successfully!',
          message: 'Your email address has been updated successfully. Welcome to your updated account!',
          actionText: 'Continue',
          onAction: () => _navigateToDashboard(),
        );
      } catch (e) {
        print('❌ Failed to recover email change session: $e');
        _showErrorDialog('Failed to confirm email change: $e');
      }
    } else {
      print('❌ No valid email change tokens found');
      _showErrorDialog('Invalid email change link - no authentication tokens found.\n\nPlease make sure you clicked the link from your email.');
    }
  }

  void _handleMagicLink(Uri uri) {
    print('✨ Handling magic link login');
    
    final accessToken = uri.queryParameters['access_token'];
    
    if (accessToken != null) {
      print('🎫 Magic link tokens found');
      
      // Show success and navigate to dashboard
      _showSuccessDialog(
        title: '✨ Magic Link Login',
        message: 'Successfully logged in! Welcome back to RoadAid.',
        actionText: 'Continue',
        onAction: () => _navigateToDashboard(),
      );
    } else {
      print('❌ No magic link tokens found');
      _showErrorDialog('Invalid magic link');
    }
  }

  void _handleAuthCallback(Uri uri) {
    print('🔄 Handling general auth callback');
    
    final accessToken = uri.queryParameters['access_token'];
    final error = uri.queryParameters['error'];
    
    if (error != null) {
      print('❌ Auth error: $error');
      _showErrorDialog('Authentication failed: $error');
      return;
    }
    
    if (accessToken != null) {
      print('✅ Auth tokens received');
      
      // Set the session in Supabase
      try {
        // Navigate to appropriate screen based on user type
        _navigateBasedOnUserType();
      } catch (e) {
        print('❌ Error setting session: $e');
        _showErrorDialog('Failed to complete login');
      }
    } else {
      print('❌ No auth tokens found');
      _showErrorDialog('Authentication incomplete');
    }
  }

  void _handleInviteAcceptance(Uri uri) {
    print('📧 Handling invite acceptance');
    
    final token = uri.queryParameters['token'];
    final shopId = uri.queryParameters['shop_id'];
    
    if (token != null) {
      print('🎫 Invite token found for shop: $shopId');
      
      _showSuccessDialog(
        title: '🎉 Invitation Accepted!',
        message: 'Welcome to the RoadAid team! Please complete your profile setup.',
        actionText: 'Setup Profile',
        onAction: () => _navigateToProfileSetup(shopId),
      );
    } else {
      print('❌ No invite token found');
      _showErrorDialog('Invalid invitation link');
    }
  }

  void _handleDefaultCallback(Uri uri) {
    print('🔄 Handling default callback');
    
    // Check if this is a payment success callback
    final requestId = uri.queryParameters['request_id'];
    final invoiceId = uri.queryParameters['invoice_id'];
    
    if (requestId != null || invoiceId != null) {
      print('💳 Payment success detected! Request ID: $requestId, Invoice ID: $invoiceId');
      
      // Check if user is authenticated
      final user = Supabase.instance.client.auth.currentUser;
      
      if (user != null) {
        print('✅ User authenticated, navigating to dashboard with payment success data');
        // Navigate to dashboard and pass the request_id to show bottom sheet
        _navigateToCustomerDashboardWithPaymentSuccess(requestId ?? invoiceId!);
      } else {
        print('ℹ️ User not authenticated, navigating to login');
        _navigateToLogin();
      }
      return;
    }
    
    // Check if user is already authenticated
    final user = Supabase.instance.client.auth.currentUser;
    
    if (user != null) {
      print('✅ User is authenticated, navigating to dashboard');
      _navigateBasedOnUserType();
    } else {
      print('ℹ️ User not authenticated, navigating to login');
      _navigateToLogin();
    }
  }
  
  void _navigateToCustomerDashboardWithPaymentSuccess(String requestId) {
    print('📍 Navigating to customer dashboard with request: $requestId');
    
    try {
      // Use NavigationService to pass data
      // This will trigger the dashboard to show the bottom sheet for this request
      NavigationService.navigatorKey.currentState?.pushNamedAndRemoveUntil(
        '/customer-dashboard',
        (route) => false,
        arguments: {
          'show_bottom_sheet': true,
          'request_id': requestId,
        },
      );
    } catch (_) {
      if (_context != null) {
        Navigator.of(_context!).pushNamedAndRemoveUntil(
          '/customer-dashboard',
          (route) => false,
          arguments: {
            'show_bottom_sheet': true,
            'request_id': requestId,
          },
        );
      }
    }
  }

  void _showSuccessDialog({
    required String title,
    required String message,
    required String actionText,
    required VoidCallback onAction,
  }) {
    if (_context == null) return;
    
    showDialog(
      context: _context!,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              onAction();
            },
            child: Text(actionText),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    if (_context == null) return;
    
    showDialog(
      context: _context!,
      builder: (context) => AlertDialog(
        title: const Text('❌ Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _navigateToLogin() {
    // Prefer using the global navigator so navigation works even if _context is null
    try {
      NavigationService.navigatorKey.currentState?.pushNamedAndRemoveUntil('/login', (route) => false);
    } catch (_) {
      if (_context != null) {
        Navigator.of(_context!).pushNamedAndRemoveUntil('/login', (route) => false);
      }
    }
  }

  void _navigateToDashboard() {
    try {
      NavigationService.navigatorKey.currentState?.pushNamedAndRemoveUntil('/dashboard', (route) => false);
    } catch (_) {
      if (_context != null) {
        Navigator.of(_context!).pushNamedAndRemoveUntil('/dashboard', (route) => false);
      }
    }
  }

  void _navigateToPasswordReset() {
    // Session should already be set by the auth callback
    // Navigate without passing token since session is active
    try {
      NavigationService.navigatorKey.currentState?.pushNamed('/reset-password');
    } catch (_) {
      if (_context != null) {
        Navigator.of(_context!).pushNamed('/reset-password');
      }
    }
  }

  void _navigateToProfileSetup(String? shopId) {
    if (_context == null) return;
    
    // Navigate to profile setup for mechanics
    Navigator.of(_context!).pushNamed(
      '/profile-setup',
      arguments: {'shop_id': shopId},
    );
  }

  Future<void> _navigateBasedOnUserType() async {
    if (_context == null) return;
    
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        _navigateToLogin();
        return;
      }

      // Get user profile to determine user type
      final profile = await Supabase.instance.client
          .from('user_profiles')
          .select('user_type')
          .eq('id', user.id)
          .single();

      final userTypeRaw = profile['user_type'];
      final userType = NavigationService.normalizeUserType(userTypeRaw);

      switch (userType) {
        case 'talyer_owner':
          Navigator.of(_context!).pushNamedAndRemoveUntil(
            '/talyer-dashboard',
            (route) => false,
          );
          break;
        case 'mechanic':
          Navigator.of(_context!).pushNamedAndRemoveUntil(
            '/mechanic-dashboard',
            (route) => false,
          );
          break;
        case 'customer':
        default:
          Navigator.of(_context!).pushNamedAndRemoveUntil(
            '/customer-dashboard',
            (route) => false,
          );
          break;
      }
    } catch (e) {
      print('❌ Error determining user type: $e');
      _navigateToLogin();
    }
  }

  void dispose() {
    print('🔗 Disposing RoadAid Deep Link Service...');
    _linkSubscription?.cancel();
    _context = null;
  }
}










