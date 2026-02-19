// Splash screen that checks VPN, shows dialog or navigates to Home

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'vpn_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {

  @override
  void initState() {
    super.initState();
    _checkVpn();
  }

  // Check VPN asynchronously using platform channel
  Future<void> _checkVpn() async {
    bool active = false;
    try {
      active = await VpnService.isVpnActive();
    } on PlatformException catch (_) {
      active = false;
    }

    // Keep splash for at least 2 seconds for visual polish
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    if (active) {
      _showVpnDialog();
    } else {
      // No VPN detected — navigate to Home
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
    }
  }

  // Show blocking dialog when VPN is detected
  void _showVpnDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false, // user must act
      builder: (context) => AlertDialog(
        title: const Text('VPN detected'),
        content: const Text('VPN detected. Please turn off your VPN to continue using this app.'),
        actions: [
          TextButton(
            onPressed: () {
              // Cleanly pop the Flutter activity (works for Android/iOS)
              SystemNavigator.pop();
            },
            child: const Text('Exit App'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.security, size: 84, color: Colors.blue),
            SizedBox(height: 20),
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Checking VPN connection...', style: TextStyle(fontSize: 16, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

// Simple HomeScreen to navigate to when no VPN is active
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: const Center(child: Text('No VPN detected. Welcome!')),
    );
  }
}
