import 'package:flutter/material.dart';
import '../services/user_data_service.dart';
import '../services/auth_service.dart';
import 'vehicle_details_screen.dart';
import '../models/shop_model.dart';

class EnhancedServiceSelectionScreen extends StatefulWidget {
  final String serviceType;
  final String description;
  final String? issueTitle;

  const EnhancedServiceSelectionScreen({
    Key? key,
    required this.serviceType,
    required this.description,
    this.issueTitle,
  }) : super(key: key);

  @override
  State<EnhancedServiceSelectionScreen> createState() => _EnhancedServiceSelectionScreenState();
}

class _EnhancedServiceSelectionScreenState extends State<EnhancedServiceSelectionScreen> {
  String _selectedOption = ''; // 'shop_based' or 'routing'
  List<ShopModel> _availableShops = [];
  ShopModel? _selectedShop;
  bool _isLoadingShops = false;
  
  @override
  void initState() {
    super.initState();
    _loadAvailableShops();
  }
  
  Future<void> _loadAvailableShops() async {
    setState(() {
      _isLoadingShops = true;
    });
    
    try {
      // Load available shops from database
      final shops = await _fetchNearbyShops();
      setState(() {
        _availableShops = shops;
        _isLoadingShops = false;
      });
    } catch (e) {
      print('Error loading shops: $e');
      setState(() {
        _isLoadingShops = false;
      });
    }
  }
  
  Future<List<ShopModel>> _fetchNearbyShops() async {
    // Mock implementation - replace with actual API call
    return [
      ShopModel(
        id: '1',
        name: 'QuickFix Auto Services',
        owner: 'John Martinez',
        address: 'Makati City, Metro Manila',
        distance: '2.3 km',
        rating: 4.8,
        totalReviews: 156,
        specialties: ['Engine Repair', 'Transmission', 'Electrical'],
        isVerified: true,
        priceRange: '₱800 - ₱2,500',
        responseTime: '15-20 minutes',
      ),
      ShopModel(
        id: '2',
        name: 'Metro Roadside Rescue',
        owner: 'Maria Santos',
        address: 'Quezon City, Metro Manila',
        distance: '3.7 km',
        rating: 4.6,
        totalReviews: 203,
        specialties: ['Battery Replacement', 'Tire Repair', 'Jump Start'],
        isVerified: true,
        priceRange: '₱500 - ₱1,800',
        responseTime: '10-15 minutes',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 176, 12, 1),
        foregroundColor: Colors.white,
        title: const Text('Request Service'),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Header Info
          _buildHeaderInfo(),
          
          // Selection Options
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Service Request Options Title
                  const Text(
                    'How would you like to request service?',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Option 1: Specific Shop
                  _buildSelectionCard(
                    option: 'shop_based',
                    title: 'Choose Specific Shop',
                    subtitle: 'Select a shop and only their mechanics will receive your request',
                    icon: Icons.storefront,
                    color: Colors.blue,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Option 2: Any Available Mechanic
                  _buildSelectionCard(
                    option: 'routing',
                    title: 'Any Available Mechanic',
                    subtitle: 'Broadcast to all nearby mechanics for faster response',
                    icon: Icons.broadcast_on_personal,
                    color: Colors.orange,
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Shop Selection (if shop_based is selected)
                  if (_selectedOption == 'shop_based') ...[
                    _buildShopSelection(),
                    const SizedBox(height: 24),
                  ],
                  
                  // Continue Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _canProceed() ? _proceedToVehicleDetails : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromARGB(255, 176, 12, 1),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: Text(
                        _getButtonText(),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildHeaderInfo() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color.fromARGB(255, 176, 12, 1),
            const Color.fromARGB(255, 200, 50, 30),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.build_circle,
                color: Colors.white,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.issueTitle ?? 'Roadside Assistance',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: Colors.white70,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Service Type: ${widget.serviceType}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Description: ${widget.description}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSelectionCard({
    required String option,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    final isSelected = _selectedOption == option;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedOption = option;
          if (option == 'routing') {
            _selectedShop = null; // Clear shop selection if switching to routing
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.white,
          border: Border.all(
            color: isSelected ? color : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected ? color : Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : Colors.grey[600],
                size: 28,
              ),
            ),
            
            const SizedBox(width: 16),
            
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? color : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            
            if (isSelected)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 16,
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildShopSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select a Shop',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        
        const SizedBox(height: 12),
        
        if (_isLoadingShops)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_availableShops.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange[200]!),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.orange),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'No shops available in your area. Please select "Any Available Mechanic" option.',
                    style: TextStyle(color: Colors.orange),
                  ),
                ),
              ],
            ),
          )
        else
          Column(
            children: _availableShops.map((shop) {
              final isSelected = _selectedShop?.id == shop.id;
              
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedShop = shop;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.blue[50] : Colors.white,
                      border: Border.all(
                        color: isSelected ? Colors.blue : Colors.grey[300]!,
                        width: isSelected ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: isSelected ? Colors.blue : Colors.grey[300],
                              child: Icon(
                                Icons.storefront,
                                color: isSelected ? Colors.white : Colors.grey[600],
                                size: 20,
                              ),
                            ),
                            
                            const SizedBox(width: 12),
                            
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          shop.name,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: isSelected ? Colors.blue[700] : Colors.black87,
                                          ),
                                        ),
                                      ),
                                      if (shop.isVerified)
                                        Icon(
                                          Icons.verified,
                                          color: Colors.blue[600],
                                          size: 16,
                                        ),
                                    ],
                                  ),
                                  
                                  const SizedBox(height: 4),
                                  
                                  Text(
                                    '${shop.distance} • ${shop.responseTime}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            if (isSelected)
                              const Icon(
                                Icons.check_circle,
                                color: Colors.blue,
                                size: 24,
                              ),
                          ],
                        ),
                        
                        const SizedBox(height: 8),
                        
                        Row(
                          children: [
                            Icon(Icons.star, size: 14, color: Colors.orange[600]),
                            const SizedBox(width: 4),
                            Text(
                              '${shop.rating} (${shop.totalReviews} reviews)',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Icon(Icons.attach_money, size: 14, color: Colors.red[600]),
                            Text(
                              shop.priceRange,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }
  
  bool _canProceed() {
    if (_selectedOption.isEmpty) return false;
    if (_selectedOption == 'routing') return true;
    if (_selectedOption == 'shop_based') return _selectedShop != null;
    return false;
  }
  
  String _getButtonText() {
    if (_selectedOption.isEmpty) {
      return 'Select an option to continue';
    }
    if (_selectedOption == 'routing') {
      return 'Continue with Any Available Mechanic';
    }
    if (_selectedOption == 'shop_based') {
      if (_selectedShop == null) {
        return 'Select a shop to continue';
      }
      return 'Continue with ${_selectedShop!.name}';
    }
    return 'Continue';
  }
  
  void _proceedToVehicleDetails() {
    Map<String, dynamic>? preSelectedMechanic;
    
    if (_selectedOption == 'shop_based' && _selectedShop != null) {
      preSelectedMechanic = {
        'serviceType': 'shop_based',
        'shopId': _selectedShop!.id,
        'shopName': _selectedShop!.name,
        'providerId': _selectedShop!.id, // Assuming shop ID is provider ID
      };
    } else {
      preSelectedMechanic = {
        'serviceType': 'routing',
      };
    }
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VehicleDetailsScreen(
          issueType: widget.serviceType,
          issueDescription: widget.description,
          issueTitle: widget.issueTitle,
          preSelectedMechanic: preSelectedMechanic,
        ),
      ),
    );
  }
}










