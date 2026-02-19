import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../services/security_logging_service.dart';
import '../widgets/nearby_shops_widget.dart';
import '../widgets/real_time_mechanic_tracking_widget.dart';
import 'service_type_selection_screen.dart';
import 'customer_invoices_screen.dart';
import 'customer_profile_screen.dart';
import 'service_history_screen.dart';

class CustomerDashboard extends StatefulWidget {
  const CustomerDashboard({Key? key}) : super(key: key);

  @override
  State<CustomerDashboard> createState() => _CustomerDashboardState();
}

class _CustomerDashboardState extends State<CustomerDashboard> {
  int _selectedIndex = 0;
  Map<String, dynamic>? _userProfile;
  List<Map<String, dynamic>> _activeRequests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
    _logUserLogin();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _logUserLogin() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      await SecurityLoggingService.logSecurityEvent(
        userId: user.id,
        actionType: 'login',
        success: true,
        details: {'dashboard': 'customer'},
      );
    }
  }

  Future<void> _loadDashboardData() async {
    try {
      _userProfile = AuthService.instance.userProfile;
      await _loadActiveRequests();
    } catch (e) {
      print('Error loading dashboard data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadActiveRequests() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final response = await Supabase.instance.client
          .from('service_requests')
          .select('''
            *,
            shops(shop_name),
            service_categories(name)
          ''')
          .eq('customer_id', user.id)
          .inFilter('status', ['pending', 'awaiting_payment', 'paid', 'accepted', 'assigned', 'in_progress'])
          .order('created_at', ascending: false);

      setState(() {
        _activeRequests = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      print('Error loading active requests: $e');
    }
  }

  void _onNavItemTapped(int index) {
    // Block Request Service tab (index 1) if customer has active request
    if (index == 1 && _activeRequests.isNotEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Active Request Found'),
          content: const Text(
            'You already have an active service request. Please complete or cancel it before creating a new request.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return; // Don't change the selected tab
    }

    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _signOut() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        await SecurityLoggingService.logSecurityEvent(
          userId: user.id,
          actionType: 'logout',
          success: true,
          details: {'dashboard': 'customer'},
        );
      }
      await AuthService.instance.signOut();
    } catch (e) {
      print('Error signing out: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final List<Widget> pages = [
      _buildHomeTab(),
      const ServiceTypeSelectionScreen(),
      CustomerInvoicesScreen(),
      const ServiceHistoryScreen(),
      const CustomerProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('Hello, ${_userProfile?['first_name'] ?? 'Customer'}!'),
        backgroundColor: Colors.orange[700],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
          ),
        ],
      ),
      body: pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onNavItemTapped,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.orange[700],
        unselectedItemColor: Colors.grey[600],
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.build_circle),
            label: 'Request Service',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long),
            label: 'Invoices',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'History',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _buildHomeTab() {
    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Quick Actions Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quick Actions',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildQuickActionButton(
                            icon: Icons.build_circle,
                            label: 'Request Service',
                            color: Colors.orange[700]!,
                            onTap: () => _onNavItemTapped(1),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildQuickActionButton(
                            icon: Icons.store,
                            label: 'Browse Shops',
                            color: Colors.blue[700]!,
                            onTap: () {
                              // Scroll to nearby shops section
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Active Requests
            if (_activeRequests.isNotEmpty) ...[
              Text(
                'Active Requests',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              
              // Real-time tracking widgets for in-progress requests
              ..._activeRequests.where((request) => 
                ['in_progress', 'assigned'].contains(request['status'])).map((request) => 
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: RealTimeMechanicTrackingWidget(
                    serviceRequestId: request['id'],
                  ),
                )
              ).toList(),
              
              // Regular list view for other requests
              if (_activeRequests.where((request) => 
                !['in_progress', 'assigned'].contains(request['status'])).isNotEmpty)
                Card(
                  child: Column(
                    children: _activeRequests.where((request) => 
                      !['in_progress', 'assigned'].contains(request['status'])).map((request) {
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _getStatusColor(request['status']),
                          child: Icon(
                            Icons.build,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        title: Text(request['title'] ?? 'Service Request'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Status: ${_formatStatus(request['status'])}'),
                            if (request['shops'] != null)
                              Text('Shop: ${request['shops']['shop_name']}'),
                          ],
                        ),
                        trailing: Text(
                          '₱${request['estimated_price']?.toStringAsFixed(0) ?? 'TBD'}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                        onTap: () {
                          // TODO: Navigate to request details
                        },
                      );
                    }).toList(),
                  ),
                ),
              const SizedBox(height: 20),
            ],

            // Nearby Shops
            const NearbyShopsWidget(),

            const SizedBox(height: 20),

            // Emergency Contact Card
            Card(
              color: Colors.red[50],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.emergency,
                      color: Colors.red[700],
                      size: 32,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Emergency Service',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.red[700],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Need immediate roadside assistance?',
                            style: TextStyle(color: Colors.red[600]),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        // TODO: Create emergency request
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[700],
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Call Now'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'accepted':
      case 'assigned':
        return Colors.blue;
      case 'in_progress':
        return Colors.purple;
      case 'completed':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _formatStatus(String status) {
    return status.split('_').map((word) {
      return word[0].toUpperCase() + word.substring(1);
    }).join(' ');
  }
}











