import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/marketplace_service.dart';
import '../services/auth_service.dart';

class ServiceRequestScreen extends StatefulWidget {
  final ShopWithServices shop;
  final LatLng? customerLocation;

  const ServiceRequestScreen({
    super.key,
    required this.shop,
    this.customerLocation,
  });

  @override
  State<ServiceRequestScreen> createState() => _ServiceRequestScreenState();
}

class _ServiceRequestScreenState extends State<ServiceRequestScreen> {
  final MarketplaceService _marketplaceService = MarketplaceService();
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();

  List<Vehicle> _vehicles = [];
  
  Vehicle? _selectedVehicle;
  ShopService? _selectedService;
  bool _isEmergency = false;
  DateTime? _preferredTime;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    _initializeAddress();
  }

  void _initializeAddress() {
    if (widget.customerLocation != null) {
      // You would typically use a geocoding service to convert coordinates to address
      _addressController.text = 'Current Location (${widget.customerLocation!.latitude.toStringAsFixed(6)}, ${widget.customerLocation!.longitude.toStringAsFixed(6)})';
    }
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final user = await AuthService.getCurrentUser();
      if (user?.id == null) {
        throw Exception('User not authenticated');
      }

      // Load customer vehicles
      _vehicles = await _marketplaceService.getCustomerVehicles(user!.id);

      // Set default vehicle if available
      if (_vehicles.isNotEmpty) {
        _selectedVehicle = _vehicles.firstWhere(
          (v) => v.isPrimary,
          orElse: () => _vehicles.first,
        );
      }

    } catch (e) {
      _showError('Failed to load data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedVehicle == null) {
      _showError('Please select a vehicle');
      return;
    }
    if (_selectedService == null) {
      _showError('Please select a service');
      return;
    }
    if (widget.customerLocation == null) {
      _showError('Location not available');
      return;
    }

    try {
      setState(() {
        _isLoading = true;
      });

      final user = await AuthService.getCurrentUser();
      if (user?.id == null) {
        throw Exception('User not authenticated');
      }

      final result = await _marketplaceService.createServiceRequest(
        customerId: user!.id,
        shopId: widget.shop.shopId,
        serviceId: _selectedService!.serviceId,
        vehicleId: _selectedVehicle!.id,
        pickupLatitude: widget.customerLocation!.latitude,
        pickupLongitude: widget.customerLocation!.longitude,
        pickupAddress: _addressController.text.trim(),
        description: _descriptionController.text.trim().isEmpty 
            ? null 
            : _descriptionController.text.trim(),
        isEmergency: _isEmergency,
        preferredTime: _preferredTime,
      );

      if (result.success) {
        _showSuccessDialog(result);
      } else {
        _showError(result.error ?? 'Failed to create service request');
      }

    } catch (e) {
      _showError('Error: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccessDialog(ServiceRequestResult result) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Request Submitted'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(result.message),
            const SizedBox(height: 16),
            Text('Shop: ${result.shopName}'),
            Text('Service: ${result.serviceName}'),
            Text('Estimated Price: ₱${result.estimatedPrice?.toStringAsFixed(2)}'),
            Text('Distance: ${result.distanceKm?.toStringAsFixed(1)} km'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(); // Go back to marketplace
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Request Service - ${widget.shop.shopName}'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildShopSummary(),
                    const SizedBox(height: 24),
                    _buildVehicleSelection(),
                    const SizedBox(height: 24),
                    _buildServiceSelection(),
                    const SizedBox(height: 24),
                    _buildLocationSection(),
                    const SizedBox(height: 24),
                    _buildDescriptionSection(),
                    const SizedBox(height: 24),
                    _buildOptionsSection(),
                    const SizedBox(height: 24),
                    _buildPriceEstimate(),
                    const SizedBox(height: 32),
                    _buildSubmitButton(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildShopSummary() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.blue.withAlpha(26),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.car_repair, size: 30, color: Colors.blue),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.shop.shopName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${widget.shop.distanceKm.toStringAsFixed(1)} km away',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 16),
                      const SizedBox(width: 2),
                      Text(
                        '${widget.shop.averageRating.toStringAsFixed(1)} (${widget.shop.totalReviews})',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVehicleSelection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Vehicle',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (_vehicles.isEmpty)
              const Text('No vehicles found. Please add a vehicle first.')
            else
              DropdownButtonFormField<Vehicle>(
                value: _selectedVehicle,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Vehicle',
                ),
                items: _vehicles.map((vehicle) {
                  return DropdownMenuItem(
                    value: vehicle,
                    child: Text(
                      '${vehicle.brandName} ${vehicle.modelName} ${vehicle.year}' +
                      (vehicle.plateNumber != null ? ' (${vehicle.plateNumber})' : ''),
                    ),
                  );
                }).toList(),
                onChanged: (vehicle) {
                  setState(() {
                    _selectedVehicle = vehicle;
                  });
                },
                validator: (value) {
                  if (value == null) {
                    return 'Please select a vehicle';
                  }
                  return null;
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceSelection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Service',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...widget.shop.availableServices.map((service) {
              return RadioListTile<ShopService>(
                value: service,
                groupValue: _selectedService,
                onChanged: (selected) {
                  setState(() {
                    _selectedService = selected;
                  });
                },
                title: Text(service.serviceName),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (service.description != null)
                      Text(service.description!),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          '₱${service.price.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                        if (service.estimatedDuration != null) ...[
                          const SizedBox(width: 16),
                          Text('${service.estimatedDuration} min'),
                        ],
                      ],
                    ),
                  ],
                ),
                contentPadding: EdgeInsets.zero,
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pickup Location',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Address',
                hintText: 'Enter pickup address',
              ),
              maxLines: 2,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter pickup address';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDescriptionSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Service Description',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Describe the issue or specific service needed (optional)',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'e.g., Engine making strange noise, battery not starting...',
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Service Options',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
              value: _isEmergency,
              onChanged: (value) {
                setState(() {
                  _isEmergency = value ?? false;
                });
              },
              title: const Text('Emergency Service'),
              subtitle: const Text('Faster response (+50% service fee)'),
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceEstimate() {
    if (_selectedService == null) return const SizedBox.shrink();

    final servicePrice = _selectedService!.price;
    final serviceFee = widget.shop.minServiceFee * (_isEmergency ? 1.5 : 1.0);
    final total = servicePrice + serviceFee;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Price Estimate',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Service Price:'),
                Text('₱${servicePrice.toStringAsFixed(2)}'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Service Fee${_isEmergency ? ' (Emergency)' : ''}:'),
                Text('₱${serviceFee.toStringAsFixed(2)}'),
              ],
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total Estimate:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  '₱${total.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Note: Final price may vary based on actual work performed.',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submitRequest,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : const Text(
                'Submit Service Request',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
      ),
    );
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _addressController.dispose();
    super.dispose();
  }
}










