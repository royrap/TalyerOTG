import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import 'review_dialog.dart';

/// 🎉 Service Completion Dialog
/// Shows when mechanic scans QR code and completes the job
/// Offers customer option to rate the mechanic
class ServiceCompletionDialog extends StatefulWidget {
  final String serviceRequestId;
  final String mechanicId;
  final String? mechanicName;
  final String? mechanicProfileImage;

  const ServiceCompletionDialog({
    Key? key,
    required this.serviceRequestId,
    required this.mechanicId,
    this.mechanicName,
    this.mechanicProfileImage,
  }) : super(key: key);

  @override
  State<ServiceCompletionDialog> createState() => _ServiceCompletionDialogState();
}

class _ServiceCompletionDialogState extends State<ServiceCompletionDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _logCompletion();
  }

  void _setupAnimations() {
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _controller.forward();
  }

  Future<void> _logCompletion() async {
    try {
      // Log the completion event
      print('✅ Service ${widget.serviceRequestId} completed successfully');
      
      // Optional: Update completion timestamp
      await SupabaseService.client
          .from('service_requests')
          .update({
            'completed_at': DateTime.now().toIso8601String(),
          })
          .eq('id', widget.serviceRequestId);
    } catch (e) {
      print('❌ Error logging completion: $e');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _showRatingDialog() {
    Navigator.pop(context); // Close completion dialog first
    
    // Show review dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ReviewDialog(
        providerId: widget.mechanicId,
        requestId: widget.serviceRequestId,
        serviceTitle: widget.mechanicName ?? 'Service',
      ),
    );
  }

  void _closeDialog() {
    Navigator.pop(context);
    
    // Navigate back to home or dashboard
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white,
                  Colors.green.shade50,
                ],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Success Icon with Animation
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 800),
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: value,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green.withOpacity(0.3),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 50,
                        ),
                      ),
                    );
                  },
                ),
                
                const SizedBox(height: 24),
                
                // Title
                const Text(
                  'Service Completed Successfully!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                
                const SizedBox(height: 12),
                
                // Message
                Text(
                  'Your service has been completed. Thank you for using RoadAid!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey[700],
                    height: 1.5,
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Mechanic Info Card
                if (widget.mechanicName != null)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      children: [
                        // Mechanic Avatar
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: Colors.orange.shade100,
                          backgroundImage: widget.mechanicProfileImage != null
                              ? NetworkImage(widget.mechanicProfileImage!)
                              : null,
                          child: widget.mechanicProfileImage == null
                              ? Icon(
                                  Icons.person,
                                  size: 32,
                                  color: Colors.orange.shade700,
                                )
                              : null,
                        ),
                        const SizedBox(width: 16),
                        
                        // Mechanic Name
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Mechanic',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.mechanicName!,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // Rating Icon
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.star,
                            color: Colors.amber.shade700,
                            size: 28,
                          ),
                        ),
                      ],
                    ),
                  ),
                
                const SizedBox(height: 24),
                
                // Rating Question
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.help_outline, color: Colors.blue.shade700),
                      const SizedBox(width: 12),
                      Text(
                        'Would you like to rate your mechanic?',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue.shade900,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Action Buttons
                Row(
                  children: [
                    // Close Button
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _closeDialog,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(color: Colors.grey.shade400, width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Close',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(width: 12),
                    
                    // Rate Mechanic Button
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _showRatingDialog,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Colors.orange.shade600,
                          foregroundColor: Colors.white,
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.star, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Rate Mechanic',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 8),
                
                // Skip Text
                TextButton(
                  onPressed: _closeDialog,
                  child: Text(
                    'Maybe later',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
