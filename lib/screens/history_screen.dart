import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/customer_history_service.dart';
import '../services/mechanic_history_service.dart';
import '../services/auth_service.dart';
import '../models/job_history.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({Key? key}) : super(key: key);

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<dynamic> _jobHistory = []; // Changed to dynamic to handle both Customer and Mechanic history
  bool _isLoading = true;
  String _selectedFilter = 'all'; // all, completed, cancelled
  String? _userType; // Store user type to determine which service to use

  @override
  void initState() {
    super.initState();
    _loadJobHistory();
  }

  Future<void> _loadJobHistory() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      // Get user type to determine which history service to use
      _userType = AuthService.instance.userType;
      print('📋 HistoryScreen: Loading history for user type: $_userType');

      List<dynamic> history;
      
      if (_userType == 'mechanic') {
        // Use MechanicHistoryService for mechanics
        history = await MechanicHistoryService.instance.getMechanicJobHistory();
        print('🔧 Loaded ${history.length} mechanic job history entries');
      } else {
        // Use CustomerHistoryService for customers (default)
        print('👤 Loading customer job history...');
        history = await CustomerHistoryService.instance.getCustomerJobHistory();
        print('👤 Loaded ${history.length} customer job history entries');
        
        // Additional debug: Check if user is authenticated
        final currentUser = Supabase.instance.client.auth.currentUser;
        if (currentUser == null) {
          print('❌ No authenticated user found for customer history');
        } else {
          print('✅ Authenticated user: ${currentUser.id} (${currentUser.email})');
        }
      }
      
      if (mounted) {
        setState(() {
          _jobHistory = history;
          _isLoading = false;
        });
        
        // Log final result
        print('📋 HistoryScreen: Final job history count: ${history.length}');
      }
    } catch (e) {
      print('❌ Error loading job history: $e');
      print('🔍 Error details: ${e.toString()}');
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading job history: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  List<dynamic> get _filteredHistory {
    if (_selectedFilter == 'all') {
      return _jobHistory;
    }
    return _jobHistory.where((job) {
      String status;
      if (job is CustomerJobHistory) {
        status = job.jobStatus.toLowerCase();
      } else if (job is MechanicJobHistory) {
        status = job.jobStatus.toLowerCase();
      } else {
        // Fallback for Map<String, dynamic>
        status = job['job_status']?.toString().toLowerCase() ?? '';
      }
      return status == _selectedFilter;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          // Filter tabs
          _buildFilterTabs(),
          
          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredHistory.isEmpty
                    ? _buildEmptyState()
                    : _buildJobHistoryList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTabs() {
    // Calculate counts based on job history
    final completedCount = _jobHistory.where((job) {
      String status;
      if (job is CustomerJobHistory) {
        status = job.jobStatus.toLowerCase();
      } else if (job is MechanicJobHistory) {
        status = job.jobStatus.toLowerCase();
      } else {
        status = job['job_status']?.toString().toLowerCase() ?? '';
      }
      return status == 'completed';
    }).length;

    final cancelledCount = _jobHistory.where((job) {
      String status;
      if (job is CustomerJobHistory) {
        status = job.jobStatus.toLowerCase();
      } else if (job is MechanicJobHistory) {
        status = job.jobStatus.toLowerCase();
      } else {
        status = job['job_status']?.toString().toLowerCase() ?? '';
      }
      return status == 'cancelled';
    }).length;

    final filters = [
      {'key': 'all', 'label': 'All', 'count': _jobHistory.length},
      {'key': 'completed', 'label': 'Completed', 'count': completedCount},
      {'key': 'cancelled', 'label': 'Cancelled', 'count': cancelledCount},
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: filters.map((filter) {
            final isSelected = _selectedFilter == filter['key'];
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(
                  '${filter['label']} (${filter['count']})',
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey[700],
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    _selectedFilter = filter['key'] as String;
                  });
                },
                selectedColor: const Color.fromARGB(255, 176, 12, 1),
                backgroundColor: Colors.white,
                side: BorderSide(
                  color: isSelected 
                      ? const Color.fromARGB(255, 176, 12, 1)
                      : Colors.grey[300]!,
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.history,
              size: 48,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _selectedFilter == 'all' 
                ? 'No service requests yet'
                : 'No ${_selectedFilter} requests',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _selectedFilter == 'all'
                ? 'Your service history will appear here'
                : 'No requests match this filter',
            style: TextStyle(
              color: Colors.grey[600],
            ),
          ),
          if (_selectedFilter == 'all') ...[
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () async {
                // Reload history for debugging with force sync
                print('🔄 Manual reload with force sync requested by user');
                setState(() => _isLoading = true);
                
                try {
                  if (_userType != 'mechanic') {
                    // Force sync for customers
                    await CustomerHistoryService.instance.syncServiceRequestsToHistory();
                    await Future.delayed(const Duration(milliseconds: 500)); // Allow sync to complete
                  }
                  await _loadJobHistory();
                } catch (e) {
                  print('❌ Error during manual refresh: $e');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Refresh error: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange[700],
                foregroundColor: Colors.white,
              ),
              child: const Text('Refresh'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                // Safe navigate to request service tab if a DefaultTabController exists
                try {
                  DefaultTabController.of(context).animateTo(2);
                } catch (e) {
                  // Fallback: inform the user that navigation isn't available in this context
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Cannot navigate to Request Service: tab controller unavailable')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 176, 12, 1),
                foregroundColor: Colors.white,
              ),
              child: const Text('Request Service'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildJobHistoryList() {
    return RefreshIndicator(
      onRefresh: _loadJobHistory,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _filteredHistory.length,
        itemBuilder: (context, index) {
          final job = _filteredHistory[index];
          return _buildJobHistoryCard(job);
        },
      ),
    );
  }
  Widget _buildJobHistoryCard(dynamic job) {
    // Handle both CustomerJobHistory and MechanicJobHistory objects
    String jobTitle;
    String jobStatus;
    DateTime? completedAt;
    DateTime? cancelledAt;
    double? totalAmount;
    int? rating;
    String? reviewText;
    String? customerName;
    String? mechanicName;
    String? shopName;
    String? vehicleInfo;
    
    if (job is CustomerJobHistory) {
      jobTitle = job.jobTitle;
      jobStatus = job.jobStatus;
      completedAt = job.completedAt;
      cancelledAt = job.cancelledAt;
      totalAmount = job.totalAmount;
      rating = job.rating?.toInt();
      reviewText = job.reviewText;
      mechanicName = job.mechanicName;
      shopName = job.shopName;
      customerName = null; // Customer viewing their own history
      
      // Extract vehicle info from service request or vehicles table
      vehicleInfo = _extractVehicleInfo(job);
    } else if (job is MechanicJobHistory) {
      jobTitle = job.jobTitle;
      jobStatus = job.jobStatus;
      completedAt = job.completedAt;
      cancelledAt = job.cancelledAt;
      totalAmount = job.totalAmount;
      rating = job.rating?.toInt();
      reviewText = job.reviewText;
      customerName = job.customer?.firstName != null && job.customer?.lastName != null 
          ? '${job.customer!.firstName} ${job.customer!.lastName}'
          : 'Unknown Customer';
      shopName = job.shop?.shopName;
      mechanicName = null; // Mechanic viewing their own history
      
      // For mechanic history, vehicle info might be in service request
      vehicleInfo = _extractVehicleInfoFromMechanicJob(job);
    } else {
      // Fallback for Map<String, dynamic>
      jobTitle = job['job_title'] ?? 'Unknown Job';
      jobStatus = job['job_status'] ?? 'unknown';
      totalAmount = job['total_amount']?.toDouble();
      rating = job['rating'];
      reviewText = job['review_text'];
      customerName = job['customer_name'];
      mechanicName = job['mechanic_name'];
      shopName = job['shop_name'];
      vehicleInfo = _extractVehicleInfoFromMap(job);
      
      // Parse dates
      if (job['completed_at'] != null) {
        completedAt = DateTime.tryParse(job['completed_at']);
      }
      if (job['cancelled_at'] != null) {
        cancelledAt = DateTime.tryParse(job['cancelled_at']);
      }
    }

    final isCompleted = jobStatus.toLowerCase() == 'completed';
    final isCancelled = jobStatus.toLowerCase() == 'cancelled';
    final displayDate = completedAt ?? cancelledAt ?? DateTime.now();

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with title and status
            Row(
              children: [
                Expanded(
                  child: Text(
                    jobTitle,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: isCompleted 
                        ? Colors.green.withOpacity(0.1)
                        : isCancelled
                            ? Colors.red.withOpacity(0.1)
                            : Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isCompleted 
                        ? '✅ Completed'
                        : isCancelled
                            ? '❌ Cancelled'
                            : jobStatus.toUpperCase(),
                    style: TextStyle(
                      color: isCompleted 
                          ? Colors.green[700]
                          : isCancelled
                              ? Colors.red[700]
                              : Colors.orange[700],
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Customer/Mechanic name
            if (customerName != null) ...[
              Row(
                children: [
                  Icon(Icons.person, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text('Customer: $customerName', style: TextStyle(color: Colors.grey[600])),
                ],
              ),
              const SizedBox(height: 4),
            ],
            
            if (mechanicName != null) ...[
              Row(
                children: [
                  Icon(Icons.build, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text('Mechanic: $mechanicName', style: TextStyle(color: Colors.grey[600])),
                ],
              ),
              const SizedBox(height: 4),
            ],
            
            // Shop name
            if (shopName != null) ...[
              Row(
                children: [
                  Icon(Icons.store, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text('Shop: $shopName', style: TextStyle(color: Colors.grey[600])),
                ],
              ),
              const SizedBox(height: 4),
            ],

            // Vehicle information
            if (vehicleInfo != null) ...[
              Row(
                children: [
                  Icon(Icons.directions_car, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Vehicle: $vehicleInfo', 
                      style: TextStyle(color: Colors.grey[600]),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
            ],
            
            // Date
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(
                  '${isCompleted ? "Completed" : isCancelled ? "Cancelled" : "Date"}: ${_formatDate(displayDate)}',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
            
            // Amount and rating
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (totalAmount != null) ...[
                  Text(
                    '₱${totalAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color.fromARGB(255, 176, 12, 1),
                    ),
                  ),
                ],
                if (rating != null && rating > 0) ...[
                  Row(
                    children: [
                      Icon(Icons.star, size: 16, color: Colors.amber[600]),
                      const SizedBox(width: 4),
                      Text(
                        '$rating/5',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
            
            // Review text
            if (reviewText != null && reviewText.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  reviewText,
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Extract vehicle information for customer job history
  String? _extractVehicleInfo(CustomerJobHistory job) {
    // First try to get from vehicles relation
    if (job.toJson().containsKey('vehicles') && job.toJson()['vehicles'] != null) {
      final vehicle = job.toJson()['vehicles'];
      return _formatVehicleInfo(vehicle);
    }
    
    // Then try from service request vehicle_info
    if (job.serviceRequest != null) {
      // Check if ServiceRequestData has vehicle info
      final serviceRequestJson = job.serviceRequest!.toJson();
      if (serviceRequestJson.containsKey('vehicle_info') && serviceRequestJson['vehicle_info'] != null) {
        return _formatVehicleInfoFromJson(serviceRequestJson['vehicle_info']);
      }
    }
    
    return null;
  }

  // Extract vehicle information from mechanic job history
  String? _extractVehicleInfoFromMechanicJob(MechanicJobHistory job) {
    if (job.serviceRequest != null) {
      final serviceRequestJson = job.serviceRequest!.toJson();
      if (serviceRequestJson.containsKey('vehicle_info') && serviceRequestJson['vehicle_info'] != null) {
        return _formatVehicleInfoFromJson(serviceRequestJson['vehicle_info']);
      }
    }
    return null;
  }

  // Extract vehicle information from map data
  String? _extractVehicleInfoFromMap(Map<String, dynamic> job) {
    // Check vehicles relation
    if (job.containsKey('vehicles') && job['vehicles'] != null) {
      return _formatVehicleInfo(job['vehicles']);
    }
    
    // Check service request vehicle_info
    if (job.containsKey('service_requests') && 
        job['service_requests'] != null &&
        job['service_requests']['vehicle_info'] != null) {
      return _formatVehicleInfoFromJson(job['service_requests']['vehicle_info']);
    }
    
    return null;
  }

  // Format vehicle info from vehicle table data
  String _formatVehicleInfo(Map<String, dynamic> vehicle) {
    final make = vehicle['make'] ?? '';
    final model = vehicle['model'] ?? '';
    final year = vehicle['year']?.toString() ?? '';
    final color = vehicle['color'] ?? '';
    
    final List<String> parts = [];
    if (year.isNotEmpty) parts.add(year);
    if (color.isNotEmpty) parts.add(color);
    if (make.isNotEmpty) parts.add(make);
    if (model.isNotEmpty) parts.add(model);
    
    return parts.isNotEmpty ? parts.join(' ') : 'Unknown Vehicle';
  }

  // Format vehicle info from JSON field
  String _formatVehicleInfoFromJson(dynamic vehicleInfo) {
    if (vehicleInfo is Map) {
      final make = vehicleInfo['make']?.toString() ?? '';
      final model = vehicleInfo['model']?.toString() ?? '';
      final year = vehicleInfo['year']?.toString() ?? '';
      final color = vehicleInfo['color']?.toString() ?? '';
      
      final List<String> parts = [];
      if (year.isNotEmpty) parts.add(year);
      if (color.isNotEmpty) parts.add(color);
      if (make.isNotEmpty) parts.add(make);
      if (model.isNotEmpty) parts.add(model);
      
      return parts.isNotEmpty ? parts.join(' ') : 'Unknown Vehicle';
    }
    return 'Unknown Vehicle';
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);
    
    // For customer history: Show date only (no time)
    if (dateOnly == today) {
      return 'Today';
    } else if (dateOnly == yesterday) {
      return 'Yesterday';
    } else {
      return '${months[date.month - 1]} ${date.day}, ${date.year}';
    }
  }
}
