-- =====================================================
-- FLUTTER/SUPABASE INTEGRATION GUIDE
-- Auto Repair Ride-Hailing System
-- =====================================================

-- =====================================================
-- SUPABASE SETUP COMMANDS
-- =====================================================

-- Run these commands in your Supabase SQL Editor:

-- 1. Enable required extensions
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS uuid-ossp;

-- 2. Enable real-time for relevant tables
ALTER PUBLICATION supabase_realtime ADD TABLE public.service_requests;
ALTER PUBLICATION supabase_realtime ADD TABLE public.request_routing;
ALTER PUBLICATION supabase_realtime ADD TABLE public.mechanics;

-- 3. Grant necessary permissions
GRANT USAGE ON SCHEMA public TO anon, authenticated;
GRANT ALL ON ALL TABLES IN SCHEMA public TO authenticated;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO authenticated;
GRANT ALL ON ALL FUNCTIONS IN SCHEMA public TO authenticated;

-- =====================================================
-- FLUTTER DART CODE EXAMPLES
-- =====================================================

/*
// 1. SERVICE CLASS EXAMPLE - MechanicService.dart

import 'package:supabase_flutter/supabase_flutter.dart';

class MechanicService {
  static final SupabaseClient _client = Supabase.instance.client;

  // Get available mechanics in a shop
  static Future<List<Map<String, dynamic>>> getAvailableMechanicsInShop(String shopId) async {
    final response = await _client
        .rpc('get_available_mechanics_in_shop', params: {'shop_id_param': shopId});
    return List<Map<String, dynamic>>.from(response);
  }

  // Find nearest available mechanic
  static Future<Map<String, dynamic>?> getNearestMechanic(
      double latitude, double longitude, {double maxDistanceKm = 25.0}) async {
    final response = await _client.rpc('get_nearest_available_mechanic', params: {
      'customer_lat': latitude,
      'customer_lng': longitude,
      'max_distance_km': maxDistanceKm,
    });
    
    if (response.isNotEmpty) {
      return Map<String, dynamic>.from(response.first);
    }
    return null;
  }

  // Accept a service request atomically
  static Future<Map<String, dynamic>> acceptServiceRequest(
      String requestId, String mechanicId) async {
    final response = await _client.rpc('accept_service_request', params: {
      'request_id_param': requestId,
      'mechanic_id_param': mechanicId,
    });
    return Map<String, dynamic>.from(response.first);
  }

  // Broadcast request to nearby mechanics
  static Future<Map<String, dynamic>> broadcastServiceRequest(
      String requestId, {double maxDistanceKm = 20.0, int maxMechanics = 10}) async {
    final response = await _client.rpc('broadcast_service_request', params: {
      'request_id_param': requestId,
      'max_distance_km': maxDistanceKm,
      'max_mechanics': maxMechanics,
    });
    return Map<String, dynamic>.from(response.first);
  }

  // Get nearby shops with mechanics
  static Future<List<Map<String, dynamic>>> getNearbyShops(
      double latitude, double longitude, {double radiusKm = 20.0}) async {
    final response = await _client.rpc('get_nearby_shops_with_mechanics', params: {
      'customer_lat': latitude,
      'customer_lng': longitude,
      'radius_km': radiusKm,
    });
    return List<Map<String, dynamic>>.from(response);
  }
}

// 2. SERVICE REQUEST CLASS - ServiceRequestService.dart

class ServiceRequestService {
  static final SupabaseClient _client = Supabase.instance.client;

  // Create a new service request
  static Future<String> createServiceRequest({
    required String title,
    required String description,
    required String serviceType,
    required double latitude,
    required double longitude,
    required String address,
    String? shopId,
    bool isEmergency = false,
    Map<String, dynamic>? vehicleInfo,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final request = await _client.from('service_requests').insert({
      'customer_id': user.id,
      'shop_id': shopId,
      'title': title,
      'description': description,
      'service_type': serviceType,
      'pickup_latitude': latitude,
      'pickup_longitude': longitude,
      'pickup_address': address,
      'is_emergency': isEmergency,
      'vehicle_info': vehicleInfo ?? {},
      'status': 'pending',
      'request_type': shopId != null ? 'shop_specific' : 'broadcast',
    }).select('id').single();

    final requestId = request['id'] as String;

    // If no shop specified, broadcast to nearby mechanics
    if (shopId == null) {
      await MechanicService.broadcastServiceRequest(requestId);
    }

    return requestId;
  }

  // Get user's service requests
  static Future<List<Map<String, dynamic>>> getUserRequests() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];

    final response = await _client
        .from('service_requests')
        .select()
        .eq('customer_id', user.id)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  // Cancel a service request
  static Future<void> cancelServiceRequest(String requestId) async {
    await _client
        .from('service_requests')
        .update({'status': 'cancelled', 'cancelled_at': DateTime.now().toIso8601String()})
        .eq('id', requestId);
  }
}

// 3. REAL-TIME SUBSCRIPTION EXAMPLE

class ServiceRequestTracker {
  static StreamSubscription? _subscription;

  // Listen to service request updates
  static Stream<Map<String, dynamic>> trackServiceRequest(String requestId) {
    return _client
        .from('service_requests')
        .stream(primaryKey: ['id'])
        .eq('id', requestId)
        .map((data) => data.isNotEmpty ? data.first : {});
  }

  // Listen to mechanic location updates (for assigned requests)
  static Stream<Map<String, dynamic>> trackMechanicLocation(String requestId) {
    return _client
        .from('service_requests')
        .stream(primaryKey: ['id'])
        .eq('id', requestId)
        .asyncMap((data) async {
          if (data.isNotEmpty && data.first['accepted_by'] != null) {
            final tracking = await _client.rpc('get_active_request_tracking', 
                params: {'request_id_param': requestId});
            return tracking.isNotEmpty ? tracking.first : {};
          }
          return {};
        });
  }

  // Mechanic: Listen for incoming requests
  static Stream<List<Map<String, dynamic>>> listenForMechanicRequests() {
    final user = _client.auth.currentUser;
    if (user == null) return Stream.empty();

    return _client
        .from('request_routing')
        .stream(primaryKey: ['id'])
        .eq('mechanic_id', user.id)
        .eq('response_status', 'pending')
        .asyncMap((routingData) async {
          final List<Map<String, dynamic>> requests = [];
          
          for (final routing in routingData) {
            final requestData = await _client
                .from('service_requests')
                .select()
                .eq('id', routing['request_id'])
                .single();
            
            requests.add({
              ...requestData,
              'routing_id': routing['id'],
              'distance_km': routing['distance_km'],
              'response_deadline': routing['response_deadline'],
            });
          }
          
          return requests;
        });
  }
}

// 4. LOCATION SERVICE INTEGRATION

class LocationService {
  // Get nearby shops for customer
  static Future<List<Map<String, dynamic>>> getNearbyShopsForCustomer() async {
    final position = await Geolocator.getCurrentPosition();
    
    return await MechanicService.getNearbyShops(
      position.latitude,
      position.longitude,
      radiusKm: 15.0,
    );
  }

  // Calculate distance between two points
  static double calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    return Geolocator.distanceBetween(lat1, lng1, lat2, lng2) / 1000; // km
  }

  // Update mechanic location
  static Future<void> updateMechanicLocation(double latitude, double longitude) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    await _client.from('mechanics').update({
      'latitude': latitude,
      'longitude': longitude,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('user_id', user.id);
  }
}

// 5. UI WIDGET EXAMPLES

// Customer: Shop Selection Screen
class ShopSelectionScreen extends StatefulWidget {
  @override
  _ShopSelectionScreenState createState() => _ShopSelectionScreenState();
}

class _ShopSelectionScreenState extends State<ShopSelectionScreen> {
  List<Map<String, dynamic>> nearbyShops = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNearbyShops();
  }

  Future<void> _loadNearbyShops() async {
    try {
      final shops = await LocationService.getNearbyShopsForCustomer();
      setState(() {
        nearbyShops = shops;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading shops: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Select a Shop')),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: nearbyShops.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  // "Find Nearest Mechanic" option
                  return ListTile(
                    leading: Icon(Icons.search),
                    title: Text('Find Nearest Available Mechanic'),
                    subtitle: Text('Let us find the closest mechanic for you'),
                    onTap: () => _createBroadcastRequest(),
                  );
                }
                
                final shop = nearbyShops[index - 1];
                return ListTile(
                  leading: Icon(Icons.store),
                  title: Text(shop['shop_name']),
                  subtitle: Text(
                    '${shop['distance_km']} km • ${shop['available_mechanics']} mechanics available'
                  ),
                  trailing: Text('${shop['shop_rating']}⭐'),
                  onTap: () => _selectShop(shop['shop_id']),
                );
              },
            ),
    );
  }

  void _createBroadcastRequest() {
    // Navigate to service request creation with no shop selected
    Navigator.push(context, MaterialPageRoute(
      builder: (context) => ServiceRequestScreen(shopId: null),
    ));
  }

  void _selectShop(String shopId) {
    // Navigate to service request creation with selected shop
    Navigator.push(context, MaterialPageRoute(
      builder: (context) => ServiceRequestScreen(shopId: shopId),
    ));
  }
}

// Mechanic: Incoming Request Widget
class IncomingRequestCard extends StatelessWidget {
  final Map<String, dynamic> request;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const IncomingRequestCard({
    Key? key,
    required this.request,
    required this.onAccept,
    required this.onReject,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.all(16),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.build, color: Colors.orange),
                SizedBox(width: 8),
                Text(
                  request['title'],
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Spacer(),
                Chip(
                  label: Text('${request['distance_km']} km'),
                  backgroundColor: Colors.blue[100],
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(request['description']),
            SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.location_on, size: 16),
                SizedBox(width: 4),
                Expanded(child: Text(request['pickup_address'])),
              ],
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: onReject,
                    child: Text('Decline'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onAccept,
                    child: Text('Accept'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
*/

-- =====================================================
-- SUPABASE EDGE FUNCTIONS (Optional)
-- =====================================================

/*
// Supabase Edge Function: send-notifications
// Save as supabase/functions/send-notifications/index.ts

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? ''
    )

    const { requestId, mechanicIds, requestData } = await req.json()

    // Send push notifications to mechanics
    for (const mechanicId of mechanicIds) {
      // Your push notification logic here
      console.log(`Sending notification to mechanic ${mechanicId} for request ${requestId}`)
    }

    return new Response(
      JSON.stringify({ success: true, notified: mechanicIds.length }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 }
    )
  }
})
*/

-- =====================================================
-- REALTIME SUBSCRIPTION PATTERNS
-- =====================================================

/*
// Pattern 1: Customer tracking their request
class CustomerRequestTracker extends StatefulWidget {
  final String requestId;
  
  @override
  _CustomerRequestTrackerState createState() => _CustomerRequestTrackerState();
}

class _CustomerRequestTrackerState extends State<CustomerRequestTracker> {
  StreamSubscription? _requestSubscription;
  StreamSubscription? _locationSubscription;
  Map<String, dynamic>? requestData;
  Map<String, dynamic>? mechanicLocation;

  @override
  void initState() {
    super.initState();
    _startTracking();
  }

  void _startTracking() {
    // Track request status changes
    _requestSubscription = ServiceRequestTracker
        .trackServiceRequest(widget.requestId)
        .listen((data) {
      setState(() => requestData = data);
      
      // If mechanic assigned, start location tracking
      if (data['accepted_by'] != null && _locationSubscription == null) {
        _startLocationTracking();
      }
    });
  }

  void _startLocationTracking() {
    _locationSubscription = ServiceRequestTracker
        .trackMechanicLocation(widget.requestId)
        .listen((locationData) {
      setState(() => mechanicLocation = locationData);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Request Status')),
      body: requestData == null
          ? Center(child: CircularProgressIndicator())
          : _buildStatusView(),
    );
  }

  Widget _buildStatusView() {
    final status = requestData!['status'];
    
    return Column(
      children: [
        StatusIndicator(status: status),
        if (mechanicLocation != null) ...[
          MechanicLocationMap(
            mechanicLocation: mechanicLocation!,
            customerLocation: {
              'lat': requestData!['pickup_latitude'],
              'lng': requestData!['pickup_longitude'],
            },
          ),
          EstimatedArrival(
            minutes: mechanicLocation!['estimated_arrival_minutes'],
            distance: mechanicLocation!['distance_to_customer_km'],
          ),
        ],
      ],
    );
  }

  @override
  void dispose() {
    _requestSubscription?.cancel();
    _locationSubscription?.cancel();
    super.dispose();
  }
}

// Pattern 2: Mechanic listening for requests
class MechanicDashboard extends StatefulWidget {
  @override
  _MechanicDashboardState createState() => _MechanicDashboardState();
}

class _MechanicDashboardState extends State<MechanicDashboard> {
  StreamSubscription? _requestSubscription;
  List<Map<String, dynamic>> incomingRequests = [];
  bool isOnline = false;

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  void _startListening() {
    _requestSubscription = ServiceRequestTracker
        .listenForMechanicRequests()
        .listen((requests) {
      setState(() => incomingRequests = requests);
      
      // Show notification for new requests
      if (requests.isNotEmpty) {
        _showRequestNotification(requests.last);
      }
    });
  }

  void _showRequestNotification(Map<String, dynamic> request) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => IncomingRequestDialog(
        request: request,
        onAccept: () => _acceptRequest(request),
        onReject: () => _rejectRequest(request),
      ),
    );
  }

  Future<void> _acceptRequest(Map<String, dynamic> request) async {
    try {
      final result = await MechanicService.acceptServiceRequest(
        request['id'],
        Supabase.instance.client.auth.currentUser!.id,
      );
      
      if (result['success']) {
        Navigator.of(context).pop(); // Close dialog
        // Navigate to job details
        Navigator.push(context, MaterialPageRoute(
          builder: (context) => JobDetailsScreen(requestId: request['id']),
        ));
      } else {
        _showError(result['message']);
      }
    } catch (e) {
      _showError('Failed to accept request: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Mechanic Dashboard'),
        actions: [
          Switch(
            value: isOnline,
            onChanged: _toggleOnlineStatus,
          ),
        ],
      ),
      body: isOnline
          ? _buildOnlineView()
          : _buildOfflineView(),
    );
  }
}
*/

-- =====================================================
-- DEPLOYMENT CHECKLIST
-- =====================================================

/*
SUPABASE SETUP CHECKLIST:

□ 1. Enable PostGIS extension
□ 2. Run AUTO_REPAIR_SCHEMA_OPTIMIZED.sql
□ 3. Enable real-time for tables:
   - service_requests
   - request_routing  
   - mechanics
□ 4. Set up Row Level Security policies
□ 5. Configure authentication providers
□ 6. Set up storage buckets for images/documents
□ 7. Deploy edge functions (if using)
□ 8. Configure environment variables

FLUTTER SETUP CHECKLIST:

□ 1. Add dependencies:
   - supabase_flutter
   - geolocator
   - permission_handler
   - google_maps_flutter (optional)
□ 2. Configure Supabase client
□ 3. Set up location permissions
□ 4. Implement authentication flows
□ 5. Create service classes
□ 6. Set up real-time subscriptions
□ 7. Test on physical devices
□ 8. Configure push notifications

TESTING SCENARIOS:

□ 1. Customer creates request with shop selection
□ 2. Customer creates broadcast request (no shop)
□ 3. Multiple mechanics receive broadcast
□ 4. First mechanic accepts (others get notified it's taken)
□ 5. Real-time location tracking works
□ 6. Request completion flow works
□ 7. Offline/online mechanic status changes
□ 8. Distance calculations are accurate
□ 9. RLS policies prevent unauthorized access
□ 10. Performance with many concurrent users
*/