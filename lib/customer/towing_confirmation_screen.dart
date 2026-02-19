import 'package:flutter/material.dart';
import 'vehicle_details_screen.dart';

class TowingConfirmationScreen extends StatefulWidget {
  final String serviceType;
  final String description;
  final dynamic analysisResult;
  final String towingReason;

  const TowingConfirmationScreen({
    super.key,
    required this.serviceType,
    required this.description,
    required this.analysisResult,
    required this.towingReason,
  });

  @override
  State<TowingConfirmationScreen> createState() => _TowingConfirmationScreenState();
}

class _TowingConfirmationScreenState extends State<TowingConfirmationScreen> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Towing Required',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading ? _buildLoadingScreen() : _buildTowingContent(),
    );
  }

  Widget _buildLoadingScreen() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
          ),
          SizedBox(height: 20),
          Text(
            'Processing your request...',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTowingContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Towing Alert Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.orange.shade50, Colors.red.shade50],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.orange.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.local_shipping,
                        color: Colors.orange.shade700,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Towing Service Required',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildAnalysisDetails(),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Explanation Message
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.blue.shade600,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Important Information',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Your issue requires towing because your car cannot be repaired on the roadside. However, we can send a mechanic to inspect the car and assist with arranging towing if you wish.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.towingReason,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.blue.shade700,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Options Section
          _buildOptionsSection(),
          
          const SizedBox(height: 32),
          
          // Action Buttons
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildAnalysisDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'AI Analysis Results:',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        
        // Confidence Score
        Row(
          children: [
            const Icon(Icons.analytics, size: 16, color: Colors.grey),
            const SizedBox(width: 8),
            Text(
              'Confidence: ${(widget.analysisResult.confidence * 100).toStringAsFixed(1)}%',
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        
        // Severity Level
        Row(
          children: [
            const Icon(Icons.warning, size: 16, color: Colors.orange),
            const SizedBox(width: 8),
            Text(
              'Severity: ${widget.analysisResult.isSevere ? 'HIGH' : 'MODERATE'}',
              style: TextStyle(
                fontSize: 13,
                color: widget.analysisResult.isSevere ? Colors.red : Colors.orange,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        
        // Issue Description
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.description, size: 16, color: Colors.grey),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Issue: ${widget.description}',
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOptionsSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'What would you like to do?',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          
          // Option 1: Send Mechanic for Inspection
          _buildOptionCard(
            icon: Icons.person_search,
            iconColor: Colors.red,
            title: 'Yes - Send Mechanic for Inspection',
            description: 'A mechanic will come to inspect your vehicle and provide a detailed report. We will also help arrange towing services.',
            benefits: [
              'Professional on-site assessment',
              'Detailed diagnostic report',
              'Towing recommendations',
              'Cost estimation for repairs'
            ],
            isRecommended: true,
          ),
          
          const SizedBox(height: 12),
          
          // Option 2: Cancel and Return
          _buildOptionCard(
            icon: Icons.cancel,
            iconColor: Colors.red,
            title: 'No - Cancel Request',
            description: 'Cancel the mechanic dispatch and return to the dashboard. You can arrange towing separately.',
            benefits: [
              'No immediate service charges',
              'Arrange your own towing',
              'Contact insurance if covered',
              'Seek alternative solutions'
            ],
            isRecommended: false,
          ),
        ],
      ),
    );
  }

  Widget _buildOptionCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
    required List<String> benefits,
    required bool isRecommended,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isRecommended ? Colors.red.shade200 : Colors.grey.shade300,
          width: isRecommended ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withAlpha(26),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 20,
                ),
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
                            title,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        if (isRecommended)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'RECOMMENDED',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.red.shade700,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...benefits.map((benefit) => Padding(
            padding: const EdgeInsets.only(left: 24, bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '• ',
                  style: TextStyle(
                    fontSize: 14,
                    color: iconColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Expanded(
                  child: Text(
                    benefit,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          )).toList(),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        // YES Button - Send Mechanic for Inspection
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _proceedWithMechanicInspection,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.person_search, size: 20),
                SizedBox(width: 8),
                Text(
                  'Yes - Send Mechanic for Inspection',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 12),
        
        // NO Button - Cancel and Return to Dashboard
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _cancelAndReturnToDashboard,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red.shade600,
              side: BorderSide(color: Colors.red.shade600),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.cancel, size: 20),
                SizedBox(width: 8),
                Text(
                  'No - Cancel Request',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _proceedWithMechanicInspection() {
    setState(() {
      _isLoading = true;
    });

    // Show confirmation dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Proceeding with Inspection'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Preparing vehicle details form...'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              setState(() {
                _isLoading = false;
              });
            },
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    // Simulate processing time
    Future.delayed(const Duration(seconds: 2), () {
      Navigator.pop(context); // Close loading dialog
      
      setState(() {
        _isLoading = false;
      });
      
      // Navigate to Vehicle Details Screen for inspection
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => VehicleDetailsScreen(
            issueType: widget.serviceType,
            issueDescription: '${widget.description}\n\n🚛 TOWING REQUIRED - Inspection Only\n📋 Reason: ${widget.towingReason}',
            issueTitle: 'Towing Required - Vehicle Inspection',
          ),
        ),
      );
    });
  }

  void _cancelAndReturnToDashboard() {
    // Show confirmation dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Request'),
        content: const Text(
          'Are you sure you want to cancel the mechanic request? You will need to arrange towing and repairs separately.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep Request'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              
              // Show cancellation message
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Request cancelled. You can create a new request anytime.'),
                  backgroundColor: Colors.orange,
                ),
              );
              
              // Return to dashboard (pop all screens back to main)
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Cancel Request'),
          ),
        ],
      ),
    );
  }
}





















