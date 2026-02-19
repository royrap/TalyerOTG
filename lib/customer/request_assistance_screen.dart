import 'package:flutter/material.dart';
import 'vehicle_details_screen.dart';
import '../services/ai_description_analysis_service.dart';
import 'severe_issue_confirmation_screen.dart';
import 'towing_confirmation_screen.dart';

class RequestAssistanceScreen extends StatefulWidget {
  final String? initialServiceType;
  final Map<String, dynamic>? preSelectedMechanic;
  
  const RequestAssistanceScreen({
    super.key,
    this.initialServiceType,
    this.preSelectedMechanic,
  });

  @override
  State<RequestAssistanceScreen> createState() => _RequestAssistanceScreenState();
}

class _RequestAssistanceScreenState extends State<RequestAssistanceScreen> {
  List<int> _selectedIssueIndices = [];
  bool _isSubmitting = false;
  final TextEditingController _descriptionController = TextEditingController();
  bool _showDescriptionField = false;
  String _analysisResult = '';
  bool _isAnalyzing = false;

  final List<Map<String, dynamic>> _issues = [
    {
      'title': 'Mechanical Issue',
      'icon': Icons.build,
      'description': 'Engine, transmission, or mechanical problems',
      'category': 'mechanical',
      'priority': 'high',
      'estimatedDuration': 60,
    },
    {
      'title': 'Electrical Problem',
      'icon': Icons.electrical_services,
      'description': 'Battery, lights, or electrical system issues',
      'category': 'electrical',
      'priority': 'medium',
      'estimatedDuration': 45,
    },
    {
      'title': 'Tire Issue',
      'icon': Icons.tire_repair,
      'description': 'Flat tire, puncture, or tire-related problems',
      'category': 'tire',
      'priority': 'high',
      'estimatedDuration': 30,
    },
    {
      'title': 'Fuel Problem',
      'icon': Icons.local_gas_station,
      'description': 'Out of fuel or fuel system issues',
      'category': 'fuel',
      'priority': 'medium',
      'estimatedDuration': 20,
    },
    {
      'title': 'Lockout Service',
      'icon': Icons.lock_open,
      'description': 'Locked out of vehicle or key issues',
      'category': 'lockout',
      'priority': 'medium',
      'estimatedDuration': 15,
    },
    {
      'title': 'Emergency Service',
      'icon': Icons.emergency,
      'description': 'Urgent roadside assistance needed',
      'category': 'emergency',
      'priority': 'critical',
      'estimatedDuration': 45,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 176, 12, 1),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Request Assistance',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
                    const Color.fromARGB(255, 176, 12, 1).withOpacity(0.8),
                  ],
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  const Icon(
                    Icons.car_repair,
                    size: 60,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'What type of assistance do you need?',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Select your issue type and we\'ll connect you with the right help',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
            
            // Main content
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Service Type Selection
                  _buildServiceTypeSelection(),
                  
                  const SizedBox(height: 30),
                  
                  // Description Field
                  if (_showDescriptionField) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
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
                                  color: const Color.fromARGB(255, 176, 12, 1).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.description,
                                  color: Color.fromARGB(255, 176, 12, 1),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Describe your issue:',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Selected: ${_selectedIssueIndices.map((i) => _issues[i]['title']).join(', ')}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: const Color.fromARGB(255, 176, 12, 1),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildDescriptionField(),
                          
                          if (_analysisResult.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            _buildAIAnalysisDisplay(),
                          ],
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 30),
                  ],
                  
                  // Continue Button
                  if (_selectedIssueIndices.isNotEmpty)
                    _buildContinueButton(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceTypeSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Choose Service Type',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color.fromARGB(255, 176, 12, 1).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Multiple select',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: const Color.fromARGB(255, 176, 12, 1),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Tap to select multiple issue types that apply to your situation',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.0,
          ),
          itemCount: _issues.length,
          itemBuilder: (context, index) {
            final issue = _issues[index];
            final isSelected = _selectedIssueIndices.contains(index);
            
            return GestureDetector(
              onTap: () {
                setState(() {
                  if (isSelected) {
                    _selectedIssueIndices.remove(index);
                  } else {
                    _selectedIssueIndices.add(index);
                  }
                  _showDescriptionField = _selectedIssueIndices.isNotEmpty;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected 
                        ? const Color.fromARGB(255, 176, 12, 1)
                        : Colors.grey.shade200,
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isSelected 
                          ? const Color.fromARGB(255, 176, 12, 1).withOpacity(0.2)
                          : Colors.black.withOpacity(0.05),
                      blurRadius: isSelected ? 10 : 5,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Stack(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isSelected 
                                  ? const Color.fromARGB(255, 176, 12, 1).withOpacity(0.1)
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              issue['icon'],
                              size: 32,
                              color: isSelected 
                                  ? const Color.fromARGB(255, 176, 12, 1)
                                  : Colors.grey.shade600,
                            ),
                          ),
                          if (isSelected)
                            Positioned(
                              right: -2,
                              top: -2,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Color.fromARGB(255, 176, 12, 1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.check,
                                  size: 12,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        issue['title'],
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isSelected 
                              ? const Color.fromARGB(255, 176, 12, 1)
                              : Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        issue['description'],
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                          height: 1.3,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildDescriptionField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: TextField(
        controller: _descriptionController,
        onChanged: (value) {
          // Trigger AI analysis with debouncing
          _analyzeDescription();
        },
        maxLines: 5,
        style: const TextStyle(
          fontSize: 14,
          height: 1.4,
        ),
        decoration: const InputDecoration(
          hintText: 'Please describe your issue in detail...\n\nExample: "My car won\'t start and I can hear clicking sounds when I turn the key. The lights are working but the engine doesn\'t turn over."',
          border: InputBorder.none,
          contentPadding: EdgeInsets.all(16),
          hintStyle: TextStyle(
            color: Colors.grey,
            fontSize: 14,
            height: 1.4,
          ),
        ),
      ),
    );
  }

  Widget _buildAIAnalysisDisplay() {
    return Container(
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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color.fromARGB(255, 176, 12, 1).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 176, 12, 1).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  size: 16,
                  color: Color.fromARGB(255, 176, 12, 1),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'AI Analysis',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color.fromARGB(255, 176, 12, 1),
                ),
              ),
              const Spacer(),
              if (_isAnalyzing) ...[
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      const Color.fromARGB(255, 176, 12, 1),
                    ),
                  ),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 12,
                        color: Colors.red.shade700,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Complete',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.red.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Text(
              _isAnalyzing ? 'Analyzing your description...' : _analysisResult,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black87,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContinueButton() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color.fromARGB(255, 176, 12, 1).withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _proceedWithRequest,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color.fromARGB(255, 176, 12, 1),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: _isSubmitting
            ? const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Processing...',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.arrow_forward,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _selectedIssueIndices.length > 1 
                        ? 'Continue with ${_selectedIssueIndices.length} Services'
                        : 'Continue to Vehicle Details',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  void _analyzeDescription() {
    final description = _descriptionController.text.trim();
    
    if (description.isEmpty) {
      setState(() {
        _analysisResult = '';
        _isAnalyzing = false;
      });
      return;
    }
    
    setState(() {
      _isAnalyzing = true;
    });
    
    // Simulate AI processing time
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) {
        final analysisResult = AIDescriptionAnalysisService.analyzeDescription(description);
        
        setState(() {
          _analysisResult = analysisResult.reasoning;
          _isAnalyzing = false;
        });
        
        print('🤖 AI Analysis Result: $analysisResult');
        print('🎯 Confidence: ${(analysisResult.confidence * 100).toStringAsFixed(1)}%');
        print('📝 Analysis: ${analysisResult.reasoning}');
      }
    });
  }

  void _proceedWithRequest() async {
    if (_selectedIssueIndices.isEmpty) return;
    
    final description = _descriptionController.text.trim();
    if (description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please provide a description of your issue'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    setState(() {
      _isSubmitting = true;
    });
    
    // 🧠 Enhanced AI Analysis with Multi-Level Detection
    final analysisResult = AIDescriptionAnalysisService.analyzeDescription(description);
    
    print('🤖 Final AI Analysis: $analysisResult');
    print('📊 Severity: ${analysisResult.isSevere ? 'SEVERE' : 'MANAGEABLE'}');
    print('🎯 Confidence: ${(analysisResult.confidence * 100).toStringAsFixed(1)}%');
    print('📝 Analysis: ${analysisResult.reasoning}');
    
    // 🚛 NEW: Check if issue requires towing (HIGHEST PRIORITY)
    final requiresTowing = AIDescriptionAnalysisService.requiresTowing(description);
    print('🚛 Towing Required: $requiresTowing');
    
    // Get combined service type from selected issues
    final selectedServiceTypes = _selectedIssueIndices.map((i) => _issues[i]['title']).join(' + ');
    
    // 🔄 NEW LOGIC FLOW: Priority-based routing
    if (requiresTowing) {
      // 🚛 HIGHEST PRIORITY: Towing required - show towing confirmation
      final towingReason = AIDescriptionAnalysisService.getTowingReason(description);
      
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TowingConfirmationScreen(
            serviceType: selectedServiceTypes,
            description: description,
            analysisResult: analysisResult,
            towingReason: towingReason,
          ),
        ),
      ).then((_) {
        if (mounted) {
          setState(() {
            _isSubmitting = false;
          });
        }
      });
    } else if (analysisResult.isSevere) {
      // 🔧 SECOND PRIORITY: Severe issue but roadside repairable
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SevereIssueConfirmationScreen(
            issueDescription: description,
            analysisResult: analysisResult,
            onProceedWithMechanic: () {
              Navigator.pop(context);
              _navigateToVehicleSelection(description);
            },
            onSkipMechanic: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('For severe issues requiring specialized equipment, please contact a repair facility directly.'),
                  backgroundColor: Colors.orange,
                  duration: Duration(seconds: 5),
                ),
              );
              setState(() {
                _isSubmitting = false;
              });
            },
          ),
        ),
      ).then((_) {
        if (mounted) {
          setState(() {
            _isSubmitting = false;
          });
        }
      });
    } else {
      // ✅ STANDARD FLOW: Minor to moderate issues
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🤖 AI Analysis: Issue appears manageable by our roadside mechanics'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      _navigateToVehicleSelection(description);
    }
  }

  void _navigateToVehicleSelection(String? customDescription) {
    if (_selectedIssueIndices.isEmpty) return;
    
    // Combine selected service types
    final selectedServiceTypes = _selectedIssueIndices.map((i) => _issues[i]['title']).join(' + ');
    
    // Determine priority based on selected issues
    final priority = _determinePriority();
    
    // Calculate estimated duration
    final estimatedDuration = _calculateEstimatedDuration();
    
    // Get categories for selected issues
    final categories = _selectedIssueIndices.map((i) => _issues[i]['category']).join(',');
    
    // Merge shop data from widget.preSelectedMechanic with analysis data
    Map<String, dynamic> mechanicData = {
      'priority': priority,
      'estimatedDuration': estimatedDuration,
      'categories': categories,
      'selectedIssues': _selectedIssueIndices.map((i) => _issues[i]).toList(),
    };
    
    // If this is a shop-based request, merge the shop data
    if (widget.preSelectedMechanic != null) {
      mechanicData.addAll(widget.preSelectedMechanic!);
      print('🏪 Passing shop data to VehicleDetailsScreen: ${widget.preSelectedMechanic}');
    } else {
      print('🚀 Direct mechanic request - no shop data');
    }
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VehicleDetailsScreen(
          issueType: selectedServiceTypes,
          issueDescription: customDescription ?? _descriptionController.text,
          issueTitle: selectedServiceTypes,
          // Pass complete mechanic data including shop information
          preSelectedMechanic: mechanicData,
        ),
      ),
    ).then((_) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    });
  }

  String _determinePriority() {
    // Check for critical issues first
    if (_selectedIssueIndices.any((i) => _issues[i]['priority'] == 'critical')) {
      return 'critical';
    }
    
    // Check for high priority issues
    if (_selectedIssueIndices.any((i) => _issues[i]['priority'] == 'high')) {
      return 'high';
    }
    
    // Check for medium priority issues
    if (_selectedIssueIndices.any((i) => _issues[i]['priority'] == 'medium')) {
      return 'medium';
    }
    
    return 'normal';
  }

  int _calculateEstimatedDuration() {
    // Sum up estimated durations for all selected issues
    int totalDuration = 0;
    for (int index in _selectedIssueIndices) {
      totalDuration += _issues[index]['estimatedDuration'] as int;
    }
    
    // Add 15 minutes buffer for multiple issues
    if (_selectedIssueIndices.length > 1) {
      totalDuration += 15;
    }
    
    return totalDuration;
  }
}











