import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'talyer_owner_api_service.dart';

class ShopSettingsScreen extends StatefulWidget {
  final String shopId;

  const ShopSettingsScreen({Key? key, required this.shopId}) : super(key: key);

  @override
  State<ShopSettingsScreen> createState() => _ShopSettingsScreenState();
}

class _ShopSettingsScreenState extends State<ShopSettingsScreen> {
  final TalyerOwnerApiService _apiService = TalyerOwnerApiService();
  final _formKey = GlobalKey<FormState>();
  
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isFetchingLocation = false;
  
  // Controllers
  final _shopNameController = TextEditingController();
  final _shopAddressController = TextEditingController();
  final _shopPhoneController = TextEditingController();
  final _shopEmailController = TextEditingController();
  final _shopDescriptionController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();
  
  // Owner data (now editable)
  final _ownerNameController = TextEditingController();
  final _ownerEmailController = TextEditingController();
  final _ownerPhoneController = TextEditingController();
  String? _businessPermitUrl;
  String? _driversLicenseUrl;

  Map<String, Map<String, String?>> _businessHours = {
    'monday': {'open': '08:00', 'close': '18:00'},
    'tuesday': {'open': '08:00', 'close': '18:00'},
    'wednesday': {'open': '08:00', 'close': '18:00'},
    'thursday': {'open': '08:00', 'close': '18:00'},
    'friday': {'open': '08:00', 'close': '18:00'},
    'saturday': {'open': '08:00', 'close': '16:00'},
    'sunday': {'open': null, 'close': null},
  };

  @override
  void initState() {
    super.initState();
    _loadShopSettings();
  }

  @override
  void dispose() {
    _shopNameController.dispose();
    _shopAddressController.dispose();
    _shopPhoneController.dispose();
    _shopEmailController.dispose();
    _shopDescriptionController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _ownerNameController.dispose();
    _ownerEmailController.dispose();
    _ownerPhoneController.dispose();
    super.dispose();
  }

  Future<void> _loadShopSettings() async {
    setState(() => _isLoading = true);

    try {
      final settings = await _apiService.getShopSettings(widget.shopId);

      if (settings != null) {
        // Shop data
        _shopNameController.text = settings['shop_name'] ?? '';
        _shopAddressController.text = settings['shop_address'] ?? '';
        _shopPhoneController.text = settings['shop_phone'] ?? '';
        _shopEmailController.text = settings['shop_email'] ?? '';
        _shopDescriptionController.text = settings['shop_description'] ?? '';
        _latitudeController.text = settings['latitude']?.toString() ?? '';
        _longitudeController.text = settings['longitude']?.toString() ?? '';

        // Owner data
        _ownerNameController.text = settings['contact_person'] ?? '';
        _ownerEmailController.text = settings['owner_email'] ?? '';
        _ownerPhoneController.text = settings['owner_phone'] ?? '';
        _businessPermitUrl = settings['business_permit_url'];
        _driversLicenseUrl = settings['drivers_license_url'];

        // Parse business hours
        if (settings['business_hours'] != null) {
          final hours = Map<String, dynamic>.from(settings['business_hours'] as Map);
          _businessHours = hours.map((key, value) {
            if (value is Map) {
              return MapEntry(key, {
                'open': value['open'] as String?,
                'close': value['close'] as String?,
              });
            }
            return MapEntry(key, {'open': null, 'close': null});
          });
        }
      }

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading settings: $e')),
        );
      }
    }
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      // Safely parse latitude/longitude to avoid FormatException
      double? latitude;
      double? longitude;

      if (_latitudeController.text.isNotEmpty) {
        latitude = double.tryParse(_latitudeController.text.replaceAll(',', '.'));
        if (latitude == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Invalid latitude value')),
            );
          }
          setState(() => _isSaving = false);
          return;
        }
      }

      if (_longitudeController.text.isNotEmpty) {
        longitude = double.tryParse(_longitudeController.text.replaceAll(',', '.'));
        if (longitude == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Invalid longitude value')),
            );
          }
          setState(() => _isSaving = false);
          return;
        }
      }

      await _apiService.updateShopSettings(
        shopId: widget.shopId,
        shopName: _shopNameController.text.isNotEmpty ? _shopNameController.text : null,
        shopAddress: _shopAddressController.text.isNotEmpty ? _shopAddressController.text : null,
        shopPhone: _shopPhoneController.text.isNotEmpty ? _shopPhoneController.text : null,
        shopEmail: _shopEmailController.text.isNotEmpty ? _shopEmailController.text : null,
        shopDescription: _shopDescriptionController.text.isNotEmpty ? _shopDescriptionController.text : null,
        latitude: latitude,
        longitude: longitude,
        // serviceRadius removed
        businessHours: _businessHours,
        contactPerson: _ownerNameController.text.isNotEmpty ? _ownerNameController.text : null,
        ownerEmail: _ownerEmailController.text.isNotEmpty ? _ownerEmailController.text : null,
        ownerPhone: _ownerPhoneController.text.isNotEmpty ? _ownerPhoneController.text : null,
      );

      setState(() => _isSaving = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving settings: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isFetchingLocation = true);

    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location services are disabled. Please enable location services.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );
        }
        setState(() => _isFetchingLocation = false);
        return;
      }

      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Location permission denied'),
                backgroundColor: Colors.red,
              ),
            );
          }
          setState(() => _isFetchingLocation = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permission denied permanently. Please enable in app settings.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 4),
            ),
          );
        }
        setState(() => _isFetchingLocation = false);
        return;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Update text fields
      setState(() {
        _latitudeController.text = position.latitude.toStringAsFixed(6);
        _longitudeController.text = position.longitude.toStringAsFixed(6);
        _isFetchingLocation = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📍 Location retrieved successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      setState(() => _isFetchingLocation = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error getting location: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shop Settings'),
        backgroundColor: Colors.red,
        actions: [
          if (!_isLoading)
            IconButton(
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.save),
              onPressed: _isSaving ? null : _saveSettings,
            ),
        ],
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
                    const Text(
                      '� Owner Information',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildOwnerInfoSection(),
                    const SizedBox(height: 24),
                    // Basic Information removed per request
                    const SizedBox(height: 8),
                    const Text(
                      '📍 Location Settings',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildLocationSection(),
                    const SizedBox(height: 24),
                    const Text(
                      '🕐 Business Hours',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildBusinessHoursSection(),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveSettings,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Save Changes',
                                style: TextStyle(
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
    );
  }

  // Basic information section removed per request.

  Widget _buildLocationSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _latitudeController,
                    decoration: const InputDecoration(
                      labelText: 'Latitude',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.my_location),
                    ),
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _longitudeController,
                    decoration: const InputDecoration(
                      labelText: 'Longitude',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.place),
                    ),
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isFetchingLocation ? null : _getCurrentLocation,
                icon: _isFetchingLocation
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.gps_fixed),
                label: Text(
                  _isFetchingLocation ? 'Getting Location...' : 'Get Current Location',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildBusinessHoursSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: _businessHours.entries.map((entry) {
            final day = entry.key;
            final hours = entry.value;
            final isClosed = hours['open'] == null || hours['close'] == null;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 100,
                    child: Text(
                      day.substring(0, 1).toUpperCase() + day.substring(1),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Expanded(
                    child: isClosed
                        ? const Text(
                            'Closed',
                            style: TextStyle(
                              color: Colors.grey,
                              fontStyle: FontStyle.italic,
                            ),
                          )
                        : Text(
                            '${hours['open']} - ${hours['close']}',
                            style: const TextStyle(fontSize: 14),
                          ),
                  ),
                  IconButton(
                    icon: Icon(
                      isClosed ? Icons.add_circle_outline : Icons.edit,
                      color: Colors.orange,
                    ),
                    onPressed: () => _editBusinessHours(day, hours),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Future<void> _editBusinessHours(String day, Map<String, String?> currentHours) async {
    bool isClosed = currentHours['open'] == null;
    TimeOfDay? openTime;
    TimeOfDay? closeTime;

    // Parse existing times
    if (!isClosed) {
      final openParts = (currentHours['open'] ?? '08:00').split(':');
      final closeParts = (currentHours['close'] ?? '18:00').split(':');
      openTime = TimeOfDay(
        hour: int.parse(openParts[0]),
        minute: int.parse(openParts[1]),
      );
      closeTime = TimeOfDay(
        hour: int.parse(closeParts[0]),
        minute: int.parse(closeParts[1]),
      );
    }

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Edit ${day.substring(0, 1).toUpperCase()}${day.substring(1)} Hours'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                title: const Text('Closed'),
                value: isClosed,
                onChanged: (value) {
                  setDialogState(() => isClosed = value);
                },
              ),
              if (!isClosed) ...[
                const SizedBox(height: 16),
                // Opening Time Picker
                InkWell(
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: openTime ?? const TimeOfDay(hour: 8, minute: 0),
                      builder: (context, child) {
                        return MediaQuery(
                          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
                          child: child!,
                        );
                      },
                    );
                    if (picked != null) {
                      setDialogState(() => openTime = picked);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.access_time, color: Colors.green),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Opening Time',
                                style: TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                openTime != null ? _formatTimeOfDay(openTime!) : '08:00 AM',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.edit, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Closing Time Picker
                InkWell(
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: closeTime ?? const TimeOfDay(hour: 18, minute: 0),
                      builder: (context, child) {
                        return MediaQuery(
                          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
                          child: child!,
                        );
                      },
                    );
                    if (picked != null) {
                      setDialogState(() => closeTime = picked);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.access_time, color: Colors.red),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Closing Time',
                                style: TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                closeTime != null ? _formatTimeOfDay(closeTime!) : '06:00 PM',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.edit, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  if (isClosed) {
                    _businessHours[day] = {'open': null, 'close': null};
                  } else {
                    // Provide safe defaults if user didn't pick times to avoid
                    // null-check operator errors when using openTime/closeTime.
                    final safeOpen = openTime ?? const TimeOfDay(hour: 8, minute: 0);
                    final safeClose = closeTime ?? const TimeOfDay(hour: 18, minute: 0);

                    _businessHours[day] = {
                      'open': _timeOfDayTo24Hour(safeOpen),
                      'close': _timeOfDayTo24Hour(safeClose),
                    };
                  }
                });
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  /// Convert TimeOfDay to 24-hour format string (HH:MM)
  String _timeOfDayTo24Hour(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  /// Format TimeOfDay to 12-hour format for display (e.g., "6:00 PM")
  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  Widget _buildOwnerInfoSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue[700]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Owner contact information (editable)',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[700],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _ownerNameController,
              decoration: const InputDecoration(
                labelText: 'Contact Person',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter contact person name';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _ownerEmailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter email';
                }
                if (!value.contains('@')) {
                  return 'Please enter a valid email';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _ownerPhoneController,
              decoration: const InputDecoration(
                labelText: 'Phone',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter phone number';
                }
                return null;
              },
            ),
            if (_businessPermitUrl != null) ...[
              const SizedBox(height: 12),
              _buildDocumentLink('Business Permit', _businessPermitUrl!),
            ],
            if (_driversLicenseUrl != null) ...[
              const SizedBox(height: 12),
              _buildDocumentLink('Driver\'s License', _driversLicenseUrl!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentLink(String label, String url) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.description, color: Colors.blue[700]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  'Verified document on file',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.check_circle, color: Colors.green[700]),
        ],
      ),
    );
  }
}
