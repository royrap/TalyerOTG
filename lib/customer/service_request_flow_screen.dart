import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'available_shops_screen.dart';
import 'request_assistance_screen.dart';
import '../services/auth_service.dart';

class ServiceRequestFlowScreen extends StatefulWidget {
  const ServiceRequestFlowScreen({Key? key}) : super(key: key);

  @override
  State<ServiceRequestFlowScreen> createState() => _ServiceRequestFlowScreenState();
}

class _ServiceRequestFlowScreenState extends State<ServiceRequestFlowScreen> {
  int _currentStep = 0;
  final PageController _pageController = PageController();

  final List<Map<String, dynamic>> _flowSteps = [
    {
      'title': 'Choose Service Type',
      'description': 'Select your issue type and describe the problem',
      'icon': Icons.build,
      'status': 'pending',
    },
    {
      'title': 'Select Shop (Optional)',
      'description': 'Choose a nearby shop or let us find available mechanics',
      'icon': Icons.store,
      'status': 'pending',
    },
    {
      'title': 'Set Location',
      'description': 'Pin your exact location on the map',
      'icon': Icons.location_on,
      'status': 'pending',
    },
    {
      'title': 'Choose Vehicle',
      'description': 'Select and add your vehicle information',
      'icon': Icons.directions_car,
      'status': 'pending',
    },
    {
      'title': 'Pay Service Fee',
      'description': 'Pay the service fee to request assistance',
      'icon': Icons.payment,
      'status': 'pending',
    },
    {
      'title': 'Wait for Mechanic',
      'description': 'Mechanic will accept and head to your location',
      'icon': Icons.person_search,
      'status': 'pending',
    },
    {
      'title': 'Service & Payment',
      'description': 'Get service and pay the final invoice',
      'icon': Icons.construction,
      'status': 'pending',
    },
    {
      'title': 'Generate QR Code',
      'description': 'Show QR code to mechanic to complete the job',
      'icon': Icons.qr_code,
      'status': 'pending',
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
          'Request Roadside Assistance',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Header with progress indicator
          _buildHeader(),
          
          // Flow options
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Quick start options
                  _buildQuickStartSection(),
                  
                  const SizedBox(height: 30),
                  
                  // Process flow visualization
                  _buildProcessFlow(),
                  
                  const SizedBox(height: 30),
                  
                  // Action buttons
                  _buildActionButtons(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
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
          const Icon(
            Icons.car_repair,
            size: 60,
            color: Colors.white,
          ),
          const SizedBox(height: 16),
          const Text(
            'How would you like to get assistance?',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Choose your preferred flow and we\'ll guide you through',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStartSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Start Options',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        
        // Direct request option
        _buildQuickOption(
          title: 'Direct Request',
          description: 'Request any available mechanic nearby',
          icon: Icons.flash_on,
          color: Colors.red,
          onTap: () => _startDirectFlow(),
        ),
        
        const SizedBox(height: 12),
        
        // Shop-based request option
        _buildQuickOption(
          title: 'Choose Shop',
          description: 'Select from nearby verified auto shops',
          icon: Icons.store,
          color: Colors.blue,
          onTap: () => _startShopFlow(),
        ),
      ],
    );
  }

  Widget _buildQuickOption({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      width: double.infinity,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        elevation: 2,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
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
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.grey,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProcessFlow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Complete Process Flow',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Here\'s how the complete service process works:',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 16),
        
        // Flow steps
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _flowSteps.length,
          itemBuilder: (context, index) {
            final step = _flowSteps[index];
            final isLast = index == _flowSteps.length - 1;
            
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Step indicator
                Column(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(
                          color: const Color.fromARGB(255, 176, 12, 1),
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        step['icon'],
                        color: const Color.fromARGB(255, 176, 12, 1),
                        size: 20,
                      ),
                    ),
                    if (!isLast)
                      Container(
                        width: 2,
                        height: 50,
                        color: Colors.grey[300],
                      ),
                  ],
                ),
                
                const SizedBox(width: 16),
                
                // Step content
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                step['title'],
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${index + 1}',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          step['description'],
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        // Primary action button
        Container(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _startDirectFlow,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromARGB(255, 176, 12, 1),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 2,
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.flash_on, size: 20),
                SizedBox(width: 8),
                Text(
                  'Start Direct Request',
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
        
        // Secondary action button
        Container(
          width: double.infinity,
          height: 56,
          child: OutlinedButton(
            onPressed: _startShopFlow,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color.fromARGB(255, 176, 12, 1),
              side: const BorderSide(
                color: Color.fromARGB(255, 176, 12, 1),
                width: 2,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.store, size: 20),
                SizedBox(width: 8),
                Text(
                  'Browse Nearby Shops',
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

  void _startDirectFlow() {
    // Navigate directly to request assistance
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const RequestAssistanceScreen(),
      ),
    );
  }

  void _startShopFlow() async {
    // Get current location and navigate to shops
    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(
            color: Color.fromARGB(255, 176, 12, 1),
          ),
        ),
      );

      // Get location
      final position = await Geolocator.getCurrentPosition();
      
      // Close loading
      if (mounted) Navigator.pop(context);
      
      // Navigate to shops screen
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AvailableShopsScreen(
              userLocation: LatLng(position.latitude, position.longitude),
            ),
          ),
        );
      }
    } catch (e) {
      // Close loading
      if (mounted) Navigator.pop(context);
      
      // Show error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error getting location: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}










