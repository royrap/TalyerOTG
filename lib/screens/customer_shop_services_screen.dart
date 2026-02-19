import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/location_service.dart';
import '../widgets/nearby_shops_widget.dart';

import 'dart:async';

class CustomerShopServicesScreen extends StatefulWidget {
  const CustomerShopServicesScreen({Key? key}) : super(key: key);

  @override
  State<CustomerShopServicesScreen> createState() => _CustomerShopServicesScreenState();
}

class _CustomerShopServicesScreenState extends State<CustomerShopServicesScreen> {
  final LocationService _locationService = LocationService();
  
  LatLng? _currentLocation;
  bool _isLoadingLocation = true;
  bool _hasLocationError = false;
  String _locationErrorMessage = '';
  
  StreamSubscription<LatLng>? _locationSubscription;
  String? _selectedServiceFilter;
  double _searchRadius = 10.0;

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeLocation() async {
    try {
      setState(() {
        _isLoadingLocation = true;
        _hasLocationError = false;
      });

      // Get current location
      final location = await _locationService.getCurrentLocation();
      
      if (mounted) {
        setState(() {
          _currentLocation = location;
          _isLoadingLocation = false;
        });

        // Start location tracking for real-time updates
        _locationSubscription = _locationService.startLocationTracking().listen(
          (newLocation) {
            if (mounted) {
              setState(() {
                _currentLocation = newLocation;
              });
            }
          },
          onError: (error) {
            print('Location tracking error: $error');
          },
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
          _hasLocationError = true;
          _locationErrorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Services'),
        backgroundColor: Colors.orange[700],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterOptions,
          ),
        ],
      ),
      body: _isLoadingLocation
          ? _buildLoadingScreen()
          : _hasLocationError
              ? _buildLocationErrorScreen()
              : _buildMainContent(),
    );
  }

  Widget _buildLoadingScreen() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Getting your location...'),
          SizedBox(height: 8),
          Text(
            'This helps us find nearby services',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationErrorScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.location_off,
              size: 64,
              color: Colors.red[300],
            ),
            const SizedBox(height: 16),
            Text(
              'Location Access Required',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'We need your location to find nearby shops and calculate distances.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _locationErrorMessage,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _initializeLocation,
              icon: const Icon(Icons.location_on),
              label: const Text('Enable Location'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange[700],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                // Show location help dialog
                _showLocationHelpDialog();
              },
              child: const Text('Why do you need my location?'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    return RefreshIndicator(
      onRefresh: _initializeLocation,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Location header
            _buildLocationHeader(),
            
            const SizedBox(height: 16),
            
            // Quick service search
            QuickServiceSearchWidget(
              customerLocation: _currentLocation,
              onServiceSelected: (serviceQuery) {
                setState(() {
                  _selectedServiceFilter = serviceQuery;
                });
              },
            ),
            
            const SizedBox(height: 24),
            
            // Nearby shops
            NearbyShopsWidget(
              customerLocation: _currentLocation,
              radiusKm: _searchRadius,
              serviceFilter: _selectedServiceFilter,
              onLocationError: () {
                setState(() {
                  _hasLocationError = true;
                  _locationErrorMessage = 'Location service unavailable';
                });
              },
            ),
            
            const SizedBox(height: 24),
            
            // Additional options
            _buildAdditionalOptions(),
            
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange[700]!, Colors.orange[500]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.location_on,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _currentLocation != null
                      ? 'Your current location'
                      : 'Location unavailable',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (_currentLocation != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_searchRadius.toStringAsFixed(0)} km radius',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          if (_currentLocation != null) ...[
            const SizedBox(height: 4),
            Text(
              'Lat: ${_currentLocation!.latitude.toStringAsFixed(4)}, '
              'Lng: ${_currentLocation!.longitude.toStringAsFixed(4)}',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ],
          if (_selectedServiceFilter != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Filtered: $_selectedServiceFilter',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 4),
                  InkWell(
                    onTap: () {
                      setState(() {
                        _selectedServiceFilter = null;
                      });
                    },
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAdditionalOptions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'More Options',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          
          // Search all services button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                // TODO: Navigate to comprehensive search screen
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Comprehensive search coming soon!'),
                  ),
                );
              },
              icon: const Icon(Icons.search),
              label: const Text('Search All Services'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.orange[700],
                side: BorderSide(color: Colors.orange[700]!),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Emergency services button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                // TODO: Navigate to emergency services
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Emergency services coming soon!'),
                    backgroundColor: Colors.red,
                  ),
                );
              },
              icon: const Icon(Icons.emergency),
              label: const Text('Emergency Services'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[600],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showFilterOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            Text(
              'Search Settings',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Search radius
            Text(
              'Search Radius: ${_searchRadius.toStringAsFixed(0)} km',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Slider(
              value: _searchRadius,
              min: 1.0,
              max: 50.0,
              divisions: 49,
              activeColor: Colors.orange[700],
              onChanged: (value) {
                setState(() {
                  _searchRadius = value;
                });
              },
            ),
            
            const SizedBox(height: 16),
            
            // Service filter
            Text(
              'Service Filter',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                FilterChip(
                  label: const Text('All Services'),
                  selected: _selectedServiceFilter == null,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedServiceFilter = null;
                      });
                    }
                  },
                  selectedColor: Colors.orange[100],
                  checkmarkColor: Colors.orange[700],
                ),
                FilterChip(
                  label: const Text('Oil Change'),
                  selected: _selectedServiceFilter == 'oil change',
                  onSelected: (selected) {
                    setState(() {
                      _selectedServiceFilter = selected ? 'oil change' : null;
                    });
                  },
                  selectedColor: Colors.orange[100],
                  checkmarkColor: Colors.orange[700],
                ),
                FilterChip(
                  label: const Text('Tire Repair'),
                  selected: _selectedServiceFilter == 'tire repair',
                  onSelected: (selected) {
                    setState(() {
                      _selectedServiceFilter = selected ? 'tire repair' : null;
                    });
                  },
                  selectedColor: Colors.orange[100],
                  checkmarkColor: Colors.orange[700],
                ),
                FilterChip(
                  label: const Text('Battery'),
                  selected: _selectedServiceFilter == 'battery',
                  onSelected: (selected) {
                    setState(() {
                      _selectedServiceFilter = selected ? 'battery' : null;
                    });
                  },
                  selectedColor: Colors.orange[100],
                  checkmarkColor: Colors.orange[700],
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Apply button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('Apply Filters'),
              ),
            ),
            
            // Add bottom padding for safe area
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }

  void _showLocationHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Location Access'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('We use your location to:'),
            SizedBox(height: 8),
            Text('• Find shops near you'),
            Text('• Calculate distances to services'),
            Text('• Show accurate travel times'),
            Text('• Provide relevant recommendations'),
            SizedBox(height: 16),
            Text(
              'Your location is not stored or shared with third parties.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}
