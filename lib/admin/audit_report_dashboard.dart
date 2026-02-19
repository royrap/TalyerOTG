import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/audit_logging_service.dart';

/// Administrative dashboard for viewing audit logs and system activity
class AuditReportDashboard extends StatefulWidget {
  const AuditReportDashboard({Key? key}) : super(key: key);

  @override
  State<AuditReportDashboard> createState() => _AuditReportDashboardState();
}

class _AuditReportDashboardState extends State<AuditReportDashboard> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final AuditLoggingService _auditService = AuditLoggingService();
  
  // Data variables
  List<Map<String, dynamic>> _userActivities = [];
  List<Map<String, dynamic>> _systemSummary = [];
  bool _isLoading = false;
  
  // Filter variables
  DateTime? _startDate;
  DateTime? _endDate;
  String? _selectedUserId;
  String? _selectedRole;
  String? _selectedAction;
  
  final List<String> _roles = [
    'customer',
    'mechanic', 
    'talyer_owner',
    'admin',
    'super_admin',
    'system'
  ];
  
  final List<String> _actions = [
    'USER_LOGIN',
    'USER_LOGOUT',
    'USER_REGISTRATION',
    'SERVICE_REQUEST_CREATED',
    'SERVICE_REQUEST_ASSIGNED',
    'SERVICE_REQUEST_COMPLETED',
    'QR_CODE_GENERATED',
    'QR_CODE_SCANNED_SUCCESS',
    'LOCATION_UPDATE',
    'EARNINGS_CALCULATED',
    'PROFILE_UPDATE',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _startDate = DateTime.now().subtract(const Duration(days: 7));
    _endDate = DateTime.now();
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      // Load system activity summary
      final systemSummary = await _auditService.getSystemActivitySummary(
        startDate: _startDate,
        endDate: _endDate,
      );
      
      setState(() {
        _systemSummary = systemSummary;
      });
      
      // If a specific user is selected, load their activity
      if (_selectedUserId != null) {
        final userActivities = await _auditService.getUserActivityReport(
          userId: _selectedUserId!,
          startDate: _startDate,
          endDate: _endDate,
        );
        
        setState(() {
          _userActivities = userActivities;
        });
      }
      
    } catch (e) {
      print('Error loading audit data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading audit data: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Audit Report Dashboard'),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.analytics), text: 'System Summary'),
            Tab(icon: Icon(Icons.person_search), text: 'User Activity'),
            Tab(icon: Icon(Icons.filter_list), text: 'Filters'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSystemSummaryTab(),
          _buildUserActivityTab(),
          _buildFiltersTab(),
        ],
      ),
    );
  }

  Widget _buildSystemSummaryTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date range display
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Icon(Icons.date_range, color: Colors.blue[800]),
                  const SizedBox(width: 8),
                  Text(
                    'Report Period: ${DateFormat('MMM dd, yyyy').format(_startDate!)} - ${DateFormat('MMM dd, yyyy').format(_endDate!)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // System activity summary
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _systemSummary.isEmpty
                    ? const Center(
                        child: Text(
                          'No audit data found for selected period',
                          style: TextStyle(fontSize: 16),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _systemSummary.length,
                        itemBuilder: (context, index) {
                          final item = _systemSummary[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: _getRoleColor(item['role']),
                                child: Icon(
                                  _getRoleIcon(item['role']),
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                '${item['role']} - ${item['action']}',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                'Count: ${item['count']} | Success Rate: ${item['success_rate']}%',
                              ),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _getSuccessRateColor(item['success_rate']),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${item['success_rate']}%',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserActivityTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // User ID input
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Enter User ID to view activity:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    onChanged: (value) {
                      _selectedUserId = value.isEmpty ? null : value;
                    },
                    decoration: const InputDecoration(
                      hintText: 'Enter user ID (UUID format)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _selectedUserId?.isNotEmpty == true ? _loadData : null,
                    icon: const Icon(Icons.search),
                    label: const Text('Load User Activity'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // User activities list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _userActivities.isEmpty
                    ? const Center(
                        child: Text(
                          'No user activity found. Enter a valid User ID.',
                          style: TextStyle(fontSize: 16),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _userActivities.length,
                        itemBuilder: (context, index) {
                          final activity = _userActivities[index];
                          final createdAt = DateTime.parse(activity['created_at']);
                          
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ExpansionTile(
                              leading: Icon(
                                _getActionIcon(activity['action']),
                                color: activity['success'] ? Colors.green : Colors.red,
                              ),
                              title: Text(
                                activity['action'],
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                '${DateFormat('MMM dd, yyyy HH:mm').format(createdAt)} | Table: ${activity['table_name'] ?? 'N/A'}',
                              ),
                              trailing: Icon(
                                activity['success'] ? Icons.check_circle : Icons.error,
                                color: activity['success'] ? Colors.green : Colors.red,
                              ),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (activity['additional_info'] != null) ...[
                                        const Text('Additional Info:', style: TextStyle(fontWeight: FontWeight.bold)),
                                        Text(activity['additional_info'].toString()),
                                        const SizedBox(height: 8),
                                      ],
                                      Text('Log ID: ${activity['log_id']}'),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date range filters
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Date Range',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => _selectDate(context, true),
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Start Date',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.calendar_today),
                            ),
                            child: Text(
                              DateFormat('MMM dd, yyyy').format(_startDate!),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: InkWell(
                          onTap: () => _selectDate(context, false),
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'End Date',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.calendar_today),
                            ),
                            child: Text(
                              DateFormat('MMM dd, yyyy').format(_endDate!),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Quick date filters
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Quick Filters',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildQuickFilterChip('Last 24 Hours', 1),
                      _buildQuickFilterChip('Last 7 Days', 7),
                      _buildQuickFilterChip('Last 30 Days', 30),
                      _buildQuickFilterChip('Last 90 Days', 90),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Apply filters button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('Apply Filters & Refresh'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[800],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickFilterChip(String label, int days) {
    return FilterChip(
      label: Text(label),
      selected: false,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _endDate = DateTime.now();
            _startDate = _endDate!.subtract(Duration(days: days));
          });
          _loadData();
        }
      },
    );
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? _startDate! : _endDate!,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );
    
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'customer':
        return Colors.blue;
      case 'mechanic':
        return Colors.orange;
      case 'talyer_owner':
        return Colors.purple;
      case 'admin':
        return Colors.green;
      case 'super_admin':
        return Colors.red;
      case 'system':
        return Colors.grey;
      default:
        return Colors.blueGrey;
    }
  }

  IconData _getRoleIcon(String role) {
    switch (role) {
      case 'customer':
        return Icons.person;
      case 'mechanic':
        return Icons.build;
      case 'talyer_owner':
        return Icons.store;
      case 'admin':
        return Icons.admin_panel_settings;
      case 'super_admin':
        return Icons.supervisor_account;
      case 'system':
        return Icons.computer;
      default:
        return Icons.help;
    }
  }

  IconData _getActionIcon(String action) {
    if (action.contains('LOGIN')) return Icons.login;
    if (action.contains('LOGOUT')) return Icons.logout;
    if (action.contains('REGISTRATION')) return Icons.person_add;
    if (action.contains('QR_CODE')) return Icons.qr_code;
    if (action.contains('LOCATION')) return Icons.location_on;
    if (action.contains('SERVICE_REQUEST')) return Icons.build;
    if (action.contains('EARNINGS')) return Icons.attach_money;
    if (action.contains('PROFILE')) return Icons.edit;
    return Icons.info;
  }

  Color _getSuccessRateColor(dynamic successRate) {
    final rate = (successRate as num).toDouble();
    if (rate >= 95) return Colors.green;
    if (rate >= 80) return Colors.orange;
    return Colors.red;
  }
}