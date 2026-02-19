import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'talyer_owner_api_service.dart';
import 'invoice_management_screen.dart';
import 'mechanics_performance_screen.dart';
import 'shop_reports_screen.dart';
import 'shop_settings_screen.dart';
import 'manage_shop_services_screen.dart';

class TalyerOwnerDashboard extends StatefulWidget {
  const TalyerOwnerDashboard({Key? key}) : super(key: key);

  @override
  State<TalyerOwnerDashboard> createState() => _TalyerOwnerDashboardState();
}

class _TalyerOwnerDashboardState extends State<TalyerOwnerDashboard> {
  final TalyerOwnerApiService _apiService = TalyerOwnerApiService();
  final SupabaseClient _supabase = Supabase.instance.client;
  
  String? _shopId;
  String? _shopName;
  bool _isLoading = true;
  Map<String, dynamic>? _dashboardData;
  RealtimeChannel? _realtimeChannel;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  @override
  void dispose() {
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    
    try {
      // Get shop ID
      _shopId = await _apiService.getShopId();
      
      if (_shopId == null) {
        throw Exception('Shop not found for current user');
      }

      // Get shop name
      final shopSettings = await _apiService.getShopSettings(_shopId!);
      _shopName = shopSettings?['shop_name'] ?? 'My Shop';

      // Get dashboard overview data
      final data = await _apiService.getDashboardOverview(_shopId!);
      
      setState(() {
        _dashboardData = data;
        _isLoading = false;
      });

      // Setup real-time updates
      _setupRealtimeUpdates();
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading dashboard: $e')),
        );
      }
    }
  }

  void _setupRealtimeUpdates() {
    if (_shopId == null) return;

    _realtimeChannel = _apiService.subscribeToDashboardUpdates(
      _shopId!,
      (update) {
        // Reload dashboard data when changes occur
        _loadDashboardData();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_shopName ?? 'Shop Dashboard'),
        backgroundColor: Colors.red,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDashboardData,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _showLogoutConfirmation(context),
          ),
        ],
      ),
      drawer: _buildDrawer(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDashboardData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🏪 Dashboard Overview',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 16),
                    _buildOverviewCards(),
                    const SizedBox(height: 24),
                    _buildQuickActions(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              color: Colors.red,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Icon(
                  Icons.store,
                  size: 48,
                  color: Colors.white,
                ),
                const SizedBox(height: 8),
                Text(
                  _shopName ?? 'Shop Dashboard',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text(
                  'Talyer Owner Portal',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.dashboard),
            title: const Text('Dashboard'),
            onTap: () => Navigator.pop(context),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.receipt_long),
            title: const Text('Invoice Management'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => InvoiceManagementScreen(shopId: _shopId!),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.people),
            title: const Text('Mechanics Performance'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MechanicsPerformanceScreen(shopId: _shopId!),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.build_circle),
            title: const Text('Manage Services'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ManageShopServicesScreen(shopId: _shopId!),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.bar_chart),
            title: const Text('Shop Reports'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ShopReportsScreen(shopId: _shopId!),
                ),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Shop Settings'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ShopSettingsScreen(shopId: _shopId!),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewCards() {
    if (_dashboardData == null) {
      return const SizedBox.shrink();
    }

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.3,
      children: [
        _buildStatCard(
          'Total Mechanics',
          '${_dashboardData!['totalMechanics']}',
          Icons.engineering,
          Colors.blue,
        ),
        _buildStatCard(
          'Active Mechanics',
          '${_dashboardData!['activeMechanics']}',
          Icons.check_circle,
          Colors.green,
        ),
        _buildStatCard(
          'Completed Jobs',
          '${_dashboardData!['completedJobs']}',
          Icons.done_all,
          Colors.teal,
        ),
        _buildStatCard(
          'Cancelled Jobs',
          '${_dashboardData!['cancelledJobs']}',
          Icons.cancel,
          Colors.red,
        ),
        _buildStatCard(
          'Total Earnings',
          '₱${(_dashboardData!['totalEarnings'] as num).toStringAsFixed(2)}',
          Icons.attach_money,
          Colors.amber,
        ),
        _buildStatCard(
          "Today's Earnings",
          '₱${(_dashboardData!['todayEarnings'] as num).toStringAsFixed(2)}',
          Icons.today,
          Colors.red,
        ),
        _buildStatCard(
          'In Progress',
          '${_dashboardData!['inProgress']}',
          Icons.hourglass_bottom,
          Colors.purple,
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [color.withOpacity(0.1), Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(icon, color: color, size: 24),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '⚡ Quick Actions',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 2,
          children: [
            _buildActionButton(
              'View Invoices',
              Icons.receipt_long,
              Colors.blue,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => InvoiceManagementScreen(shopId: _shopId!),
                ),
              ),
            ),
            _buildActionButton(
              'View Mechanics',
              Icons.people,
              Colors.green,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MechanicsPerformanceScreen(shopId: _shopId!),
                ),
              ),
            ),
            _buildActionButton(
              'Reports',
              Icons.bar_chart,
              Colors.red,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ShopReportsScreen(shopId: _shopId!),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              colors: [color.withOpacity(0.15), Colors.white],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLogoutConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Confirm Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await _supabase.auth.signOut();
                if (mounted) {
                  Navigator.of(context).pushReplacementNamed('/login');
                }
              },
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );
  }
}
