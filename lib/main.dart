import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart' show NetworkAssetBundle;
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import 'customer/request_assistance_screen.dart';
import 'loading_screen.dart';
import 'customer/shop_services_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/history_screen.dart';
import 'screens/payment_success_screen.dart';
import 'customer/real_time_invoice_screen.dart';
import 'widgets/history_bottom_sheet.dart';
import 'customer/job_completion_qr_screen.dart';
import 'customer/widgets/customer_payment_result_bottom_sheet.dart';
import 'mechanic/mechanic_dashboard.dart';
import 'talyer_owner/talyer_owner_dashboard.dart';
import 'services/supabase_service.dart';
import 'services/auth_service.dart';
import 'services/user_data_service.dart';
import 'services/location_service.dart';
import 'screens/auth/simple_password_reset_screen.dart';
import 'services/roadaid_deep_link_service.dart';
import 'services/navigation_service.dart';
import 'auth/login_screen.dart';
import 'widgets/review_dialog.dart';
import 'widgets/invoice_notification_widget.dart';
import 'widgets/real_time_eta_widget.dart';
import 'shared/services/google_maps_service.dart';
import 'services/logging_service.dart';
import 'screens/secure_qr_scanner_screen.dart';
import 'theme/roadaid_colors.dart';

// Platform channel for native phone calling
const platform = MethodChannel('roadaid/phone_launcher');

// Helper function to make phone calls using native Android intent
Future<bool> makePhoneCallNative(String phoneNumber) async {
  try {
    print('🔥 Attempting native phone call to: $phoneNumber');
    final bool result = await platform.invokeMethod('makePhoneCall', {'phoneNumber': phoneNumber});
    print('✅ Native phone call result: $result');
    return result;
  } on PlatformException catch (e) {
    print('❌ Native phone call failed: ${e.message}');
    return false;
  }
}

MaterialColor createMaterialColor(Color color) {
  List strengths = <double>[.05];
  Map<int, Color> swatch = {};
  final int r = color.red;
  final int g = color.green;  
  final int b = color.blue;

  for (int i = 1; i < 10; i++) {
    strengths.add(0.1 * i);
  }
  for (var strength in strengths) {
    final double ds = 0.5 - strength;
    swatch[(strength * 1000).round()] = Color.fromRGBO(
      r + ((ds < 0 ? r : (255 - r)) * ds).round(),
      g + ((ds < 0 ? g : (255 - g)) * ds).round(),
      b + ((ds < 0 ? b : (255 - b)) * ds).round(),
      1,
    );
  }
  return MaterialColor(color.toARGB32(), swatch);
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Start the app UI immediately so the loading screen (logo) is visible right away.
  runApp(const MyApp());

  // Perform heavier initializations in the background so they don't block the UI.
  // This allows the LoadingScreen to show immediately while VPN check runs.
  () async {
    try {
      // Initialize WebView Platform in background
      if (WebViewPlatform.instance == null) {
        if (!kIsWeb) {
          if (defaultTargetPlatform == TargetPlatform.android) {
            WebViewPlatform.instance = AndroidWebViewPlatform();
            // ignore: avoid_print
            print('✅ Android WebView platform initialized (background)');
          } else if (defaultTargetPlatform == TargetPlatform.iOS) {
            WebViewPlatform.instance = WebKitWebViewPlatform();
            // ignore: avoid_print
            print('✅ iOS WebView platform initialized (background)');
          }
        }
      }
    } catch (e) {
      // ignore: avoid_print
      print('⚠️ WebView initialization error: $e');
    }

    try {
      await SupabaseService.initialize();
      // ignore: avoid_print
      print('✅ Supabase initialized (background)');
    } catch (e) {
      // ignore: avoid_print
      print('⚠️ Supabase initialization failed: $e');
    }

    try {
      await AuthService.instance.initialize();
      // ignore: avoid_print
      print('✅ AuthService initialized (background)');
    } catch (e) {
      // ignore: avoid_print
      print('⚠️ AuthService initialization failed: $e');
    }
  }();
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'RoadAid',
      navigatorKey: NavigationService.navigatorKey,
      theme: RoadAidTheme.lightTheme,
  // Use LoadingScreen as the app entry point so VPN detection runs first
  home: const LoadingScreen(),
      routes: {
        '/app': (context) => const AuthWrapper(),
        '/login': (context) => const LoginScreen(),
        '/reset-password': (context) => const SimplePasswordResetScreen(),
        '/payment/success': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          return PaymentSuccessScreen(
            serviceRequestId: args?['serviceRequestId'],
            transactionId: args?['transactionId'],
            amount: args?['amount'] != null ? double.tryParse(args!['amount'].toString()) : null,
          );
        },
        '/secure_qr_scanner': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          return SecureQRScannerScreen(
            requestId: args?['requestId'] ?? '',
            jobTitle: args?['jobTitle'] ?? 'Service Completion',
          );
        },
  // Named routes used by background services/navigation helpers
  '/customer-dashboard': (context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final requestId = args?['request_id'] as String?;
    
    // If coming from payment success with request_id, pass it to show bottom sheet
    if (requestId != null) {
      print('📍 Opening customer dashboard with request_id: $requestId');
      return RoadAidHomePage(
        initialIndex: 0,
        paymentSuccessData: {
          'requestId': requestId,
          'show_bottom_sheet': true,
        },
      );
    }
    
    return const RoadAidHomePage(initialIndex: 0);
  },
  '/mechanic-dashboard': (context) => const MechanicDashboard(),
  '/talyer-dashboard': (context) => const TalyerOwnerDashboard(),
  '/dashboard': (context) => const RoadAidHomePage(initialIndex: 0),
      },
    );
  }
}

class AuthWrapper extends StatefulWidget {
  final Map<String, dynamic>? paymentSuccessData;
  
  const AuthWrapper({
    Key? key,
    this.paymentSuccessData,
  }) : super(key: key);

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    // Add listener to track changes
    AuthService.instance.addListener(_onAuthStateChanged);
    print('🎯 AuthWrapper initialized, current state: ${AuthService.instance.isAuthenticated}');
    
    // Initialize deep link service after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      RoadAidDeepLinkService().initialize(context);
      print('🔗 Deep link service initialized');
    });
  }

  @override
  void dispose() {
    AuthService.instance.removeListener(_onAuthStateChanged);
    RoadAidDeepLinkService().dispose();
    super.dispose();
  }

  void _onAuthStateChanged() {
    print('🔔 AuthWrapper listener triggered! isAuthenticated: ${AuthService.instance.isAuthenticated}');
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAuthenticated = AuthService.instance.isAuthenticated;
    final userId = AuthService.instance.userId;
    final userEmail = AuthService.instance.userEmail;
    final userType = AuthService.instance.userType;
    
    print('🔄 AuthWrapper build - isAuthenticated: $isAuthenticated, userId: $userId, email: $userEmail, userType: $userType');

    if (isAuthenticated) {
      // Safely normalize the userType to avoid null/JS values
      final safeUserType = NavigationService.normalizeUserType(userType);
      print('🏠 Navigating based on user type: $safeUserType');

      // Route users to appropriate dashboard based on their type
      // Note: Admin access is restricted - admins must use separate admin portal
      switch (safeUserType) {
        case 'mechanic':
          print('🔧 Loading Mechanic Dashboard');
          return const MechanicDashboard();
        case 'talyer_owner':
          print('🏢 Loading Talyer Owner Dashboard');
          return const TalyerOwnerDashboard();
        case 'admin':
        case 'super_admin':
          print('🚫 Admin access restricted - redirecting to customer dashboard');
          // Admins should use the dedicated admin portal, not the main app
          return RoadAidHomePage(
            initialIndex: 0,
            paymentSuccessData: widget.paymentSuccessData,
          );
        case 'customer':
        default:
          print('👤 Loading Customer Dashboard (userType was: $userType)');
          return RoadAidHomePage(
            initialIndex: 0,
            paymentSuccessData: widget.paymentSuccessData,
          );
      }
    } else {
      print('🔐 Showing LoginScreen (user not authenticated)');
      return const LoginScreen();
    }
  }
}

class RoadAidHomePage extends StatefulWidget {
  final int initialIndex;
  final Map<String, dynamic>? paymentSuccessData;
  
  const RoadAidHomePage({
    Key? key,
    this.initialIndex = 0,
    this.paymentSuccessData,
  }) : super(key: key);

  @override
  State<RoadAidHomePage> createState() => _RoadAidHomePageState();
}

class _RoadAidHomePageState extends State<RoadAidHomePage> 
    with SingleTickerProviderStateMixin {
  late int _currentIndex;
  bool _hasActiveService = false;
  Map<String, dynamic>? _activeServiceData;
  late AnimationController _bottomSheetController;
  late Animation<double> _bottomSheetAnimation;
  
  // Payment result mode
  bool _isShowingPaymentResult = false;
  
  // Invoice notification system
  StreamSubscription? _invoiceSubscription;
  
  // Customer service status monitoring
  StreamSubscription? _serviceRequestSubscription;
  
  // Dynamic pages based on service status
  List<Widget> get _pages => [
    RoadAidBody(hasActiveService: _hasActiveServiceInProgress(), currentTabIndex: _currentIndex),
    const HistoryScreen(),
    _hasActiveServiceInProgress() ? _buildBlockedRequestScreen() : const RequestAssistanceScreen(),
    const RealTimeInvoiceScreen(),
    const ProfileScreen(),
  ];

  // Build blocked request screen when user has active service
  Widget _buildBlockedRequestScreen() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Request Assistance'),
        backgroundColor: const Color.fromARGB(255, 176, 12, 1),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.block,
                size: 80,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 24),
              Text(
                'Active Service in Progress',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'You cannot request a new service while you have an active service in progress. Please wait for your current service to be completed.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () {
                  // Show the active service bottom sheet
                  if (!_bottomSheetController.isCompleted) {
                    _bottomSheetController.forward();
                  }
                },
                icon: const Icon(Icons.visibility),
                label: const Text('View Active Service'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 176, 12, 1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    
    // Initialize animation controller for bottom sheet
    _bottomSheetController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _bottomSheetAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _bottomSheetController,
      curve: Curves.easeInOut,
      
    ));
    
    // Show payment success bottom sheet if payment data is provided
    if (widget.paymentSuccessData != null) {
      _hasActiveService = true;
      _activeServiceData = widget.paymentSuccessData;
      _isShowingPaymentResult = true;
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showPaymentResultBottomSheet();
      });
    }

    // Auto-load any active service so the bottom sheet shows on device too
    // This helps when navigation didn't pass paymentSuccessData.
    // Runs after a short delay to avoid racing initial auth/layout.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadActiveServiceIfAny();
      _setupInvoiceNotifications(); // Add invoice notification system
      _setupCustomerServiceMonitoring(); // Add customer service status monitoring
    });
  }

  // Detect the most recent active service request for the logged-in customer
  // and populate the persistent bottom sheet.
  Future<void> _loadActiveServiceIfAny() async {
    try {
      if (!mounted) return;
      // If already showing via navigation data, skip
      if (_hasActiveService && _activeServiceData != null) return;

      final userId = SupabaseService.client.auth.currentUser?.id;
      if (userId == null) return;

      // Consider these as active statuses
      final activeStatuses = [
        'pending',
        'awaiting_payment',
        'paid',
        'accepted',
        'ready_to_assign',
        'assigned',
        'in_progress',
      ];

      // Fetch the latest active service for this user
      Map<String, dynamic>? response;
      try {
        response = await SupabaseService.client
            .from('service_requests')
            .select('*')
            .eq('customer_id', userId)
            .inFilter('status', activeStatuses)
            .order('updated_at', ascending: false)
            .limit(1)
            .maybeSingle();
      } catch (e) {
        // Log but do not fail loading the app
        print('⚠️ Active service query (filtered) failed: $e');
      }

      // Fallback: get the most recent request for this user if none matched active statuses
      if (response == null) {
        try {
          response = await SupabaseService.client
              .from('service_requests')
              .select('*')
              .eq('customer_id', userId)
              .order('updated_at', ascending: false)
              .limit(1)
              .maybeSingle();
        } catch (e) {
          print('⚠️ Fallback latest service query failed: $e');
        }
      }

      if (response != null) {
        final r = Map<String, dynamic>.from(response);
        // Build the data map expected by the sheet
        final String? title = (r['title'] as String?) ?? (r['issue_title'] as String?);
        final String? providerId = r['provider_id'] as String?;
        final String? assignedMechanicId = r['assigned_mechanic_id'] as String?;
        final String status = (r['status']?.toString() ?? '').toLowerCase();
        final dynamic finalPrice = r['final_price'];
        final String amountStr = finalPrice is num
            ? '₱${finalPrice.toStringAsFixed(2)}'
            : (finalPrice is String && double.tryParse(finalPrice) != null
                ? '₱${double.parse(finalPrice).toStringAsFixed(2)}'
                : '₱0.00');

        // Fetch mechanic phone number
        String mechanicPhone = '';
        try {
          if (assignedMechanicId != null) {
            // Try to get assigned mechanic phone
            final mechProfile = await SupabaseService.client
                .from('user_profiles')
                .select('phone_number')
                .eq('id', assignedMechanicId)
                .maybeSingle();
            mechanicPhone = mechProfile?['phone_number'] ?? '';
          } else if (providerId != null) {
            // Fallback: get provider phone
            final providerData = await SupabaseService.client
                .from('service_providers')
                .select('''
                  user_profiles!service_providers_user_id_fkey (
                    phone_number
                  )
                ''')
                .eq('id', providerId)
                .maybeSingle();
            mechanicPhone = providerData?['user_profiles']?['phone_number'] ?? '';
          }
        } catch (e) {
          print('⚠️ Error fetching mechanic phone: $e');
        }

        if (mounted) {
          setState(() {
            _hasActiveService = true;
            _activeServiceData = {
              'requestId': r['id'] as String?,
              'providerId': providerId,
              'issueTitle': title ?? 'Service Request',
              'vehicleBrand': null,
              'vehicleModel': null,
              'vehicleYear': null,
              'paymentMethod': r['payment_method'] ?? 'GCash',
              'amount': amountStr,
              'isActualPayment': ((r['payment_status']?.toString().toLowerCase()) == 'completed'),
              'serviceStatus': status.isNotEmpty ? status : 'in_progress',
              'mechanicPhone': mechanicPhone,
            };
          });
        }

        // Smoothly reveal the bottom sheet
        if (mounted && !_bottomSheetController.isCompleted) {
          _bottomSheetController.forward();
        }

        print('🧭 Active service loaded for bottom sheet: ${response['id']} ($status)');
      } else {
        print('ℹ️ No active service found for current user.');
      }
    } catch (e) {
      print('❌ Error auto-loading active service: $e');
    }
  }

  // Setup real-time invoice notifications
  Future<void> _setupInvoiceNotifications() async {
    try {
      final userId = SupabaseService.client.auth.currentUser?.id;
      if (userId == null) return;

      print('🔔 Setting up invoice notifications for user: $userId');

      // Listen for new invoices for this customer
      _invoiceSubscription = SupabaseService.client
          .from('invoices')
          .stream(primaryKey: ['id'])
          .eq('customer_id', userId)
          .listen((data) {
            if (data.isNotEmpty) {
              final latestInvoice = data.last;
              final invoiceStatus = latestInvoice['status']?.toString().toLowerCase();
              
              // Only show popup for newly sent invoices
              if (invoiceStatus == 'sent') {
                _showInvoicePopup(latestInvoice);
              }
            }
          });
    } catch (e) {
      print('❌ Error setting up invoice notifications: $e');
    }
  }

  // Show invoice popup when new invoice is received
  void _showInvoicePopup(Map<String, dynamic> invoiceData) {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false, // Force user to interact with invoice
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: EdgeInsets.zero,
        content: Container(
          width: double.maxFinite,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.blue[50]!, Colors.white],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blue[600],
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.receipt_long,
                        color: Colors.blue,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Invoice Received!',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Your mechanic has sent you an invoice',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Invoice details
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInvoiceDetailRow('Service Type', invoiceData['service_details']?['service_type'] ?? invoiceData['service_type'] ?? 'Vehicle Service'),
                    _buildInvoiceDetailRow('Description', invoiceData['service_details']?['description'] ?? invoiceData['description'] ?? 'Professional vehicle repair'),
                    _buildInvoiceDetailRow('Amount', '₱${invoiceData['total_amount']?.toStringAsFixed(2) ?? '0.00'}'),
                    const SizedBox(height: 20),
                    
                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              side: BorderSide(color: Colors.grey[400]!),
                            ),
                            child: const Text('View Later'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                              _navigateToInvoicePayment(invoiceData);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue[600],
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text(
                              'Pay Now',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper to build invoice detail rows
  Widget _buildInvoiceDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Navigate to invoice payment screen
  void _navigateToInvoicePayment(Map<String, dynamic> invoiceData) {
    // Navigate to your existing invoice payment screen
    setState(() {
      _currentIndex = 3; // Invoice tab
    });
    
    // Show success message
    _showTopNotification(
      'Opening invoice for payment...',
      backgroundColor: Colors.green,
    );
  }

  // Setup customer service monitoring for status changes (completed/cancelled)
  Future<void> _setupCustomerServiceMonitoring() async {
    try {
      final userId = SupabaseService.client.auth.currentUser?.id;
      if (userId == null) return;

      print('🔔 Setting up customer service monitoring for user: $userId');

      // Listen for service status changes for this customer
      _serviceRequestSubscription = SupabaseService.client
          .from('service_requests')
          .stream(primaryKey: ['id'])
          .eq('customer_id', userId)
          .listen((data) {
            if (data.isNotEmpty && mounted) {
              final serviceRequest = data.last; // Get the latest service request
              final serviceStatus = serviceRequest['status'] as String?;
              final requestId = serviceRequest['id'] as String?;
              
              print('📡 Customer service update received - Status: $serviceStatus, Request ID: $requestId');
              
              // Check if service is completed or cancelled
              if (serviceStatus != null && 
                  (serviceStatus.toLowerCase() == 'completed' || serviceStatus.toLowerCase() == 'cancelled')) {
                
                // Only process this if we have an active service for this request
                if (_hasActiveService && _activeServiceData != null && 
                    _activeServiceData!['requestId'] == requestId) {
                  print('🏁 Customer service $serviceStatus - Showing completion dialog');
                  
                  if (mounted) {
                    // Show completion/cancellation message
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(serviceStatus.toLowerCase() == 'completed' 
                          ? '✅ Your service has been completed successfully!' 
                          : '❌ Your service request has been cancelled'),
                        backgroundColor: serviceStatus.toLowerCase() == 'completed' 
                          ? Colors.green 
                          : Colors.orange,
                        duration: Duration(seconds: 3),
                      ),
                    );
                    
                    // For completed services, show rating dialog
                    // For cancelled services, just close after a delay
                    if (serviceStatus.toLowerCase() == 'completed') {
                      Future.delayed(Duration(milliseconds: 1500), () {
                        if (mounted && requestId != null) {
                          _showCompletionDialog(requestId);
                        } else if (mounted) {
                          _closeService();
                        }
                      });
                    } else {
                      // Cancelled - just close after delay
                      Future.delayed(Duration(milliseconds: 2000), () {
                        if (mounted) {
                          _closeService();
                        }
                      });
                    }
                  }
                }
              }
            }
          });
    } catch (e) {
      print('❌ Error setting up customer service monitoring: $e');
    }
  }

  @override
  void dispose() {
    _bottomSheetController.dispose();
    _invoiceSubscription?.cancel(); // Cancel invoice subscription
    _serviceRequestSubscription?.cancel(); // Cancel service monitoring subscription
    super.dispose();
  }

  // Show completion dialog with rating option
  Future<void> _showCompletionDialog(String requestId) async {
    try {
      // Get service request details
      final serviceRequest = await SupabaseService.getServiceRequestById(requestId);
      if (serviceRequest == null) {
        print('⚠️ Could not find service request for rating');
        _closeService();
        return;
      }

      final providerId = serviceRequest['provider_id'] as String?;
      final mechanicId = serviceRequest['assigned_mechanic_id'] as String?;
      final serviceTitle = serviceRequest['title'] as String? ?? serviceRequest['service_type'] as String? ?? 'Service Request';
      
      // Use mechanic_id if available, otherwise use provider_id
      final ratingTargetId = mechanicId ?? providerId;
      
      if (ratingTargetId == null) {
        print('⚠️ No mechanic or provider ID found for rating');
        _closeService();
        return;
      }

      // Check if user has already reviewed
      final hasReviewed = await UserDataService.hasUserReviewed(requestId);
      if (hasReviewed) {
        print('ℹ️ User has already reviewed this service');
        _closeService();
        return;
      }

      if (!mounted) return;

      // Show enhanced completion dialog with Close and Rate Mechanic buttons
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => WillPopScope(
          onWillPop: () async => false, // Prevent dismissing with back button
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green[700],
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    color: Colors.white,
                    size: 36,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Text(
                    'Job Completed!',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color.fromARGB(255, 27, 94, 32),
                    ),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your service has been completed successfully.',
                  style: TextStyle(
                    fontSize: 17,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green[200]!, width: 2),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.stars, color: Colors.green[700], size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Would you like to rate your mechanic?',
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.green[900],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Thank you for using RoadAid!',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
            actions: [
              OutlinedButton.icon(
                onPressed: () {
                  print('📱 Close button pressed - dismissing dialog');
                  Navigator.pop(context); // Close dialog
                  _closeService(); // Close service tracking
                },
                icon: const Icon(Icons.close, size: 20),
                label: const Text('Close', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.grey[700],
                  side: BorderSide(color: Colors.grey[400]!, width: 2),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  print('⭐ Rate Mechanic button pressed');
                  Navigator.pop(context); // Close completion dialog
                  
                  // Show rating dialog
                  await showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => ReviewDialog(
                      requestId: requestId,
                      providerId: ratingTargetId,
                      serviceTitle: serviceTitle,
                      onReviewSubmitted: () {
                        print('✅ Review submitted successfully');
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Thank you for your review!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      },
                    ),
                  );
                  
                  // Close service tracking after review
                  if (mounted) {
                    _closeService();
                  }
                },
                icon: const Icon(Icons.star_rate, size: 22),
                label: const Text('Rate Mechanic', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 176, 12, 1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
            actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          ),
        ),
      );
    } catch (e) {
      print('❌ Error showing completion dialog: $e');
      // Close service even on error
      if (mounted) {
        _closeService();
      }
    }
  }

  void _showPaymentResultBottomSheet() {
    if (_activeServiceData == null) return;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return CustomerPaymentResultBottomSheet(
          paymentData: _activeServiceData!,
          onClose: () {
            Navigator.of(context).pop();
            // After closing payment result, show regular service tracking
            if (mounted) {
              setState(() {
                _isShowingPaymentResult = false;
              });
            }
            // Refresh active service data to pick up any assignments or updates
            _loadActiveServiceIfAny().then((_) {
              // Then reveal the persistent bottom sheet
              if (mounted && !_bottomSheetController.isCompleted) {
                _bottomSheetController.forward();
              }
            });
          },
        );
      },
    );
  }

  void _toggleBottomSheet() {
    // Allow customers to minimize the bottom sheet but still track active service
    // The service tracking continues in the background
    if (_bottomSheetController.isCompleted) {
      _bottomSheetController.reverse();
      // Show reminder message when minimizing active service
      final serviceStatus = _activeServiceData?['serviceStatus']?.toString().toLowerCase();
      final activeStatuses = ['pending', 'awaiting_payment', 'paid', 'accepted', 'ready_to_assign', 'assigned', 'in_progress'];
      
      if (activeStatuses.contains(serviceStatus)) {
        _showTopNotification(
          'Service minimized. You cannot request new services until current one is completed.',
          backgroundColor: Colors.blue,
        );
      }
    } else {
      _bottomSheetController.forward();
    }
  }

  void _closeService() {
    setState(() {
      _hasActiveService = false;
      _activeServiceData = null;
    });
    _bottomSheetController.reverse();
  }

  // Helper method to check if customer has an active service
  bool _hasActiveServiceInProgress() {
    if (!_hasActiveService || _activeServiceData == null) return false;
    
    final serviceStatus = _activeServiceData?['serviceStatus']?.toString().toLowerCase();
    final activeStatuses = ['pending', 'awaiting_payment', 'paid', 'accepted', 'ready_to_assign', 'assigned', 'in_progress'];
    
    return activeStatuses.contains(serviceStatus);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Handle back button to prevent unwanted navigation
      canPop: _currentIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _currentIndex != 0) {
          setState(() {
            _currentIndex = 0;
          });
        }
      },
      child: Scaffold(
        drawer: const RoadAidDrawer(),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.black),
          title: const Text(
            'RoadAid',
            style: TextStyle(
              color: Color.fromARGB(255, 176, 12, 1),
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          actions: [
            GestureDetector(
              onTap: () {
                setState(() {
                  _currentIndex = 4; // Profile index (matches _pages list)
                });
              },
              child: Container(
                margin: const EdgeInsets.only(right: 16),
                child: const CircleAvatar(
                  backgroundColor: Color.fromARGB(255, 176, 12, 1),
                  radius: 16,
                  child: Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ),
          ],
        ),
        body: Stack(
          children: [
            // Main content
            IndexedStack(
              index: _currentIndex,
              children: _pages,
            ),
            
            // Persistent bottom sheet overlay (ONLY show in Home tab - index 0)
            if (_currentIndex == 0 && _hasActiveService && _activeServiceData != null && !_isShowingPaymentResult && _activeServiceData!['serviceStatus']?.toString().toLowerCase() != 'completed')
              _buildPersistentBottomSheet(),
              
            // Floating action button to show/hide service info (ONLY show in Home tab - index 0)
            if (_currentIndex == 0 && _hasActiveService && _activeServiceData != null && !_isShowingPaymentResult && _activeServiceData!['serviceStatus']?.toString().toLowerCase() != 'completed')
              _buildServiceToggleButton(),
          ],
        ),
        bottomNavigationBar: RoadAidBottomNavBar(
          currentIndex: _currentIndex,
          isRequestDisabled: _hasActiveServiceInProgress(),
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
        ),
      ),
    );
  }

  Widget _buildServiceToggleButton() {
    return Positioned(
      right: 16,
      bottom: 100, // Position above bottom navigation
      child: AnimatedBuilder(
        animation: _bottomSheetAnimation,
        builder: (context, child) {
          // Only show toggle button when bottom sheet is minimized
          return _bottomSheetAnimation.value < 0.5
              ? FloatingActionButton(
                  heroTag: "service_toggle_button", // Add unique hero tag
                  onPressed: () {
                    final serviceStatus = _activeServiceData?['serviceStatus']?.toString().toLowerCase();
                    final activeStatuses = ['pending', 'awaiting_payment', 'paid', 'accepted', 'ready_to_assign', 'assigned', 'in_progress'];
                    
                    if (activeStatuses.contains(serviceStatus)) {
                      // Allow expanding but show appropriate message
                      _toggleBottomSheet();
                      
                      String statusMessage = '';
                      switch (serviceStatus) {
                        case 'pending':
                          statusMessage = 'Service request is pending approval';
                          break;
                        case 'awaiting_payment':
                          statusMessage = 'Service is awaiting payment completion';
                          break;
                        case 'paid':
                          statusMessage = 'Service has been paid, waiting for mechanic';
                          break;
                        case 'accepted':
                          statusMessage = 'Service has been accepted by shop';
                          break;
                        case 'assigned':
                          statusMessage = 'Service has been assigned to mechanic';
                          break;
                        case 'in_progress':
                          statusMessage = 'Service is currently in progress';
                          break;
                      }
                      
                      if (statusMessage.isNotEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(statusMessage),
                            backgroundColor: Colors.blue,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    } else {
                      _toggleBottomSheet();
                    }
                  },
                  backgroundColor: const Color.fromARGB(255, 176, 12, 1),
                  child: const Icon(
                    Icons.info_outline,
                    color: Colors.white,
                  ),
                )
              : const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildPersistentBottomSheet() {
    return AnimatedBuilder(
      animation: _bottomSheetAnimation,
      builder: (context, child) {
        final double sheetHeight = MediaQuery.of(context).size.height * 0.7;
        final double minHeight = 80; // Minimized height showing just a bar
        
        final double currentHeight = minHeight + 
            (sheetHeight - minHeight) * _bottomSheetAnimation.value;
        
        return Positioned(
          left: 0,
          right: 0,
          bottom: 0,          child: GestureDetector(
            onTap: _bottomSheetAnimation.value < 0.5 ? _toggleBottomSheet : null,
            onPanUpdate: (details) {
              // Check if service is active - prevent drag-to-close for all active statuses
              final serviceStatus = _activeServiceData?['serviceStatus']?.toString().toLowerCase();
              final activeStatuses = ['pending', 'awaiting_payment', 'paid', 'accepted', 'ready_to_assign', 'assigned', 'in_progress'];
              
              if (activeStatuses.contains(serviceStatus)) {
                return; // Prevent drag handling during active service
              }
              
              // Handle drag to resize
              final double delta = details.delta.dy;
              final double newValue = _bottomSheetAnimation.value - 
                  (delta / (sheetHeight - minHeight));
              _bottomSheetController.value = newValue.clamp(0.0, 1.0);
            },
            onPanEnd: (details) {
              // Check if service is active - prevent snap-to-close for all active statuses
              final serviceStatus = _activeServiceData?['serviceStatus']?.toString().toLowerCase();
              final activeStatuses = ['pending', 'awaiting_payment', 'paid', 'accepted', 'ready_to_assign', 'assigned', 'in_progress'];
              
              if (activeStatuses.contains(serviceStatus)) {
                // Force back to expanded if trying to close during active service
                _bottomSheetController.forward();
                return;
              }
              
              // Snap to expanded or collapsed based on velocity and position
              if (details.velocity.pixelsPerSecond.dy > 300 || 
                  _bottomSheetAnimation.value < 0.3) {
                _bottomSheetController.reverse();
              } else {
                _bottomSheetController.forward();
              }
            },
            child: Container(
              height: currentHeight,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    spreadRadius: 0,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: _bottomSheetAnimation.value < 0.3
                  ? _buildMinimizedServiceBar()
                  : _buildExpandedServiceSheet(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMinimizedServiceBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Service status indicator
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withOpacity(0.3),
                  blurRadius: 6,
                  spreadRadius: 0,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          
          // Service info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Service Request Active',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  _activeServiceData!['issueTitle'] ?? 'Service Request',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          
          // Action buttons
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: () async {
                  // Direct call to mechanic
                  final mechanicPhone = _activeServiceData?['mechanicPhone'] as String? ?? '';
                  if (mechanicPhone.isNotEmpty) {
                    // Clean the phone number (remove spaces, dashes, etc.)
                    final cleanPhone = mechanicPhone.replaceAll(RegExp(r'[^\d+]'), '');
                    
                    print('🔥 Attempting to call: $cleanPhone');
                    print('🔥 Original phone: $mechanicPhone');
                    
                    try {
                      // Try multiple URI formats for better compatibility
                      bool launched = false;
                      
                      // Strategy 1: Try direct tel: URIs with different formats
                      final telUris = [
                        'tel:$cleanPhone',
                        'tel:+63${cleanPhone.startsWith('0') ? cleanPhone.substring(1) : cleanPhone}',
                        'tel://$cleanPhone',
                        // Try without cleaning to see if original format works
                        'tel:$mechanicPhone',
                      ];
                      
                      for (final telUri in telUris) {
                        print('🔥 Trying call URI: $telUri');
                        try {
                          final uri = Uri.parse(telUri);
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                            launched = true;
                            print('✅ Phone call launched successfully with: $uri');
                            break;
                          }
                        } catch (e) {
                          print('❌ Failed with call URI: $telUri - Error: $e');
                        }
                      }
                      
                      // Strategy 1.5: Try Android intent approach
                      if (!launched && Platform.isAndroid) {
                        print('🤖 Trying Android intent approach...');
                        try {
                          // Try dialer intent instead of call intent (works on emulators)
                          final intentUri = Uri.parse('intent://tel:$cleanPhone#Intent;scheme=tel;action=android.intent.action.DIAL;end');
                          await launchUrl(intentUri, mode: LaunchMode.externalApplication);
                          launched = true;
                          print('✅ Android dialer intent launched successfully');
                        } catch (e) {
                          print('❌ Android intent failed: $e');
                          // Try simpler dialer approach
                          try {
                            final dialUri = Uri.parse('tel:$cleanPhone');
                            await launchUrl(dialUri, mode: LaunchMode.platformDefault);
                            launched = true;
                            print('✅ Simple dialer launched successfully');
                          } catch (e2) {
                            print('❌ Simple dialer also failed: $e2');
                          }
                        }
                      }
                      
                      // Strategy 2: Try dialer intent (Android specific fallback)
                      if (!launched) {
                        print('🔥 Trying Android dialer intent...');
                        for (final phone in [cleanPhone, '+63${cleanPhone.startsWith('0') ? cleanPhone.substring(1) : cleanPhone}']) {
                          try {
                            final dialUri = Uri.parse('tel:$phone');
                            await launchUrl(dialUri, mode: LaunchMode.platformDefault);
                            launched = true;
                            print('✅ Dialer opened successfully with: $dialUri');
                            break;
                          } catch (e) {
                            print('❌ Failed with dialer: tel:$phone - Error: $e');
                          }
                        }
                      }
                      
                      // Strategy 3: Try with system mode
                      if (!launched) {
                        print('🔥 Trying system mode...');
                        try {
                          final systemUri = Uri.parse('tel:$cleanPhone');
                          await launchUrl(systemUri, mode: LaunchMode.inAppBrowserView);
                          launched = true;
                          print('✅ System call launched successfully');
                        } catch (e) {
                          print('❌ Failed with system mode: $e');
                        }
                      }
                      
                      if (!launched) {
                        print('❌ All URI formats failed');
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Unable to make phone call to $cleanPhone.\n\nPlease dial manually:\n$mechanicPhone'),
                              backgroundColor: Colors.red,
                              duration: const Duration(seconds: 6),
                              action: SnackBarAction(
                                label: 'OK',
                                textColor: Colors.white,
                                onPressed: () {},
                              ),
                            ),
                          );
                        }
                      }
                    } catch (e) {
                      print('❌ Phone call error: $e');
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error making phone call: $e\n\nPlease dial manually:\n$mechanicPhone'),
                            backgroundColor: Colors.red,
                            duration: const Duration(seconds: 6),
                          ),
                        );
                      }
                    }
                  } else {
                    print('❌ No phone number available');
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Mechanic phone number not available'),
                          backgroundColor: Colors.orange,
                          duration: Duration(seconds: 3),
                        ),
                      );
                    }
                  }
                },
                icon: const Icon(
                  Icons.phone,
                  color: Color.fromARGB(255, 176, 12, 1),
                  size: 20,
                ),
              ),
              IconButton(
                onPressed: _toggleBottomSheet,
                icon: const Icon(
                  Icons.keyboard_arrow_up,
                  color: Colors.grey,
                  size: 20,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedServiceSheet() {
    return Column(
      children: [
        // Header / handle bar
        Container(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                (_activeServiceData!['isActualPayment'] == true)
                    ? 'Service in Progress'
                    : 'Service Request Confirmed',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    onPressed: _toggleBottomSheet,
                    icon: const Icon(Icons.keyboard_arrow_down),
                  ),
                  IconButton(
                    onPressed: () {
                      // Check if service is active - prevent close for all active statuses
                      final serviceStatus = _activeServiceData?['serviceStatus']?.toString().toLowerCase();
                      final activeStatuses = ['pending', 'awaiting_payment', 'paid', 'accepted', 'ready_to_assign', 'assigned', 'in_progress'];

                      if (activeStatuses.contains(serviceStatus)) {
                        String statusMessage = '';
                        switch (serviceStatus) {
                          case 'pending':
                            statusMessage = 'Cannot close service details while request is pending';
                            break;
                          case 'awaiting_payment':
                            statusMessage = 'Cannot close service details while awaiting payment';
                            break;
                          case 'paid':
                            statusMessage = 'Cannot close service details after payment is made';
                            break;
                          case 'accepted':
                            statusMessage = 'Cannot close service details while service is accepted';
                            break;
                          case 'assigned':
                            statusMessage = 'Cannot close service details while mechanic is assigned';
                            break;
                          case 'in_progress':
                            statusMessage = 'Cannot close service details while service is in progress';
                            break;
                        }

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(statusMessage),
                            backgroundColor: Colors.orange,
                            duration: const Duration(seconds: 3),
                          ),
                        );
                        return;
                      }
                      _showCloseServiceDialog();
                    },
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        // Content
        Expanded(
          child: ServiceDetailsBottomSheet(
            // Avoid passing 'N/A' which causes invalid UUID errors
            requestId: (_activeServiceData!['requestId'] is String)
                ? (_activeServiceData!['requestId'] as String)
                : '',
            providerId: _activeServiceData!['providerId'], // Add this
            issueTitle: _activeServiceData!['issueTitle'],
            vehicleBrand: _activeServiceData!['vehicleBrand'],
            vehicleModel: _activeServiceData!['vehicleModel'],
            vehicleYear: _activeServiceData!['vehicleYear'],
            paymentMethod: _activeServiceData!['paymentMethod'] ?? 'N/A',
            amount: _activeServiceData!['amount'] ?? '₱0.00',
            isActualPayment: _activeServiceData!['isActualPayment'] ?? false,
            serviceStatus: _activeServiceData!['serviceStatus'] ?? 'in_progress', // Add this
            onContactMechanic: _showContactOptions,
            onCancelService: () => _showCloseServiceDialog(),
            currentTabIndex: _currentIndex, // Pass current tab index
          ),
        ),
      ],
    );
  }
  void _showContactOptions() {
    // Check if service is active - prevent dismissal for all active statuses
    final serviceStatus = _activeServiceData?['serviceStatus']?.toString().toLowerCase();
    final activeStatuses = ['pending', 'awaiting_payment', 'paid', 'accepted', 'ready_to_assign', 'assigned', 'in_progress'];
    final bool isServiceActive = activeStatuses.contains(serviceStatus);
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: !isServiceActive, // Prevent dismissal when service is active
      enableDrag: !isServiceActive, // Prevent drag dismissal when service is active
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isServiceActive) ...[
              // Show status indicator for active services
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 50,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.orange[700],
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Service is ${serviceStatus?.replaceAll('_', ' ')} - Contact options available',
                        style: TextStyle(
                          color: Colors.orange[700],
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              const SizedBox(height: 20),
            ],
            const Text(
              'Contact Options',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.phone, color: Colors.green),
              title: const Text('Call Mechanic'),
              subtitle: const Text('+63 912 345 6789'),
              onTap: () async {
                Navigator.pop(context);
                // Implement call functionality using url_launcher
                final phoneNumber = '+639123456789';
                final uri = Uri(scheme: 'tel', path: phoneNumber);
                
                try {
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri);
                  } else {
                    // Fallback: show error message
                    if (mounted) {
                      _showTopNotification(
                        'Unable to make phone call. Please check your device settings.',
                        backgroundColor: Colors.red,
                      );
                    }
                  }
                } catch (e) {
                  // Handle any errors
                  if (mounted) {
                    _showTopNotification(
                      'Error making phone call: $e',
                      backgroundColor: Colors.red,
                    );
                  }
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.message, color: Colors.blue),
              title: const Text('Send Message'),
              subtitle: const Text('Chat with your assigned mechanic'),
              onTap: () {
                Navigator.pop(context);
                // Navigate to messages
                if (mounted) {
                  setState(() {
                    _currentIndex = 5; // Updated index for messages
                  });
                }
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
  void _showCloseServiceDialog() {
    final serviceStatus = _activeServiceData?['serviceStatus']?.toString().toLowerCase();
    final activeStatuses = ['pending', 'awaiting_payment', 'paid', 'accepted', 'ready_to_assign', 'assigned', 'in_progress'];
    
    // Different dialog content based on service status
    String title = 'Cancel Service';
    String content = 'Are you sure you want to cancel this service? This action cannot be undone.';
    
    if (activeStatuses.contains(serviceStatus)) {
      switch (serviceStatus) {
        case 'pending':
          title = 'Service Request Pending';
          content = 'This service request is pending approval. You cannot cancel a pending request as it may already be processed by the shop. Please wait for shop response or contact the shop directly.';
          break;
        case 'awaiting_payment':
          title = 'Payment Required';
          content = 'This service is awaiting payment completion. You cannot cancel at this stage as the service has been confirmed. Please complete the payment or contact the shop for assistance.';
          break;
        case 'paid':
          title = 'Service Paid';
          content = 'This service has been paid for and is waiting for mechanic assignment. You cannot cancel a paid service. Please contact the shop for refund or service modification.';
          break;
        case 'accepted':
          title = 'Service Accepted';
          content = 'This service has been accepted by the shop. You cannot cancel an accepted service as resources have been allocated. Please contact the shop directly.';
          break;
        case 'assigned':
          title = 'Mechanic Assigned';
          content = 'A mechanic has been assigned to your service. You cannot cancel at this stage as the mechanic is preparing to assist you. Please contact the shop or mechanic directly.';
          break;
        case 'in_progress':
          title = 'Service In Progress';
          content = 'This service is currently being performed by the mechanic. You cannot cancel a service that is already in progress. Please wait for the mechanic to complete the service.';
          break;
      }
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: activeStatuses.contains(serviceStatus)
            ? [
                // For active services, only show "OK" button
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ]
            : [
                // For completed/cancelled services, show cancel option
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Keep Service'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context); // Close dialog
                    
                    // Show loading overlay
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => const AlertDialog(
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text('Cancelling service...'),
                          ],
                        ),
                      ),
                    );
                    
                    try {
                      // Cancel the service request
                      final requestId = _activeServiceData?['requestId'];
                      if (requestId != null) {
                        await UserDataService.cancelServiceRequest(requestId);
                        
                        // Close loading dialog
                        Navigator.pop(context);
                        
                        // Close the service and show success
                        _closeService();
                        
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Service cancelled successfully'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } else {
                        // Close loading dialog
                        Navigator.pop(context);
                        
                        // Just close the service if no request ID
                        _closeService();
                      }
                    } catch (e) {
                      // Close loading dialog
                      Navigator.pop(context);
                      
                      // Show error message
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error cancelling service: ${e.toString()}'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                  ),
                  child: const Text(
                    'Cancel Service',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
      ),
    );
  }

  // Helper method to show top banner notification
  void _showTopNotification(String message, {Color? backgroundColor}) {
    // Hide any existing banner first
    ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
    
    ScaffoldMessenger.of(context).showMaterialBanner(
      MaterialBanner(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: backgroundColor ?? Colors.blue,
        actions: [
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
            },
            child: const Text(
              'OK',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
    
    // Auto-hide the banner after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
      }
    });
  }
}

// ServiceDetailsBottomSheet class for displaying service details with real-time location tracking
class ServiceDetailsBottomSheet extends StatefulWidget {
  final String requestId;
  final String? providerId;
  final String? issueTitle;
  final String? vehicleBrand;
  final String? vehicleModel;
  final String? vehicleYear;
  final String? paymentMethod;
  final String? amount;
  final bool? isActualPayment;
  final String? serviceStatus;
  final VoidCallback onContactMechanic;
  final VoidCallback onCancelService;
  final int currentTabIndex; // Add current tab index to control history button

  const ServiceDetailsBottomSheet({
    Key? key,
    required this.requestId,
    this.providerId,
    this.issueTitle,
    this.vehicleBrand,
    this.vehicleModel,
    this.vehicleYear,
    this.paymentMethod,
    this.amount,
    this.isActualPayment,
    this.serviceStatus,
    required this.onContactMechanic,
    required this.onCancelService,
    this.currentTabIndex = 0, // Default to home tab
  }) : super(key: key);

  @override
  State<ServiceDetailsBottomSheet> createState() => _ServiceDetailsBottomSheetState();
}

class _ServiceDetailsBottomSheetState extends State<ServiceDetailsBottomSheet> {
  // Real-time location tracking state
  Timer? _locationUpdateTimer;
  StreamSubscription? _mechanicLocationSubscription;
  StreamSubscription? _serviceRequestSubscription; // Add service request real-time listener
  LatLng? _customerPickupLocation;
  String _customerPickupAddress = 'Loading...';
  
  // Map and location state
  LatLng? _currentLocation;
  LatLng? _mechanicLocation;
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  // Polyline drawing debounce and state
  Timer? _routeDrawDebounce;
  bool _routeDrawInProgress = false;
  bool _pendingRouteDraw = false;
  
  // Mechanic info state
  String? _assignedMechanicUserId; // auth.users.id / user_profiles.id
  String? _mechanicName;
  // Track if we're showing provider fallback instead of an assigned mechanic
  bool _isProviderFallback = false;
  String? _mechanicPhone;
  String? _mechanicProfileImage;
  bool _mechanicLoading = true;
  String? _distanceToMechanic;
  String? _durationToMechanic;
    // UI state
  bool _checkingReview = true;
  bool _hasReviewed = false;

  // Map type
  MapType _currentMapType = MapType.normal;

  @override
  void initState() {
    super.initState();
    _initializeLocationTracking();
  }

  @override
  void dispose() {
    _locationUpdateTimer?.cancel();
    _mechanicLocationSubscription?.cancel();
    _serviceRequestSubscription?.cancel(); // Cancel service request listener
    super.dispose();
  }

  // Initialize location tracking system
  Future<void> _initializeLocationTracking() async {
  await _loadCustomerPickupLocation();
  await _getCurrentLocation();
  await _loadMechanicInfo(); // Load mechanic profile info
    _startRealTimeLocationTracking();
    _startServiceRequestListener(); // Add real-time service request listener
    await _checkReviewStatus();
  }

  // Load mechanic profile information
  Future<void> _loadMechanicInfo() async {
    try {
      if (widget.requestId.isEmpty) {
        if (mounted) {
          setState(() { _mechanicLoading = false; });
        }
        return;
      }
      
      print('🔍 Loading mechanic info for request: ${widget.requestId}');
      
      // First, fetch the service_request to check for an assigned mechanic
      final request = await SupabaseService.getServiceRequestById(widget.requestId);

      String? assignedMechanicId = request != null ? request['assigned_mechanic_id'] as String? : null;
      String? providerId = widget.providerId ?? (request != null ? request['provider_id'] as String? : null);

      print('🔍 Request data - Assigned Mechanic: $assignedMechanicId, Provider: $providerId');

      if (assignedMechanicId != null) {
        // Preferred: load the assigned mechanic's profile (user_profiles = auth.users)
        print('👤 Loading assigned mechanic by user_profiles.id: $assignedMechanicId');
        final mechProfile = await SupabaseService.client
            .from('user_profiles')
            .select('id, first_name, last_name, phone_number, profile_image_url, current_latitude, current_longitude')
            .eq('id', assignedMechanicId)
            .maybeSingle();

        print('🔍 Mechanic profile response: $mechProfile');

        if (mechProfile != null) {
          final lat = mechProfile['current_latitude'];
          final lng = mechProfile['current_longitude'];
          
          print('🔍 Mechanic location data - Lat: $lat, Lng: $lng');
          
          if (mounted) {
            setState(() {
              _assignedMechanicUserId = mechProfile['id'] as String?;
              _mechanicName = '${(mechProfile['first_name'] ?? '')} ${(mechProfile['last_name'] ?? '')}'.trim().isNotEmpty
                  ? '${(mechProfile['first_name'] ?? '')} ${(mechProfile['last_name'] ?? '')}'.trim()
                  : 'Mechanic';
              _mechanicPhone = mechProfile['phone_number'] as String? ?? '';
              _mechanicProfileImage = mechProfile['profile_image_url'] as String?;
              _isProviderFallback = false;

              if (lat != null && lng != null) {
                _mechanicLocation = LatLng(double.parse(lat.toString()), double.parse(lng.toString()));
                print('✅ Mechanic location set: $_mechanicLocation');
              } else {
                print('⚠️ Mechanic location not available in profile');
              }
              _mechanicLoading = false;
            });
          }

          print('✅ Assigned mechanic loaded: $_mechanicName, Phone: $_mechanicPhone');

          await _updateMarkers();
          await _updateDistanceAndDuration();
          // Schedule route draw now that mechanic info and markers are loaded
          _scheduleRouteDraw();
          return; // We're done
        } else {
          print('⚠️ Mechanic profile not found for ID: $assignedMechanicId');
        }
      }

      // Fallback: load provider's user profile (shop owner/provider account)
  if (providerId != null) {
        print('👤 Loading mechanic via provider fallback: $providerId');
        final mechanicResponse = await SupabaseService.client
            .from('service_providers')
            .select('''
              *,
              user_profiles!service_providers_user_id_fkey (
                id,
                first_name,
                last_name,
                phone_number,
                profile_image_url,
                current_latitude,
                current_longitude
              )
            ''')
            .eq('id', providerId)
            .maybeSingle();

      if (mechanicResponse != null && mounted) {
          final userProfile = mechanicResponse['user_profiles'];
          setState(() {
            _assignedMechanicUserId = userProfile?['id'] as String?;
            _mechanicName = userProfile != null 
                ? '${userProfile['first_name'] ?? ''} ${userProfile['last_name'] ?? ''}'.trim()
                : 'Mechanic';
            _mechanicPhone = userProfile?['phone_number'] ?? '';
            _mechanicProfileImage = userProfile?['profile_image_url'];
            _isProviderFallback = true; // This is a provider contact, not yet assigned mechanic

            final lat = userProfile?['current_latitude'];
            final lng = userProfile?['current_longitude'];
            if (lat != null && lng != null) {
              _mechanicLocation = LatLng(double.parse(lat.toString()), double.parse(lng.toString()));
            }
            _mechanicLoading = false;
          });

          print('✅ Provider user loaded as fallback: $_mechanicName, Phone: $_mechanicPhone');
          await _updateMarkers();
          await _updateDistanceAndDuration();
          // Schedule route draw after provider fallback mechanic info is set
          _scheduleRouteDraw();
        } else {
          if (mounted) {
            setState(() {
              _mechanicLoading = false;
            });
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _mechanicLoading = false;
          });
        }
      }
    } catch (e) {
      print('❌ Error loading mechanic info: $e');
      if (mounted) {
        setState(() {
          _mechanicLoading = false;
        });
      }
    }
  }

  // Start real-time service request listener to detect mechanic assignment
  void _startServiceRequestListener() {
    if (widget.requestId.isEmpty) return;
    
    try {
      print('🔄 Starting real-time service request listener for request: ${widget.requestId}');
      
      _serviceRequestSubscription = SupabaseService.client
          .from('service_requests')
          .stream(primaryKey: ['id'])
          .eq('id', widget.requestId)
          .listen((data) {
            if (data.isNotEmpty && mounted) {
              final serviceRequest = data.first;
              final currentAssignedMechanic = serviceRequest['assigned_mechanic_id'] as String?;
              final serviceStatus = serviceRequest['status'] as String?;
              
              print('📡 Service request update received - Assigned Mechanic: $currentAssignedMechanic, Status: $serviceStatus');
              
              // Check if service is cancelled only - auto-close bottom sheet
              // For completed status, let the bottom sheet widget handle the completion dialog
              if (serviceStatus != null && serviceStatus.toLowerCase() == 'cancelled') {
                print('🏁 Service $serviceStatus - Closing bottom sheet automatically');
                
                if (mounted) {
                  // Show cancellation message
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('❌ Service has been cancelled'),
                      backgroundColor: Colors.orange,
                      duration: Duration(seconds: 4),
                    ),
                  );
                  
                  // Close the bottom sheet after a brief delay
                  Future.delayed(Duration(milliseconds: 1500), () {
                    if (mounted) {
                      Navigator.of(context).pop();
                    }
                  });
                }
                return; // Exit early since service is finished
              }
              
              // For completed status, the bottom sheet will show completion dialog with review option
              if (serviceStatus != null && serviceStatus.toLowerCase() == 'completed') {
                print('✅ Service completed - bottom sheet will handle completion dialog');
                // Don't close automatically - let the bottom sheet's _showJobCompletionDialog handle it
              }
              
              // Check if a mechanic was just assigned (and we don't have one yet)
              if (currentAssignedMechanic != null && 
                  _assignedMechanicUserId != currentAssignedMechanic) {
                print('🎉 New mechanic assigned! Reloading mechanic info...');
                _loadMechanicInfo(); // Reload mechanic information
                
                // Show success notification
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('🔧 Mechanic assigned! Your service is ready.'),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 3),
                  ),
                );
              }
            }
          });
    } catch (e) {
      print('❌ Error setting up service request listener: $e');
    }
  }

  // Load customer pickup location for the request
  Future<void> _loadCustomerPickupLocation() async {
    try {
  if (widget.requestId.isEmpty) return;
  final serviceRequest = await SupabaseService.getServiceRequestById(widget.requestId);
      
      if (serviceRequest != null) {
        final pickupLat = serviceRequest['pickup_latitude'];
        final pickupLng = serviceRequest['pickup_longitude']; 
        final pickupAddress = serviceRequest['pickup_address'];
        
        if (pickupLat != null && pickupLng != null) {
          if (mounted) {
            setState(() {
              _customerPickupLocation = LatLng(
                double.parse(pickupLat.toString()),
                double.parse(pickupLng.toString()),
              );
              _customerPickupAddress = pickupAddress ?? 'Pickup Location';
            });
          }
          print('📍 Customer pickup location loaded: $_customerPickupLocation');
          await _updateMarkers(); // Update map markers
        }
      }
    } catch (e) {
      print('❌ Error loading customer pickup location: $e');
    }
  }

  // Start real-time location tracking
  void _startRealTimeLocationTracking() {
    print('🚀 Starting real-time location tracking...');
    
    // Periodic updates every 10 seconds
    _locationUpdateTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _updateMechanicLocationFromDatabase();
    });
    
    // Real-time updates via Supabase subscriptions
    _listenToMechanicLocationUpdates();
  }

  // Update mechanic location from database
  Future<void> _updateMechanicLocationFromDatabase() async {
    try {
  if (widget.requestId.isEmpty) return;
  final mechanicData = await SupabaseService.getMechanicLocationForRequest(widget.requestId);
      
      if (mechanicData == null) {
        print('⚠️ No mechanicData returned for request ${widget.requestId}');
      } else {
        print('ℹ️ mechanicData lookup result: $mechanicData');
      }

      if (mechanicData != null) {
        final lat = mechanicData['latitude'];
        final lng = mechanicData['longitude'];
        
        if (lat == null || lng == null) {
          print('⚠️ mechanicData missing lat/lng: $mechanicData');
        }
        if (lat != null && lng != null) {
          final newLocation = LatLng(double.parse(lat.toString()), double.parse(lng.toString()));
          
          // Only update if location has changed significantly (> 10m)
          if (_mechanicLocation == null ||
              _calculateDistanceBetweenPoints(_mechanicLocation!, newLocation) > 0.01) {
            if (mounted) {
              setState(() {
                _mechanicLocation = newLocation;
                _mechanicName = mechanicData['name'];
                _mechanicPhone = mechanicData['phone_number'];
                _mechanicProfileImage = mechanicData['profile_image_url'];
                _mechanicLoading = false;
              });
            }
            
            print('🚗 Mechanic location updated: $_mechanicLocation');
            await _updateMarkers();
            await _updateDistanceAndDuration();
              // Schedule polyline draw (debounced & guarded)
              _scheduleRouteDraw();
          }
        }
      }
    } catch (e) {
      print('❌ Error updating mechanic location: $e');
    }
  }

  // Listen to real-time mechanic location updates
  void _listenToMechanicLocationUpdates() {
    
    try {
      print('🎯 Setting up real-time location tracking...');
      print('🎯 Assigned Mechanic User ID: $_assignedMechanicUserId');
      print('🎯 Provider ID: ${widget.providerId}');
      // Cancel any existing subscription before creating a new one
      _mechanicLocationSubscription?.cancel();

      // Prefer subscribing to the mechanic_locations table where mechanics upsert live tracking rows
      final table = 'mechanic_locations';

      // Helper to subscribe to user_locations as a fallback
      void _subscribeToUserLocations() {
        try {
          final fallbackTable = 'user_locations';
          print('ℹ️ Attempting fallback subscription to $fallbackTable');
          _mechanicLocationSubscription?.cancel();

          if (_assignedMechanicUserId != null && _assignedMechanicUserId!.isNotEmpty) {
            _mechanicLocationSubscription = SupabaseService.client
                .from(fallbackTable)
                .stream(primaryKey: ['user_id'])
                .eq('user_id', _assignedMechanicUserId!)
                .listen((data) {
              print('📡 Received user_locations update (by user_id): ${data.length} records');
              final typedData = data.map((item) => Map<String, dynamic>.from(item as Map)).toList();
              _processMechanicLocationUpdate(typedData);
            }, onError: (err) {
              print('❌ user_locations realtime error: $err');
            });
            return;
          }

          if (widget.providerId != null && widget.providerId!.isNotEmpty) {
            _mechanicLocationSubscription = SupabaseService.client
                .from(fallbackTable)
                .stream(primaryKey: ['user_id'])
                .eq('user_id', widget.providerId!)
                .listen((data) {
              print('📡 Received user_locations update (by providerId): ${data.length} records');
              final typedData = data.map((item) => Map<String, dynamic>.from(item as Map)).toList();
              _processMechanicLocationUpdate(typedData);
            }, onError: (err) {
              print('❌ user_locations realtime error: $err');
            });
            return;
          }

          print('⚠️ No assigned mechanic or provider ID to subscribe by — skipping user_locations realtime subscription');
        } catch (e) {
          print('❌ Fallback subscription to user_locations failed: $e');
        }
      }

      // Try subscribing to mechanic_locations first; if it fails, fall back to user_locations
      try {
        if (_assignedMechanicUserId != null && _assignedMechanicUserId!.isNotEmpty) {
          _mechanicLocationSubscription = SupabaseService.client
              .from(table)
              .stream(primaryKey: ['id'])
              .eq('user_id', _assignedMechanicUserId!)
              .listen((data) {
            print('📡 Received mechanic_locations update (by user_id): ${data.length} records');
            final typedData = data.map((item) => Map<String, dynamic>.from(item as Map)).toList();
            _processMechanicLocationUpdate(typedData);
          }, onError: (err) {
            print('❌ mechanic_locations realtime error: $err');
            // Attempt fallback
            _subscribeToUserLocations();
          });
        } else if (widget.providerId != null && widget.providerId!.isNotEmpty) {
          _mechanicLocationSubscription = SupabaseService.client
              .from(table)
              .stream(primaryKey: ['id'])
              .eq('user_id', widget.providerId!)
              .listen((data) {
            print('📡 Received mechanic_locations update (by providerId): ${data.length} records');
            final typedData = data.map((item) => Map<String, dynamic>.from(item as Map)).toList();
            _processMechanicLocationUpdate(typedData);
          }, onError: (err) {
            print('❌ mechanic_locations realtime error: $err');
            // Attempt fallback
            _subscribeToUserLocations();
          });
        } else {
          print('⚠️ No assigned mechanic or provider ID to subscribe by — skipping mechanic_locations realtime subscription');
        }
      } catch (e) {
        print('❌ Subscription to $table failed: $e');
        // Fallback to user_locations
        _subscribeToUserLocations();
      }
    } catch (e) {
      print('❌ Error setting up real-time location listener: $e');
    }
  }

  // Process real-time location updates
  void _processMechanicLocationUpdate(List<Map<String, dynamic>> data) async {
    if (widget.providerId == null && _assignedMechanicUserId == null) {
      print('⚠️ No provider ID or assigned mechanic ID available');
      return;
    }
    
    try {
      // Find location update for our specific mechanic
      for (final locationData in data) {
        // Get the mechanic's user_id from location data
        final userId = locationData['user_id'];
        
        print('📍 Processing location for user: $userId');
        
        // Check if this location update is for our assigned mechanic
        if (_isMechanicLocationUpdate(userId, locationData)) {
          final latRaw = locationData['latitude'];
          final lngRaw = locationData['longitude'];

          // Parse coordinates robustly (accept num or string)
          double? lat;
          double? lng;
          try {
            if (latRaw is num) lat = latRaw.toDouble();
            else if (latRaw is String) lat = double.tryParse(latRaw);
          } catch (_) { lat = null; }
          try {
            if (lngRaw is num) lng = lngRaw.toDouble();
            else if (lngRaw is String) lng = double.tryParse(lngRaw);
          } catch (_) { lng = null; }

          print('📍 Found matching mechanic location - rawLat: $latRaw, rawLng: $lngRaw -> parsedLat: $lat, parsedLng: $lng');

          if (lat != null && lng != null) {
            final newLocation = LatLng(lat, lng);
            
            // Only update if location has changed significantly (> 10m)
            if (_mechanicLocation == null ||
                _calculateDistanceBetweenPoints(_mechanicLocation!, newLocation) > 0.01) {
              if (mounted) {
                setState(() {
                  _mechanicLocation = newLocation;
                });
              }
              
              await _updateMarkers();
              await _updateDistanceAndDuration();
              
              // Schedule polyline draw (debounced & guarded)
              _scheduleRouteDraw();
              
              print('🚗 Real-time mechanic location updated: $_mechanicLocation');
              print('🗺️ Polyline automatically refreshed with new mechanic position');
            } else {
              print('📍 Mechanic location unchanged (small movement)');
            }
          }
        } else {
          print('📍 Location update not for our mechanic (user: $userId)');
        }
      }
    } catch (e) {
      print('❌ Error processing real-time location update: $e');
    }
  }

  // Check if location update is for our assigned mechanic
  bool _isMechanicLocationUpdate(String? userId, Map<String, dynamic> locationData) {
    if (userId == null) {
      print('🔍 Location update has no user_id');
      return false;
    }
    
    print('🔍 Checking if location update is for our mechanic:');
    print('  - Location user_id: $userId');
    print('  - Assigned mechanic ID: $_assignedMechanicUserId');
    print('  - Provider ID: ${widget.providerId}');
    
    // Priority 1: Check against assigned mechanic user ID (most reliable)
    if (_assignedMechanicUserId != null) {
      final isMatch = userId.toString() == _assignedMechanicUserId.toString();
      print('  - Match with assigned mechanic: $isMatch');
      return isMatch;
    }
    
    // Priority 2: If no assigned mechanic ID, try provider ID
    if (widget.providerId != null) {
      final isMatch = userId.toString() == widget.providerId.toString();
      print('  - Match with provider ID: $isMatch');
      return isMatch;
    }
    
    print('  - No mechanic ID available to match against');
    return false;
  }

  // Get current user location
  Future<void> _getCurrentLocation() async {
    try {
      final hasPermission = await Geolocator.checkPermission();
      if (hasPermission == LocationPermission.denied) {
        final permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
          print('⚠️ Location permission denied, using default location');
          if (mounted) {
            setState(() {
              _currentLocation = const LatLng(14.6760, 121.0437); // Default to Manila
            });
          }
          await _updateMarkers();
          return;
        }
      }
      
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      
      if (mounted) {
        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
        });
      }
      
      print('✅ Current location obtained: ${_currentLocation?.latitude}, ${_currentLocation?.longitude}');
      
      // Update markers after getting location
      await _updateMarkers();
    } catch (e) {
      print('❌ Error getting current location: $e');
      // Fallback to default location
      if (mounted) {
        setState(() {
          _currentLocation = const LatLng(14.6760, 121.0437); // Default to Manila
        });
      }
      await _updateMarkers();
    }
      // Get location address if needed
    if (_currentLocation != null) {
      try {
        await GoogleMapsService.getAddressFromCoordinates(_currentLocation!);
        // Address retrieved successfully for future use
      } catch (e) {
        print('Error getting address: $e');
      }
    }
      // Set fallback mechanic location for demo purposes
    if (_customerPickupLocation != null && _mechanicLocation == null) {
      if (mounted) {
        setState(() {
          _mechanicLocation = LatLng(
            _customerPickupLocation!.latitude + 0.005, // Slightly offset from pickup location
            _customerPickupLocation!.longitude + 0.005,
          );
        });
      }
    }
    
    await _updateDistanceAndDuration();
    // Draw initial polyline if locations are ready; schedule to avoid race with map creation
    _scheduleRouteDraw(immediate: true);
  }  // Update distance and duration between mechanic and customer pickup location using Google Maps API
  Future<void> _updateDistanceAndDuration() async {
    if (_mechanicLocation != null && _customerPickupLocation != null) {
      try {
        // Try to get accurate distance and duration from Google Maps API
        // Route from mechanic's current location to customer's pickup location
        final directionsData = await GoogleMapsService.getDistanceMatrix(
          origin: _mechanicLocation!, // Mechanic's current location
          destination: _customerPickupLocation!, // Customer's pickup location
        );
        
        if (directionsData != null && mounted) {
          setState(() {
            _distanceToMechanic = directionsData['distance'] ?? 'Unknown';
            _durationToMechanic = directionsData['duration'] ?? 'Unknown';
          });
          
          // Also automatically show route with accurate data
          _showRouteAutomatically();
        } else {
          // Fallback to straight-line calculation
          _calculateStraightLineDistance();
        }
      } catch (e) {
        print('❌ Error getting distance from Google Maps API: $e');
        // Fallback to straight-line calculation
        _calculateStraightLineDistance();
      }
    }
  }  // Fallback method for straight-line distance calculation between mechanic and pickup location
  void _calculateStraightLineDistance() {
    if (_mechanicLocation != null && _customerPickupLocation != null && mounted) {
      final distanceInKm = _calculateDistanceBetweenPoints(_mechanicLocation!, _customerPickupLocation!);
      
      setState(() {
        _distanceToMechanic = '${distanceInKm.toStringAsFixed(1)} km (direct)';
        _durationToMechanic = '${(distanceInKm * 3).round()} min (est.)'; // Rough estimate
      });
      
      // Show fallback straight-line route
      _showFallbackRoute();
    }
  }

  // Calculate distance between two points in kilometers
  double _calculateDistanceBetweenPoints(LatLng point1, LatLng point2) {
    return Geolocator.distanceBetween(
          point1.latitude, point1.longitude,
          point2.latitude, point2.longitude,
        ) / 1000; // Convert to kilometers
  }  // Automatically show route with Google Maps API route points from mechanic to customer pickup location
  Future<void> _showRouteAutomatically() async {
    if (_mechanicLocation != null && _customerPickupLocation != null) {
      try {
        // Get actual route points from Google Maps API
        // Route from mechanic's current location to customer's pickup location
        final routePoints = await GoogleMapsService.getRoutePoints(
          origin: _mechanicLocation!, // Mechanic's current location
          destination: _customerPickupLocation!, // Customer's pickup location
        );
        
        if (routePoints != null && routePoints.isNotEmpty && mounted) {
          setState(() {
            _polylines = {
              Polyline(
                polylineId: const PolylineId('mechanic_to_pickup_route'),
                color: const Color.fromARGB(255, 176, 12, 1), // RoadAid brand color
                width: 6,
                points: routePoints, // Actual route points from Google Directions API
                patterns: [], // Solid line for real route
                startCap: Cap.roundCap,
                endCap: Cap.roundCap,
                geodesic: true,
              ),
            };
          });
          
          // Auto-fit camera to show entire route
          _animateCameraToShowRoute(routePoints);
          
          print('🗺️ Real-time route displayed: ${routePoints.length} points');
        } else {
          // Fallback to straight line if API fails
          _showFallbackRoute();
        }
      } catch (e) {
        print('❌ Error showing automatic route: $e');
        _showFallbackRoute();
      }
    }
  }
  // Show fallback straight-line route when API is unavailable
  void _showFallbackRoute() {
    // Intentionally left blank: do not draw a straight-line fallback here.
    // The customer UI should rely on the centralized MapsService.routeStream
    // which provides the mechanic's driving route. Keeping this a no-op
    // prevents accidental overwrites of the proper route polyline.
    LoggingService().debug('ℹ️ _showFallbackRoute called but skipped - relying on MapsService.routeStream');
  }

  // Draw polyline between mechanic and customer with real-time updates
  Future<void> _drawPolyline() async {
    if (_mechanicLocation == null || _customerPickupLocation == null) {
      LoggingService().debug('⚠️ Cannot draw polyline - missing locations');
      return;
    }

    try {
      LoggingService().debug('🎨 Drawing polyline from mechanic to customer');

      // Try to fetch route points; retry once if the first call fails or returns empty
      List<LatLng>? routePoints = await GoogleMapsService.getRoutePoints(
        origin: _mechanicLocation!,
        destination: _customerPickupLocation!,
      );

      if ((routePoints == null || routePoints.isEmpty) && mounted) {
        // brief retry to handle transient Directions API glitches
        await Future.delayed(const Duration(milliseconds: 600));
        routePoints = await GoogleMapsService.getRoutePoints(
          origin: _mechanicLocation!,
          destination: _customerPickupLocation!,
        );
      }

      if (routePoints != null && routePoints.isNotEmpty && mounted) {
        setState(() {
          _polylines.clear();
          _polylines.add(
            Polyline(
              polylineId: const PolylineId('mechanic_to_customer_route'),
              points: routePoints!,
              color: const Color.fromARGB(255, 176, 12, 1), // RoadAid brand solid color
              width: 6,
              // Solid route line to match mechanic map
              patterns: [],
              startCap: Cap.roundCap,
              endCap: Cap.roundCap,
              geodesic: true,
              jointType: JointType.round,
            ),
          );
        });

  LoggingService().debug('✅ Polyline drawn with ${routePoints.length} points');
        
        // Animate camera to show full route
        _animateCameraToShowRoute(routePoints);
      } else {
        // Fallback to straight line if API fails after retry
        LoggingService().debug('⚠️ Directions API returned no route, drawing straight line fallback');
        _drawStraightLinePolyline();
      }
    } catch (e) {
      LoggingService().error('❌ Error drawing polyline: $e');
      _drawStraightLinePolyline();
    }
  }

  // Schedule a debounced route draw. If `immediate` is true, attempt to draw now.
  void _scheduleRouteDraw({bool immediate = false}) {
    // Cancel any pending debounce timer
    _routeDrawDebounce?.cancel();

    if (immediate) {
      // Try to perform immediately but still respect in-progress guard
      if (!_routeDrawInProgress) {
        _performDrawRoute();
      } else {
        _pendingRouteDraw = true;
      }
      return;
    }

    // Debounce normal updates slightly to batch rapid location updates
    _routeDrawDebounce = Timer(const Duration(milliseconds: 600), () {
      if (!_routeDrawInProgress) {
        _performDrawRoute();
      } else {
        _pendingRouteDraw = true;
      }
    });
  }

  // Perform the actual draw, guarded to avoid concurrent executions and ensure
  // both mechanic and pickup locations are available and the map controller exists.
  Future<void> _performDrawRoute() async {
    if (_mechanicLocation == null || _customerPickupLocation == null) {
      LoggingService().debug('⚠️ _performDrawRoute skipped - missing mechanic or pickup location');
      return;
    }

    if (_mapController == null) {
      LoggingService().debug('⚠️ _performDrawRoute skipped - map controller not ready');
      return;
    }

    if (_routeDrawInProgress) {
      _pendingRouteDraw = true;
      return;
    }

    _routeDrawInProgress = true;
    try {
      // Delegate to existing drawing logic which fetches route points and updates polylines
  await _drawPolyline();
    } catch (e) {
      LoggingService().error('❌ _performDrawRoute error: $e');
    } finally {
      _routeDrawInProgress = false;
    }

    // If another draw was requested while we were busy, schedule another pass
    if (_pendingRouteDraw) {
      _pendingRouteDraw = false;
      // Small delay to allow state to settle
      Future.delayed(const Duration(milliseconds: 250), () => _scheduleRouteDraw());
    }
  }

  // Fallback method for straight-line polyline
  void _drawStraightLinePolyline() {
    // No-op: avoid drawing a straight-line fallback in customer ServiceDetails.
    // Route rendering should come exclusively from MapsService so the customer's
    // map mirrors the mechanic's driving route in real time.
    LoggingService().debug('ℹ️ _drawStraightLinePolyline called but skipped to avoid straight-line fallback');
  }

  // Animate camera to show route points
  void _animateCameraToShowRoute(List<LatLng> routePoints) {
    if (_mapController != null && routePoints.isNotEmpty) {
      // Calculate bounds that include all route points
      double minLat = routePoints.first.latitude;
      double maxLat = routePoints.first.latitude;
      double minLng = routePoints.first.longitude;
      double maxLng = routePoints.first.longitude;
      
      for (final point in routePoints) {
        minLat = math.min(minLat, point.latitude);
        maxLat = math.max(maxLat, point.latitude);
        minLng = math.min(minLng, point.longitude);
        maxLng = math.max(maxLng, point.longitude);
      }
      
      _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(minLat, minLng),
            northeast: LatLng(maxLat, maxLng),
          ),
          100.0, // Padding
        ),
      );
    }
  }
  // Animate camera to show mechanic location and customer pickup location
  void _animateCameraToShowPoints() {
    if (_mapController != null && _mechanicLocation != null && _customerPickupLocation != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(
              math.min(_mechanicLocation!.latitude, _customerPickupLocation!.latitude),
              math.min(_mechanicLocation!.longitude, _customerPickupLocation!.longitude),
            ),
            northeast: LatLng(
              math.max(_mechanicLocation!.latitude, _customerPickupLocation!.latitude),
              math.max(_mechanicLocation!.longitude, _customerPickupLocation!.longitude),
            ),
          ),
          100.0, // Padding
        ),
      );
    }
  }

  // Update map markers
  Future<void> _updateMarkers() async {
    final Set<Marker> markers = {};
    
  LoggingService().debug('🗺️ Updating markers - Pickup: $_customerPickupLocation, Mechanic: $_mechanicLocation');
    
    // Add user pickup location marker first
    if (_customerPickupLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('pickup_location'),
          position: _customerPickupLocation!,
          infoWindow: InfoWindow(
            title: 'Your Location',
            snippet: _customerPickupAddress,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        ),
      );
  LoggingService().debug('✅ Added pickup location marker at $_customerPickupLocation');
    }
    
    // Add mechanic location marker
    if (_mechanicLocation != null) {
      final bool isCompleted = widget.serviceStatus?.toLowerCase() == 'completed';
      
      final icon = await _buildMechanicMarkerIcon(
        imageUrl: _mechanicProfileImage,
        fallbackHue: isCompleted ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueRed,
      );
      markers.add(
        Marker(
          markerId: const MarkerId('mechanic_location'),
          position: _mechanicLocation!,
          infoWindow: InfoWindow(
            title: isCompleted ? 'Service Completed' : (_mechanicName ?? 'Mechanic'),
            snippet: isCompleted ? 'Service has been completed at this location' : 'Mechanic is here',
          ),
          icon: icon,
        ),
      );
      LoggingService().debug('✅ Added mechanic marker at $_mechanicLocation for $_mechanicName');
    } else {
      LoggingService().debug('⚠️ No mechanic location available - marker not added');
    }
    
    LoggingService().debug('🗺️ Total markers to display: ${markers.length}');
    
    if (mounted) {
      setState(() {
        _markers = markers;
      });
    }
  }

  Future<BitmapDescriptor> _buildMechanicMarkerIcon({String? imageUrl, double size = 120, double fallbackHue = BitmapDescriptor.hueRed}) async {
    try {
      if (imageUrl == null || imageUrl.isEmpty) {
        return BitmapDescriptor.defaultMarkerWithHue(fallbackHue);
      }
      final data = (await NetworkAssetBundle(Uri.parse(imageUrl)).load(imageUrl)).buffer.asUint8List();
      final codec = await ui.instantiateImageCodec(data, targetWidth: size.toInt());
      final frame = await codec.getNextFrame();
      final img = frame.image;

      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      final paint = ui.Paint();
      final radius = size / 2;

      final path = ui.Path()..addOval(ui.Rect.fromCircle(center: ui.Offset(radius, radius), radius: radius));
      canvas.clipPath(path);
      paint.isAntiAlias = true;
      canvas.drawImageRect(
        img,
        ui.Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
        ui.Rect.fromLTWH(0, 0, size, size),
        paint,
      );

      final borderPaint = ui.Paint()
        ..style = ui.PaintingStyle.stroke
        ..color = const Color(0xFFFFFFFF)
        ..strokeWidth = 6;
      canvas.drawCircle(ui.Offset(radius, radius), radius - 3, borderPaint);

      final picture = recorder.endRecording();
      final pngBytes = await (await picture.toImage(size.toInt(), size.toInt())).toByteData(format: ui.ImageByteFormat.png);
      if (pngBytes == null) return BitmapDescriptor.defaultMarkerWithHue(fallbackHue);
      return BitmapDescriptor.fromBytes(pngBytes.buffer.asUint8List());
    } catch (_) {
      return BitmapDescriptor.defaultMarkerWithHue(fallbackHue);
    }
  }

  // Check if user has reviewed this service
  Future<void> _checkReviewStatus() async {
    try {
      if (widget.requestId.isEmpty) {
        print('⚠️ Request ID is empty, cannot check review status');
        if (mounted) {
          setState(() {
            _checkingReview = false;
            _hasReviewed = false; // Default to not reviewed if no request ID
          });
        }
        return;
      }

      print('🔍 Checking review status for request: ${widget.requestId}');
      final hasReviewed = await UserDataService.hasUserReviewed(widget.requestId);
      print('📝 Review status: ${hasReviewed ? 'Already reviewed' : 'Not reviewed yet'}');
      
      if (mounted) {
        setState(() {
          _hasReviewed = hasReviewed;
          _checkingReview = false;
        });
      }
    } catch (e) {
      print('❌ Error checking review status: $e');
      if (mounted) {
        setState(() {
          _checkingReview = false;
          _hasReviewed = false; // Default to showing review option on error
        });
      }
    }
  }
  // Show review dialog
  void _showReviewDialog() {
    if (widget.providerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to identify service provider. Please try again later.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    print('🌟 Opening review dialog for Request: ${widget.requestId}, Provider: ${widget.providerId}');

    showDialog(
      context: context,
      barrierDismissible: false, // Prevent accidental dismissal
      builder: (context) => ReviewDialog(
        requestId: widget.requestId,
        providerId: widget.providerId!,
        serviceTitle: widget.issueTitle ?? 'Service Request',
        onReviewSubmitted: () {
          setState(() {
            _hasReviewed = true;
          });
          // Refresh review status to ensure UI updates
          _checkReviewStatus();
        },
      ),
    );
  }
  // Show existing review
  void _showExistingReview() async {
    try {
      final review = await UserDataService.getServiceReview(widget.requestId);
      if (review != null) {
        // Show review details in a dialog
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Your Review'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Rating: ${review['rating']}/5 stars'),
                const SizedBox(height: 8),
                if (review['comment'] != null)
                  Text('Comment: ${review['comment']}'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      print('Error loading review: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading review: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Call mechanic directly
  Future<void> _callMechanic(String phoneNumber) async {
    try {
      // Clean the phone number (remove spaces, dashes, etc.)
      final cleanPhone = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
      
      print('🔥 Attempting to call mechanic: $cleanPhone');
      print('🔥 Original phone: $phoneNumber');
      
      // Try multiple URI formats for better compatibility
      final uris = [
        Uri.parse('tel:$cleanPhone'),
        Uri.parse('tel://$cleanPhone'),
        Uri.parse('tel:+63${cleanPhone.startsWith('0') ? cleanPhone.substring(1) : cleanPhone}'),
      ];
      
      bool launched = false;
      
      for (final uri in uris) {
        print('🔥 Trying call URI: $uri');
        try {
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
            launched = true;
            print('✅ Phone call launched successfully with: $uri');
            break;
          }
        } catch (e) {
          print('❌ Failed with call URI: $uri - Error: $e');
        }
      }
      
      // Android intent strategy (between direct and dialer fallback)
      if (!launched && Platform.isAndroid) {
        print('🤖 Trying Android intent approach...');
        try {
          // Use DIAL action instead of CALL for better compatibility
          final intentUri = Uri.parse('intent://tel:$cleanPhone#Intent;scheme=tel;action=android.intent.action.DIAL;end');
          await launchUrl(intentUri, mode: LaunchMode.externalApplication);
          launched = true;
          print('✅ Android dialer intent launched successfully');
        } catch (e) {
          print('❌ Android intent failed: $e');
          // Try simpler dialer approach
          try {
            final dialUri = Uri.parse('tel:$cleanPhone');
            await launchUrl(dialUri, mode: LaunchMode.platformDefault);
            launched = true;
            print('✅ Simple dialer launched successfully');
          } catch (e2) {
            print('❌ Simple dialer also failed: $e2');
          }
        }
      }
      
      // If direct calling failed, try opening dialer (less permissions needed)
      if (!launched) {
        print('🔥 Trying dialer fallback...');
        for (final phone in [cleanPhone, '+63${cleanPhone.startsWith('0') ? cleanPhone.substring(1) : cleanPhone}']) {
          try {
            final dialUri = Uri.parse('tel:$phone');
            if (await canLaunchUrl(dialUri)) {
              await launchUrl(dialUri, mode: LaunchMode.platformDefault);
              launched = true;
              print('✅ Dialer opened successfully with: $dialUri');
              break;
            }
          } catch (e) {
            print('❌ Failed with dialer: tel:$phone - Error: $e');
          }
        }
      }
      
      if (!launched) {
        print('❌ All URI formats failed');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not launch phone dialer for $cleanPhone.\n\nPlease dial manually:\n$phoneNumber'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 6),
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Phone call error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error making call: $e\n\nPlease dial manually:\n$phoneNumber'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isCompleted = widget.serviceStatus?.toLowerCase() == 'completed';
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Mechanic Profile Section - Featured at the top
          if (!_mechanicLoading && _mechanicName != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color.fromARGB(255, 176, 12, 1).withOpacity(0.1),
                    const Color.fromARGB(255, 176, 12, 1).withOpacity(0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color.fromARGB(255, 176, 12, 1).withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Mechanic Profile Picture
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color.fromARGB(255, 176, 12, 1),
                            width: 2,
                          ),
                        ),
                        child: ClipOval(
                          child: _mechanicProfileImage != null && _mechanicProfileImage!.isNotEmpty
                              ? Image.network(
                                  _mechanicProfileImage!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      color: Colors.grey[300],
                                      child: const Icon(
                                        Icons.person,
                                        color: Colors.grey,
                                        size: 30,
                                      ),
                                    );
                                  },
                                )
                              : Container(
                                  color: const Color.fromARGB(255, 176, 12, 1).withOpacity(0.1),
                                  child: const Icon(
                                    Icons.build,
                                    color: Color.fromARGB(255, 176, 12, 1),
                                    size: 30,
                                  ),
                                ),
                        ),
                      ),
                      
                      const SizedBox(width: 16),
                      
                      // Mechanic Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _mechanicName!,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color.fromARGB(255, 176, 12, 1),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _isProviderFallback ? 'Provider Contact (awaiting assignment)' : 'Your Assigned Mechanic',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (!isCompleted && _distanceToMechanic != null) ...[
                              const SizedBox(height: 8),
                              Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 8,
                                runSpacing: 4,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.location_on,
                                        size: 16,
                                        color: Colors.orange[700],
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '$_distanceToMechanic away',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.orange[700],
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (_durationToMechanic != null)
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.access_time,
                                          size: 16,
                                          color: Colors.orange[700],
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'ETA: $_durationToMechanic',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.orange[700],
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      
                      // Call Button
                      if (_mechanicPhone != null && _mechanicPhone!.isNotEmpty)
                        Container(
                          decoration: BoxDecoration(
                            color: const Color.fromARGB(255, 176, 12, 1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: IconButton(
                            onPressed: () => _callMechanic(_mechanicPhone!),
                            icon: const Icon(
                              Icons.phone,
                              color: Colors.white,
                              size: 24,
                            ),
                            tooltip: 'Call Mechanic',
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            
            // Real-time ETA Widget - Show if mechanic is assigned and service is active
            if (!isCompleted && _assignedMechanicUserId != null && _customerPickupLocation != null)
              RealTimeETAWidget(
                serviceRequestId: widget.requestId,
                mechanicId: _assignedMechanicUserId!,
                customerLocation: _customerPickupLocation!,
                mechanicName: _mechanicName,
              ),
              
          ] else if (_mechanicLoading) ...[
            // Loading state for mechanic info
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.grey[300],
                    ),
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color.fromARGB(255, 176, 12, 1),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Loading mechanic info...',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Please wait',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
          
          // Status indicator
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isCompleted ? Colors.green[50] : Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isCompleted ? Colors.green : Colors.blue,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isCompleted ? Icons.check_circle : Icons.info,
                  color: isCompleted ? Colors.green : Colors.blue,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isCompleted ? 'Service Completed' : 'Service Active',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isCompleted ? Colors.green[700] : Colors.blue[700],
                        ),
                      ),
                      if (!isCompleted)
                        Text(
                          'Real-time tracking enabled',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          
          // Google Maps Section
          const Text(
            'Live Location Tracking',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          
          Container(
            height: 300,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _currentLocation != null
                  ? GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: _customerPickupLocation ?? _currentLocation!,
                        zoom: 15.0,
                      ),
                      markers: _markers,
                      polylines: _polylines,
                      onMapCreated: (GoogleMapController controller) {
                        _mapController = controller;
                        print('🗺️ Map created successfully');
                        // Automatically show route when map is ready
                        if (_mechanicLocation != null && _customerPickupLocation != null) {
                          Future.delayed(const Duration(milliseconds: 1000), () {
                            _animateCameraToShowPoints();
                            _updateDistanceAndDuration();
                          });
                        }
                      },
                      
                      // Do NOT display the customer's live location on the map
                      myLocationEnabled: false,
                      myLocationButtonEnabled: false,
                      
                      // Enhanced UI controls
                      zoomControlsEnabled: true, // Enable zoom controls for better UX
                      mapToolbarEnabled: true, // Enable map toolbar
                      compassEnabled: true,
                      
                      // Full gesture control for maximum movability
                      zoomGesturesEnabled: true, // Pinch to zoom
                      scrollGesturesEnabled: true, // Drag to pan
                      rotateGesturesEnabled: true, // Two-finger rotation
                      tiltGesturesEnabled: true, // Two-finger tilt
                      
                      // CRITICAL: Allow map gestures to work in bottom sheet
                      gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                        Factory<EagerGestureRecognizer>(
                          () => EagerGestureRecognizer(),
                        ),
                      },
                      
                      // Map type and visual enhancements
                      mapType: _currentMapType,
                      trafficEnabled: false, // Disable for better performance
                      buildingsEnabled: true,
                      indoorViewEnabled: true, // Enable indoor maps where available
                      
                      // Enhanced interaction handling
                      onTap: (LatLng position) {
                        print('Map tapped at: ${position.latitude}, ${position.longitude}');
                        // Optional: Add marker or show info at tapped location
                        _handleMapTap(position);
                      },
                      
                      onLongPress: (LatLng position) {
                        print('Map long pressed at: ${position.latitude}, ${position.longitude}');
                        // Optional: Show context menu or add custom marker
                        _handleMapLongPress(position);
                      },
                      
                      onCameraMove: (CameraPosition position) {
                        // Handle real-time camera movement (reduced logging)
                        // Removed excessive print statements
                      },
                      
                      onCameraIdle: () {
                        // Called when camera movement ends
                        print('Camera is now idle');
                        _onCameraIdle();
                      },
                      
                      onCameraMoveStarted: () {
                        // Called when camera movement starts (reduced logging)
                        // Removed excessive print statements
                      },
                      
                      // Minimum and maximum zoom levels for better control
                      minMaxZoomPreference: const MinMaxZoomPreference(5.0, 20.0),
                    )
                  : Container(
                      color: Colors.grey[200],
                      child: const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 8),
                            Text('Loading map...'),
                          ],
                        ),
                      ),
                    ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Service details section
          const Text(
            'Service Details',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          
          _buildDetailRow('Issue:', widget.issueTitle ?? "Service Request"),
          _buildDetailRow('Vehicle:', '${widget.vehicleBrand ?? ""} ${widget.vehicleModel ?? ""} ${widget.vehicleYear ?? ""}'.trim()),
          _buildDetailRow('Payment Method:', widget.paymentMethod ?? 'N/A'),
          _buildDetailRow('Amount:', widget.amount ?? '₱0.00'),
          
          const SizedBox(height: 20),
          
          // Invoice notification widget
          InvoiceNotificationWidget(requestId: widget.requestId),
          
          const SizedBox(height: 20),
          
          // Action buttons
          // Show QR Code button after payment or when completed
          if ((!_checkingReview && widget.isActualPayment == true) || 
              (isCompleted && !_checkingReview)) ...[
            // QR Code Generation Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _generateQRCode,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: const BorderSide(color: Color.fromARGB(255, 176, 12, 1)),
                ),
                icon: const Icon(Icons.qr_code_2, color: Color.fromARGB(255, 176, 12, 1)),
                label: Text(
                  isCompleted ? 'Generate QR Code' : 'Show Completion QR Code',
                  style: const TextStyle(color: Color.fromARGB(255, 176, 12, 1)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            
            // Review section with loading state
            if (_checkingReview) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[300],
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Checking review status...',
                        style: TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ] else if (!_hasReviewed) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _showReviewDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 176, 12, 1),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.star, color: Colors.white),
                  label: const Text(
                    'Rate & Review Service',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ] else ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _showExistingReview,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color.fromARGB(255, 176, 12, 1)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text(
                    'View Your Review',
                    style: TextStyle(
                      color: Color.fromARGB(255, 176, 12, 1),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ] else if (!isCompleted) ...[
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: widget.onCancelService,
                child: const Text(
                  'Cancel Service',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Handle map tap events
void _handleMapTap(LatLng position) {
  print('User tapped map at: ${position.latitude}, ${position.longitude}');
  
  // Optional: Show distance from tapped point to mechanic
  if (_mechanicLocation != null) {
    final distance = _calculateDistanceBetweenPoints(position, _mechanicLocation!);
    
    // Show snackbar with distance info
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Distance to mechanic: ${distance.toStringAsFixed(2)} km'),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

// Handle map long press events
void _handleMapLongPress(LatLng position) {
  print('User long pressed map at: ${position.latitude}, ${position.longitude}');
  
  // Show context menu with options
  showModalBottomSheet(
    context: context,
    builder: (BuildContext context) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.location_on),
              title: const Text('Set as Destination'),
              onTap: () {
                Navigator.pop(context);
                _setCustomDestination(position);
              },
            ),
            ListTile(
              leading: const Icon(Icons.navigation),
              title: const Text('Get Directions'),
              onTap: () {
                Navigator.pop(context);
                _getDirectionsToPoint(position);
              },
            ),
            ListTile(
              leading: const Icon(Icons.info),
              title: const Text('Location Info'),
              onTap: () {
                Navigator.pop(context);
                _showLocationInfo(position);
              },
            ),
          ],
        ),
      );
    },
  );
}

// Called when camera movement ends
void _onCameraIdle() {
  // Optional: Update visible markers or perform location-based queries
  print('Camera is now idle');
}

// Set custom destination
void _setCustomDestination(LatLng position) {
  setState(() {
    // Add a custom destination marker
    _markers.add(
      Marker(
        markerId: const MarkerId('custom_destination'),
        position: position,
        infoWindow: const InfoWindow(
          title: 'Custom Destination',
          snippet: 'Tap to remove',
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        onTap: () {
          // Remove the custom marker when tapped
          setState(() {
            _markers.removeWhere((marker) => marker.markerId.value == 'custom_destination');
          });
        },
      ),
    );
  });
}

// Get directions to specific point
void _getDirectionsToPoint(LatLng destination) async {
  if (_mechanicLocation != null) {
    try {
      final routePoints = await GoogleMapsService.getRoutePoints(
        origin: _mechanicLocation!,
        destination: destination,
      );
      
      if (routePoints != null && routePoints.isNotEmpty && mounted) {
        setState(() {
          _polylines.add(
            Polyline(
              polylineId: const PolylineId('custom_route'),
              color: Colors.blue,
              width: 3,
              points: routePoints,
              patterns: [PatternItem.dash(10), PatternItem.gap(10)],
            ),
          );
        });
        
        // Animate camera to show the route
        _animateCameraToShowRoute(routePoints);
      }
    } catch (e) {
      print('Error getting directions: $e');
    }
  }
}

// Show location information
void _showLocationInfo(LatLng position) async {
  try {
    // Get address for the location
    final address = await GoogleMapsService.getAddressFromCoordinates(position);
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Location Information'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Latitude: ${position.latitude.toStringAsFixed(6)}'),
              Text('Longitude: ${position.longitude.toStringAsFixed(6)}'),
              if (address != null) ...[
                const SizedBox(height: 8),
                Text('Address: $address'),
              ],
              if (_mechanicLocation != null) ...[
                const SizedBox(height: 8),
                Text('Distance to mechanic: ${_calculateDistanceBetweenPoints(position, _mechanicLocation!).toStringAsFixed(2)} km'),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  } catch (e) {
    print('Error getting location info: $e');
  }
}

  // Generate QR Code for service (available after payment)
  Future<void> _generateQRCode() async {
    final status = widget.serviceStatus?.toLowerCase();
    final isPaid = widget.isActualPayment == true;
    
    // Allow QR generation if payment is completed or service is completed
    if (status != 'completed' && !isPaid && 
        !['paid', 'invoice_paid', 'in_progress', 'assigned'].contains(status)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('QR code will be available after payment is completed'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Navigate to dedicated QR completion screen
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => JobCompletionQRScreen(
          serviceRequestId: widget.requestId,
          jobDetails: {
            'issueTitle': widget.issueTitle ?? 'Service Request',
            'amount': widget.amount ?? '₱0.00',
            'serviceStatus': widget.serviceStatus,
            'isActualPayment': widget.isActualPayment,
          },
        ),
      ),
    );
    
    // If job was completed, close the bottom sheet
    if (result == true) {
      final homeState = context.findAncestorStateOfType<_RoadAidHomePageState>();
      homeState?._closeService();
    }
  }



}

class RoadAidDrawer extends StatefulWidget {
  const RoadAidDrawer({Key? key}) : super(key: key);

  @override
  State<RoadAidDrawer> createState() => _RoadAidDrawerState();
}

class _RoadAidDrawerState extends State<RoadAidDrawer> {
  String _userName = 'Loading...';
  String _userEmail = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final authService = AuthService.instance;
      final userId = authService.userId;
        if (userId != null) {
        // Use UserDataService instead of SupabaseService
        final profileData = await UserDataService.getUserProfile();
        setState(() {
          // Combine first_name and last_name instead of looking for full_name
          final firstName = profileData['first_name'] ?? '';
          final lastName = profileData['last_name'] ?? '';
          _userName = '$firstName $lastName'.trim();
          
          // If both names are empty, show a fallback
          if (_userName.isEmpty) {
            _userName = 'User';
          }
          
          _userEmail = profileData['email'] ?? '';
          _isLoading = false;
        });
      } else {
        setState(() {
          _userName = 'Guest User';
          _userEmail = '';
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading user data in drawer: $e');
      
      // Try to get basic info from AuthService as fallback
      try {
        final authService = AuthService.instance;
        final userProfile = authService.userProfile;
        
        if (userProfile != null) {
          setState(() {
            final firstName = userProfile['first_name'] ?? '';
            final lastName = userProfile['last_name'] ?? '';
            _userName = '$firstName $lastName'.trim();
            
            if (_userName.isEmpty) {
              _userName = 'User';
            }
            
            _userEmail = userProfile['email'] ?? '';
            _isLoading = false;
          });
        } else {
          setState(() {
            _userName = 'User';
            _userEmail = '';
            _isLoading = false;
          });
        }
      } catch (fallbackError) {
        print('Fallback error: $fallbackError');
        setState(() {
          _userName = 'User';
          _userEmail = '';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ),
              Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color.fromARGB(255, 176, 12, 1),
                      const Color.fromARGB(255, 200, 40, 30),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color.fromARGB(255, 176, 12, 1).withOpacity(0.3),
                      blurRadius: 8,
                      spreadRadius: 0,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Enhanced avatar with glow effect
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withOpacity(0.3),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 32,
                        backgroundColor: Colors.white,
                        child: _isLoading 
                            ? const CircularProgressIndicator(
                                color: Color.fromARGB(255, 176, 12, 1),
                                strokeWidth: 2,
                              )
                            : CircleAvatar(
                                radius: 28,
                                backgroundColor: const Color.fromARGB(255, 176, 12, 1),
                                child: Text(
                                  _getInitials(_userName),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isLoading ? 'Loading...' : _userName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          if (_userEmail.isNotEmpty)
                            Text(
                              _userEmail,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const RoadAidHomePage(initialIndex: 4),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(color: Colors.white.withOpacity(0.3)),
                              ),
                              child: const Text(
                                'View Profile',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            DrawerMenuItem(
              icon: Icons.home,
              title: 'Home',
              isSelected: true,
              onTap: () {
                Navigator.pop(context);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const RoadAidHomePage(initialIndex: 0), // No paymentSuccessData
                  ),
                );
              },
            ),
            
            DrawerMenuItem(
              icon: Icons.history,
              title: 'Service History',
              onTap: () {
                Navigator.pop(context);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const RoadAidHomePage(initialIndex: 1),
                  ),
                );
              },
            ),
            
            DrawerMenuItem(
              icon: Icons.build,
              title: 'Request Service',
              onTap: () {
                Navigator.pop(context);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const RoadAidHomePage(initialIndex: 2),
                  ),
                );
              },
            ),
            
            DrawerMenuItem(
              icon: Icons.message,
              title: 'Messages',
              onTap: () {
                Navigator.pop(context);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const RoadAidHomePage(initialIndex: 3),
                  ),
                );
              },
            ),
            
            DrawerMenuItem(
              icon: Icons.settings,
              title: 'Settings',
              onTap: () {
                Navigator.pop(context);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const RoadAidHomePage(initialIndex: 4),
                  ),
                );
              },
            ),
            
            const Spacer(),
            
            // Logout button
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    
                    // Show confirmation dialog
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Logout'),
                        content: const Text('Are you sure you want to logout?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                            child: const Text('Logout'),
                          ),
                        ],
                      ),
                    );
                    
                    if (confirmed == true) {
                      await AuthService.instance.signOut();
                    }
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text('Logout'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to get user initials
  String _getInitials(String name) {
    if (name.isEmpty || name == 'Loading...' || name == 'Guest User') {
      return 'U';
    }
    
    final names = name.trim().split(' ');
    if (names.length >= 2) {
      return '${names[0][0]}${names[1][0]}'.toUpperCase();
    } else if (names.isNotEmpty) {
      return names[0][0].toUpperCase();
    }
    return 'U';
  }
}

class DrawerMenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool isSelected;
  final VoidCallback onTap;
  
  const DrawerMenuItem({
    Key? key,
    required this.icon,
    required this.title,
    this.isSelected = false,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color.fromARGB(255, 176, 12, 1).withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? const Color.fromARGB(255, 176, 12, 1) : Colors.grey,
              size: 24,
            ),
            const SizedBox(width: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                color: isSelected ? const Color.fromARGB(255, 176, 12, 1) : Colors.grey[700],
                fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RoadAidBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final bool isRequestDisabled;
  
  const RoadAidBottomNavBar({
    Key? key,
    required this.currentIndex,
    required this.onTap,
    this.isRequestDisabled = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      selectedItemColor: const Color.fromARGB(255, 176, 12, 1),
      unselectedItemColor: Colors.grey,
      currentIndex: currentIndex,
      onTap: (index) {
        if (index == 2 && isRequestDisabled) {
          // Show message when request tab is disabled
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Complete your current service before requesting a new one.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
          return;
        }
        onTap(index);
      },
      items: [
        const BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: 'Home',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.history),
          label: 'History',
        ),
        BottomNavigationBarItem(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isRequestDisabled 
                ? Colors.grey[400] 
                : const Color.fromARGB(255, 176, 12, 1),
              shape: BoxShape.circle,
            ),
            child: Stack(
              children: [
                Icon(
                  Icons.location_on, 
                  color: Colors.white,
                ),
                if (isRequestDisabled)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          label: isRequestDisabled ? 'Blocked' : 'Request',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.receipt),
          label: 'Invoices',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: 'Profile',
        ),
      ],
    );
  }
}

class RoadAidBody extends StatefulWidget {
  final bool hasActiveService;
  final int currentTabIndex;
  
  const RoadAidBody({
    Key? key, 
    this.hasActiveService = false, 
    required this.currentTabIndex
  }) : super(key: key);

  @override
  State<RoadAidBody> createState() => _RoadAidBodyState();
}

class _RoadAidBodyState extends State<RoadAidBody> {
  String _currentAddress = 'Getting location...';
  bool _locationLoading = true;
  final LocationService _locationService = LocationService();
  StreamSubscription? _locationStreamSubscription;
  StreamSubscription? _shopLocationSubscription; // ✅ NEW: Listen to shop location changes
  List<Map<String, dynamic>> _nearbyMechanics = [];
  bool _mechanicsLoading = false;
  LatLng? _lastKnownCustomerLocation; // ✅ NEW: Store customer location for updates

  @override
  void initState() {
    super.initState();
    _updateLocation();
    _startLocationTracking();
    _listenToLocationUpdates();
    _listenToShopLocationUpdates(); // ✅ NEW: Listen to shop location changes
  }

  @override
  void dispose() {
    _locationStreamSubscription?.cancel();
    _shopLocationSubscription?.cancel(); // ✅ NEW: Cancel shop location subscription
    super.dispose();
  }

  Future<void> _updateLocation() async {
    setState(() => _locationLoading = true);
    
    try {      final locationData = await _locationService.getCurrentLocationWithAddress();
      if (locationData != null && mounted) {
        final customerLocation = LatLng(
          locationData['latitude'], 
          locationData['longitude']
        );
        
        setState(() {
          _currentAddress = locationData['address'] ?? 'Unknown location';
          _locationLoading = false;
          _lastKnownCustomerLocation = customerLocation; // ✅ Store customer location
        });
        
        // Start tracking nearby mechanics
        _trackNearbyMechanics(customerLocation);
        
        // Location update notification disabled per user request
        // ScaffoldMessenger.of(context).showSnackBar(
        //   const SnackBar(
        //     content: Text('Location updated'),
        //     backgroundColor: Colors.green,
        //     duration: Duration(seconds: 2),
        //   ),
        // );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _currentAddress = 'Location unavailable';
          _locationLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error getting location: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }  void _startLocationTracking() {
    // Start listening to location updates from the service
    _locationStreamSubscription = _locationService.locationStream.listen((locationData) {
      if (mounted) {
        setState(() {
          _currentAddress = locationData['address'] ?? 'Unknown location';
        });
        
        // Update nearby mechanics when location changes
        _trackNearbyMechanics(LatLng(
          locationData['latitude'],
          locationData['longitude'],
        ));
      }
    });
  }  void _listenToLocationUpdates() {
    // Listen to location updates from the service
    _locationStreamSubscription = _locationService.locationStream.listen((locationData) {
      if (mounted) {
        final customerLocation = LatLng(
          locationData['latitude'],
          locationData['longitude'],
        );
        
        setState(() {
          _currentAddress = locationData['address'] ?? 'Unknown location';
          _lastKnownCustomerLocation = customerLocation; // ✅ Update stored location
        });
        
        // Update nearby mechanics when location changes
        _trackNearbyMechanics(customerLocation);
      }
    });
  }

  // ✅ NEW: Listen to real-time shop location updates
  void _listenToShopLocationUpdates() {
    try {
      print('🔔 Setting up real-time shop location listener...');
      
      // Subscribe to SHOPS table for direct location updates
      // This triggers when talyer owner clicks "Use Current Location" in Shop Settings
      _shopLocationSubscription = SupabaseService.client
          .from('shops')
          .stream(primaryKey: ['id'])
          .listen((data) {
            if (!mounted) return;
            
            // When any shop updates their latitude/longitude, refresh the list
            if (_lastKnownCustomerLocation != null) {
              print('📍 Shop location updated in shops table - refreshing available shops...');
              _trackNearbyMechanics(_lastKnownCustomerLocation!);
            }
          });
      
      print('✅ Shop location listener active (monitoring shops table)');
    } catch (e) {
      print('❌ Error setting up shop location listener: $e');
    }
  }  Future<void> _trackNearbyMechanics(LatLng currentLocation) async {
    setState(() => _mechanicsLoading = true);
    
    try {
      print('🏪 _trackNearbyMechanics() - Getting nearby shops using talyer owner locations...');
      
      // Method 1: Use optimized database function (recommended)
      try {
        final nearbyShopsResponse = await SupabaseService.client
            .rpc('get_nearby_shops', params: {
              'customer_lat': currentLocation.latitude,
              'customer_lon': currentLocation.longitude,
              'radius_km': 15.0,
            });

        List<Map<String, dynamic>> nearbyShops = [];
        
        for (final shop in nearbyShopsResponse) {
          // Convert address from coordinates
          String businessAddress = 'Address not available';
          try {
            final address = await _getAddressFromCoordinates(
              shop['shop_latitude']?.toDouble() ?? 0.0,
              shop['shop_longitude']?.toDouble() ?? 0.0
            );
            businessAddress = address;
          } catch (e) {
            print('Error getting address for shop ${shop['shop_id']}: $e');
            businessAddress = shop['shop_name'] ?? 'Address not available';
          }
          
          nearbyShops.add({
            'id': shop['shop_id'],
            'user_id': shop['shop_id'], // Using shop_id as identifier
            'name': shop['shop_name'] ?? '${shop['owner_name']}\'s Shop',
            'owner_name': shop['owner_name'] ?? 'Shop Owner',
            'shop_name': shop['shop_name'],
            'business_address': businessAddress,
            'business_hours': shop['business_hours'], // Add business hours
            'rating': 4.2, // Default rating, calculate from reviews later
            'total_reviews': 25, // Default value
            'experience_years': 5, // Default value
            'is_available': shop['is_available'] ?? false,
            'phone_number': shop['owner_phone'],
            'latitude': shop['shop_latitude']?.toDouble(),
            'longitude': shop['shop_longitude']?.toDouble(),
            'distance': shop['distance_km']?.toDouble(),
            'mechanics_count': 2, // Default value
            'specialization': 'Auto Repair Shop',
          });
        }

        if (mounted) {
          setState(() {
            _nearbyMechanics = nearbyShops;
            _mechanicsLoading = false;
          });
          print('🏪 Found ${nearbyShops.length} shops within 15km using database function');
        }
        return;
        
      } catch (e) {
        print('Database function failed, falling back to manual query: $e');
      }

      // Method 2: Fallback to manual query if database function doesn't exist
      final shopsResponse = await SupabaseService.client
          .from('shops')
          .select('''
            id,
            shop_name,
            shop_address,
            owner_id,
            is_active,
            latitude,
            longitude,
            business_hours,
            user_profiles!shops_owner_id_fkey (
              id,
              first_name,
              last_name,
              phone_number,
              user_type,
              is_available
            )
          ''')
          .eq('is_active', true);

      print('🏪 Found ${shopsResponse.length} active shops, filtering by shop location (from shops table)...');

      List<Map<String, dynamic>> nearbyShops2 = [];
      
      for (final shop in shopsResponse) {
        final ownerProfile = shop['user_profiles'];
        if (ownerProfile == null) {
          print('Warning: No owner profile found for shop ${shop['id']}');
          continue;
        }

        // Ensure this is a talyer owner
        if (ownerProfile['user_type'] != 'talyer_owner') {
          print('Skipping shop ${shop['id']} - owner is not a talyer_owner');
          continue;
        }

        // ✅ FIX: Use shops.latitude/longitude (updated by Shop Settings)
        final shopLat = shop['latitude']?.toDouble();
        final shopLng = shop['longitude']?.toDouble();
        
        if (shopLat != null && shopLng != null) {
          final distance = _calculateDistance(
            currentLocation.latitude,
            currentLocation.longitude,
            shopLat,
            shopLng,
          );
          
          // Only include shops within 15km
          if (distance <= 15.0) {
            final firstName = ownerProfile['first_name'] ?? '';
            final lastName = ownerProfile['last_name'] ?? '';
            final ownerName = '$firstName $lastName'.trim();
            
            // Convert coordinates to address
            String businessAddress = 'Address not available';
            try {
              final address = await _getAddressFromCoordinates(shopLat, shopLng);
              businessAddress = address;
            } catch (e) {
              print('Error getting address for shop ${shop['id']}: $e');
              businessAddress = shop['shop_name'] ?? 'Address not available';
            }
            
            // Get shop rating (you might want to calculate this from reviews)
            double rating = 4.2; // Default rating, you can calculate from reviews later
            
            // ✅ IMPORTANT: Check if shop is currently open
            final businessHours = shop['business_hours'];
            if (!_isShopCurrentlyOpen(businessHours)) {
              print('⏰ Skipping ${shop['shop_name']} - currently closed');
              continue; // Skip closed shops
            }
            
            nearbyShops2.add({
              'id': shop['id'],
              'user_id': shop['owner_id'],
              'name': shop['shop_name'] ?? (ownerName.isNotEmpty ? '$ownerName\'s Shop' : 'Auto Shop'),
              'owner_name': ownerName.isNotEmpty ? ownerName : 'Shop Owner',
              'shop_name': shop['shop_name'],
              'business_address': businessAddress,
              'business_hours': shop['business_hours'], // Add business hours
              'rating': rating,
              'total_reviews': 25, // Default value, calculate from actual reviews later
              'experience_years': 5, // Default value
              'is_available': ownerProfile['is_available'] ?? false,
              'phone_number': ownerProfile['phone_number'],
              'latitude': shopLat,
              'longitude': shopLng,
              'distance': distance,
              'mechanics_count': 2, // Default value, you can count actual mechanics later
              'specialization': 'Auto Repair Shop',
            });
          }
        } else {
          print('Shop ${shop['id']} owner has no location data (lat: $shopLat, lng: $shopLng)');
        }
      }
      
      // Sort by distance
      nearbyShops2.sort((a, b) => (a['distance'] as double).compareTo(b['distance'] as double));
      
      if (mounted) {
        setState(() {
          _nearbyMechanics = nearbyShops2;
          _mechanicsLoading = false;
        });
        print('🏪 Nearby shops found within 15km using talyer owner locations: ${nearbyShops2.length}');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _mechanicsLoading = false;
        });
      }
      print('❌ Error fetching nearby shops: $e');
    }
  }

  // Helper method to get address from coordinates
  Future<String> _getAddressFromCoordinates(double latitude, double longitude) async {
    try {
      // Use a simple geocoding approach - you might want to integrate with a proper service
      // For now, return a formatted coordinate string that looks more like an address
      final latStr = latitude.toStringAsFixed(4);
      final lngStr = longitude.toStringAsFixed(4);
      
      // Try to get a readable address format
      // You can integrate with Google Maps Geocoding API or other services here
      return 'Location: ${latStr}°N, ${lngStr}°E';
    } catch (e) {
      print('Error converting coordinates to address: $e');
      return 'Location not available';
    }
  }
  
  // Calculate distance between two points using Haversine formula
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // Earth's radius in kilometers
    
    final double dLat = _toRadians(lat2 - lat1);
    final double dLon = _toRadians(lon2 - lon1);
    
    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) * math.cos(_toRadians(lat2)) *
        math.sin(dLon / 2) * math.sin(dLon / 2);
    
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    
    return earthRadius * c;
  }
  
  double _toRadians(double degrees) {
    return degrees * (math.pi / 180);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Location header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color.fromARGB(255, 176,  12, 1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    'Current Location',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _locationLoading ? 'Loading...' : _currentAddress,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _updateLocation,                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color.fromARGB(255, 176, 12, 1),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.my_location, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Update Location',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // History button - only show on history tab (index 1)
                  if (widget.currentTabIndex == 1)
                    ElevatedButton(
                      onPressed: () {
                        HistoryBottomSheet.showCustomerHistory(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color.fromARGB(255, 176, 12, 1),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.history, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'View History',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Quick services section
            const Text(
              'Quick Services',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),            Row(
              children: [
                Expanded(
                  child: _buildQuickServiceCard(
                    icon: Icons.build,
                    title: 'Repair',
                    subtitle: 'Get mechanical help',
                    color: Colors.blue,
                    onTap: widget.hasActiveService ? _handleBlockedRequest : () {
                      // Navigate to vehicle service screen for mechanical repair
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const RequestAssistanceScreen(
                            initialServiceType: 'mechanical',
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildQuickServiceCard(
                    icon: Icons.local_gas_station,
                    title: 'Fuel',
                    subtitle: 'Emergency fuel delivery',
                    color: Colors.green,
                    onTap: widget.hasActiveService ? _handleBlockedRequest : () {
                      // Navigate to vehicle service screen for fuel delivery
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const RequestAssistanceScreen(
                            initialServiceType: 'fuel',
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
              const SizedBox(height: 12),
            
            Row(
              children: [
                Expanded(
                  child: _buildQuickServiceCard(
                    icon: Icons.lock_open,
                    title: 'Lockout Service',
                    subtitle: 'Car lockout assistance',
                    color: Colors.orange,
                    onTap: widget.hasActiveService ? _handleBlockedRequest : () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const RequestAssistanceScreen(
                            initialServiceType: 'lockout',
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildQuickServiceCard(
                    icon: Icons.battery_charging_full,
                    title: 'Jump Start',
                    subtitle: 'Battery assistance',
                    color: Colors.purple,
                    onTap: widget.hasActiveService ? _handleBlockedRequest : () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const RequestAssistanceScreen(
                            initialServiceType: 'electrical',
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
              // Emergency button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: widget.hasActiveService ? _handleBlockedRequest : () {
                  // Navigate to emergency assistance screen
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const RequestAssistanceScreen(
                        initialServiceType: 'emergency',
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.car_repair, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Vehicle Assistance',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
              const SizedBox(height: 24),
            
            // Available Shops Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 20,
                    spreadRadius: 0,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color.fromARGB(255, 176, 12, 1),
                              const Color.fromARGB(255, 200, 50, 20),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.store,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Available Shops',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            Text(
                              'Nearby automotive services',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_mechanicsLoading)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Color.fromARGB(255, 176, 12, 1),
                            ),
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color.fromARGB(255, 176, 12, 1).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color.fromARGB(255, 176, 12, 1).withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            '${_nearbyMechanics.length}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color.fromARGB(255, 176, 12, 1),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Mechanics List
                  _buildMechanicsList(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildQuickServiceCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildMechanicsList() {
    if (_mechanicsLoading) {
      return Container(
        height: 140,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.grey[50]!,
              Colors.grey[100]!,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 176, 12, 1).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color.fromARGB(255, 176, 12, 1)),
                  strokeWidth: 3,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Finding nearby shops...',
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    if (_nearbyMechanics.isEmpty) {
      return Container(
        height: 160, // Increased height to fit content
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.grey[50]!,
              Colors.grey[100]!,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min, // Added to prevent overflow
            children: [
              Container(
                padding: const EdgeInsets.all(12), // Reduced padding
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.search_off,
                  size: 28, // Reduced size
                  color: Colors.grey[400],
                ),
              ),
              const SizedBox(height: 8), // Reduced spacing
              Text(
                'No shops found nearby',
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 14, // Reduced font size
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6), // Reduced spacing
              ElevatedButton.icon(
                onPressed: _updateLocation,
                icon: const Icon(Icons.refresh, size: 14), // Reduced icon size
                label: const Text('Refresh', style: TextStyle(fontSize: 12)), // Reduced font size
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 176, 12, 1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), // Reduced padding
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    return Column(
      children: [
        // Show mechanics in a horizontal scroll with smaller height
        SizedBox(
          height: 160,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: math.min(_nearbyMechanics.length, 5),
            itemBuilder: (context, index) {
              final mechanic = _nearbyMechanics[index];
              return Container(
                width: 160,
                margin: EdgeInsets.only(
                  right: index < math.min(_nearbyMechanics.length, 5) - 1 ? 12 : 0,
                ),
                child: _buildMechanicCard(mechanic),
              );
            },
          ),
        ),
        if (_nearbyMechanics.length > 5) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _showAllMechanicsBottomSheet,
              icon: const Icon(Icons.list, size: 16),
              label: Text('View all ${_nearbyMechanics.length} shops'),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color.fromARGB(255, 176, 12, 1)),
                foregroundColor: const Color.fromARGB(255, 176, 12, 1),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMechanicCard(Map<String, dynamic> mechanic) {
    final shopName = mechanic['name'] ?? 'Unknown Shop';
    final distance = mechanic['distance']?.toStringAsFixed(1) ?? '0.0';
    final rating = mechanic['rating']?.toDouble() ?? 0.0;
    final isAvailable = mechanic['is_available'] ?? false;
    final businessAddress = mechanic['business_address'] ?? 'Address not available';
    
    return GestureDetector(
      onTap: () => _showShopDetailsBottomSheet(mechanic),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isAvailable 
              ? const Color.fromARGB(255, 176, 12, 1).withOpacity(0.3) 
              : Colors.grey[300]!,
            width: isAvailable ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              spreadRadius: 0,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with icon and status
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color.fromARGB(255, 176, 12, 1),
                        const Color.fromARGB(255, 200, 50, 20),
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.store,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: isAvailable 
                      ? Colors.green.withOpacity(0.1)
                      : Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isAvailable 
                        ? Colors.green.withOpacity(0.4) 
                        : Colors.orange.withOpacity(0.4),
                    ),
                  ),
                  child: Text(
                    isAvailable ? 'Open' : 'Busy',
                    style: TextStyle(
                      color: isAvailable ? Colors.green[800] : Colors.orange[800],
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            
            // Shop Name
            Text(
              shopName,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.black87,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            
            const SizedBox(height: 4),
            
            // Address
            Row(
              children: [
                Icon(
                  Icons.location_city,
                  color: Colors.grey[500],
                  size: 12,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    businessAddress,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 10,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 4),
            
            // Business Hours
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  color: Colors.grey[500],
                  size: 12,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    _formatBusinessHours(mechanic),
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            
            // Rating and distance
            Row(
              children: [
                Icon(
                  Icons.star_rounded,
                  color: Colors.amber[600],
                  size: 14,
                ),
                const SizedBox(width: 2),
                Text(
                  rating.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(255, 176, 12, 1).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.location_on_rounded,
                        color: const Color.fromARGB(255, 176, 12, 1),
                        size: 12,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '${distance}km',
                        style: const TextStyle(
                          color: Color.fromARGB(255, 176, 12, 1),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
    );
  }

  String _formatBusinessHours(Map<String, dynamic> shop) {
    try {
      final businessHours = shop['business_hours'];
      if (businessHours == null) return 'Hours not set';
      
      // Get current day name
      final now = DateTime.now();
      final dayNames = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
      final currentDay = dayNames[now.weekday - 1];
      
      // Get today's hours
      final todayHours = businessHours[currentDay];
      if (todayHours == null) return 'Closed today';
      
      final openTime = todayHours['open'] as String?;
      final closeTime = todayHours['close'] as String?;
      
      if (openTime == null || closeTime == null) return 'Closed today';
      if (openTime == 'closed' || closeTime == 'closed') return 'Closed today';
      
      return '${_formatTime(openTime)} - ${_formatTime(closeTime)}';
    } catch (e) {
      return 'Hours not available';
    }
  }

  String _formatTime(String time24) {
    try {
      final parts = time24.split(':');
      if (parts.length != 2) return time24;
      
      int hour = int.parse(parts[0]);
      final minute = parts[1];
      
      final period = hour >= 12 ? 'PM' : 'AM';
      if (hour > 12) hour -= 12;
      if (hour == 0) hour = 12;
      
      return '$hour:$minute$period';
    } catch (e) {
      return time24;
    }
  }

  // Check if shop is currently open based on business hours
  bool _isShopCurrentlyOpen(dynamic businessHours) {
    try {
      if (businessHours == null) return false;
      
      final now = DateTime.now();
      final dayNames = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
      final currentDay = dayNames[now.weekday - 1];
      
      // Get today's hours
      final todayHours = businessHours[currentDay];
      if (todayHours == null) return false;
      
      final openTime = todayHours['open'] as String?;
      final closeTime = todayHours['close'] as String?;
      
      // Check if closed today
      if (openTime == null || closeTime == null) return false;
      if (openTime == 'closed' || closeTime == 'closed') return false;
      
      // Parse times
      final openParts = openTime.split(':');
      final closeParts = closeTime.split(':');
      if (openParts.length != 2 || closeParts.length != 2) return false;
      
      final openHour = int.parse(openParts[0]);
      final openMinute = int.parse(openParts[1]);
      final closeHour = int.parse(closeParts[0]);
      final closeMinute = int.parse(closeParts[1]);
      
      // Create DateTime objects for comparison
      final currentTime = TimeOfDay(hour: now.hour, minute: now.minute);
      final openTimeOfDay = TimeOfDay(hour: openHour, minute: openMinute);
      final closeTimeOfDay = TimeOfDay(hour: closeHour, minute: closeMinute);
      
      // Convert to minutes for easier comparison
      final currentMinutes = currentTime.hour * 60 + currentTime.minute;
      final openMinutes = openTimeOfDay.hour * 60 + openTimeOfDay.minute;
      final closeMinutes = closeTimeOfDay.hour * 60 + closeTimeOfDay.minute;
      
      // Check if current time is within business hours
      return currentMinutes >= openMinutes && currentMinutes < closeMinutes;
    } catch (e) {
      print('Error checking shop open status: $e');
      return false; // If error, assume closed for safety
    }
  }

  void _viewShopServices(Map<String, dynamic> shopData) {
    // Block shop services access when customer has active service
    if (widget.hasActiveService) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Complete your current service before viewing other shops.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ShopServicesScreen(shopData: shopData),
      ),
    );
  }

  // New: Show shop details bottom sheet with map options
  void _showShopDetailsBottomSheet(Map<String, dynamic> shop) {
    final lat = shop['latitude'];
    final lng = shop['longitude'];
    final hasCoordinates = lat != null && lng != null && lat is num && lng is num;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                shop['name'] ?? 'Shop',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(shop['address'] ?? 'Address not available'),
              const SizedBox(height: 8),
              if (hasCoordinates) ...[
                Text('Latitude: ${lat.toString()}'),
                Text('Longitude: ${lng.toString()}'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.map_outlined),
                      label: const Text('View on Map'),
                      onPressed: () async {
                        // Open external Google Maps
                        final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=${lat},${lng}');
                        try {
                          await launchUrl(url, mode: LaunchMode.externalApplication);
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Could not open external map')),
                          );
                        }
                      },
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.build),
                      label: const Text('View Services'),
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => ShopServicesScreen(shopData: shop)),
                        );
                      },
                    ),
                  ],
                ),
              ] else ...[
                const SizedBox(height: 8),
                const Text('Location coordinates not available'),
              ],
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  // New: Open in-app map modal centered on shop location with a red marker and InfoWindow
  // Note: In-app map view removed per request. External 'View on Map' remains.

  // Helper method to handle blocked service requests
  void _handleBlockedRequest() {
    ScaffoldMessenger.of(context).showMaterialBanner(
      MaterialBanner(
        content: const Text(
          'Complete your current service before requesting a new one.',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.orange,
        actions: [
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
            },
            child: const Text(
              'OK',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
    
    // Auto-hide the banner after 4 seconds
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
      }
    });
  }
  
  void _showAllMechanicsBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                width: 50,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Available Shops (${_nearbyMechanics.length})',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              
              // Mechanics list
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _nearbyMechanics.length,
                  itemBuilder: (context, index) {
                    final mechanic = _nearbyMechanics[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: _buildDetailedMechanicCard(mechanic),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildDetailedMechanicCard(Map<String, dynamic> mechanic) {
    final shopName = mechanic['name'] ?? 'Unknown Shop';
    final ownerName = mechanic['owner_name'] ?? 'Shop Owner';
    final distance = mechanic['distance']?.toStringAsFixed(1) ?? '0.0';
    final rating = mechanic['rating']?.toDouble() ?? 0.0;
    final isAvailable = mechanic['is_available'] ?? false;
    final phone = mechanic['phone_number'] ?? '';
    final experience = mechanic['experience_years'] ?? 0;
    final mechanicsCount = mechanic['mechanics_count'] ?? 0;
    final businessAddress = mechanic['company_name'] ?? 'Address not provided';
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isAvailable ? const Color.fromARGB(255, 176, 12, 1).withOpacity(0.2) : Colors.grey[200]!,
          width: isAvailable ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: const Color.fromARGB(255, 176, 12, 1),
                      child: const Icon(
                        Icons.store,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    if (isAvailable)
                      Positioned(
                        right: 2,
                        bottom: 2,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              shopName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: isAvailable ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isAvailable ? Colors.green.withOpacity(0.3) : Colors.orange.withOpacity(0.3),
                              ),
                            ),
                            child: Text(
                              isAvailable ? 'Open' : 'Closed',
                              style: TextStyle(
                                color: isAvailable ? Colors.green[700] : Colors.orange[700],
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Owner: $ownerName',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.location_city, color: Colors.grey[500], size: 14),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              businessAddress,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.star_rounded, color: Colors.amber[600], size: 18),
                          const SizedBox(width: 4),
                          Text(
                            rating.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Icon(
                            Icons.location_on_rounded,
                            color: Colors.grey[500],
                            size: 18,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${distance}km away',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Mechanics count
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.build,
                              color: Colors.blue[700],
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$mechanicsCount available mechanic${mechanicsCount != 1 ? 's' : ''}',
                              style: TextStyle(
                                color: Colors.blue[700],
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (experience > 0) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.work_outline, color: Colors.grey[500], size: 16),
                            const SizedBox(width: 4),
                            Text(
                              '$experience years experience',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
              const SizedBox(height: 20),
            
            // Action buttons
            Row(
              children: [
                // View Services button
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context); // Close the bottom sheet
                      _viewShopServices(mechanic);
                    },
                    icon: const Icon(Icons.build, size: 18),
                    label: const Text('View Services'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 176, 12, 1),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                
                // Call button if phone is available
                if (phone.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        _callMechanic(phone);
                      },
                      icon: const Icon(Icons.phone_rounded, size: 18),
                      label: const Text('Call'),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color.fromARGB(255, 176, 12, 1)),
                        foregroundColor: const Color.fromARGB(255, 176, 12, 1),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  
  Future<void> _callMechanic(String phone) async {
    // Clean the phone number (remove spaces, dashes, etc.)
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    
    print('🔥 Attempting to call mechanic from list: $cleanPhone');
    print('🔥 Original phone: $phone');
    
    try {
      // Try multiple URI formats for better compatibility
      final uris = [
        Uri.parse('tel:$cleanPhone'),
        Uri.parse('tel://$cleanPhone'),
        Uri.parse('tel:+63${cleanPhone.startsWith('0') ? cleanPhone.substring(1) : cleanPhone}'),
      ];
      
      bool launched = false;
      
      for (final uri in uris) {
        print('🔥 Trying call URI: $uri');
        try {
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
            launched = true;
            print('✅ Phone call launched successfully with: $uri');
            break;
          }
        } catch (e) {
          print('❌ Failed with call URI: $uri - Error: $e');
        }
      }
      
      // Android intent strategy (between direct and dialer fallback)
      if (!launched && Platform.isAndroid) {
        print('🤖 Trying Android intent approach...');
        try {
          final intentUri = Uri.parse('intent://tel:$cleanPhone#Intent;scheme=tel;action=android.intent.action.CALL;end');
          await launchUrl(intentUri, mode: LaunchMode.externalApplication);
          launched = true;
          print('✅ Android intent call launched successfully');
        } catch (e) {
          print('❌ Android intent failed: $e');
        }
      }
      
      // If direct calling failed, try opening dialer (less permissions needed)
      if (!launched) {
        print('🔥 Trying dialer fallback...');
        for (final phoneNum in [cleanPhone, '+63${cleanPhone.startsWith('0') ? cleanPhone.substring(1) : cleanPhone}']) {
          try {
            final dialUri = Uri.parse('tel:$phoneNum');
            if (await canLaunchUrl(dialUri)) {
              await launchUrl(dialUri, mode: LaunchMode.platformDefault);
              launched = true;
              print('✅ Dialer opened successfully with: $dialUri');
              break;
            }
          } catch (e) {
            print('❌ Failed with dialer: tel:$phoneNum - Error: $e');
          }
        }
      }
      
      if (!launched) {
        print('❌ All URI formats failed');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Unable to make phone call to $cleanPhone.\n\nPlease dial manually:\n$phone'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 6),
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Phone call error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error making phone call: $e\n\nPlease dial manually:\n$phone'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    }
  }
}
