import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Minimal global navigation helper. Keep it intentionally small: the deep-link
/// service uses this to navigate without needing a Widget BuildContext.
class NavigationService {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static Future<T?>? pushNamed<T extends Object?>(String routeName, {Object? arguments}) {
    return navigatorKey.currentState?.pushNamed<T>(routeName, arguments: arguments);
  }

  static Future<T?>? pushReplacementNamed<T extends Object?, TO extends Object?>(String routeName, {TO? result, Object? arguments}) {
    return navigatorKey.currentState?.pushReplacementNamed<T, TO>(routeName, result: result, arguments: arguments);
  }

  static void pushNamedAndRemoveUntil(String routeName, RoutePredicate predicate) {
    navigatorKey.currentState?.pushNamedAndRemoveUntil(routeName, predicate);
  }

  /// Returns a short welcome message appropriate for the given [userType].
  /// Used by the login screen to show a small success SnackBar.
  static String getWelcomeMessageForUserType(String? userType) {
  final normalized = normalizeUserType(userType);
  switch (normalized) {
      case 'mechanic':
        return 'Welcome back, mechanic!';
      case 'talyer_owner':
        return 'Welcome back, shop owner!';
      case 'admin':
      case 'super_admin':
        return 'Welcome back, admin!';
      case 'customer':
      default:
        return 'Welcome back!';
    }
  }

  /// Safely normalizes a dynamic/nullable userType into a lowercase String.
  /// Returns null if [userType] is null or an empty string.
  static String? normalizeUserType(dynamic userType) {
    if (userType == null) return null;
    try {
      final s = userType is String ? userType : userType.toString();
      final trimmed = s.trim();
      if (trimmed.isEmpty) return null;
      return trimmed.toLowerCase();
    } catch (_) {
      return null;
    }
  }

  /// Navigate to the appropriate dashboard based on the current authenticated
  /// user's type. Prefers the global navigator; falls back to the provided
  /// [context] if the global navigator is not available.
  static Future<void> navigateBasedOnUserType(BuildContext context) async {
    final nav = navigatorKey.currentState;

    // Try to determine the user's type by querying the user_profiles table
    // directly via Supabase to avoid importing AuthService and causing
    // circular imports. If anything fails, fall back to the customer dashboard.
    try {
      final user = Supabase.instance.client.auth.currentUser;
      String? safeType;

      if (user != null) {
        final profile = await Supabase.instance.client
            .from('user_profiles')
            .select('user_type')
            .eq('id', user.id)
            .maybeSingle();

        safeType = normalizeUserType(profile?['user_type']);
      }

      final route = () {
        switch (safeType) {
          case 'mechanic':
            return '/mechanic-dashboard';
          case 'talyer_owner':
            return '/talyer-dashboard';
          case 'admin':
          case 'super_admin':
            return '/customer-dashboard';
          case 'customer':
          default:
            return '/customer-dashboard';
        }
      }();

      if (nav != null) {
        nav.pushNamedAndRemoveUntil(route, (r) => false);
        return;
      }

      Navigator.of(context).pushNamedAndRemoveUntil(route, (r) => false);
    } catch (e) {
      // On any error, default to customer dashboard to keep user moving.
      if (nav != null) {
        nav.pushNamedAndRemoveUntil('/customer-dashboard', (r) => false);
        return;
      }
      Navigator.of(context).pushNamedAndRemoveUntil('/customer-dashboard', (r) => false);
    }
  }
}










