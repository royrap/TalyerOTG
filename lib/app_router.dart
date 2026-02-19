import 'package:flutter/material.dart';
import 'services/auth_service.dart';
import 'auth/login_screen.dart';
import 'customer/customer_dashboard.dart';
import 'talyer_owner/talyer_owner_dashboard.dart';
import 'mechanic/mechanic_dashboard.dart';
import 'auth/first_login_password_change_screen.dart';

class AppRouter {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/':
        return MaterialPageRoute(builder: (_) => const AuthWrapper());
      case '/login':
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      case '/customer-dashboard':
        return MaterialPageRoute(builder: (_) => const CustomerDashboard());
      case '/talyer-dashboard':
                return MaterialPageRoute(builder: (_) => const TalyerOwnerDashboard());
      case '/mechanic-dashboard':
        return MaterialPageRoute(builder: (_) => const MechanicDashboard());
      case '/first-login-password':
        return MaterialPageRoute(
          builder: (_) => FirstLoginPasswordChangeScreen(
            userType: settings.arguments as String? ?? 'customer',
          ),
        );
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(
              child: Text('No route defined for ${settings.name}'),
            ),
          ),
        );
    }
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    AuthService.instance.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AuthService.instance,
      builder: (context, child) {
        if (AuthService.instance.isAuthenticated) {
          final userType = AuthService.instance.userType;
          final userProfile = AuthService.instance.userProfile;
          
          // Check if user needs to change password on first login
          if (userProfile?['first_login_completed'] == false || 
              userProfile?['password_change_required'] == true) {
            return FirstLoginPasswordChangeScreen(userType: userType ?? 'customer');
          }
          
          // Route based on user type
          switch (userType) {
            case 'customer':
              return const CustomerDashboard();
            case 'talyer_owner':
              return const TalyerOwnerDashboard();
            case 'mechanic':
              return const MechanicDashboard();
            default:
              return const LoginScreen();
          }
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}










