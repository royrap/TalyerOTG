import 'package:flutter/material.dart';
import '../models/vehicle_model.dart';
import '../services/user_data_service.dart';
import '../shared/widgets/add_vehicle_dialog.dart';

class ManageVehiclesScreen extends StatefulWidget {
  final List<Vehicle> vehicles;
  final Function(List<Vehicle>) onVehiclesUpdated;

  const ManageVehiclesScreen({
    super.key,
    required this.vehicles,
    required this.onVehiclesUpdated,
  });

  @override
  State<ManageVehiclesScreen> createState() => _ManageVehiclesScreenState();
}

class _ManageVehiclesScreenState extends State<ManageVehiclesScreen> {
  late List<Vehicle> _vehicles;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _vehicles = List.from(widget.vehicles);
  }

  Future<void> _refreshVehicles() async {
    setState(() => _isLoading = true);
    
    try {
      final vehiclesData = await UserDataService.getUserVehicles();
      final vehicles = vehiclesData.map((vehicleData) => Vehicle(
        id: vehicleData['id'],
        name: '${vehicleData['brand_name'] ?? ''} ${vehicleData['model_name'] ?? ''}'.trim(), // Updated field names
        plateNumber: vehicleData['plate_number'] ?? '',                                      // Updated field name
        icon: _getVehicleIcon(vehicleData['vehicle_type']),
        isPrimary: vehicleData['is_primary'] ?? false,
        // Add other fields from database
        year: vehicleData['year'],
        color: vehicleData['color'],
        vehicleType: vehicleData['vehicle_type'] ?? 'car',
        make: vehicleData['brand_name'],                                                     // Map to make for compatibility
        model: vehicleData['model_name'],                                                    // Map to model for compatibility
      )).toList();
      
      setState(() {
        _vehicles = vehicles;
      });
      
      widget.onVehiclesUpdated(_vehicles);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading vehicles: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  IconData _getVehicleIcon(String? vehicleType) {
    switch (vehicleType?.toLowerCase()) {
      case 'motorcycle':
        return Icons.motorcycle;
      case 'truck':
        return Icons.local_shipping;
      case 'van':
        return Icons.airport_shuttle;
      case 'suv':
        return Icons.directions_car;
      default:
        return Icons.directions_car;
    }
  }

  void _addVehicle() {
    showDialog(
      context: context,
      builder: (context) => AddVehicleDialog(
        onVehicleAdded: (newVehicleData) async {
          // Convert the database map to Vehicle object (Updated field names)
          final newVehicle = Vehicle(
            id: newVehicleData['id'],
            name: '${newVehicleData['brand_name'] ?? ''} ${newVehicleData['model_name'] ?? ''}'.trim(), // Updated field names
            plateNumber: newVehicleData['plate_number'] ?? '',                                          // Updated field name
            icon: _getVehicleIcon(newVehicleData['vehicle_type']),
            isPrimary: newVehicleData['is_primary'] ?? false,
            year: newVehicleData['year'],
            color: newVehicleData['color'],
            vehicleType: newVehicleData['vehicle_type'] ?? 'car',
            make: newVehicleData['brand_name'],                                                         // Map for compatibility
            model: newVehicleData['model_name'],                                                        // Map for compatibility
          );
          
          setState(() {
            _vehicles.add(newVehicle);
          });
          widget.onVehiclesUpdated(_vehicles);
        },
      ),
    );
  }

  Future<void> _setPrimary(String vehicleId) async {
    try {
      setState(() => _isLoading = true);
      
      // Update in database
      await UserDataService.updateVehicle(vehicleId, {'is_primary': true});
      
      // Update local state
      setState(() {
        for (var vehicle in _vehicles) {
          vehicle.isPrimary = vehicle.id == vehicleId;
        }
      });
      
      widget.onVehiclesUpdated(_vehicles);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Primary vehicle updated')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating vehicle: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _removeVehicle(String vehicleId) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Vehicle'),
        content: const Text('Are you sure you want to delete this vehicle? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    
    if (confirmed != true) return;
    
    try {
      setState(() => _isLoading = true);
      
      // Delete from database
      await UserDataService.deleteVehicle(vehicleId);
      
      // Update local state
      setState(() {
        _vehicles.removeWhere((vehicle) => vehicle.id == vehicleId);
      });
      
      widget.onVehiclesUpdated(_vehicles);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vehicle deleted successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting vehicle: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Vehicles'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshVehicles,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addVehicle,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _vehicles.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _refreshVehicles,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _vehicles.length,
                    itemBuilder: (context, index) {
                      final vehicle = _vehicles[index];
                      return _buildVehicleCard(vehicle);
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.directions_car_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No vehicles added yet',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add your first vehicle to get started',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _addVehicle,
            icon: const Icon(Icons.add),
            label: const Text('Add Vehicle'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromARGB(255, 176, 12, 1),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleCard(Vehicle vehicle) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                // Vehicle Icon
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(255, 176, 12, 1).withAlpha(26),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    vehicle.icon,
                    color: const Color.fromARGB(255, 176, 12, 1),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                
                // Vehicle Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              vehicle.displayName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          if (vehicle.isPrimary)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.red[50],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.red[200]!),
                              ),
                              child: const Text(
                                'Primary',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Plate: ${vehicle.plateNumber}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                      if (vehicle.year != null)
                        Text(
                          'Year: ${vehicle.year}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      if (vehicle.color != null && vehicle.color!.isNotEmpty)
                        Text(
                          'Color: ${vehicle.color}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                    ],
                  ),
                ),
                
                // Actions Menu
                PopupMenuButton<String>(
                  onSelected: (value) {
                    switch (value) {
                      case 'primary':
                        _setPrimary(vehicle.id);
                        break;
                      case 'delete':
                        _removeVehicle(vehicle.id);
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    if (!vehicle.isPrimary)
                      const PopupMenuItem(
                        value: 'primary',
                        child: Row(
                          children: [
                            Icon(Icons.star_outline, size: 20),
                            SizedBox(width: 8),
                            Text('Set as Primary'),
                          ],
                        ),
                      ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, size: 20, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                  child: const Icon(Icons.more_vert),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}





















