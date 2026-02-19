import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/shop_services_service.dart';
import 'request_assistance_screen.dart';

class ShopServiceSelectionScreen extends StatefulWidget {
  final String shopId;
  final String shopName;
  final Map<String, dynamic> shopData;
  final LatLng customerLocation;
  
  const ShopServiceSelectionScreen({
    Key? key,
    required this.shopId,
    required this.shopName,
    required this.shopData,
    required this.customerLocation,
  }) : super(key: key);

  @override
  State<ShopServiceSelectionScreen> createState() => _ShopServiceSelectionScreenState();
}

class _ShopServiceSelectionScreenState extends State<ShopServiceSelectionScreen> {
  List<Map<String, dynamic>> _services = [];
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  String _searchQuery = '';
  String _selectedCategory = 'all';
  
  List<String> _categories = ['all'];

  @override
  void initState() {
    super.initState();
    _loadShopServices();
  }

  Future<void> _loadShopServices() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final services = await ShopServicesService.instance.getShopServicesWithDistance(
        shopId: widget.shopId,
        customerLocation: widget.customerLocation,
      );
      
      // Extract unique categories
      final categories = <String>{'all'};
      for (final service in services) {
        final categoryName = service['service_categories']?['name']?.toString();
        if (categoryName != null && categoryName.isNotEmpty) {
          categories.add(categoryName);
        }
      }
      
      setState(() {
        _services = services;
        _categories = categories.toList()..sort();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = e.toString();
      });
    }
  }

  List<Map<String, dynamic>> get _filteredServices {
    return _services.where((service) {
      // Search filter
      if (_searchQuery.isNotEmpty) {
        final serviceName = service['service_name']?.toString().toLowerCase() ?? '';
        final description = service['service_description']?.toString().toLowerCase() ?? '';
        final query = _searchQuery.toLowerCase();
        
        if (!serviceName.contains(query) && !description.contains(query)) {
          return false;
        }
      }
      
      // Category filter
      if (_selectedCategory != 'all') {
        final categoryName = service['service_categories']?['name']?.toString();
        if (categoryName != _selectedCategory) {
          return false;
        }
      }
      
      return true; // Services from shop services API are already active
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final distance = widget.shopData['distance']?.toDouble() ?? 0.0;
    final isOpen = widget.shopData['is_open'] ?? false;
    final rating = widget.shopData['rating']?.toDouble() ?? 0.0;
    final totalReviews = widget.shopData['total_reviews'] ?? 0;
    final shopAddress = widget.shopData['shop_address']?.toString() ?? '';

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 176, 12, 1),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.shopName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Shop Info Header
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
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.shopName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              shopAddress,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isOpen ? Colors.red : Colors.red,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          isOpen ? 'OPEN' : 'CLOSED',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        color: Colors.white70,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${distance.toStringAsFixed(1)} km away',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 20),
                      
                      if (rating > 0) ...[
                        Icon(
                          Icons.star,
                          color: Colors.yellow[300],
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${rating.toStringAsFixed(1)} ($totalReviews reviews)',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          // Search and Filter Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Search Bar
                TextField(
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search services...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                ),
                
                const SizedBox(height: 12),
                
                // Category Filter
                if (_categories.length > 1) ...[
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _categories.map((category) {
                        final isSelected = _selectedCategory == category;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(category == 'all' ? 'All Services' : category),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() {
                                _selectedCategory = selected ? category : 'all';
                              });
                            },
                            selectedColor: const Color.fromARGB(255, 176, 12, 1).withOpacity(0.2),
                            checkmarkColor: const Color.fromARGB(255, 176, 12, 1),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ],
            ),
          ),
          
          // Services Count
          if (!_isLoading)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text(
                '${_filteredServices.length} service${_filteredServices.length != 1 ? 's' : ''} available',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          
          // Services List
          Expanded(
            child: _buildServicesList(),
          ),
          
          // Continue Without Selecting Service Button
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info, color: Colors.blue[700]),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Need a service not listed? You can still request assistance and discuss your needs directly with the shop.',
                          style: TextStyle(
                            color: Colors.blue[700],
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 12),
                
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _proceedWithCustomRequest(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[600],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Request Custom Service from This Shop',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServicesList() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading services...'),
          ],
        ),
      );
    }

    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            const Text(
              'Unable to load services',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage,
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadShopServices,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 176, 12, 1),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    if (_filteredServices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.build_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty ? 'No services found' : 'No services available',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isNotEmpty 
                  ? 'Try adjusting your search'
                  : 'This shop hasn\'t listed any services yet',
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadShopServices,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _filteredServices.length,
        itemBuilder: (context, index) {
          return _buildServiceCard(_filteredServices[index]);
        },
      ),
    );
  }

  Widget _buildServiceCard(Map<String, dynamic> service) {
    final serviceName = service['service_name']?.toString() ?? 'Unknown Service';
    final description = service['service_description']?.toString() ?? '';
    final price = service['price']?.toDouble() ?? 0.0;
    final estimatedDuration = service['estimated_duration'] ?? 0;
    final categoryName = service['service_categories']?['name']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _selectService(service),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            serviceName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          if (categoryName.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              categoryName,
                              style: const TextStyle(
                                color: Color.fromARGB(255, 176, 12, 1),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Text(
                      '₱${price.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
                
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
                
                const SizedBox(height: 12),
                
                Row(
                  children: [
                    if (estimatedDuration > 0) ...[
                      Icon(
                        Icons.access_time,
                        size: 16,
                        color: Colors.grey[500],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${estimatedDuration} min',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                      const Spacer(),
                    ],
                    
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color.fromARGB(255, 176, 12, 1).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Text(
                        'Select Service',
                        style: TextStyle(
                          color: Color.fromARGB(255, 176, 12, 1),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
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
    );
  }

  void _selectService(Map<String, dynamic> service) {
    final serviceName = service['service_name']?.toString() ?? 'Unknown Service';
    final price = service['price']?.toDouble() ?? 0.0;
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RequestAssistanceScreen(
          initialServiceType: serviceName,
          preSelectedMechanic: {
            'shopId': widget.shopId,
            'shopName': widget.shopName,
            'shopData': widget.shopData,
            'providerId': widget.shopData['provider_id']?.toString(),
            'selectedService': service,
            'estimatedPrice': price,
            'serviceType': 'shop_based', // This will ensure only shop mechanics are notified
          },
        ),
      ),
    );
  }

  void _proceedWithCustomRequest() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RequestAssistanceScreen(
          initialServiceType: 'Custom Service Request',
          preSelectedMechanic: {
            'shopId': widget.shopId,
            'shopName': widget.shopName,
            'shopData': widget.shopData,
            'providerId': widget.shopData['provider_id']?.toString(),
            'serviceType': 'shop_based', // This will ensure only shop mechanics are notified
            'isCustomRequest': true,
          },
        ),
      ),
    );
  }
}











