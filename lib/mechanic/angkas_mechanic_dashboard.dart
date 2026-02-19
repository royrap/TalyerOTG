import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'dart:math' as math;
import '../services/auth_service.dart';
import '../services/mechanic_service.dart';
import '../services/mechanic_history_service.dart';
import '../services/mechanic_request_service.dart';
import 'angkas_assigned_jobs_screen.dart';
import 'angkas_job_history_screen.dart';
import 'angkas_mechanic_profile_screen.dart';
import 'mechanic_waiting_payment_screen.dart';
import 'widgets/mechanic_job_tracking_bottom_sheet.dart';
import 'mechanic_location_based_dashboard.dart';
import '../widgets/history_bottom_sheet.dart';

class AngkasMechanicDashboard extends StatefulWidget {
  const AngkasMechanicDashboard({Key? key}) : super(key: key);

  @override
  State<AngkasMechanicDashboard> createState() => _AngkasMechanicDashboardState();
}

class _AngkasMechanicDashboardState extends State<AngkasMechanicDashboard>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  int _currentIndex = 0;
  bool _isOnline = false;
  bool _isProcessingRequest = false;
  StreamSubscription? _requestSubscription;
  StreamSubscription? _timeoutSubscription;
  late AnimationController _pulseController;
  late AnimationController _slideController;
  late AnimationController _bottomSheetController;
  late Animation<double> _pulseAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _bottomSheetAnimation;

  // Bottom sheet state for active jobs
  bool _hasActiveJob = false;
  Map<String, dynamic>? _activeJobData;
  String? _activeServiceRequestId;
  Timer? _jobCheckTimer; // Timer for periodic job checking
  Timer? _bottomSheetCheckTimer; // Timer to ensure bottom sheet stays visible
  StreamSubscription? _jobAcceptedSubscription; // Listen for job acceptance events
  
  // Track shown request IDs to prevent duplicates
  final Set<String> _shownRequestIds = <String>{};

  late List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Initialize animations
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
    
    _slideController = AnimationController(
      // Unified animation duration
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _bottomSheetController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    _slideAnimation = Tween<Offset>(
      // Unified offset for subtle upward slide
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));

    _bottomSheetAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _bottomSheetController,
      curve: Curves.easeInOut,
    ));
    
    _screens = _buildScreens();
    
    _initializeRequestListening();
    _initializeMechanicAvailability();
    _initializeJobAcceptedListener(); // Listen for job acceptance events
    _restoreActiveJobState(); // Restore active job if exists
    _startPeriodicJobCheck(); // Start periodic check for job persistence
    _startBottomSheetMonitoring(); // Ensure bottom sheet stays visible
    _slideController.forward();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _requestSubscription?.cancel();
    _timeoutSubscription?.cancel();
    _jobAcceptedSubscription?.cancel();
    _jobCheckTimer?.cancel(); // Cancel periodic job check
    _bottomSheetCheckTimer?.cancel(); // Cancel bottom sheet monitoring
    _pulseController.dispose();
    _slideController.dispose();
    _bottomSheetController.dispose();
    MechanicRequestService.instance.stopListening();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        print('🔄 App resumed - checking for active jobs...');
        if (_isOnline) {
          _startRequestListening();
        }
        // Always check for active job restoration when app resumes
        Future.delayed(const Duration(milliseconds: 300), () {
          _restoreActiveJobState();
        });
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        break;
      case AppLifecycleState.detached:
        MechanicRequestService.instance.stopListening();
        break;
    }
  }

  Future<void> _initializeRequestListening() async {
    try {
      _requestSubscription = MechanicRequestService.instance
          .incomingRequestStream
          .listen(_handleIncomingRequest);

      _timeoutSubscription = MechanicRequestService.instance
          .requestTimeoutStream
          .listen(_handleRequestTimeout);

      final wasOnline = await _getMechanicOnlineStatus();
      if (wasOnline) {
        await _setOnlineStatus(true);
      }
    } catch (e) {
      print('❌ Error initializing request listening: $e');
    }
  }

  Future<void> _initializeJobAcceptedListener() async {
    try {
      print('👂 Initializing job accepted listener...');
      _jobAcceptedSubscription = MechanicRequestService.instance.jobAcceptedStream.listen((event) {
        if (mounted) {
          print('🎉 Job accepted event received: ${event['request_id']}');
          setState(() {
            _hasActiveJob = true;
            _activeServiceRequestId = event['request_id'];
            _activeJobData = {
              'job_status': event['job_details']['status'],
              'customer_name': '${event['customer_details']['first_name']} ${event['customer_details']['last_name']}',
              'customer_phone': event['customer_details']['phone_number'],
              'pickup_address': event['job_details']['pickup_address'],
              'service_type': event['job_details']['service_type'],
              'title': event['job_details']['title'],
              'pickup_latitude': event['job_details']['pickup_latitude'],
              'pickup_longitude': event['job_details']['pickup_longitude'],
            };
          });
          
          // Expand bottom sheet immediately
          _bottomSheetController.forward();
          
          print('✅ Active job set from acceptance: $_activeServiceRequestId');
        }
      });
      print('✅ Job accepted listener initialized');
    } catch (e) {
      print('❌ Error initializing job accepted listener: $e');
    }
  }

  void _startBottomSheetMonitoring() {
    print('🔍 Starting bottom sheet monitoring...');
    _bottomSheetCheckTimer?.cancel();
    _bottomSheetCheckTimer = Timer.periodic(Duration(seconds: 2), (timer) {
      // Only keep expanded if on home tab and job is not completed/cancelled
      if (_currentIndex == 0 && _hasActiveJob && _activeJobData != null && 
          !['completed', 'cancelled'].contains(_activeJobData!['job_status']?.toString().toLowerCase()) &&
          !_bottomSheetController.isCompleted) {
        // Force bottom sheet to stay expanded
        _bottomSheetController.forward();
        print('🔧 Bottom sheet re-expanded for active job on home tab');
      }
    });
    print('✅ Bottom sheet monitoring started');
  }

  Future<void> _initializeMechanicAvailability() async {
    try {
      print('🔧 Initializing mechanic availability status...');
      final success = await MechanicService.instance.ensureMechanicAvailabilityStatus();
      if (success) {
        print('✅ Mechanic availability status initialized');
      } else {
        print('❌ Failed to initialize mechanic availability status');
      }
    } catch (e) {
      print('❌ Error initializing mechanic availability: $e');
    }
  }

  Future<bool> _getMechanicOnlineStatus() async {
    try {
      final user = AuthService.instance.currentUser;
      if (user == null) return false;
      return false;
    } catch (e) {
      return false;
    }
  }

  void _handleIncomingRequest(Map<String, dynamic> requestData) {
    final requestId = requestData['request_id'] as String?;
    final requestStatus = requestData['status'] as String?;
    
    // Enhanced duplicate and validity suppression
    if (requestId == null || _shownRequestIds.contains(requestId) || 
        _activeServiceRequestId == requestId || _isProcessingRequest) {
      debugPrint('⚠️ Skipping duplicate incoming request popup for $requestId');
      return;
    }
    
    // Skip if request is no longer available (already accepted by someone else)
    if (requestStatus != null && !['pending', 'broadcasted'].contains(requestStatus.toLowerCase())) {
      debugPrint('⚠️ Skipping request $requestId with invalid status: $requestStatus');
      return;
    }
    
    // Add request ID to shown set
    _shownRequestIds.add(requestId);
    
    HapticFeedback.heavyImpact();
    
    // Check if widget is still mounted before showing dialog
    if (!mounted) {
      debugPrint('⚠️ Widget disposed, skipping dialog');
      return;
    }
    
    // Show popup notification for new requests
    debugPrint('📬 New request received: $requestId - showing popup');
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AngkasRequestPopup(
        requestData: requestData,
        onAccept: () {
          // Remove from shown set when accepting (will be handled)
          _shownRequestIds.remove(requestId);
          _acceptRequest(requestData);
        },
        onReject: () {
          // Remove from shown set when rejecting
          _shownRequestIds.remove(requestId);
          _rejectRequest(requestData);
        },
      ),
    ).then((_) {
      // Clean up if dialog is dismissed in other ways
      _shownRequestIds.remove(requestId);
    });
  }

  void _handleRequestTimeout(String requestId) {
    debugPrint('⏰ Request timeout for: $requestId');
    
    // Check if widget is still mounted before accessing context
    if (!mounted) {
      debugPrint('⚠️ Widget disposed, skipping timeout handler');
      return;
    }
    
    // Remove the request from shown set
    _shownRequestIds.remove(requestId);
    
    // Only try to pop dialogs if we're still mounted
    try {
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      debugPrint('⚠️ Error popping dialogs: $e');
    }
    
    // Only show snackbar if still mounted
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.access_time, color: Colors.white),
              SizedBox(width: 8),
              Text('Request timed out'),
            ],
          ),
          backgroundColor: Colors.orange[700],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  Future<void> _acceptRequest(Map<String, dynamic> requestData) async {
    if (_isProcessingRequest) {
      print('🔄 Dashboard: Already processing request, ignoring duplicate attempt');
      return;
    }

    Navigator.of(context).pop();

    if (mounted) {
      setState(() => _isProcessingRequest = true);
    }

    try {
      print('🎯 Dashboard: Attempting to accept request: ${requestData['request_id']}');
      print('🎯 Dashboard: Routing ID: ${requestData['routing_id']}');
      // Defensive shop check: prevent calling accept if mechanic not assigned to the request's shop
      // Resolve shop_id: prefer payload value but fall back to DB row if missing
      String? requestShopId = requestData['shop_id']?.toString();
      if (requestShopId == null) {
        try {
          final fetched = await Supabase.instance.client
              .from('service_requests')
              .select('shop_id')
              .eq('id', requestData['request_id'])
              .maybeSingle();
          if (fetched != null && fetched['shop_id'] != null) {
            requestShopId = fetched['shop_id']?.toString();
            print('ℹ️ Fetched canonical shop_id for request: $requestShopId');
          }
        } catch (e) {
          print('⚠️ Error fetching request shop_id from DB: $e');
        }
      }

      if (requestShopId != null) {
        String? mechanicShopId;
        try {
          // Resolve current mechanic user id
          final mechanicUserId = Supabase.instance.client.auth.currentUser?.id ?? AuthService.instance.currentUser?.id;
          if (mechanicUserId != null) {
            // Try service_providers first
            final sp = await Supabase.instance.client
                .from('service_providers')
                .select('shop_id')
                .eq('user_id', mechanicUserId)
                .maybeSingle();
            if (sp != null && sp['shop_id'] != null) mechanicShopId = sp['shop_id']?.toString();

            // Fallback to mechanics table
            if (mechanicShopId == null) {
              final m = await Supabase.instance.client
                  .from('mechanics')
                  .select('shop_id')
                  .eq('user_id', mechanicUserId)
                  .maybeSingle();
              if (m != null && m['shop_id'] != null) mechanicShopId = m['shop_id']?.toString();
            }

            // Fallback to shop_mechanics mapping (pick first active)
            if (mechanicShopId == null) {
              final sm = await Supabase.instance.client
                  .from('shop_mechanics')
                  .select('shop_id')
                  .eq('mechanic_id', mechanicUserId)
                  .eq('is_active', true)
                  .limit(1)
                  .maybeSingle();
              if (sm != null && sm['shop_id'] != null) mechanicShopId = sm['shop_id']?.toString();
            }
          }
        } catch (e) {
          print('⚠️ Error resolving mechanic shop id: $e');
        }

        if (mechanicShopId == null || mechanicShopId != requestShopId) {
          print('❌ Local guard: mechanic shop does not match request shop (mechanic=$mechanicShopId, request=$requestShopId)');
          // Before bailing out locally, attempt a server-side validation RPC which will raise the same P0001
          // error if the mechanic is not allowed to accept. This produces a consistent server-side message.
          try {
            final mechanicUserId = Supabase.instance.client.auth.currentUser?.id ?? AuthService.instance.currentUser?.id;
            if (mechanicUserId != null) {
              print('🔍 Calling validate_mechanic_shop_for_request RPC for mechanic=$mechanicUserId request=${requestData['request_id']}');
              final rpcRes = await Supabase.instance.client.rpc('validate_mechanic_shop_for_request', params: {
                'p_request_id': requestData['request_id'],
                'p_mechanic_user_id': mechanicUserId,
              }).maybeSingle();

              // If RPC returns successfully, proceed. The validation function returns boolean true on success.
              // If it raises an exception (P0001), it will be caught below.
              if (rpcRes == true) {
                print('✅ Server validation passed for mechanic=$mechanicUserId');
                // allow acceptance to continue
              } else {
                print('❌ Server validation returned unexpected value: $rpcRes');
                _showErrorSnackBar('You cannot accept a request for a different shop.');
                return;
              }
            } else {
              // No mechanic id available; show error
              _showErrorSnackBar('❌ Error: User not properly authenticated');
              return;
            }
          } catch (e) {
            // If server raised P0001 it will surface here — show friendly message
            final err = e.toString();
            if (err.contains('Shop isolation violation') || err.contains('P0001')) {
              _showErrorSnackBar('❌ Shop isolation violation: This mechanic is not assigned to the selected shop.');
              print('❌ Server validation failed: $err');
              return;
            }

            // Other errors fall back to local guard message
            _showErrorSnackBar('You cannot accept a request for a different shop.');
            return;
          }
        }
      }
      
      final success = await MechanicRequestService.instance.acceptRequest(
        requestData['routing_id'],
        requestData['request_id'],
        isLocationBased: requestData['is_location_based'] ?? false,
      );

      if (success) {
        HapticFeedback.heavyImpact();
        _showSuccessSnackBar('✅ Request accepted! Waiting for customer payment...');

        // Get proper mechanic ID using the same method as the service
        final mechanicUserId = Supabase.instance.client.auth.currentUser?.id ?? AuthService.instance.currentUser?.id;
        if (mechanicUserId == null || mechanicUserId.isEmpty) {
          print('❌ Dashboard: No valid mechanic user ID available');
          _showErrorSnackBar('❌ Error: User not properly authenticated');
          return;
        }

        print('✅ Dashboard: Got mechanic user ID: $mechanicUserId');
        await _setOnlineStatus(false);

        // Navigate to waiting payment screen first
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MechanicWaitingPaymentScreen(
              serviceRequestId: requestData['request_id'],
              customerInfo: {
                'customer_id': requestData['customer_id'],
                'customer_name': requestData['customer_name'],
                'phone_number': requestData['customer_phone'],
                'profile_image_url': null,
                'pickup_latitude': requestData['pickup_latitude'],
                'pickup_longitude': requestData['pickup_longitude'],
                'pickup_address': requestData['pickup_address'],
                'service_type': requestData['service_type'],
                'description': requestData['description'],
              },
              mechanicInfo: {
                'id': mechanicUserId,
                'full_name': '',
                'phone_number': '',
                'profile_image_url': null,
              },
              onPaymentReceived: () {
                // After payment, return to dashboard and show persistent bottom sheet
                print('💰 Payment received callback triggered! Returning to dashboard...');
                Navigator.of(context).pop();
                _showPersistentJobBottomSheet(requestData);
              },
            ),
          ),
        );
      } else {
        print('❌ Dashboard: Request acceptance failed - showing specific error');
        _showErrorSnackBar('❌ Unable to accept job. Another mechanic may have taken it, or the request was cancelled.');
      }
    } catch (e) {
      print('❌ Dashboard: Exception during acceptance: $e');
      _showErrorSnackBar('❌ Error accepting job: $e');
    } finally {
      if (mounted) {
        setState(() => _isProcessingRequest = false);
      }
    }
  }

  void _completeJob() {
    // Handle job completion - this should only be called when QR scanning is successful
    print('🎉 Job completion confirmed via QR scanning');
    if (mounted) {
      setState(() {
        _hasActiveJob = false;
        _activeJobData = null;
        _activeServiceRequestId = null;
      });
    }
    
    // Animate the bottom sheet away
    _bottomSheetController.reverse();
    
    // Show success message after a short delay to ensure clean UI transition
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _showSuccessSnackBar('✅ Job completed successfully! Customer has been notified.');
      }
    });
  }

  void _cancelJob() {
    // Handle job cancellation
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Job'),
        content: const Text('Are you sure you want to cancel this job? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Keep Job'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                _hasActiveJob = false;
                _activeJobData = null;
                _activeServiceRequestId = null;
              });
              _bottomSheetController.reverse();
              _showInfoSnackBar('Job cancelled');
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Cancel Job', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _toggleJobBottomSheet() {
    // Keep the bottom sheet always visible while a job is active
    if (!_bottomSheetController.isCompleted) {
      _bottomSheetController.forward();
    } else {
      // Already expanded - do nothing (prevent hiding/minimizing)
      _showInfoSnackBar('Job panel stays visible while a job is active.');
    }
  }

  Widget _buildJobToggleButton() {
    return Positioned(
      right: 16,
      bottom: 100, // Position above bottom navigation
      child: AnimatedBuilder(
        animation: _bottomSheetAnimation,
        builder: (context, child) {
          // Only show toggle button when bottom sheet is minimized
          return _bottomSheetAnimation.value < 0.5
              ? FloatingActionButton(
                  heroTag: "job_toggle_button",
                  onPressed: _toggleJobBottomSheet,
                  backgroundColor: const Color(0xFFEF5350),
                  child: const Icon(
                    Icons.work,
                    color: Colors.white,
                  ),
                )
              : const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildPersistentJobBottomSheet() {
    return AnimatedBuilder(
      animation: _bottomSheetAnimation,
      builder: (context, child) {
        final double sheetHeight = MediaQuery.of(context).size.height * 0.75;
        final double minHeight = 80; // Minimized height showing just a bar
        
        final double currentHeight = minHeight + 
            (sheetHeight - minHeight) * _bottomSheetAnimation.value;
        
        return Positioned(
          left: 0,
          right: 0,
          bottom: kBottomNavigationBarHeight, // Position above the navbar
          child: GestureDetector(
            onTap: _bottomSheetAnimation.value < 0.5 ? _toggleJobBottomSheet : null,
            onPanUpdate: (details) {
              // Handle drag to resize
              final double delta = details.delta.dy;
              final double newValue = _bottomSheetAnimation.value - 
                  (delta / (sheetHeight - minHeight));
              _bottomSheetController.value = newValue.clamp(0.0, 1.0);
            },
            onPanEnd: (details) {
              // Snap to expanded or collapsed based on velocity and position
              if (details.velocity.pixelsPerSecond.dy > 300 || 
                  _bottomSheetAnimation.value < 0.3) {
                _bottomSheetController.reverse();
              } else {
                _bottomSheetController.forward();
              }
            },
            child: Container(
              height: math.max(currentHeight, minHeight),
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
                  ? _buildMinimizedJobBar()
                  : _buildExpandedJobSheet(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMinimizedJobBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Active job indicator
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withOpacity(0.3),
                  blurRadius: 6,
                  spreadRadius: 0,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          
          // Job info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      'ACTIVE JOB',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF5350),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'ONGOING',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Flexible(
                      flex: 2,
                      child: Text(
                        _activeJobData?['customer_name'] ?? 'Customer',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A1A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      flex: 1,
                      child: Text(
                        '• ${_activeJobData?['service_type'] ?? 'Service'}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Quick action button (call customer)
          if (_activeJobData?['phone_number'] != null && 
              _activeJobData!['phone_number'].toString().isNotEmpty)
            Container(
              margin: const EdgeInsets.only(right: 8),
              child: IconButton(
                onPressed: () {
                  // Quick call functionality in minimized state
                  final phone = _activeJobData!['phone_number'].toString();
                  // Add your call functionality here
                  _showSuccessSnackBar('📞 Calling $phone...');
                },
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.blue[100],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    Icons.phone,
                    color: Colors.blue[700],
                    size: 16,
                  ),
                ),
              ),
            ),
          
          // Tap to expand indicator
          Icon(
            Icons.keyboard_arrow_up,
            color: Colors.grey[600],
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedJobSheet() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Drag handle
        Container(
          margin: const EdgeInsets.only(top: 8),
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        
        // Persistent indicator with active job badge
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'ACTIVE JOB',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ),
        
        // Bottom sheet content
        Expanded(
          child: MechanicJobTrackingBottomSheet(
            serviceRequestId: _activeServiceRequestId!,
            customerInfo: _activeJobData!,
            onCancelJob: _cancelJob,
            onJobCompleted: _completeJob, // This will only be called when QR scanning is successful
          ),
        ),
      ],
    );
  }

  void _showPersistentJobBottomSheet(Map<String, dynamic> requestData) {
    // Show persistent bottom sheet after payment is received
    setState(() {
      _hasActiveJob = true;
      _activeServiceRequestId = requestData['request_id'];
      _activeJobData = {
        'service_request_id': requestData['request_id'],
        'customer_id': requestData['customer_id'],
        'customer_name': requestData['customer_name'],
        'phone_number': requestData['customer_phone'],
        'profile_image_url': null,
        'pickup_latitude': requestData['pickup_latitude'],
        'pickup_longitude': requestData['pickup_longitude'],
        'pickup_address': requestData['pickup_address'],
        'service_type': requestData['service_type'],
        'description': requestData['description'],
        'job_status': requestData['status'] ?? 'in_progress', // Track job status
      };
    });

    // Always expand the sheet when job starts
    _bottomSheetController.forward();
    _showSuccessSnackBar('💰 Payment received! Job started - job panel pinned open.');
  }

  // Restore active job state when dashboard loads
  Future<void> _restoreActiveJobState() async {
    try {
      print('🔄 Checking for existing active job to restore...');
      final activeJobData = await MechanicService.instance.getCurrentActiveJob();
      
      if (activeJobData != null) {
        print('✅ Active job found: ${activeJobData['request_id']}');
        print('📊 Current state: _hasActiveJob=$_hasActiveJob, _activeServiceRequestId=$_activeServiceRequestId');
        print('📊 Bottom sheet controller value: ${_bottomSheetController.value}');
        
        // Check if widget is still mounted before calling setState
        if (!mounted) {
          print('⚠️ Widget disposed, skipping state update');
          return;
        }
        
        // Force update the state even if it was already set
        if (!_hasActiveJob || _activeServiceRequestId != activeJobData['request_id']) {
          print('🔧 Updating active job state...');
          setState(() {
            _hasActiveJob = true;
            _activeServiceRequestId = activeJobData['request_id'];
            _activeJobData = activeJobData;
            // Rebuild screens to pass new data
            _screens = _buildScreens();
          });
        }
        
        // Always expand the bottom sheet for active jobs
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted && _hasActiveJob) {
            print('📌 Active job detected - expanding bottom sheet.');
            _bottomSheetController.forward();
          }
        });
      } else {
        print('ℹ️ No active job to restore');
        // Check if widget is still mounted before calling setState
        if (!mounted) {
          print('⚠️ Widget disposed, skipping state update');
          return;
        }
        
        // If no active job found but we think we have one, clear the state
        if (_hasActiveJob) {
          print('🧹 Clearing stale active job state...');
          setState(() {
            _hasActiveJob = false;
            _activeJobData = null;
            _activeServiceRequestId = null;
          });
          _bottomSheetController.reverse();
        }
      }
    } catch (e) {
      print('❌ Error restoring active job: $e');
    }
  }

  // Start periodic check to ensure bottom sheet stays visible for active jobs
  void _startPeriodicJobCheck() {
    _jobCheckTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      // Only check if we think we have an active job or if we might have missed one
      if (_hasActiveJob || !_hasActiveJob) {
        print('🔄 Periodic job check...');
        await _restoreActiveJobState();
      }
    });
  }

  Future<void> _rejectRequest(Map<String, dynamic> requestData) async {
    Navigator.of(context).pop();

    try {
      final success = await MechanicRequestService.instance.rejectRequest(
        requestData['routing_id'],
        requestData['request_id'],
        isLocationBased: requestData['is_location_based'] ?? false,
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.block, color: Colors.white),
                SizedBox(width: 8),
                Text('Job declined'),
              ],
            ),
            backgroundColor: Colors.grey[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      print('❌ Error rejecting job: $e');
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showInfoSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.blue[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _toggleOnlineStatus() async {
    await _setOnlineStatus(!_isOnline);
  }

  Future<void> _setOnlineStatus(bool online) async {
    try {
      if (online) {
        await _startRequestListening();
      } else {
        await _stopRequestListening();
      }

      setState(() {
        _isOnline = online;
        // Update the home screen with new online status
        _screens[0] = _AngkasHomeScreen(
          onToggleOnline: _toggleOnlineStatus,
          isOnline: _isOnline,
          pulseAnimation: _pulseAnimation,
          hasActiveJob: _hasActiveJob,
          activeJobData: _activeJobData,
          activeServiceRequestId: _activeServiceRequestId,
        );
      });

      HapticFeedback.lightImpact();
    } catch (e) {
      _showErrorSnackBar('Failed to ${online ? 'go online' : 'go offline'}: $e');
    }
  }

  Future<void> _startRequestListening() async {
    try {
      // Show loading state
      _showInfoSnackBar('Going online...');
      
      final success = await MechanicRequestService.instance.updateAvailabilityStatus(
        status: 'available',
        isAcceptingRequests: true,
      );

      if (success) {
        await MechanicRequestService.instance.startListening();
        print('✅ Mechanic is now online and accepting requests');
        _showSuccessSnackBar('You are now online and ready to receive job requests');
      } else {
        throw Exception('Failed to update availability status');
      }
    } catch (e) {
      print('❌ Error starting request listening: $e');
      String errorMessage = 'Unable to go online';
      if (e.toString().contains('duplicate key')) {
        errorMessage = 'Status update in progress, please try again';
      } else if (e.toString().contains('network')) {
        errorMessage = 'Network error, please check your connection';
      } else if (e.toString().contains('permission')) {
        errorMessage = 'Permission denied, please check your account status';
      }
      _showErrorSnackBar(errorMessage);
      rethrow;
    }
  }

  Future<void> _stopRequestListening() async {
    try {
      await MechanicRequestService.instance.updateAvailabilityStatus(
        status: 'offline',
        isAcceptingRequests: false,
      );

      MechanicRequestService.instance.stopListening();
      print('✅ Mechanic is now offline');
    } catch (e) {
      print('❌ Error stopping request listening: $e');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        final shouldClose = await showDialog<bool>(
          context: context,
          builder: (context) => AngkasExitDialog(isOnline: _isOnline),
        );

        if (shouldClose == true && _isOnline) {
          await _setOnlineStatus(false);
        }

        return shouldClose ?? false;
      },
      child: SlideTransition(
        position: _slideAnimation,
        child: Stack(
          children: [
            Scaffold(
              backgroundColor: const Color(0xFFF8F9FA),
              body: _screens[_currentIndex],
              bottomNavigationBar: AngkasBottomNav(
                currentIndex: _currentIndex,
                onTap: (index) {
                  setState(() {
                    _currentIndex = index;
                    // Rebuild screens to force animation re-init for history/profile
                    _screens = _buildScreens();
                  });
                  HapticFeedback.selectionClick();
                },
                isOnline: _isOnline,
              ),
            ),
            
            // Bottom sheet for active job tracking (only visible on home tab)
            // Shows for ALL active jobs until they are completed or cancelled
            if (_currentIndex == 0 && _hasActiveJob && _activeJobData != null && _activeServiceRequestId != null &&
                !['completed', 'cancelled'].contains(_activeJobData!['job_status']?.toString().toLowerCase())) ...[
              _buildPersistentJobBottomSheet(),
            ],
              
            // Floating toggle button (only visible on home tab)
            if (_currentIndex == 0 && _hasActiveJob && _activeJobData != null && _activeServiceRequestId != null &&
                !['completed', 'cancelled'].contains(_activeJobData!['job_status']?.toString().toLowerCase()))
              _buildJobToggleButton(),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildScreens() {
    return [
      _AngkasHomeScreen(
        onToggleOnline: _toggleOnlineStatus,
        isOnline: _isOnline,
        pulseAnimation: _pulseAnimation,
        // Pass active job data to home screen
        hasActiveJob: _hasActiveJob,
        activeJobData: _activeJobData,
        activeServiceRequestId: _activeServiceRequestId,
      ),
      const AngkasJobsScreen(),
      // Earnings tab removed - earnings info shown in history instead
      // New instances each tab visit so their AnimationController restarts
      const AngkasJobHistoryScreen(),
      const AngkasMechanicProfileScreen(),
    ];
  }
}

// Custom Bottom Navigation Bar
class AngkasBottomNav extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final bool isOnline;

  const AngkasBottomNav({
    Key? key,
    required this.currentIndex,
    required this.onTap,
    required this.isOnline,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            spreadRadius: 0,
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: currentIndex,
        onTap: onTap,
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedItemColor: const Color(0xFFEF5350),
        unselectedItemColor: Colors.grey[600],
        selectedFontSize: 12,
        unselectedFontSize: 11,
        items: [
          _buildNavItem(Icons.home_rounded, 'Home', 0),
          _buildNavItem(Icons.work_rounded, 'Jobs', 1),
          // Earnings tab removed - info shown in history
          _buildNavItem(Icons.history_rounded, 'History', 2),
          _buildNavItem(Icons.person_rounded, 'Profile', 3),
        ],
      ),
    );
  }

  BottomNavigationBarItem _buildNavItem(IconData icon, String label, int index) {
    final isSelected = currentIndex == index;
    
    return BottomNavigationBarItem(
      icon: Container(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Stack(
          children: [
            Icon(
              icon,
              size: isSelected ? 26 : 24,
              color: isSelected ? const Color(0xFFEF5350) : Colors.grey[600],
            ),
            if (index == 0 && isOnline)
              Positioned(
                top: 0,
                right: 0,
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
      label: label,
    );
  }
}

// Modern Home Screen
class _AngkasHomeScreen extends StatefulWidget {
  final VoidCallback onToggleOnline;
  final bool isOnline;
  final Animation<double> pulseAnimation;
  final bool hasActiveJob;
  final Map<String, dynamic>? activeJobData;
  final String? activeServiceRequestId;

  const _AngkasHomeScreen({
    required this.onToggleOnline,
    required this.isOnline,
    required this.pulseAnimation,
    required this.hasActiveJob,
    this.activeJobData,
    this.activeServiceRequestId,
  });

  @override
  State<_AngkasHomeScreen> createState() => _AngkasHomeScreenState();
}

class _AngkasHomeScreenState extends State<_AngkasHomeScreen> 
    with TickerProviderStateMixin {
  Map<String, dynamic> _stats = {};
  bool _isLoading = true;
  Timer? _refreshTimer;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));
    
    _loadStats();
    _startPeriodicRefresh();
    _slideController.forward();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _slideController.dispose();
    super.dispose();
  }

  void _startPeriodicRefresh() {
    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) {
        _loadStats();
      }
    });
  }

  Future<void> _loadStats() async {
    try {
      setState(() => _isLoading = true);
      final stats = await MechanicHistoryService.instance.getDashboardStats();
      if (mounted) {
        setState(() {
          _stats = stats;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SlideTransition(
        position: _slideAnimation,
        child: RefreshIndicator(
          onRefresh: _loadStats,
          color: const Color(0xFFEF5350),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Header
                _buildTopHeader(),
                
                // Online Status Card
                _buildOnlineStatusCard(),
                
                // Stats Grid
                _buildStatsGrid(),
                
                // Quick Actions
                _buildQuickActions(),
                
                // Recent Activity
                _buildRecentActivity(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _getGreeting(),
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              FutureBuilder<String>(
                future: _getMechanicName(),
                builder: (context, snapshot) {
                  return Text(
                    snapshot.data ?? 'Mechanic',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
                    ),
                  );
                },
              ),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: widget.isOnline ? Colors.red[50] : Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: widget.isOnline ? Colors.red[200]! : Colors.grey[300]!,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: widget.isOnline ? Colors.red : Colors.grey,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  widget.isOnline ? 'ONLINE' : 'OFFLINE',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: widget.isOnline ? Colors.red[700] : Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOnlineStatusCard() {
    return Container(
      margin: const EdgeInsets.all(20),
      child: AnimatedBuilder(
        animation: widget.pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: widget.isOnline ? widget.pulseAnimation.value : 1.0,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: widget.isOnline
                      ? [const Color(0xFFEF5350), const Color(0xFFE53935)]
                      : [Colors.grey[700]!, Colors.grey[800]!],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: (widget.isOnline ? const Color(0xFFEF5350) : Colors.grey[700]!)
                        .withOpacity(0.4),
                    spreadRadius: 0,
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Icon(
                    widget.isOnline ? Icons.radio_button_checked : Icons.radio_button_off,
                    color: Colors.white,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.isOnline 
                        ? 'You\'re Online and Ready!'
                        : 'Tap to Go Online',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.isOnline
                        ? 'Accepting new service requests'
                        : 'Start receiving job requests',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: widget.onToggleOnline,
                    icon: Icon(
                      widget.isOnline ? Icons.pause : Icons.play_arrow,
                      size: 24,
                    ),
                    label: Text(
                      widget.isOnline ? 'Go Offline' : 'Go Online',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: widget.isOnline ? const Color(0xFFEF5350) : Colors.grey[700],
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatsGrid() {
    if (_isLoading) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        child: GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          childAspectRatio: 1.4,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          children: List.generate(4, (index) => _buildLoadingStatCard()),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        // Slightly wider tiles to reduce vertical crowding
        childAspectRatio: 1.55,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        children: [
          _AngkasStatCard(
            title: 'Today\'s Jobs',
            value: _stats['completedToday']?.toString() ?? '0',
            icon: Icons.build_rounded,
            color: const Color(0xFF1976D2),
            gradient: const LinearGradient(
              colors: [Color(0xFF1976D2), Color(0xFF1565C0)],
            ),
          ),
          _AngkasStatCard(
            title: 'Today\'s Earnings',
            value: '₱${(_stats['earningsToday'] ?? 0.0).toStringAsFixed(0)}',
            icon: Icons.account_balance_wallet_rounded,
            color: const Color(0xFFEF5350),
            gradient: const LinearGradient(
              colors: [Color(0xFFEF5350), Color(0xFFEF5350)],
            ),
          ),
          _AngkasStatCard(
            title: 'Active Jobs',
            value: _stats['activeJobs']?.toString() ?? '0',
            icon: Icons.work_rounded,
            color: const Color(0xFFE65100),
            gradient: const LinearGradient(
              colors: [Color(0xFFE65100), Color(0xFFD84315)],
            ),
          ),
          _AngkasStatCard(
            title: 'Rating',
            value: '${(_stats['averageRating'] ?? 0.0).toStringAsFixed(1)}⭐',
            icon: Icons.star_rounded,
            color: const Color(0xFFF57C00),
            gradient: const LinearGradient(
              colors: [Color(0xFFF57C00), Color(0xFFEF6C00)],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Container(
      margin: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _AngkasActionCard(
                  title: 'Nearby Requests',
                  icon: Icons.location_on_outlined,
                  color: const Color(0xFFEF5350),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const MechanicLocationBasedDashboard(),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _AngkasActionCard(
                  title: 'My Jobs',
                  icon: Icons.work_outline_rounded,
                  color: const Color(0xFF1976D2),
                  onTap: () {
                    // Switch to Jobs tab (index 1)
                    final parentState = context.findAncestorStateOfType<_AngkasMechanicDashboardState>();
                    if (parentState != null) {
                      parentState.setState(() {
                        parentState._currentIndex = 1;
                      });
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _AngkasActionCard(
                  title: 'History',
                  icon: Icons.history_rounded,
                  color: const Color(0xFFFF8F00),
                  onTap: () {
                    HistoryBottomSheet.showMechanicHistory(context);
                  },
                ),
              ),

            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivity() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent Activity',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  spreadRadius: 0,
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Icon(
                  Icons.history_rounded,
                  size: 48,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 12),
                Text(
                  'No recent activity',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your completed jobs will appear here',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingStatCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            spreadRadius: 0,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: 60,
              height: 20,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: 80,
              height: 12,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  Future<String> _getMechanicName() async {
    try {
      final profile = AuthService.instance.userProfile;
      if (profile != null) {
        final firstName = profile['first_name'] ?? '';
        final lastName = profile['last_name'] ?? '';
        return '$firstName $lastName'.trim();
      }
      return 'Mechanic';
    } catch (e) {
      return 'Mechanic';
    }
  }
}

// Custom Stat Card
class _AngkasStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final Gradient gradient;

  const _AngkasStatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            spreadRadius: 0,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.22),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: Colors.white, size: 20),
                ),
                // Value aligned top-right
                Flexible(
                  child: Text(
                    value,
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.05,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Flexible(
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.25,
                  color: Colors.white.withOpacity(0.80),
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Custom Action Card
class _AngkasActionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _AngkasActionCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              spreadRadius: 0,
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: color,
                size: 28,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Custom Request Popup
class AngkasRequestPopup extends StatefulWidget {
  final Map<String, dynamic> requestData;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const AngkasRequestPopup({
    Key? key,
    required this.requestData,
    required this.onAccept,
    required this.onReject,
  }) : super(key: key);

  @override
  State<AngkasRequestPopup> createState() => _AngkasRequestPopupState();
}

class _AngkasRequestPopupState extends State<AngkasRequestPopup>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _progressController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _progressAnimation;
  int _countdown = 30;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _progressController = AnimationController(
      duration: const Duration(seconds: 30),
      vsync: this,
    );
    
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );
    
    _progressAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.linear),
    );
    
    _controller.forward();
    _progressController.forward();
    
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 0) {
        setState(() {
          _countdown--;
        });
      } else {
        timer.cancel();
        Navigator.of(context).pop();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _progressController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        backgroundColor: Colors.black.withOpacity(0.7),
        body: Center(
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Container(
              margin: const EdgeInsets.all(24),
              child: Card(
                elevation: 20,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Colors.white, Color(0xFFF8F9FA)],
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Progress indicator
                      AnimatedBuilder(
                        animation: _progressAnimation,
                        builder: (context, child) {
                          return Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox(
                                width: 80,
                                height: 80,
                                child: CircularProgressIndicator(
                                  value: _progressAnimation.value,
                                  strokeWidth: 6,
                                  backgroundColor: Colors.grey[300],
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    _countdown > 10 ? const Color(0xFFEF5350) : Colors.red,
                                  ),
                                ),
                              ),
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: _countdown > 10 ? const Color(0xFFEF5350) : Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.build_rounded,
                                  color: Colors.white,
                                  size: 30,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      
                      const SizedBox(height: 20),
                      
                      Text(
                        'New Service Request!',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      
                      Text(
                        '${_countdown}s to respond',
                        style: TextStyle(
                          fontSize: 16,
                          color: _countdown > 10 ? const Color(0xFFEF5350) : Colors.red,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Customer info
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.person, color: Colors.grey[600], size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  widget.requestData['customer_name'] ?? 'Customer',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.build, color: Colors.grey[600], size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    widget.requestData['service_type'] ?? 'Service Request',
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.location_on, color: Colors.grey[600], size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    widget.requestData['pickup_address'] ?? 'Location not available',
                                    style: const TextStyle(fontSize: 14),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Action buttons
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: widget.onReject,
                              icon: const Icon(Icons.close_rounded, size: 20),
                              label: const Text(
                                'Decline',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey[600],
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: widget.onAccept,
                              icon: const Icon(Icons.check_rounded, size: 20),
                              label: const Text(
                                'Accept',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFEF5350),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Custom Exit Dialog
class AngkasExitDialog extends StatelessWidget {
  final bool isOnline;

  const AngkasExitDialog({Key? key, required this.isOnline}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(
            isOnline ? Icons.warning_rounded : Icons.exit_to_app_rounded,
            color: isOnline ? Colors.orange : Colors.grey[600],
          ),
          const SizedBox(width: 8),
          const Text('Exit App'),
        ],
      ),
      content: Text(
        isOnline 
            ? 'You are currently online. Exiting will stop you from receiving new requests. Are you sure?'
            : 'Are you sure you want to exit the app?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFEF5350),
            foregroundColor: Colors.white,
          ),
          child: const Text('Exit'),
        ),
      ],
    );
  }
}

// Placeholder screens for other tabs
class AngkasJobsScreen extends StatelessWidget {
  const AngkasJobsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const AngkasAssignedJobsScreen(); // Use new Angkas-style jobs screen
  }
}

class AngkasEarningsScreenWrapper extends StatelessWidget {
  const AngkasEarningsScreenWrapper({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Use a simple earnings screen with Angkas styling for now
    return const _SimpleAngkasEarningsScreen();
  }
}

// Simple earnings screen with Angkas design
class _SimpleAngkasEarningsScreen extends StatefulWidget {
  const _SimpleAngkasEarningsScreen();

  @override
  State<_SimpleAngkasEarningsScreen> createState() => _SimpleAngkasEarningsScreenState();
}

class _SimpleAngkasEarningsScreenState extends State<_SimpleAngkasEarningsScreen>
    with TickerProviderStateMixin {
  Map<String, dynamic> _earnings = {};
  bool _isLoading = true;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));
    
    _loadEarnings();
    _slideController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _loadEarnings() async {
    try {
      setState(() => _isLoading = true);
      await Future.delayed(const Duration(milliseconds: 500)); // Simulate loading
      final stats = await MechanicService.instance.getMechanicStats();
      if (mounted) {
        setState(() {
          _earnings = {

            'totalEarnings': stats['totalEarnings'] ?? 0.0,
            'completedJobs': stats['totalCompleted'] ?? 0,
            'averagePerJob': stats['totalCompleted'] > 0 
                ? (stats['totalEarnings'] ?? 0.0) / stats['totalCompleted']
                : 0.0,
          };
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: SlideTransition(
          position: _slideAnimation,
          child: RefreshIndicator(
            onRefresh: _loadEarnings,
            color: const Color(0xFFEF5350),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  _buildHeader(),
                  
                  // Main earnings card
                  _buildMainEarningsCard(),
                  
                  // Stats grid
                  _buildStatsGrid(),
                  
                  const SizedBox(height: 24),
                  
                  // No earnings state
                  _buildEarningsContent(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: const Row(
        children: [
          Icon(Icons.monetization_on_rounded, 
               color: Color(0xFFEF5350), 
               size: 32),
          SizedBox(width: 12),
          Text(
            'Earnings',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainEarningsCard() {
    if (_isLoading) {
      return Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Column(
          children: [
            SizedBox(height: 60),
            Center(child: CircularProgressIndicator(color: Color(0xFFEF5350))),
            SizedBox(height: 20),
            Text('Loading earnings...', style: TextStyle(color: Colors.grey)),
            SizedBox(height: 60),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFEF5350), Color(0xFFE53935)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFEF5350).withOpacity(0.4),
            spreadRadius: 0,
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_earnings['completedJobs'] ?? 0}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const Text(
                              'Jobs Completed',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.star_rounded, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '5.0',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'Average Rating',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    if (_isLoading) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        child: GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          childAspectRatio: 1.4,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          children: List.generate(4, (index) => Container(
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(child: CircularProgressIndicator()),
          )),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        childAspectRatio: 1.4,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        children: [
          _buildStatCard('Total Earnings', '₱${(_earnings['totalEarnings'] ?? 0.0).toStringAsFixed(2)}', Icons.monetization_on_rounded, const Color(0xFF1976D2)),
          _buildStatCard('This Week', '₱0.00', Icons.date_range_rounded, const Color(0xFFEF5350)),
          _buildStatCard('Average/Job', '₱${(_earnings['averagePerJob'] ?? 0.0).toStringAsFixed(2)}', Icons.trending_up_rounded, const Color(0xFFD32F2F)),
          _buildStatCard('Total Jobs', '${_earnings['completedJobs'] ?? 0}', Icons.work_rounded, const Color(0xFFAD4E00)),
        ],
      ),
    );
  }

  Widget _buildEarningsContent() {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(color: Color(0xFFEF5350)),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            spreadRadius: 0,
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            Icons.monetization_on_outlined,
            size: 56,
            color: Colors.grey[500],
          ),
          const SizedBox(height: 12),
          const Text(
            'No Earnings Yet',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A),
              height: 1.1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Complete your first job to start earning!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            spreadRadius: 0,
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                    height: 1.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.left,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
              height: 1.1,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// Placeholder wrapper classes - these redirect to the actual Angkas-style screens

class AngkasHistoryScreen extends StatelessWidget {
  const AngkasHistoryScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const AngkasJobHistoryScreen(); // Use new Angkas-style history screen
  }
}

class AngkasProfileScreen extends StatelessWidget {
  const AngkasProfileScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const AngkasMechanicProfileScreen(); // Use new Angkas-style profile screen
  }
}

// Active Job Card with Real-time Invoice Status
class _ActiveJobCard extends StatefulWidget {
  final Map<String, dynamic> activeJobData;
  final String activeServiceRequestId;

  const _ActiveJobCard({
    required this.activeJobData,
    required this.activeServiceRequestId,
  });

  @override
  State<_ActiveJobCard> createState() => _ActiveJobCardState();
}

class _ActiveJobCardState extends State<_ActiveJobCard> {
  Map<String, dynamic>? _currentInvoice;
  String _invoiceStatus = 'No invoice';
  bool _hasInvoice = false;
  bool _canScanQR = false;
  StreamSubscription? _invoiceSubscription;

  @override
  void initState() {
    super.initState();
    _loadCurrentInvoice();
    _startInvoiceTracking();
  }

  @override
  void dispose() {
    _invoiceSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadCurrentInvoice() async {
    try {
      final response = await Supabase.instance.client
          .from('invoices')
          .select('*')
          .eq('request_id', widget.activeServiceRequestId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response != null && mounted) {
        setState(() {
          _currentInvoice = response;
          _hasInvoice = true;
          _invoiceStatus = response['status'] ?? 'unknown';
          // Enable QR scanning for paid invoices OR in development/testing scenarios
          _canScanQR = _invoiceStatus == 'paid' || _invoiceStatus == 'accepted' || (_currentInvoice != null && _hasInvoice);
        });
      }
    } catch (e) {
      print('❌ Error loading current invoice: $e');
    }
  }

  void _startInvoiceTracking() {
    // Listen for real-time invoice updates
    _invoiceSubscription = Supabase.instance.client
        .from('invoices')
        .stream(primaryKey: ['id'])
        .eq('request_id', widget.activeServiceRequestId)
        .listen((data) {
          if (data.isNotEmpty && mounted) {
            final latestInvoice = data.last;
            setState(() {
              _currentInvoice = latestInvoice;
              _hasInvoice = true;
              _invoiceStatus = latestInvoice['status'] ?? 'unknown';
              // Enable QR scanning for paid invoices OR in development/testing scenarios
              _canScanQR = _invoiceStatus == 'paid' || _invoiceStatus == 'accepted' || _hasInvoice;
            });
            
            // Show notification for status changes
            if (_invoiceStatus == 'accepted') {
              _showStatusNotification('💰 Invoice accepted by customer!', Colors.red);
            } else if (_invoiceStatus == 'paid') {
              _showStatusNotification('🎉 Payment received! You can now scan QR to complete job.', Colors.blue);
            } else if (_invoiceStatus == 'rejected') {
              _showStatusNotification('❌ Invoice rejected by customer', Colors.red);
            }
          }
        });

    // Also listen to service request status changes for redundancy
    Supabase.instance.client
        .from('service_requests')
        .stream(primaryKey: ['id'])
        .eq('id', widget.activeServiceRequestId)
        .listen((data) {
          if (data.isNotEmpty && mounted) {
            final latestRequest = data.last;
            final requestStatus = latestRequest['status'] ?? 'unknown';
            
            // If service request status shows invoice_paid, refresh invoice status
            if (requestStatus == 'invoice_paid' && _invoiceStatus != 'paid') {
              _loadCurrentInvoice();
              _showStatusNotification('🎉 Payment confirmed! You can now scan QR to complete job.', Colors.blue);
            }
          }
        });
  }

  void _showStatusNotification(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _scanQR() async {
    try {
      final mechanicId = AuthService.instance.currentUser?.id;
      if (mechanicId == null) {
        print('❌ No authenticated user for QR scanning');
        return;
      }

      if (widget.activeServiceRequestId.isEmpty) {
        print('❌ No active service request for QR scanning');
        return;
      }

      print('📱 Opening QR scanner for request: ${widget.activeServiceRequestId}');

      // Navigate to the proper secure QR scanner
      final result = await Navigator.of(context).pushNamed(
        '/secure_qr_scanner',
        arguments: {
          'requestId': widget.activeServiceRequestId,
          'jobTitle': 'Service Completion',
        },
      );

      print('🔍 QR scanner result: $result');

      // Handle the result
      if (result == true) {
        print('✅ QR scan successful, job should be completed');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🎉 Job completed successfully!'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        print('❌ QR scan failed or cancelled');
      }
    } catch (e) {
      print('❌ Error opening QR scanner: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening QR scanner: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final job = widget.activeJobData;
    
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1565C0).withOpacity(0.3),
            spreadRadius: 0,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header with status
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.work,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Active Job',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${job['service_type'] ?? 'Service Request'}',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red, width: 1),
                  ),
                  child: const Text(
                    'IN PROGRESS',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Invoice Status Section
          Container(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Icon(
                    _getInvoiceStatusIcon(),
                    color: _getInvoiceStatusColor(),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Invoice Status',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          _getInvoiceStatusText(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_hasInvoice && _currentInvoice != null)
                    Text(
                      '₱${_currentInvoice!['total_amount']?.toStringAsFixed(0) ?? '0'}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
            ),
          ),
          
          // Customer info
          Container(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  child: const Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        job['customer_name'] ?? 'Customer',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (job['customer_phone'] != null && job['customer_phone'].isNotEmpty)
                        Text(
                          job['customer_phone'],
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 14,
                          ),
                        ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.phone,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.navigation,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Action buttons
          Container(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: [
                // Primary action button
                if (!_hasInvoice) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        // Navigate to invoice generation 
                        await Navigator.pushNamed(
                          context,
                          '/enhanced_invoice_generation',
                          arguments: {
                            'serviceRequestId': widget.activeServiceRequestId,
                            'customerInfo': job,
                          },
                        );
                        
                        // Refresh the invoice state when returning
                        if (mounted) {
                          print('🔄 Returning from invoice generation, refreshing invoice state...');
                          await _loadCurrentInvoice();
                        }
                      },
                      icon: const Icon(Icons.receipt_long, size: 18),
                      label: const Text(
                        'Generate Invoice',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF1565C0),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ] else if (_canScanQR) ...[
                  // QR Scan button when paid
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _scanQR,
                      icon: const Icon(Icons.qr_code_scanner, size: 18),
                      label: const Text(
                        'Scan QR to Complete Job',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  // Manage Invoice button for other statuses
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        // Navigate to invoice management and refresh state on return
                        await Navigator.pushNamed(
                          context,
                          '/enhanced_invoice_generation',
                          arguments: {
                            'serviceRequestId': widget.activeServiceRequestId,
                            'customerInfo': job,
                          },
                        );
                        
                        // Refresh the invoice state when returning
                        if (mounted) {
                          print('🔄 Returning from invoice management, refreshing invoice state...');
                          await _loadCurrentInvoice();
                        }
                      },
                      icon: const Icon(Icons.receipt_long, size: 18),
                      label: const Text(
                        'Manage Invoice',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF1565C0),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getInvoiceStatusIcon() {
    switch (_invoiceStatus) {
      case 'sent':
      case 'generated':
        return Icons.send;
      case 'accepted':
        return Icons.check_circle;
      case 'paid':
        return Icons.payments;
      case 'rejected':
        return Icons.cancel;
      default:
        return Icons.receipt;
    }
  }

  Color _getInvoiceStatusColor() {
    switch (_invoiceStatus) {
      case 'sent':
      case 'generated':
        return Colors.orange;
      case 'accepted':
        return Colors.blue;
      case 'paid':
        return Colors.red;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.white;
    }
  }

  String _getInvoiceStatusText() {
    switch (_invoiceStatus) {
      case 'sent':
      case 'generated':
        return 'Invoice sent - waiting for customer';
      case 'accepted':
        return 'Invoice accepted - awaiting payment';
      case 'paid':
        return 'Payment received - ready to complete';
      case 'rejected':
        return 'Invoice rejected by customer';
      default:
        return 'No invoice sent yet';
    }
  }
}

