import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/service_history_detail_screen.dart';
import 'dart:async';

class ServiceHistoryScreen extends StatefulWidget {
  const ServiceHistoryScreen({Key? key}) : super(key: key);

  @override
  State<ServiceHistoryScreen> createState() => _ServiceHistoryScreenState();
}

class _ServiceHistoryScreenState extends State<ServiceHistoryScreen> {
  List<Map<String, dynamic>> _serviceHistory = [];
  bool _isLoading = true;
  String _selectedFilter = 'all';
  StreamSubscription? _realtimeSubscription;

  @override
  void initState() {
    super.initState();
    _loadServiceHistory();
    _setupRealtimeListener();
  }

  @override
  void dispose() {
    _realtimeSubscription?.cancel();
    super.dispose();
  }

  /// Setup realtime listener for service_requests changes
  void _setupRealtimeListener() {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      print('🔔 Setting up realtime listener for customer history');

      // Listen to changes in service_requests table
      _realtimeSubscription = Supabase.instance.client
          .from('service_requests')
          .stream(primaryKey: ['id'])
          .eq('customer_id', user.id)
          .listen((List<Map<String, dynamic>> data) {
            print('🔔 Realtime update received for service_requests');
            _loadServiceHistory(); // Reload the full history with relations
          });

      print('✅ Realtime listener setup complete');
    } catch (e) {
      print('❌ Error setting up realtime listener: $e');
    }
  }

  Future<void> _loadServiceHistory() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      var query = Supabase.instance.client
          .from('service_requests')
          .select('''
            *,
            shops(shop_name),
            service_categories(name, icon_name),
            reviews(rating, comment),
            invoices(total_amount, status, mechanic:user_profiles!invoices_mechanic_id_fkey(first_name, last_name, email)),
            vehicles(brand_name, model_name, plate_number)
          ''')
          .eq('customer_id', user.id);

      // Apply filter
      if (_selectedFilter != 'all') {
        query = query.eq('status', _selectedFilter);
      }

      final response = await query.order('created_at', ascending: false);

      setState(() {
        _serviceHistory = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading service history: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showServiceDetails(Map<String, dynamic> service) async {
    // Navigate to detailed view screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ServiceHistoryDetailScreen(
          requestId: service['id'],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Service History'),
        backgroundColor: Colors.orange[700],
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Filter Chips
          Container(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('all', 'All Services'),
                  const SizedBox(width: 8),
                  _buildFilterChip('completed', 'Completed'),
                  const SizedBox(width: 8),
                  _buildFilterChip('cancelled', 'Cancelled'),
                  const SizedBox(width: 8),
                  _buildFilterChip('in_progress', 'In Progress'),
                ],
              ),
            ),
          ),

          // Service History List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _serviceHistory.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _loadServiceHistory,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _serviceHistory.length,
                          itemBuilder: (context, index) {
                            final service = _serviceHistory[index];
                            return _buildServiceCard(service);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _selectedFilter == value;
    return FilterChip(
      selected: isSelected,
      label: Text(label),
      onSelected: (selected) {
        setState(() {
          _selectedFilter = value;
          _isLoading = true;
        });
        _loadServiceHistory();
      },
      selectedColor: Colors.orange[100],
      checkmarkColor: Colors.orange[700],
    );
  }

  Widget _buildServiceCard(Map<String, dynamic> service) {
    final shop = service['shops'];
    final category = service['service_categories'];
    final reviews = service['reviews'] as List?;
    final invoices = service['invoices'] as List?;
    final review = reviews?.isNotEmpty == true ? reviews!.first : null;
    final invoice = invoices?.isNotEmpty == true ? invoices!.first : null;

    final createdAt = DateTime.parse(service['created_at']);
    final completedAt = service['completed_at'] != null 
        ? DateTime.parse(service['completed_at'])
        : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showServiceDetails(service),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _getStatusColor(service['status']).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getCategoryIcon(category?['icon_name']),
                      color: _getStatusColor(service['status']),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          service['title'] ?? 'Service Request',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          category?['name'] ?? 'General Service',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(service['status']),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _formatStatus(service['status']),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),
              
              // Mechanic Info - SAME STYLE AS INVOICE
              if (invoice != null && invoice['mechanic'] != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.person_outline, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 6),
                    Text(
                      '${invoice['mechanic']['first_name'] ?? ''} ${invoice['mechanic']['last_name'] ?? ''}',
                      style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                    ),
                  ],
                ),
                if (invoice['mechanic']['email'] != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.email_outlined, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 6),
                      Text(
                        invoice['mechanic']['email'],
                        style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                      ),
                    ],
                  ),
                ],
              ],
              
              // Vehicle Info - SAME STYLE AS INVOICE
              if (service['vehicles'] != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.directions_car, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 6),
                    Text(
                      '${service['vehicles']['brand_name'] ?? ''} ${service['vehicles']['model_name'] ?? ''} - ${service['vehicles']['plate_number'] ?? 'N/A'}',
                      style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                    ),
                  ],
                ),
              ],
              
              const SizedBox(height: 8),
              
              // Shop and Date Info
              Row(
                children: [
                  Icon(Icons.store, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    shop?['shop_name'] ?? 'Unknown Shop',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const Spacer(),
                  Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    _formatDate(createdAt),
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),

              // Service Details
              if (service['description'] != null) ...[
                const SizedBox(height: 8),
                Text(
                  service['description'],
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey[700]),
                ),
              ],

              const SizedBox(height: 12),

              // Bottom Row - Price and Rating
              Row(
                children: [
                  if (invoice != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '₱${invoice['total_amount']?.toStringAsFixed(0) ?? '0'}',
                        style: TextStyle(
                          color: Colors.red[700],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  
                  if (review != null) ...[
                    Row(
                      children: [
                        Icon(Icons.star, size: 16, color: Colors.amber[600]),
                        const SizedBox(width: 2),
                        Text(
                          review['rating'].toString(),
                          style: TextStyle(
                            color: Colors.amber[600],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 8),
                  ],

                  const Spacer(),

                  if (completedAt != null)
                    Text(
                      'Completed ${_formatDate(completedAt)}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ],
          ),
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
            Icons.history,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No Service History',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your completed services will appear here',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String? iconName) {
    switch (iconName) {
      case 'tire_repair':
        return Icons.tire_repair;
      case 'battery':
        return Icons.battery_charging_full;
      case 'oil':
        return Icons.local_gas_station;
      case 'brake':
        return Icons.directions_car;
      case 'lockout':
        return Icons.lock_open;
      case 'towing':
        return Icons.local_shipping;
      default:
        return Icons.build;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      case 'in_progress':
        return Colors.blue;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _formatStatus(String status) {
    return status.split('_').map((word) {
      return word[0].toUpperCase() + word.substring(1);
    }).join(' ');
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}












