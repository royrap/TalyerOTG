import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../services/location_service.dart';
import '../services/gemini_issue_analysis_service.dart';

class ServiceRequestScreen extends StatefulWidget {
  const ServiceRequestScreen({super.key});

  @override
  State<ServiceRequestScreen> createState() => _ServiceRequestScreenState();
}

class _ServiceRequestScreenState extends State<ServiceRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _vehicleInfoController = TextEditingController();
  
  String _selectedCategory = '';
  String _selectedClassification = 'minor';
  bool _isEmergency = false;
  bool _isLoading = false;
  Position? _currentLocation;
  String? _currentAddress;
  List<Map<String, dynamic>> _serviceCategories = [];
  List<Map<String, dynamic>> _vehicles = [];
  String? _selectedVehicleId;
  
  // AI Analysis state
  bool _isAnalyzing = false;
  Map<String, dynamic>? _aiAnalysis;
  bool _showTowingRecommendation = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _vehicleInfoController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    await Future.wait([
      _loadServiceCategories(),
      _loadUserVehicles(),
      _getCurrentLocation(),
    ]);
  }

  Future<void> _loadServiceCategories() async {
    try {
      final response = await Supabase.instance.client
          .from('service_categories')
          .select('*')
          .eq('is_active', true)
          .order('name');

      setState(() {
        _serviceCategories = List<Map<String, dynamic>>.from(response);
        if (_serviceCategories.isNotEmpty) {
          _selectedCategory = _serviceCategories.first['id'];
        }
      });
    } catch (e) {
      print('Error loading service categories: $e');
    }
  }

  Future<void> _loadUserVehicles() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final response = await Supabase.instance.client
          .from('vehicles')
          .select('*')
          .eq('user_id', user.id)
          .order('is_primary', ascending: false);

      setState(() {
        _vehicles = List<Map<String, dynamic>>.from(response);
        if (_vehicles.isNotEmpty) {
          _selectedVehicleId = _vehicles.first['id'];
        }
      });
    } catch (e) {
      print('Error loading vehicles: $e');
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      final location = await LocationService().getCurrentLocation();
      if (location != null) {
        setState(() {
          _currentLocation = Position(
            latitude: location.latitude,
            longitude: location.longitude,
            timestamp: DateTime.now(),
            accuracy: 0,
            altitude: 0,
            heading: 0,
            speed: 0,
            speedAccuracy: 0,
            altitudeAccuracy: 0,
            headingAccuracy: 0,
          );
        });
        
        // Get address from coordinates
        _currentAddress = await LocationService().getAddressFromCoordinates(
          location.latitude,
          location.longitude,
        );
        setState(() {});
      }
    } catch (e) {
      print('Error getting location: $e');
    }
  }

  /// Analyze issue description using Gemini AI
  Future<void> _analyzeIssueWithAI() async {
    final description = _descriptionController.text.trim();
    if (description.isEmpty || description.length < 10) {
      return; // Don't analyze very short descriptions
    }

    setState(() {
      _isAnalyzing = true;
      _aiAnalysis = null;
      _showTowingRecommendation = false;
    });

    try {
      print('🤖 Analyzing customer issue with Gemini AI...');
      final analysis = await GeminiIssueAnalysisService.analyzeIssueDescription(description);
      
      setState(() {
        _aiAnalysis = analysis;
        _isAnalyzing = false;
        
        // Show towing recommendation if AI suggests it
        if (analysis['needs_towing'] == true) {
          _showTowingRecommendation = true;
          
          // Auto-select emergency if critical
          if (analysis['severity'] == 'critical') {
            _isEmergency = true;
          }
          
          // Update classification based on severity
          if (analysis['severity'] == 'severe' || analysis['severity'] == 'critical') {
            _selectedClassification = 'major';
          }
        }
      });

      // Show result dialog
      if (mounted && analysis['needs_towing'] == true) {
        _showTowingRecommendationDialog(analysis);
      }
      
    } catch (e) {
      print('❌ Error analyzing with AI: $e');
      setState(() {
        _isAnalyzing = false;
      });
    }
  }

  /// Show dialog when AI recommends towing
  void _showTowingRecommendationDialog(Map<String, dynamic> analysis) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.local_shipping, color: Colors.orange[700], size: 28),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Towing Service Recommended',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🤖 AI Analysis Result:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange[900],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      analysis['explanation'] ?? 'Based on your description, towing service is recommended.',
                      style: TextStyle(color: Colors.grey[800]),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _buildAnalysisDetailRow(
                Icons.warning,
                'Severity',
                analysis['severity']?.toString().toUpperCase() ?? 'MODERATE',
                _getSeverityColor(analysis['severity']),
              ),
              const SizedBox(height: 8),
              _buildAnalysisDetailRow(
                Icons.build,
                'Primary Issue',
                analysis['primary_issue'] ?? 'Vehicle issue detected',
                Colors.grey[700]!,
              ),
              const SizedBox(height: 8),
              _buildAnalysisDetailRow(
                Icons.access_time,
                'Est. Time',
                analysis['estimated_time'] ?? 'Unknown',
                Colors.blue[700]!,
              ),
              if (analysis['safety_concerns'] != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.red[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber, color: Colors.red[700], size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          analysis['safety_concerns'],
                          style: TextStyle(
                            color: Colors.red[900],
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (analysis['recommended_services'] != null && 
                  (analysis['recommended_services'] as List).isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  'Recommended Services:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                ...((analysis['recommended_services'] as List).map((service) => 
                  Padding(
                    padding: const EdgeInsets.only(left: 8, top: 4),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.red[600], size: 18),
                        const SizedBox(width: 6),
                        Text(service.toString()),
                      ],
                    ),
                  ),
                )),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _showTowingRecommendation = false;
              });
              Navigator.pop(context);
            },
            child: const Text('Continue Without Towing'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              // Keep the towing recommendation visible
              setState(() {
                _showTowingRecommendation = true;
                _isEmergency = true; // Mark as emergency if towing needed
              });
            },
            icon: const Icon(Icons.local_shipping),
            label: const Text('Request Towing'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange[700],
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisDetailRow(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Color _getSeverityColor(String? severity) {
    switch (severity?.toLowerCase()) {
      case 'minor':
        return Colors.red[700]!;
      case 'moderate':
        return Colors.orange[700]!;
      case 'severe':
        return Colors.red[700]!;
      case 'critical':
        return Colors.red[900]!;
      default:
        return Colors.grey[700]!;
    }
  }

  Widget _buildAIBadge(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.3),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitServiceRequest() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_currentLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enable location services to submit a request'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Create service request
      final requestData = {
        'customer_id': user.id,
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'category_id': _selectedCategory,
        'vehicle_id': _selectedVehicleId,
        'vehicle_info': _vehicleInfoController.text.trim(),
        'service_classification': _selectedClassification,
        'is_emergency': _isEmergency,
        'pickup_latitude': _currentLocation!.latitude,
        'pickup_longitude': _currentLocation!.longitude,
        'pickup_address': _currentAddress ?? 'Location detected',
        'status': 'pending',
        'payment_status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      };

      final response = await Supabase.instance.client
          .from('service_requests')
          .insert(requestData)
          .select()
          .single();

      // Log status history
      await Supabase.instance.client
          .from('request_status_history')
          .insert({
            'request_id': response['id'],
            'status': 'pending',
            'notes': 'Service request created by customer',
            'changed_by': user.id,
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Service request submitted successfully!'),
            backgroundColor: Colors.red,
          ),
        );
        
        // Clear form
        _titleController.clear();
        _descriptionController.clear();
        _vehicleInfoController.clear();
        setState(() {
          _selectedClassification = 'minor';
          _isEmergency = false;
        });
      }
    } catch (e) {
      print('Error submitting service request: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Request Service'),
        backgroundColor: Colors.orange[700],
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Location Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.location_on, color: Colors.orange[700]),
                          const SizedBox(width: 8),
                          Text(
                            'Your Location',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _currentAddress ?? 'Detecting location...',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      if (_currentLocation == null) ...[
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: _getCurrentLocation,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Refresh Location'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Service Details Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Service Details',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Service Category
                      DropdownButtonFormField<String>(
                        value: _selectedCategory.isNotEmpty ? _selectedCategory : null,
                        decoration: const InputDecoration(
                          labelText: 'Service Category',
                          border: OutlineInputBorder(),
                        ),
                        items: _serviceCategories.map((category) {
                          return DropdownMenuItem<String>(
                            value: category['id'],
                            child: Text(category['name']),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() => _selectedCategory = value!);
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please select a service category';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      // Title
                      TextFormField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          labelText: 'Issue Title',
                          hintText: 'e.g., Flat tire on highway',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a title for your request';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      // Description
                      TextFormField(
                        controller: _descriptionController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: 'Description',
                          hintText: 'Describe the issue in detail...',
                          border: const OutlineInputBorder(),
                          suffixIcon: _isAnalyzing
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                )
                              : IconButton(
                                  icon: const Icon(Icons.psychology),
                                  onPressed: _analyzeIssueWithAI,
                                  tooltip: 'Analyze with AI',
                                ),
                        ),
                        onChanged: (value) {
                          // Auto-analyze after user stops typing (debounce)
                          if (value.trim().length >= 20) {
                            Future.delayed(const Duration(seconds: 2), () {
                              if (_descriptionController.text == value && !_isAnalyzing) {
                                _analyzeIssueWithAI();
                              }
                            });
                          }
                        },
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please describe the issue';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      // AI Towing Recommendation Card
                      if (_showTowingRecommendation && _aiAnalysis != null) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.orange[700]!, Colors.orange[500]!],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.orange.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.local_shipping,
                                      color: Colors.orange,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Expanded(
                                    child: Text(
                                      'Towing Service Recommended',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close, color: Colors.white),
                                    onPressed: () {
                                      setState(() {
                                        _showTowingRecommendation = false;
                                      });
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.psychology,
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 8),
                                        const Text(
                                          'AI Analysis:',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      _aiAnalysis!['explanation'] ?? 'Towing service recommended',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        _buildAIBadge(
                                          'Severity',
                                          _aiAnalysis!['severity']?.toString().toUpperCase() ?? 'MODERATE',
                                        ),
                                        const SizedBox(width: 8),
                                        _buildAIBadge(
                                          'Time',
                                          _aiAnalysis!['estimated_time'] ?? 'Unknown',
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.info_outline,
                                    color: Colors.white70,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      _aiAnalysis!['can_drive'] == false
                                          ? 'Vehicle may not be safe to drive'
                                          : 'Consider towing for faster resolution',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Service Classification
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Issue Severity'),
                          Row(
                            children: [
                              Expanded(
                                child: RadioListTile<String>(
                                  title: const Text('Minor'),
                                  subtitle: const Text('Simple fix'),
                                  value: 'minor',
                                  groupValue: _selectedClassification,
                                  onChanged: (value) {
                                    setState(() => _selectedClassification = value!);
                                  },
                                ),
                              ),
                              Expanded(
                                child: RadioListTile<String>(
                                  title: const Text('Major'),
                                  subtitle: const Text('Complex repair'),
                                  value: 'major',
                                  groupValue: _selectedClassification,
                                  onChanged: (value) {
                                    setState(() => _selectedClassification = value!);
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      // Emergency checkbox
                      CheckboxListTile(
                        title: const Text('Emergency Service'),
                        subtitle: const Text('I need immediate assistance'),
                        value: _isEmergency,
                        onChanged: (value) {
                          setState(() => _isEmergency = value ?? false);
                        },
                        activeColor: Colors.red,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Vehicle Information Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Vehicle Information',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Vehicle Selection
                      if (_vehicles.isNotEmpty) ...[
                        DropdownButtonFormField<String>(
                          value: _selectedVehicleId,
                          decoration: const InputDecoration(
                            labelText: 'Select Vehicle',
                            border: OutlineInputBorder(),
                          ),
                          items: _vehicles.map((vehicle) {
                            return DropdownMenuItem<String>(
                              value: vehicle['id'],
                              child: Text(
                                '${vehicle['brand_name']} ${vehicle['model_name']} (${vehicle['year']})',
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() => _selectedVehicleId = value);
                          },
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Additional Vehicle Info
                      TextFormField(
                        controller: _vehicleInfoController,
                        decoration: const InputDecoration(
                          labelText: 'Additional Vehicle Details',
                          hintText: 'Color, license plate, special notes...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Submit Button
              ElevatedButton(
                onPressed: _isLoading ? null : _submitServiceRequest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        _isEmergency ? 'Submit Emergency Request' : 'Submit Service Request',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),

              const SizedBox(height: 16),

              // Info Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info, color: Colors.blue[700]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Your request will be reviewed by nearby service providers. You\'ll be notified when someone accepts your request.',
                        style: TextStyle(color: Colors.blue[700]),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}





















