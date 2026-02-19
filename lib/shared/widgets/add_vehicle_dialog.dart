import 'package:flutter/material.dart';
import '../../services/user_data_service.dart';
import '../../services/vehicle_api_service.dart';

class AddVehicleDialog extends StatefulWidget {
  final Function(Map<String, dynamic>) onVehicleAdded;

  const AddVehicleDialog({
    super.key, 
    required this.onVehicleAdded,
  });

  @override
  State<AddVehicleDialog> createState() => _AddVehicleDialogState();
}

class _AddVehicleDialogState extends State<AddVehicleDialog> {
  final _formKey = GlobalKey<FormState>();
  final _plateController = TextEditingController();
  
  String? _selectedBrand;
  String? _selectedBrandId;
  String? _selectedModel;
  String? _selectedModelId;
  String? _selectedVehicleType;
  String? _selectedColor;
  int? _selectedYear;
  bool _isLoading = false;
  bool _isPrimary = false;
  bool _isLoadingBrands = true;
  bool _isLoadingModels = false;

  List<VehicleBrand> _availableBrands = [];
  List<VehicleModel> _availableModels = [];
  List<int> _availableYears = [];
  final List<Map<String, dynamic>> _vehicleTypes = [
    {'name': 'Car', 'value': 'car', 'icon': Icons.directions_car},
    {'name': 'Motorcycle', 'value': 'motorcycle', 'icon': Icons.motorcycle},
    {'name': 'Truck', 'value': 'truck', 'icon': Icons.local_shipping},
    {'name': 'Van', 'value': 'van', 'icon': Icons.airport_shuttle},
    {'name': 'SUV', 'value': 'suv', 'icon': Icons.directions_car},
  ];

  final List<String> _colors = [
    'White', 'Black', 'Silver', 'Gray', 'Red', 'Blue', 'Green', 
    'Yellow', 'Orange', 'Brown', 'Purple', 'Gold', 'Other'
  ];
  @override
  void initState() {
    super.initState();
    _selectedVehicleType = 'car'; // Set default
    _loadBrands();
  }
  
  @override
  void dispose() {
    _plateController.dispose();
    super.dispose();
  }

  /// Load vehicle brands from API
  Future<void> _loadBrands() async {
    setState(() {
      _isLoadingBrands = true;
    });
    
    try {
      final brands = await VehicleApiService.getAllBrands();
      setState(() {
        _availableBrands = brands;
        _isLoadingBrands = false;
      });
    } catch (e) {
      print('Error loading brands: $e');
      setState(() {
        _isLoadingBrands = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading vehicle brands: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Load models for selected brand and vehicle type
  Future<void> _loadModels() async {
    if (_selectedBrandId == null || _selectedVehicleType == null) return;

    setState(() {
      _isLoadingModels = true;
      _availableModels = [];
      _selectedModel = null;
      _selectedModelId = null;
      _availableYears = [];
      _selectedYear = null;
    });

    try {
      final allModels = await VehicleApiService.getModelsByBrand(_selectedBrandId!);
      // Filter models by vehicle type
      final filteredModels = allModels.where((model) => model.type == _selectedVehicleType).toList();
      
      setState(() {
        _availableModels = filteredModels;
        _isLoadingModels = false;
      });
    } catch (e) {
      print('Error loading models: $e');
      setState(() {
        _isLoadingModels = false;
      });
    }
  }

  /// Generate available years for selected model
  void _generateAvailableYears() {
    if (_selectedModelId == null) return;

    final selectedModel = _availableModels.firstWhere((model) => model.id == _selectedModelId);
    final currentYear = DateTime.now().year;
    final startYear = selectedModel.startYear;
    final endYear = selectedModel.endYear ?? currentYear;

    setState(() {
      _availableYears = List.generate(
        endYear - startYear + 1,
        (index) => startYear + index,
      ).reversed.toList(); // Most recent years first
      _selectedYear = null;
    });
  }
  Future<void> _addVehicle() async {
    if (!_formKey.currentState!.validate()) return;

    // Validation using the new API-based fields
    if (_selectedBrand == null || 
        _selectedVehicleType == null ||
        _selectedModel == null ||
        _selectedYear == null ||
        _plateController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all required fields'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final newVehicle = await UserDataService.addVehicle(
        brandName: _selectedBrand!,
        modelName: _selectedModel!,
        year: _selectedYear!,
        color: _selectedColor,
        plateNumber: _plateController.text.trim(),
        vehicleType: _selectedVehicleType!,
        isPrimary: _isPrimary,
      );

      if (mounted) {
        Navigator.of(context).pop();
        widget.onVehicleAdded(newVehicle);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vehicle added successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding vehicle: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Vehicle'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Vehicle Type
                DropdownButtonFormField<String>(
                  value: _selectedVehicleType,
                  decoration: const InputDecoration(
                    labelText: 'Vehicle Type *',
                    border: OutlineInputBorder(),
                  ),
                  items: _vehicleTypes.map((type) {
                    return DropdownMenuItem<String>(
                      value: type['value'],
                      child: Row(
                        children: [
                          Icon(type['icon'], size: 20),
                          const SizedBox(width: 8),
                          Text(type['name']),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedVehicleType = value;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select a vehicle type';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                  // Brand Dropdown
                _isLoadingBrands
                    ? const Center(child: CircularProgressIndicator())
                    : DropdownButtonFormField<String>(
                        value: _selectedBrand,
                        decoration: const InputDecoration(
                          labelText: 'Brand *',
                          border: OutlineInputBorder(),
                        ),
                        items: _availableBrands.map((brand) {
                          return DropdownMenuItem<String>(
                            value: brand.name,
                            child: Text(brand.name),
                          );
                        }).toList(),
                        onChanged: (brandName) {
                          final selectedBrand = _availableBrands.firstWhere((brand) => brand.name == brandName);
                          setState(() {
                            _selectedBrand = brandName;
                            _selectedBrandId = selectedBrand.id;
                            // Reset dependent dropdowns
                            _selectedModel = null;
                            _selectedModelId = null;
                            _selectedYear = null;
                            _availableModels = [];
                            _availableYears = [];
                          });
                          _loadModels();
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please select a brand';
                          }
                          return null;
                        },
                      ),
                const SizedBox(height: 16),
                
                // Model Dropdown
                _isLoadingModels
                    ? const Row(
                        children: [
                          SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 8),
                          Text('Loading models...'),
                        ],
                      )
                    : DropdownButtonFormField<String>(
                        value: _selectedModel,
                        decoration: const InputDecoration(
                          labelText: 'Model *',
                          border: OutlineInputBorder(),
                        ),
                        items: _availableModels.map((model) {
                          return DropdownMenuItem<String>(
                            value: model.name,
                            child: Text(model.name),
                          );
                        }).toList(),
                        onChanged: _availableModels.isEmpty ? null : (modelName) {
                          final selectedModel = _availableModels.firstWhere((model) => model.name == modelName);
                          setState(() {
                            _selectedModel = modelName;
                            _selectedModelId = selectedModel.id;
                            _selectedYear = null;
                          });
                          _generateAvailableYears();
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please select a model';
                          }
                          return null;
                        },
                      ),
                const SizedBox(height: 16),
                
                // Year Dropdown
                DropdownButtonFormField<int>(
                  value: _selectedYear,
                  decoration: const InputDecoration(
                    labelText: 'Year *',
                    border: OutlineInputBorder(),
                  ),
                  items: _availableYears.map((year) {
                    return DropdownMenuItem<int>(
                      value: year,
                      child: Text(year.toString()),
                    );
                  }).toList(),
                  onChanged: _availableYears.isEmpty ? null : (year) {
                    setState(() {
                      _selectedYear = year;
                    });
                  },
                  validator: (value) {
                    if (value == null) {
                      return 'Please select a year';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                // License Plate
                TextFormField(
                  controller: _plateController,
                  decoration: const InputDecoration(
                    labelText: 'License Plate *',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.characters,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter the license plate';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                  // Color Dropdown
                DropdownButtonFormField<String>(
                  value: _selectedColor,
                  decoration: const InputDecoration(
                    labelText: 'Color',
                    border: OutlineInputBorder(),
                  ),
                  items: _colors.map((color) {
                    return DropdownMenuItem<String>(
                      value: color,
                      child: Text(color),
                    );
                  }).toList(),
                  onChanged: (color) {
                    setState(() {
                      _selectedColor = color;
                    });
                  },
                ),
                const SizedBox(height: 16),
                
                // Primary Vehicle Checkbox
                CheckboxListTile(
                  title: const Text('Set as primary vehicle'),
                  value: _isPrimary,
                  onChanged: (value) {
                    setState(() {
                      _isPrimary = value ?? false;
                    });
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _addVehicle,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color.fromARGB(255, 176, 12, 1),
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Text('Add Vehicle'),
        ),
      ],
    );
  }
}










