import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/shop_model.dart';
import '../services/supabase_service.dart';
import 'vehicle_selection_screen.dart';

/// 🏪 Shop Services Selection Screen
/// Shows all services offered by the selected shop with prices
class ShopServicesSelectionScreen extends StatefulWidget {
  final ShopModel shop;
  final double customerLat;
  final double customerLng;

  const ShopServicesSelectionScreen({
    Key? key,
    required this.shop,
    required this.customerLat,
    required this.customerLng,
  }) : super(key: key);

  @override
  State<ShopServicesSelectionScreen> createState() => _ShopServicesSelectionScreenState();
}

class _ShopServicesSelectionScreenState extends State<ShopServicesSelectionScreen> {
  List<Map<String, dynamic>> _services = [];
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _selectedService;

  @override
  void initState() {
    super.initState();
    _loadShopServices();
  }

  Future<void> _loadShopServices() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // Get all services for this shop
      final response = await SupabaseService.client
          .from('shop_services')
          .select('''
            id,
            service_name,
            service_description,
            base_price,
            service_category,
            estimated_duration,
            is_active
          ''')
          .eq('shop_id', widget.shop.id)
          .eq('is_active', true)
          .order('service_category')
          .order('service_name');

      setState(() {
        _services = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });

      print('✅ Loaded ${_services.length} services for shop ${widget.shop.shopName}');
    } catch (e) {
      print('❌ Error loading shop services: $e');
      setState(() {
        _errorMessage = 'Failed to load services: $e';
        _isLoading = false;
      });
    }
  }

  void _onServiceSelected(Map<String, dynamic> service) {
    setState(() {
      _selectedService = service;
    });
  }

  void _proceedToVehicleSelection() {
    if (_selectedService == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a service first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Navigate to vehicle selection
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VehicleSelectionScreen(
          shop: widget.shop,
          selectedService: _selectedService!,
          customerLat: widget.customerLat,
          customerLng: widget.customerLng,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(widget.shop.shopName),
        backgroundColor: Colors.orange[700],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Shop Header Card
          _buildShopHeader(),
          
          // Services List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? _buildErrorState()
                    : _services.isEmpty
                        ? _buildEmptyState()
                        : _buildServicesList(),
          ),
        ],
      ),
      bottomNavigationBar: _selectedService != null
          ? _buildProceedButton()
          : null,
    );
  }

  Widget _buildShopHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.store, color: Colors.orange[700], size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.shop.shopName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            widget.shop.shopAddress,
                            style: TextStyle(
                              fontSize: 13,
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
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildInfoChip(
                Icons.star,
                '${widget.shop.rating.toStringAsFixed(1)} ⭐',
                Colors.amber,
              ),
              const SizedBox(width: 8),
              _buildInfoChip(
                Icons.phone,
                widget.shop.shopPhone,
                Colors.blue,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServicesList() {
    // Group services by category
    Map<String, List<Map<String, dynamic>>> groupedServices = {};
    for (var service in _services) {
      final category = service['service_category'] as String? ?? 'Other';
      if (!groupedServices.containsKey(category)) {
        groupedServices[category] = [];
      }
      groupedServices[category]!.add(service);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: groupedServices.length,
      itemBuilder: (context, index) {
        final category = groupedServices.keys.elementAt(index);
        final categoryServices = groupedServices[category]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category Header
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 12, top: index > 0 ? 16 : 0),
              child: Text(
                category.toUpperCase(),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                  letterSpacing: 1.2,
                ),
              ),
            ),
            
            // Services in this category
            ...categoryServices.map((service) => _buildServiceCard(service)).toList(),
          ],
        );
      },
    );
  }

  Widget _buildServiceCard(Map<String, dynamic> service) {
    final isSelected = _selectedService?['id'] == service['id'];
    final basePrice = service['base_price'] as num?;
    final duration = service['estimated_duration'] as String?;

    return GestureDetector(
      onTap: () => _onServiceSelected(service),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.orange : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected 
                  ? Colors.orange.withOpacity(0.3)
                  : Colors.black.withOpacity(0.05),
              blurRadius: isSelected ? 12 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Service Icon
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getServiceIcon(service['service_category']),
                  color: Colors.orange[700],
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              
              // Service Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      service['service_name'] ?? 'Unknown Service',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.orange[700] : Colors.black87,
                      ),
                    ),
                    if (service['service_description'] != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        service['service_description'],
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (duration != null) ...[
                          Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Text(
                            duration,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Icon(Icons.payments, size: 14, color: Colors.green[600]),
                        const SizedBox(width: 4),
                        Text(
                          basePrice != null 
                              ? '₱${basePrice.toStringAsFixed(2)}'
                              : 'Price varies',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.green[700],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Selection Indicator
              if (isSelected)
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getServiceIcon(String? category) {
    switch (category?.toLowerCase()) {
      case 'repair':
        return Icons.build;
      case 'maintenance':
        return Icons.settings;
      case 'inspection':
        return Icons.search;
      case 'lockout':
        return Icons.lock_open;
      case 'towing':
        return Icons.local_shipping;
      case 'tire':
        return Icons.tire_repair;
      case 'battery':
        return Icons.battery_charging_full;
      case 'oil change':
        return Icons.oil_barrel;
      default:
        return Icons.car_repair;
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No services available',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This shop hasn\'t added any services yet',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 80, color: Colors.red[400]),
          const SizedBox(height: 16),
          Text(
            'Error Loading Services',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _errorMessage ?? 'Unknown error occurred',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadShopServices,
            icon: const Icon(Icons.refresh),
            label: const Text('Try Again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange[700],
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProceedButton() {
    final basePrice = _selectedService?['base_price'] as num?;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Selected Service Summary
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.orange[700]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedService?['service_name'] ?? '',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (basePrice != null)
                          Text(
                            'Starting at ₱${basePrice.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[700],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            
            // Proceed Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _proceedToVehicleSelection,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange[700],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Text(
                      'Proceed to Vehicle Selection',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
