import 'package:flutter/material.dart';
import 'dart:async';
import '../services/service_request_service.dart';
import '../customer/payment_screen.dart';

class MechanicWaitingScreen extends StatefulWidget {
  final String serviceRequestId;
  final String? issueType;
  final String? issueDescription;
  final String? issueTitle;
  final String? vehicleType;
  final String? vehicleBrand;
  final String? vehicleModel;
  final String? vehicleYear;
  final String? vehicleId;

  const MechanicWaitingScreen({
    super.key,
    required this.serviceRequestId,
    this.issueType,
    this.issueDescription,
    this.issueTitle,
    this.vehicleType,
    this.vehicleBrand,
    this.vehicleModel,
    this.vehicleYear,
    this.vehicleId,
  });

  @override
  State<MechanicWaitingScreen> createState() => _MechanicWaitingScreenState();
}

class _MechanicWaitingScreenState extends State<MechanicWaitingScreen>
    with TickerProviderStateMixin {
  Timer? _pollTimer;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  int _dotsCount = 1;
  Timer? _dotsTimer;
  Duration _waitingTime = Duration.zero;
  Timer? _timeTimer;

  @override
  void initState() {
    super.initState();
    
    // Setup pulse animation
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    _pulseController.repeat(reverse: true);

    // Setup dots animation
    _dotsTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      setState(() {
        _dotsCount = (_dotsCount % 3) + 1;
      });
    });

    // Setup waiting time counter
    _timeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _waitingTime = Duration(seconds: _waitingTime.inSeconds + 1);
      });
    });

    // Start polling for mechanic acceptance
    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _dotsTimer?.cancel();
    _timeTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      try {
        final serviceRequest = await ServiceRequestService.getServiceRequest(widget.serviceRequestId);
          if (serviceRequest != null) {
          final status = serviceRequest['status']?.toString().toLowerCase();
          
          // Check for accepted/assigned/awaiting_payment status to proceed to payment
          if (status == 'accepted' || status == 'assigned' || status == 'awaiting_payment') {
            // Mechanic accepted, navigate to payment
            _pollTimer?.cancel();
            _dotsTimer?.cancel();
            _timeTimer?.cancel();
              if (mounted) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => PaymentScreen(
                    issueType: widget.issueType,
                    issueDescription: widget.issueDescription,
                    issueTitle: widget.issueTitle,
                    vehicleType: widget.vehicleType,
                    vehicleBrand: widget.vehicleBrand,
                    vehicleModel: widget.vehicleModel,
                    vehicleYear: widget.vehicleYear,
                    vehicleId: widget.vehicleId,
                    serviceRequestId: widget.serviceRequestId,
                  ),
                ),
              );
            }
          }else if (status == 'cancelled' || status == 'rejected') {
            // Request was cancelled/rejected
            _pollTimer?.cancel();
            _showErrorAndGoBack('Your service request was not accepted. Please try again.');
          } else if (status == 'in_progress') {
            // Service is already in progress, navigate to tracking screen
            _pollTimer?.cancel();
            _dotsTimer?.cancel();
            _timeTimer?.cancel();
            
            if (mounted) {
              // Navigate to service tracking screen instead of payment
              _showSuccessMessage('Mechanic is on the way!');
              Navigator.of(context).pop(); // Go back to main screen
            }
          }
        }
      } catch (e) {
        print('Error polling service request: $e');
      }
    });

    // Auto-timeout after 5 minutes
    Timer(const Duration(minutes: 5), () {
      if (_pollTimer?.isActive == true) {
        _pollTimer?.cancel();
        _showErrorAndGoBack('No mechanic accepted your request. Please try again later.');
      }
    });
  }

  void _showErrorAndGoBack(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
      
      Navigator.of(context).pop();
    }
  }

  void _showSuccessMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  String _formatDuration(Duration duration) {
    int minutes = duration.inMinutes;
    int seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 176, 12, 1),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                title: Row(
                  children: [
                    const Icon(Icons.warning, color: Colors.orange),
                    const SizedBox(width: 8),
                    const Text('Cancel Request?'),
                  ],
                ),
                content: const Text(
                  'Are you sure you want to cancel this service request? This action cannot be undone.',
                  style: TextStyle(fontSize: 14),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Keep Waiting'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      try {
                        await ServiceRequestService.cancelServiceRequest(widget.serviceRequestId);
                        Navigator.of(context).pop(); // Close dialog
                        Navigator.of(context).pop(); // Go back to previous screen
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error cancelling request: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Yes, Cancel'),
                  ),
                ],
              ),
            );
          },
        ),
        title: const Text(
          'Finding Your Mechanic',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header section with gradient
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color.fromARGB(255, 176, 12, 1),
                    const Color.fromARGB(255, 176, 12, 1).withAlpha(204),
                  ],
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  
                  // Animated pulse icon
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _pulseAnimation.value,
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(51),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.search,
                            size: 60,
                            color: Colors.white,
                          ),
                        ),
                      );
                    },
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Main title with animated dots
                  Text(
                    'Looking for available mechanics${'.' * _dotsCount}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Subtitle
                  Text(
                    'We\'re finding the best mechanic for your ${widget.issueTitle?.toLowerCase() ?? 'service request'}',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Waiting time card
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(38),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withAlpha(77)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.timer, size: 20, color: Colors.white),
                        const SizedBox(width: 12),
                        Column(
                          children: [
                            const Text(
                              'Waiting Time',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white70,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatDuration(_waitingTime),
                              style: const TextStyle(
                                fontSize: 24,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 30),
                ],
              ),
            ),
            
            // Main content
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Service details card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(13),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color.fromARGB(255, 176, 12, 1).withAlpha(26),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.description,
                                color: Color.fromARGB(255, 176, 12, 1),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Service Request Details',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _buildDetailRow('Service Type', widget.issueTitle ?? 'General Service'),
                        _buildDetailRow('Vehicle', '${widget.vehicleBrand ?? ''} ${widget.vehicleModel ?? ''} ${widget.vehicleYear ?? ''}'.trim()),
                        _buildDetailRow('Request ID', widget.serviceRequestId),
                        if (widget.issueDescription != null && widget.issueDescription!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          const Text(
                            'Description:',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              widget.issueDescription!,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black87,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Status progress card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(13),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color.fromARGB(255, 176, 12, 1).withAlpha(26),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.timeline,
                                color: Color.fromARGB(255, 176, 12, 1),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Request Progress',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _buildProgressStep('Request Sent', 'Your service request has been submitted', true, true),
                        _buildProgressStep('Finding Mechanic', 'We\'re searching for available mechanics', true, false),
                        _buildProgressStep('Mechanic Assigned', 'A mechanic will be assigned to your request', false, false),
                        _buildProgressStep('Payment', 'Complete payment to begin service', false, false),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Help section
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.blue[600],
                          size: 28,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'What\'s happening?',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'We\'re notifying nearby mechanics about your request. This usually takes 1-3 minutes. You\'ll be automatically redirected once a mechanic accepts.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                            height: 1.4,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isNotEmpty ? value : 'N/A',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressStep(String title, String description, bool isActive, bool isCompleted) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step indicator
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: isCompleted 
                  ? const Color.fromARGB(255, 176, 12, 1)
                  : isActive
                      ? const Color.fromARGB(255, 176, 12, 1).withAlpha(77)
                      : Colors.grey[300],
              shape: BoxShape.circle,
              border: isActive && !isCompleted
                  ? Border.all(color: const Color.fromARGB(255, 176, 12, 1), width: 2)
                  : null,
            ),
            child: isCompleted
                ? const Icon(Icons.check, color: Colors.white, size: 14)
                : isActive
                    ? Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Color.fromARGB(255, 176, 12, 1),
                          shape: BoxShape.circle,
                        ),
                      )
                    : null,
          ),
          
          const SizedBox(width: 16),
          
          // Step content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isCompleted 
                        ? const Color.fromARGB(255, 176, 12, 1)
                        : isActive
                            ? Colors.black87
                            : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}










