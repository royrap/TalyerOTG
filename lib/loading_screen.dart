// Loading screen that shows a logo and spinner while checking VPN status
// If VPN is active, a blocking dialog is shown with Retry and Exit options.
// If no VPN, the screen fades out and navigates to the main app route.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'vpn_service.dart';

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Controller for fade-out when navigating to the app
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    ));

    // Start initial VPN check after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) => _startCheck());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _fadeController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // When returning to the app (e.g., from Settings), re-run the VPN check
    if (state == AppLifecycleState.resumed) {
      // ignore: avoid_print
      print('[LoadingScreen] resumed - rechecking VPN');
      _startCheck();
    }
  }

  Future<void> _startCheck() async {
    if (!mounted) return;
    // mark as checking (no UI state needed here)
    // Debug log: entering VPN check
    // ignore: avoid_print
    print('[LoadingScreen] starting VPN check');

    bool active = false;
    try {
      // Call platform VPN service (MethodChannel)
      active = await VpnService.isVpnActive();
    } on PlatformException {
      active = false; // on error assume no VPN to avoid blocking users
    }

    // Debug log: VPN check result
    // ignore: avoid_print
    print('[LoadingScreen] VPN active? $active');

    // If VPN active, show blocking dialog
    if (!mounted) return;

    if (active) {
      _showVpnDialog();
  // finished checking
      return;
    }

  // No VPN — keep splash visible for ~3s, then fade out and navigate
  await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;
    await _fadeController.forward();

    if (!mounted) return;
    // Navigate to the main app route (registered as '/app')
    Navigator.of(context).pushReplacementNamed('/app');
  }

  // Show alert when VPN is detected. Retry will re-run check after 2s.
  void _showVpnDialog() {
    // Debug log: showing VPN dialog
    // ignore: avoid_print
    print('[LoadingScreen] showing VPN dialog');
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('VPN Detected'),
        content: const Text('Please turn off your VPN to continue using this app.'),
        actions: [
              TextButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  await Future.delayed(const Duration(seconds: 1));
                  if (!mounted) return;
                  _startCheck(); // retry detection immediately
                },
                child: const Text('Retry'),
              ),
              TextButton(
                onPressed: () async {
                  // Instead of closing the app, open the device VPN settings so the user
                  // can disable VPN and then return to the app.
                  Navigator.of(context).pop();
                  // Attempt to open platform settings; we don't block here — lifecycle
                  // observer will trigger re-check when the user returns.
                  final opened = await VpnService.openVpnSettings();
                  // ignore: avoid_print
                  print('[LoadingScreen] openVpnSettings launched: $opened');
                },
                child: const Text('Exit'),
              ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // App logo using project's LOGO.png (declared in pubspec.yaml)
              // Prominent logo (larger) using project's LOGO.png
              Image.asset(
                'LOGO.png',
                width: 160,
                height: 160,
                fit: BoxFit.contain,
                semanticLabel: 'RoadAid Logo',
                errorBuilder: (context, error, stackTrace) {
                  // ignore: avoid_print
                  print('[LoadingScreen] failed to load LOGO.png: $error');
                  return Icon(Icons.shield, size: 140, color: theme.colorScheme.primary);
                },
              ),
              const SizedBox(height: 24),
              // Spinner only; no VPN status text so the screen focuses on the logo
              const CircularProgressIndicator(),
            ],
          ),
        ),
      ),
    );
  }
}
