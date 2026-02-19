import 'package:flutter/material.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../mechanic/mechanic_waiting_screen.dart';
import 'enhanced_service_selection_screen.dart';

class TalyerSelectionScreen extends StatefulWidget {
  final String serviceType;
  final String description;
  final dynamic analysisResult;
  final bool requiresTowing;
  final bool isInspectionOnly;

  const TalyerSelectionScreen({
    Key? key,
    required this.serviceType,
    required this.description,
    required this.analysisResult,
    this.requiresTowing = false,
    this.isInspectionOnly = false,
  }) : super(key: key);

  @override
  State<TalyerSelectionScreen> createState() => _TalyerSelectionScreenState();
}

class _TalyerSelectionScreenState extends State<TalyerSelectionScreen> {
  List<Map<String, dynamic>> _availableTalyers = [];
  bool _isLoading = true;
  String _errorMessage = '';
  String _currentLocation = 'Getting location...';
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadAvailableTalyers();
    _getCurrentLocation();
    
    // Auto-refresh talyer availability every 30 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _loadAvailableTalyers();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition();
      setState(() {
        _currentLocation = '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
      });
    } catch (e) {
      setState(() {
        _currentLocation = 'Location unavailable';
      });
    }
  }

  Future<void> _loadAvailableTalyers() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      // Simulate API call to get available talyers
      await Future.delayed(const Duration(seconds: 2));

      // Mock data for available talyers based on operating hours
      final mockTalyers = _generateMockTalyers();

      setState(() {
        _availableTalyers = mockTalyers;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load available talyers: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> _generateMockTalyers() {
    final currentHour = DateTime.now().hour;
    
    final List<Map<String, dynamic>> allTalyers = [
      {
        'id': 'talyer_001',
        'name': 'QuickFix Auto Services',
        'owner': 'John Martinez',
        'phone': '+63 912 345 6789',
        'address': 'Makati City, Metro Manila',
        'distance': '2.3 km',
        'rating': 4.8,
        'totalReviews': 156,
        'specialties': ['Engine Repair', 'Transmission', 'Electrical'],
        'openHours': {'start': 6, 'end': 22}, // 6 AM to 10 PM
        'equipmentLevel': 'Professional',
        'averageResponseTime': '15-20 minutes',
        'profileImage': 'https://via.placeholder.com/60',
        'isVerified': true,
        'priceRange': '₱800 - ₱2,500',
      },
      {
        'id': 'talyer_002',
        'name': 'Metro Roadside Rescue',
        'owner': 'Maria Santos',
        'phone': '+63 917 234 5678',
        'address': 'Quezon City, Metro Manila',
        'distance': '3.7 km',
        'rating': 4.6,
        'totalReviews': 203,
        'specialties': ['Battery Replacement', 'Tire Repair', 'Jump Start'],
        'openHours': {'start': 0, 'end': 24}, // 24/7
        'equipmentLevel': 'Standard',
        'averageResponseTime': '10-15 minutes',
        'profileImage': 'https://via.placeholder.com/60',
        'isVerified': true,
        'priceRange': '₱500 - ₱1,800',
      },
      {
        'id': 'talyer_003',
        'name': 'Elite Mobile Mechanics',
        'owner': 'Carlos Rodriguez',
        'phone': '+63 905 123 4567',
        'address': 'Pasig City, Metro Manila',
        'distance': '5.1 km',
        'rating': 4.9,
        'totalReviews': 89,
        'specialties': ['Engine Diagnostics', 'AC Repair', 'Brake Service'],
        'openHours': {'start': 7, 'end': 20}, // 7 AM to 8 PM
        'equipmentLevel': 'Premium',
        'averageResponseTime': '20-25 minutes',
        'profileImage': 'https://via.placeholder.com/60',
        'isVerified': true,
        'priceRange': '₱1,200 - ₱3,500',
      },
      {
        'id': 'talyer_004',
        'name': 'Budget Auto Assist',
        'owner': 'David Kim',
        'phone': '+63 908 765 4321',
        'address': 'Mandaluyong City, Metro Manila',
        'distance': '4.2 km',
        'rating': 4.3,
        'totalReviews': 127,
        'specialties': ['Basic Repairs', 'Towing Service', 'Emergency Help'],
        'openHours': {'start': 8, 'end': 18}, // 8 AM to 6 PM
        'equipmentLevel': 'Basic',
        'averageResponseTime': '25-30 minutes',
        'profileImage': 'https://via.placeholder.com/60',
        'isVerified': false,
        'priceRange': '₱400 - ₱1,200',
      },
      {
        'id': 'talyer_005',
        'name': 'Night Owl Auto Care',
        'owner': 'Lisa Chen',
        'phone': '+63 915 987 6543',
        'address': 'Taguig City, Metro Manila',
        'distance': '6.8 km',
        'rating': 4.7,
        'totalReviews': 94,
        'specialties': ['Night Service', 'Emergency Repairs', 'Towing'],
        'openHours': {'start': 18, 'end': 6}, // 6 PM to 6 AM (night shift)
        'equipmentLevel': 'Professional',
        'averageResponseTime': '15-20 minutes',
        'profileImage': 'https://via.placeholder.com/60',
        'isVerified': true,
        'priceRange': '₱900 - ₱2,800',
      },
    ];

    // Filter talyers based on operating hours
    return allTalyers.where((talyer) {
      final startHour = talyer['openHours']['start'];
      final endHour = talyer['openHours']['end'];
      
      // Handle 24/7 operations
      if (startHour == 0 && endHour == 24) return true;
      
      // Handle night shift (e.g., 18:00 to 6:00)
      if (startHour > endHour) {
        return currentHour >= startHour || currentHour < endHour;
      }
      
      // Handle normal hours
      return currentHour >= startHour && currentHour < endHour;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    // Use enhanced service selection screen for better UX
    return EnhancedServiceSelectionScreen(
      serviceType: widget.serviceType,
      description: widget.description,
      issueTitle: widget.isInspectionOnly ? 'Vehicle Inspection' : widget.serviceType,
    );
  }

  Widget _buildHeaderInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.requiresTowing ? Colors.orange.shade50 : Colors.blue.shade50,
        border: Border(
          bottom: BorderSide(
            color: widget.requiresTowing ? Colors.orange.shade200 : Colors.blue.shade200,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                widget.isInspectionOnly ? Icons.search : Icons.build,
                color: widget.requiresTowing ? Colors.orange.shade700 : Colors.blue.shade700,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.isInspectionOnly 
                      ? 'Inspection Service Requested'
                      : 'Roadside Assistance Requested',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: widget.requiresTowing ? Colors.orange.shade700 : Colors.blue.shade700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Issue: ${widget.description}',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Location: $_currentLocation',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
          if (widget.requiresTowing) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade300),
              ),
              child: Text(
                'TOWING REQUIRED',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 20),
          Text(
            'Finding available talyers in your area...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'Error Loading Talyers',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.red.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _loadAvailableTalyers,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildNoTalyersScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.schedule,
            size: 64,
            color: Colors.orange.shade300,
          ),
          const SizedBox(height: 16),
          const Text(
            'No Talyers Available',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'All talyers are currently closed or busy. Please try again later or check back during their operating hours.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton(
                onPressed: _loadAvailableTalyers,
                child: const Text('Refresh'),
              ),
              const SizedBox(width: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTalyersList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _availableTalyers.length,
      itemBuilder: (context, index) {
        final talyer = _availableTalyers[index];
        return _buildTalyerCard(talyer);
      },
    );
  }

  Widget _buildTalyerCard(Map<String, dynamic> talyer) {
    final bool isOperating = _isTalyerOperating(talyer);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: isOperating ? () => _selectTalyer(talyer) : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                children: [
                  // Profile Image
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: isOperating ? Colors.red : Colors.grey.shade300,
                        width: 2,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: Icon(
                        Icons.build_circle,
                        size: 30,
                        color: isOperating ? Colors.red : Colors.grey,
                      ),
                    ),
                  ),
                  
                  const SizedBox(width: 16),
                  
                  // Talyer Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                talyer['name'],
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isOperating ? Colors.black87 : Colors.grey,
                                ),
                              ),
                            ),
                            if (talyer['isVerified'])
                              Icon(
                                Icons.verified,
                                size: 16,
                                color: Colors.blue.shade600,
                              ),
                          ],
                        ),
                        
                        const SizedBox(height: 4),
                        
                        Text(
                          'Owner: ${talyer['owner']}',
                          style: TextStyle(
                            fontSize: 13,
                            color: isOperating ? Colors.grey.shade600 : Colors.grey,
                          ),
                        ),
                        
                        const SizedBox(height: 2),
                        
                        Row(
                          children: [
                            Icon(
                              Icons.star,
                              size: 14,
                              color: isOperating ? Colors.orange : Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${talyer['rating']} (${talyer['totalReviews']} reviews)',
                              style: TextStyle(
                                fontSize: 12,
                                color: isOperating ? Colors.grey.shade600 : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // Status Indicator
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isOperating ? Colors.red.shade100 : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isOperating ? 'OPEN' : 'CLOSED',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isOperating ? Colors.red.shade700 : Colors.grey.shade600,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Details Row
              Row(
                children: [
                  Icon(
                    Icons.location_on,
                    size: 14,
                    color: isOperating ? Colors.grey.shade600 : Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${talyer['distance']} • ${talyer['address']}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isOperating ? Colors.grey.shade600 : Colors.grey,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 4),
              
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 14,
                    color: isOperating ? Colors.grey.shade600 : Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Response: ${talyer['averageResponseTime']}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isOperating ? Colors.grey.shade600 : Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(
                    Icons.attach_money,
                    size: 14,
                    color: isOperating ? Colors.grey.shade600 : Colors.grey,
                  ),
                  Text(
                    talyer['priceRange'],
                    style: TextStyle(
                      fontSize: 12,
                      color: isOperating ? Colors.grey.shade600 : Colors.grey,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 8),
              
              // Specialties
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: (talyer['specialties'] as List<String>).map((specialty) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: isOperating ? Colors.blue.shade50 : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isOperating ? Colors.blue.shade200 : Colors.grey.shade200,
                      ),
                    ),
                    child: Text(
                      specialty,
                      style: TextStyle(
                        fontSize: 10,
                        color: isOperating ? Colors.blue.shade700 : Colors.grey,
                      ),
                    ),
                  );
                }).toList(),
              ),
              
              if (!isOperating) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.schedule,
                        size: 16,
                        color: Colors.orange.shade700,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _getOperatingHoursText(talyer),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  bool _isTalyerOperating(Map<String, dynamic> talyer) {
    final currentHour = DateTime.now().hour;
    final startHour = talyer['openHours']['start'];
    final endHour = talyer['openHours']['end'];
    
    // Handle 24/7 operations
    if (startHour == 0 && endHour == 24) return true;
    
    // Handle night shift (e.g., 18:00 to 6:00)
    if (startHour > endHour) {
      return currentHour >= startHour || currentHour < endHour;
    }
    
    // Handle normal hours
    return currentHour >= startHour && currentHour < endHour;
  }

  String _getOperatingHoursText(Map<String, dynamic> talyer) {
    final startHour = talyer['openHours']['start'];
    final endHour = talyer['openHours']['end'];
    
    if (startHour == 0 && endHour == 24) {
      return 'Open 24/7';
    }
    
    return 'Open ${_formatHour(startHour)} - ${_formatHour(endHour)}';
  }

  String _formatHour(int hour) {
    if (hour == 0) return '12:00 AM';
    if (hour < 12) return '${hour}:00 AM';
    if (hour == 12) return '12:00 PM';
    return '${hour - 12}:00 PM';
  }

  void _selectTalyer(Map<String, dynamic> talyer) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Select ${talyer['name']}?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.isInspectionOnly
                  ? 'Send inspection request to this talyer?'
                  : 'Send service request to this talyer?',
            ),
            const SizedBox(height: 12),
            Text(
              'Owner: ${talyer['owner']}',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            Text('Distance: ${talyer['distance']}'),
            Text('Response Time: ${talyer['averageResponseTime']}'),
            Text('Price Range: ${talyer['priceRange']}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              _dispatchToTalyer(talyer);
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  void _dispatchToTalyer(Map<String, dynamic> talyer) {
    // Show dispatching dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              widget.isInspectionOnly
                  ? 'Sending inspection request to ${talyer['name']}...'
                  : 'Dispatching mechanic from ${talyer['name']}...',
            ),
          ],
        ),
      ),
    );

    // Simulate dispatch process
    Future.delayed(const Duration(seconds: 3), () {
      Navigator.pop(context); // Close dispatching dialog
      
      // Generate a mock service request ID
      final serviceRequestId = 'REQ_${DateTime.now().millisecondsSinceEpoch}';
      
      // Navigate to mechanic waiting screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => MechanicWaitingScreen(
            serviceRequestId: serviceRequestId,
            issueType: widget.serviceType,
            issueDescription: widget.description,
            issueTitle: widget.isInspectionOnly ? 'Vehicle Inspection' : widget.serviceType,
          ),
        ),
      );
    });
  }
}











