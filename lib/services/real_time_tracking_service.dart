import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';

class RealTimeTrackingService {
  static final RealTimeTrackingService _instance = RealTimeTrackingService._internal();
  factory RealTimeTrackingService() => _instance;
  RealTimeTrackingService._internal();

  static RealTimeTrackingService get instance => _instance;

  final SupabaseClient _supabase = Supabase.instance.client;
  
  // Controllers for streaming data
  final Map<String, StreamController<Map<String, dynamic>>> _mechanicLocationControllers = ;
  final Map<String, StreamController<Map<String, dynamic>>> _invoiceControllers = ;
  
  // Location tracking
  StreamSubscription<Position>? _locationSubscription;
  Timer? _locationUpdateTimer;
  
  // Active service tracking
  String? _activeServiceRequestId;
  bool _isTrackingEnabled = false;

  // =============================================================================
  // MECHANIC LOCATION TRACKING
  // =============================================================================

  /// Start tracking mechanic location for a specific service request
  Stream<Map<String, dynamic>> trackMechanicLocation(String serviceRequestId) {
    print('🗺️ Starting mechanic location tracking for request: $serviceRequestId');
    
    if (!_mechanicLocationControllers.containsKey(serviceRequestId)) {
      _mechanicLocationControllers[serviceRequestId] = StreamController<Map<String, dynamic>>.broadcast();
    }

    _startLocationPolling(serviceRequestId);
    
    return _mechanicLocationControllers[serviceRequestId]!.stream;
  }

  /// Stop tracking mechanic location
  void stopTrackingMechanicLocation(String serviceRequestId) {
    print('🛑 Stopping mechanic location tracking for request: $serviceRequestId');
    
    if (_mechanicLocationControllers.containsKey(serviceRequestId)) {
      _mechanicLocationControllers[serviceRequestId]?.close();
      _mechanicLocationControllers.remove(serviceRequestId);
    }
    
    if (_mechanicLocationControllers.isEmpty) {
      _locationUpdateTimer?.cancel();
    }
  }

  /// Start polling for mechanic location updates
  void _startLocationPolling(String serviceRequestId) {
    _locationUpdateTimer?.cancel();
    
    _locationUpdateTimer = Timer.periodic(Duration(seconds: 10), (timer) async {
      try {
        await _fetchMechanicLocationUpdate(serviceRequestId);
      } catch (e) {
        print('⚠️ Error fetching mechanic location: $e');
      }
    });
    
    // Initial fetch
    _fetchMechanicLocationUpdate(serviceRequestId);
  }

  /// Fetch current mechanic location from database
  Future<void> _fetchMechanicLocationUpdate(String serviceRequestId) async {
    try {
      final response = await _supabase
          .from('service_requests')
          .select('''
            id,
            status,
            provider_id,
            service_providers!service_requests_provider_id_fkey(
              id,
              user_id,
              company_name,
              user_profiles!service_providers_user_id_fkey(
                first_name,
                last_name,
                phone_number
              )
            ),
            mechanic_locations!mechanic_locations_service_request_id_fkey(
              latitude,
              longitude,
              accuracy,
              heading,
              speed,
              updated_at,
              is_active
            )
          ''')
          .eq('id', serviceRequestId)
          .eq('mechanic_locations.is_active', true)
          .maybeSingle();

      if (response == null) {
        print('ℹ️ No service request found or no active location data');
        return;
      }

      final provider = response['service_providers'];
      final locations = response['mechanic_locations'] as List?;
      final latestLocation = locations?.isNotEmpty == true ? locations!.last : null;

      final locationData = {
        'service_request_id': serviceRequestId,
        'status': response['status'],
        'mechanic': provider != null ? {
          'name': '${provider['user_profiles']?['first_name'] ?? ''} ${provider['user_profiles']?['last_name'] ?? ''}'.trim(),
          'company': provider['company_name'],
          'phone': provider['user_profiles']?['phone_number'],
        } : null,
        'location': latestLocation != null ? {
          'latitude': latestLocation['latitude'],
          'longitude': latestLocation['longitude'],
          'accuracy': latestLocation['accuracy'],
          'heading': latestLocation['heading'],
          'speed': latestLocation['speed'],
          'last_updated': latestLocation['updated_at'],
        } : null,
        'is_tracking_active': latestLocation != null,
        'timestamp': DateTime.now().toIso8601String(),
      };

      if (_mechanicLocationControllers.containsKey(serviceRequestId)) {
        _mechanicLocationControllers[serviceRequestId]?.add(locationData);
      }

    } catch (e) {
      print('❌ Error fetching mechanic location: $e');
      
      if (_mechanicLocationControllers.containsKey(serviceRequestId)) {
        _mechanicLocationControllers[serviceRequestId]?.addError(e);
      }
    }
  }

  // =============================================================================
  // REAL-TIME INVOICE TRACKING
  // =============================================================================

  /// Track real-time invoice updates for a service request
  Stream<Map<String, dynamic>> trackInvoiceUpdates(String serviceRequestId) {
    print('📋 Starting invoice tracking for request: $serviceRequestId');
    
    if (!_invoiceControllers.containsKey(serviceRequestId)) {
      _invoiceControllers[serviceRequestId] = StreamController<Map<String, dynamic>>.broadcast();
    }

    _startInvoicePolling(serviceRequestId);
    
    return _invoiceControllers[serviceRequestId]!.stream;
  }

  /// Stop tracking invoice updates
  void stopTrackingInvoiceUpdates(String serviceRequestId) {
    print('🛑 Stopping invoice tracking for request: $serviceRequestId');
    
    if (_invoiceControllers.containsKey(serviceRequestId)) {
      _invoiceControllers[serviceRequestId]?.close();
      _invoiceControllers.remove(serviceRequestId);
    }
  }

  /// Start polling for invoice updates
  void _startInvoicePolling(String serviceRequestId) {
    Timer.periodic(Duration(seconds: 5), (timer) async {
      if (!_invoiceControllers.containsKey(serviceRequestId)) {
        timer.cancel();
        return;
      }
      
      try {
        await _fetchInvoiceUpdate(serviceRequestId);
      } catch (e) {
        print('⚠️ Error fetching invoice update: $e');
      }
    });
    
    // Initial fetch
    _fetchInvoiceUpdate(serviceRequestId);
  }

  /// Fetch current invoice data from database
  Future<void> _fetchInvoiceUpdate(String serviceRequestId) async {
    try {
      final response = await _supabase
          .from('invoices')
          .select('''
            id,
            service_request_id,
            total_amount,
            status,
            payment_status,
            created_at,
            updated_at,
            sent_at,
            due_date,
            invoice_items!invoices_invoice_id_fkey(
              description,
              quantity,
              unit_price,
              total_price
            )
          ''')
          .eq('service_request_id', serviceRequestId)
          .order('created_at', ascending: false)
          .maybeSingle();

      if (response == null) {
        // No invoice yet - send empty state
        final emptyInvoiceData = {
          'service_request_id': serviceRequestId,
          'has_invoice': false,
          'status': 'no_invoice',
          'message': 'No invoice generated yet',
          'timestamp': DateTime.now().toIso8601String(),
        };
        
        if (_invoiceControllers.containsKey(serviceRequestId)) {
          _invoiceControllers[serviceRequestId]?.add(emptyInvoiceData);
        }
        return;
      }

      final invoiceData = {
        'service_request_id': serviceRequestId,
        'has_invoice': true,
        'invoice': {
          'id': response['id'],
          'total_amount': response['total_amount'],
          'status': response['status'],
          'payment_status': response['payment_status'],
          'created_at': response['created_at'],
          'updated_at': response['updated_at'],
          'sent_at': response['sent_at'],
          'due_date': response['due_date'],
          'items': response['invoice_items'] ?? [],
        },
        'is_new': _isNewInvoice(response['updated_at']),
        'timestamp': DateTime.now().toIso8601String(),
      };

      if (_invoiceControllers.containsKey(serviceRequestId)) {
        _invoiceControllers[serviceRequestId]?.add(invoiceData);
      }

    } catch (e) {
      print('❌ Error fetching invoice update: $e');
      
      if (_invoiceControllers.containsKey(serviceRequestId)) {
        _invoiceControllers[serviceRequestId]?.addError(e);
      }
    }
  }

  /// Check if invoice was recently updated (within last 30 seconds)
  bool _isNewInvoice(String? updatedAt) {
    if (updatedAt == null) return false;
    
    try {
      final updateTime = DateTime.parse(updatedAt);
      final now = DateTime.now();
      final difference = now.difference(updateTime);
      
      return difference.inSeconds <= 30;
    } catch (e) {
      return false;
    }
  }

  // =============================================================================
  // MECHANIC-SIDE LOCATION UPDATES (for mechanics to send their location)
  // =============================================================================

  /// Start tracking and sending mechanic's own location
  Future<void> startMechanicLocationSharing(String serviceRequestId) async {
    try {
      print('📍 Starting location sharing for mechanic on request: $serviceRequestId');
      
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('No authenticated user');

      _activeServiceRequestId = serviceRequestId;
      _isTrackingEnabled = true;

      // Request location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions permanently denied');
      }

      // Start location stream
      _locationSubscription = Geolocator.getPositionStream(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10, // Update every 10 meters
        ),
      ).listen((Position position) {
        if (_isTrackingEnabled && _activeServiceRequestId != null) {
          _updateMechanicLocation(position);
        }
      });

      print('✅ Mechanic location sharing started');
    } catch (e) {
      print('❌ Error starting mechanic location sharing: $e');
      rethrow;
    }
  }

  /// Stop sharing mechanic location
  void stopMechanicLocationSharing() {
    print('🛑 Stopping mechanic location sharing');
    
    _isTrackingEnabled = false;
    _activeServiceRequestId = null;
    _locationSubscription?.cancel();
    _locationSubscription = null;
  }

  /// Update mechanic location in database
  Future<void> _updateMechanicLocation(Position position) async {
    try {
      if (_activeServiceRequestId == null) return;

      final user = _supabase.auth.currentUser;
      if (user == null) return;

      await _supabase
          .from('mechanic_locations')
          .upsert({
            'service_request_id': _activeServiceRequestId,
            'mechanic_id': user.id,
            'latitude': position.latitude,
            'longitude': position.longitude,
            'accuracy': position.accuracy,
            'heading': position.heading,
            'speed': position.speed,
            'altitude': position.altitude,
            'is_active': true,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          });

      print('📍 Location updated: ${position.latitude}, ${position.longitude}');
    } catch (e) {
      print('❌ Error updating mechanic location: $e');
    }
  }

  // =============================================================================
  // CLEANUP
  // =============================================================================

  /// Clean up all resources
  void dispose() {
    print('🧹 Disposing RealTimeTrackingService');
    
    _locationSubscription?.cancel();
    _locationUpdateTimer?.cancel();
    
    for (final controller in _mechanicLocationControllers.values) {
      controller.close();
    }
    _mechanicLocationControllers.clear();
    
    for (final controller in _invoiceControllers.values) {
      controller.close();
    }
    _invoiceControllers.clear();
    
    _isTrackingEnabled = false;
    _activeServiceRequestId = null;
  }
}










