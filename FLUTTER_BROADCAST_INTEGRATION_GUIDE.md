# FLUTTER INTEGRATION GUIDE FOR BROADCAST REQUEST SYSTEM

This guide explains how to integrate the broadcast request system into your Flutter app.

## Overview

The broadcast system allows customers to request services without selecting a specific shop. All available mechanics/shops within the specified radius can see and compete for the request on a first-come-first-served basis.

## 1. Customer Side Implementation

### 1.1 Request Service Screen Enhancement

```dart
// lib/customer/request_service_screen.dart

class RequestServiceScreen extends StatefulWidget {
  @override
  _RequestServiceScreenState createState() => _RequestServiceScreenState();
}

class _RequestServiceScreenState extends State<RequestServiceScreen> {
  String requestType = 'shop_based'; // 'shop_based', 'direct_mechanic', 'broadcast'
  double broadcastRadius = 10.0; // km
  int maxWaitTime = 30; // minutes
  
  Widget _buildRequestTypeSelector() {
    return Column(
      children: [
        RadioListTile<String>(
          title: Text('Select Specific Shop'),
          subtitle: Text('Choose from available shops near you'),
          value: 'shop_based',
          groupValue: requestType,
          onChanged: (value) => setState(() => requestType = value!),
        ),
        RadioListTile<String>(
          title: Text('Any Available Mechanic'),
          subtitle: Text('First available mechanic gets the job'),
          value: 'broadcast',
          groupValue: requestType,
          onChanged: (value) => setState(() => requestType = value!),
        ),
      ],
    );
  }

  Widget _buildBroadcastSettings() {
    if (requestType != 'broadcast') return SizedBox.shrink();
    
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Broadcast Settings', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            
            Text('Search Radius: ${broadcastRadius.toInt()} km'),
            Slider(
              value: broadcastRadius,
              min: 5.0,
              max: 50.0,
              divisions: 9,
              onChanged: (value) => setState(() => broadcastRadius = value),
            ),
            
            Text('Max Wait Time: $maxWaitTime minutes'),
            Slider(
              value: maxWaitTime.toDouble(),
              min: 15.0,
              max: 60.0,
              divisions: 9,
              onChanged: (value) => setState(() => maxWaitTime = value.toInt()),
            ),
            
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Your request will be sent to all available mechanics within ${broadcastRadius.toInt()}km. The first to accept gets the job.',
                style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitRequest() async {
    try {
      // Create the service request
      final requestId = await _createServiceRequest();
      
      if (requestType == 'broadcast') {
        // Start broadcasting
        final result = await SupabaseService.instance.rpc('broadcast_service_request', {
          'p_request_id': requestId,
          'p_max_radius_km': broadcastRadius,
          'p_response_timeout_minutes': maxWaitTime,
        });
        
        if (result['success']) {
          // Navigate to broadcast waiting screen
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BroadcastWaitingScreen(
                requestId: requestId,
                broadcastRadius: broadcastRadius,
                maxWaitTime: maxWaitTime,
              ),
            ),
          );
        } else {
          throw Exception(result['error']);
        }
      } else {
        // Handle regular shop-based or direct mechanic requests
        _handleRegularRequest(requestId);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  Future<String> _createServiceRequest() async {
    final response = await SupabaseService.instance
        .from('service_requests')
        .insert({
          'customer_id': SupabaseService.instance.auth.currentUser!.id,
          'title': titleController.text,
          'description': descriptionController.text,
          'category_id': selectedCategoryId,
          'pickup_latitude': currentLocation.latitude,
          'pickup_longitude': currentLocation.longitude,
          'pickup_address': addressController.text,
          'request_type': requestType,
          'can_accept_by_any_mechanic': requestType == 'broadcast',
          'estimated_price': estimatedPrice,
          'vehicle_id': selectedVehicleId,
        })
        .select()
        .single();
    
    return response['id'];
  }
}
```

### 1.2 Broadcast Waiting Screen

```dart
// lib/customer/broadcast_waiting_screen.dart

class BroadcastWaitingScreen extends StatefulWidget {
  final String requestId;
  final double broadcastRadius;
  final int maxWaitTime;

  BroadcastWaitingScreen({
    required this.requestId,
    required this.broadcastRadius,
    required this.maxWaitTime,
  });

  @override
  _BroadcastWaitingScreenState createState() => _BroadcastWaitingScreenState();
}

class _BroadcastWaitingScreenState extends State<BroadcastWaitingScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Timer _countdownTimer;
  late StreamSubscription _requestSubscription;
  
  int remainingSeconds = 0;
  int notifiedProviders = 0;
  List<Map<String, dynamic>> interestedProviders = [];
  String currentStatus = 'broadcasting';

  @override
  void initState() {
    super.initState();
    remainingSeconds = widget.maxWaitTime * 60;
    
    _pulseController = AnimationController(
      duration: Duration(seconds: 2),
      vsync: this,
    )..repeat();
    
    _startCountdown();
    _listenToRequestUpdates();
    _loadRequestStatus();
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        remainingSeconds--;
        if (remainingSeconds <= 0) {
          timer.cancel();
          _handleTimeout();
        }
      });
    });
  }

  void _listenToRequestUpdates() {
    _requestSubscription = SupabaseService.instance
        .from('service_requests')
        .stream(primaryKey: ['id'])
        .eq('id', widget.requestId)
        .listen((data) {
          if (data.isNotEmpty) {
            final request = data.first;
            setState(() {
              currentStatus = request['broadcast_status'] ?? 'broadcasting';
              notifiedProviders = request['notified_providers_count'] ?? 0;
            });
            
            if (currentStatus == 'accepted') {
              _handleRequestAccepted(request);
            }
          }
        });
  }

  Future<void> _loadRequestStatus() async {
    final response = await SupabaseService.instance
        .from('service_requests')
        .select('*, request_broadcasts(*)')
        .eq('id', widget.requestId)
        .single();
    
    setState(() {
      notifiedProviders = response['notified_providers_count'] ?? 0;
      currentStatus = response['broadcast_status'] ?? 'broadcasting';
    });
  }

  void _handleRequestAccepted(Map<String, dynamic> request) {
    _countdownTimer.cancel();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ServiceTrackingScreen(
          requestId: widget.requestId,
          providerId: request['provider_id'],
          mechanicId: request['assigned_mechanic_id'],
        ),
      ),
    );
  }

  void _handleTimeout() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => RequestTimeoutScreen(
          requestId: widget.requestId,
          notifiedProviders: notifiedProviders,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Finding Available Mechanic'),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            _buildStatusHeader(),
            SizedBox(height: 30),
            _buildSearchAnimation(),
            SizedBox(height: 30),
            _buildStatusCards(),
            Spacer(),
            _buildCancelButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusHeader() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(
              Icons.search,
              size: 40,
              color: Colors.blue,
            ),
            SizedBox(height: 8),
            Text(
              'Searching for Available Mechanics',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Within ${widget.broadcastRadius.toInt()}km radius',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAnimation() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Container(
          width: 150,
          height: 150,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.blue.withOpacity(0.3),
              width: 2,
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Pulsing circles
              for (int i = 0; i < 3; i++)
                AnimatedContainer(
                  duration: Duration(milliseconds: 1000),
                  width: 50 + (i * 30) + (_pulseController.value * 20),
                  height: 50 + (i * 30) + (_pulseController.value * 20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.blue.withOpacity(0.5 - (i * 0.1)),
                      width: 1,
                    ),
                  ),
                ),
              // Center icon
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.blue,
                ),
                child: Icon(
                  Icons.build,
                  color: Colors.white,
                  size: 25,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusCards() {
    return Column(
      children: [
        _buildInfoCard(
          'Time Remaining',
          '${(remainingSeconds ~/ 60).toString().padLeft(2, '0')}:${(remainingSeconds % 60).toString().padLeft(2, '0')}',
          Icons.timer,
          Colors.orange,
        ),
        SizedBox(height: 10),
        _buildInfoCard(
          'Mechanics Notified',
          notifiedProviders.toString(),
          Icons.people,
          Colors.green,
        ),
        SizedBox(height: 10),
        _buildInfoCard(
          'Status',
          _getStatusText(),
          Icons.info,
          Colors.blue,
        ),
      ],
    );
  }

  Widget _buildInfoCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title),
        trailing: Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ),
    );
  }

  String _getStatusText() {
    switch (currentStatus) {
      case 'broadcasting':
        return 'Searching...';
      case 'accepted':
        return 'Accepted!';
      case 'expired':
        return 'Expired';
      default:
        return 'Unknown';
    }
  }

  Widget _buildCancelButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _cancelRequest,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          padding: EdgeInsets.symmetric(vertical: 15),
        ),
        child: Text(
          'Cancel Request',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
      ),
    );
  }

  Future<void> _cancelRequest() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Cancel Request?'),
        content: Text('Are you sure you want to cancel this service request?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Yes'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await SupabaseService.instance
          .from('service_requests')
          .update({
            'status': 'cancelled',
            'broadcast_status': 'cancelled',
            'cancelled_at': DateTime.now().toIso8601String(),
          })
          .eq('id', widget.requestId);

      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _countdownTimer.cancel();
    _requestSubscription.cancel();
    super.dispose();
  }
}
```

## 2. Mechanic/Provider Side Implementation

### 2.1 Available Requests Screen

```dart
// lib/mechanic/available_requests_screen.dart

class AvailableRequestsScreen extends StatefulWidget {
  @override
  _AvailableRequestsScreenState createState() => _AvailableRequestsScreenState();
}

class _AvailableRequestsScreenState extends State<AvailableRequestsScreen> {
  late StreamSubscription _requestsSubscription;
  List<Map<String, dynamic>> availableRequests = [];
  String providerId = '';

  @override
  void initState() {
    super.initState();
    _loadProviderId();
    _listenToAvailableRequests();
  }

  Future<void> _loadProviderId() async {
    final userId = SupabaseService.instance.auth.currentUser!.id;
    final response = await SupabaseService.instance
        .from('service_providers')
        .select('id')
        .eq('user_id', userId)
        .single();
    
    setState(() {
      providerId = response['id'];
    });
  }

  void _listenToAvailableRequests() {
    _requestsSubscription = SupabaseService.instance
        .from('request_broadcasts')
        .stream(primaryKey: ['id'])
        .eq('provider_id', providerId)
        .eq('response_status', 'pending')
        .listen((data) {
          _loadRequestDetails(data);
        });
  }

  Future<void> _loadRequestDetails(List<Map<String, dynamic>> broadcasts) async {
    final requestIds = broadcasts.map((b) => b['request_id']).toList();
    
    if (requestIds.isEmpty) {
      setState(() => availableRequests = []);
      return;
    }

    final requests = await SupabaseService.instance
        .from('service_requests')
        .select('''
          *,
          user_profiles!customer_id(first_name, last_name, phone_number),
          service_categories(name, icon_name),
          vehicles(brand_name, model_name, year)
        ''')
        .in_('id', requestIds)
        .eq('broadcast_status', 'broadcasting');

    // Merge with broadcast data
    final mergedData = requests.map((request) {
      final broadcast = broadcasts.firstWhere(
        (b) => b['request_id'] == request['id'],
      );
      return {...request, 'broadcast_info': broadcast};
    }).toList();

    setState(() => availableRequests = mergedData);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Available Requests'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () => _loadRequestDetails([]),
          ),
        ],
      ),
      body: availableRequests.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: availableRequests.length,
              itemBuilder: (context, index) {
                return _buildRequestCard(availableRequests[index]);
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'No Available Requests',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          SizedBox(height: 8),
          Text(
            'New requests will appear here automatically',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> request) {
    final customer = request['user_profiles'];
    final category = request['service_categories'];
    final vehicle = request['vehicles'];
    final broadcast = request['broadcast_info'];
    
    final distance = broadcast['distance_km'].toDouble();
    final timeRemaining = _calculateTimeRemaining(request['broadcast_expires_at']);

    return Card(
      margin: EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getPriorityColor(request['priority']),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    request['priority'].toUpperCase(),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Spacer(),
                Icon(Icons.timer, size: 16, color: Colors.orange),
                SizedBox(width: 4),
                Text(
                  '$timeRemaining min left',
                  style: TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            
            Text(
              request['title'],
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            
            Text(
              request['description'] ?? 'No description provided',
              style: TextStyle(color: Colors.grey[600]),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 12),
            
            Row(
              children: [
                Icon(Icons.person, size: 16, color: Colors.grey),
                SizedBox(width: 4),
                Text('${customer['first_name']} ${customer['last_name']}'),
                SizedBox(width: 16),
                Icon(Icons.location_on, size: 16, color: Colors.grey),
                SizedBox(width: 4),
                Text('${distance.toStringAsFixed(1)} km away'),
              ],
            ),
            SizedBox(height: 8),
            
            if (vehicle != null)
              Row(
                children: [
                  Icon(Icons.directions_car, size: 16, color: Colors.grey),
                  SizedBox(width: 4),
                  Text('${vehicle['year']} ${vehicle['brand_name']} ${vehicle['model_name']}'),
                ],
              ),
            
            SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _viewRequestDetails(request),
                    child: Text('View Details'),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _acceptRequest(request),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                    child: Text(
                      'Accept Job',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'urgent':
        return Colors.red;
      case 'high':
        return Colors.orange;
      case 'normal':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  int _calculateTimeRemaining(String expiresAt) {
    final expiry = DateTime.parse(expiresAt);
    final now = DateTime.now();
    final difference = expiry.difference(now);
    return difference.inMinutes.clamp(0, double.infinity.toInt());
  }

  Future<void> _acceptRequest(Map<String, dynamic> request) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Accept Job?'),
        content: Text(
          'Are you sure you want to accept this job? '
          'Distance: ${request['broadcast_info']['distance_km'].toStringAsFixed(1)} km\n'
          'Estimated Price: ₱${request['estimated_price']}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: Text('Accept Job', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final result = await SupabaseService.instance.rpc('accept_broadcast_request', {
          'p_request_id': request['id'],
          'p_provider_id': providerId,
          'p_mechanic_id': SupabaseService.instance.auth.currentUser!.id,
        });

        if (result['success']) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Job accepted successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          
          // Navigate to job details/tracking screen
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => JobTrackingScreen(
                requestId: request['id'],
              ),
            ),
          );
        } else {
          throw Exception(result['error']);
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to accept job: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _viewRequestDetails(Map<String, dynamic> request) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RequestDetailsScreen(
          request: request,
          onAccept: () => _acceptRequest(request),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _requestsSubscription.cancel();
    super.dispose();
  }
}
```

## 3. Supabase Service Integration

```dart
// lib/services/supabase_service.dart

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  static SupabaseService get instance => _instance;
  SupabaseService._internal();

  late SupabaseClient _client;
  SupabaseClient get client => _client;
  GoTrueClient get auth => _client.auth;

  Future<void> initialize() async {
    _client = SupabaseClient(
      'YOUR_SUPABASE_URL',
      'YOUR_SUPABASE_ANON_KEY',
    );
  }

  // Broadcast request methods
  Future<Map<String, dynamic>> broadcastServiceRequest({
    required String requestId,
    required double maxRadiusKm,
    required int responseTimeoutMinutes,
  }) async {
    final result = await _client.rpc('broadcast_service_request', {
      'p_request_id': requestId,
      'p_max_radius_km': maxRadiusKm,
      'p_response_timeout_minutes': responseTimeoutMinutes,
    });
    
    return Map<String, dynamic>.from(result);
  }

  Future<Map<String, dynamic>> acceptBroadcastRequest({
    required String requestId,
    required String providerId,
    String? mechanicId,
  }) async {
    final result = await _client.rpc('accept_broadcast_request', {
      'p_request_id': requestId,
      'p_provider_id': providerId,
      'p_mechanic_id': mechanicId,
    });
    
    return Map<String, dynamic>.from(result);
  }

  Future<List<Map<String, dynamic>>> getAvailableRequestsForProvider(
    String providerId,
  ) async {
    final result = await _client.rpc('get_available_broadcast_requests_for_provider', {
      'p_provider_id': providerId,
    });
    
    return List<Map<String, dynamic>>.from(result);
  }

  Stream<List<Map<String, dynamic>>> streamBroadcastRequests(String providerId) {
    return _client
        .from('request_broadcasts')
        .stream(primaryKey: ['id'])
        .eq('provider_id', providerId)
        .eq('response_status', 'pending')
        .map((data) => List<Map<String, dynamic>>.from(data));
  }

  // Other existing methods...
  PostgrestQueryBuilder from(String table) => _client.from(table);
  PostgrestRpcBuilder rpc(String fn, [Map<String, dynamic>? params]) => 
      _client.rpc(fn, params);
}
```

## 4. Push Notification Integration

Add to your notification service to handle broadcast notifications:

```dart
// lib/services/notification_service.dart

class NotificationService {
  static Future<void> handleBroadcastNotification(
    Map<String, dynamic> notification,
  ) async {
    final requestId = notification['request_id'];
    final distance = notification['distance_km'];
    final estimatedPrice = notification['estimated_price'];
    
    await _showNotification(
      title: 'New Service Request Available!',
      body: 'Distance: ${distance}km • Est. Pay: ₱$estimatedPrice',
      data: {
        'type': 'broadcast_request',
        'request_id': requestId,
        'action': 'view_request',
      },
    );
  }
}
```

## 5. Testing the System

1. **Test Broadcast Flow:**
   - Customer creates request with "Any Available Mechanic"
   - Multiple mechanics should receive notifications
   - First to accept gets the job
   - Others see "Job already taken" message

2. **Test Race Conditions:**
   - Have multiple mechanics try to accept simultaneously
   - Verify only one succeeds

3. **Test Timeouts:**
   - Create request with short timeout
   - Verify it expires and cleans up properly

4. **Test Distance Filtering:**
   - Create requests with different radii
   - Verify only mechanics within range are notified

## Implementation Notes

1. **Real-time Updates:** Use Supabase real-time subscriptions for instant updates
2. **Offline Handling:** Store pending requests locally and sync when online
3. **Performance:** Index database properly for location-based queries
4. **Security:** Validate user permissions before accepting requests
5. **Analytics:** Track response times and success rates for optimization

This system provides a competitive marketplace where mechanics can quickly respond to nearby requests, improving service availability and response times for customers.