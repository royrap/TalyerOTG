import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'widgets/angkas_slide_in.dart';
import '../services/mechanic_service.dart';
import 'enhanced_job_details_screen.dart';

class AngkasAssignedJobsScreen extends StatefulWidget {
  const AngkasAssignedJobsScreen({Key? key}) : super(key: key);

  @override
  State<AngkasAssignedJobsScreen> createState() => _AngkasAssignedJobsScreenState();
}

class _AngkasAssignedJobsScreenState extends State<AngkasAssignedJobsScreen> 
    with TickerProviderStateMixin {
  List<Map<String, dynamic>> _jobs = [];
  bool _isLoading = true;
  String _filter = 'all';
  StreamSubscription? _jobsSubscription;
  // Removed manual slide controller; use AngkasSlideIn

  final List<String> _statusFilters = [
    'all',
    'assigned',
    'accepted', 
    'awaiting_payment',
    'paid',
    'ready_to_assign',
    'in_progress',
    'inspection_started', 
    'inspection_completed',
    'estimate_provided',
    'estimate_approved',
    'invoice_sent',
    'invoice_accepted',
    'invoice_paid',
    'work_started',
    'work_completed',
    'awaiting_completion',
    'completed'
  ];

  @override
  void initState() {
    super.initState();
    _loadJobs();
    _startRealTimeUpdates();
  }

  @override
  void dispose() {
    _jobsSubscription?.cancel();
    super.dispose();
  }

  void _startRealTimeUpdates() {
    // Listen for real-time job updates to ensure jobs don't disappear after payment
    _jobsSubscription = MechanicService.instance.getAssignedJobsStream().listen(
      (jobs) {
        if (mounted) {
          setState(() {
            _jobs = jobs;
            _isLoading = false;
          });
          print('🔄 Jobs updated in real-time: ${jobs.length} jobs found');
        }
      },
      onError: (error) {
        print('❌ Error in real-time jobs stream: $error');
        // Fallback to manual refresh on error
        _loadJobs();
      },
    );
  }

  Future<void> _loadJobs() async {
    try {
      setState(() => _isLoading = true);
      final jobs = await MechanicService.instance.getAssignedJobs();
      if (mounted) {
        setState(() {
          _jobs = jobs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Error loading jobs: $e')),
              ],
            ),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  Future<void> _refreshJobs() async {
    HapticFeedback.lightImpact();
    await _loadJobs();
  }

  List<Map<String, dynamic>> _getFilteredJobs() {
    if (_filter == 'all') return _jobs;
    return _jobs.where((job) => job['status'] == _filter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredJobs = _getFilteredJobs();
    
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: AngkasSlideIn(
          child: Column(
            children: [
              // Header
              _buildHeader(),
              
              // Filter Chips
              _buildFilterChips(),
              
              // Jobs List
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: Color(0xFFEF5350)),
                      )
                    : filteredJobs.isEmpty
                        ? _buildEmptyState()
                        : RefreshIndicator(
                            onRefresh: _refreshJobs,
                            color: const Color(0xFFEF5350),
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                              itemCount: filteredJobs.length,
                              itemBuilder: (context, index) {
                                final job = filteredJobs[index];
                                return _AngkasJobCard(
                                  job: job,
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (context) => EnhancedJobDetailsScreen(
                                          jobId: job['id'],
                                        ),
                                      ),
                                    ).then((_) => _refreshJobs());
                                  },
                                );
                              },
                            ),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your Jobs',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              Text(
                '${_getFilteredJobs().length} jobs ${_filter == 'all' ? 'total' : _filter}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFEF5350).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.work_rounded,
              color: Color(0xFFEF5350),
              size: 24,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      height: 50,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _statusFilters.length,
        itemBuilder: (context, index) {
          final filter = _statusFilters[index];
          final isSelected = _filter == filter;
          final count = filter == 'all' 
              ? _jobs.length 
              : _jobs.where((job) => job['status'] == filter).length;
          
          return Container(
            margin: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _getFilterDisplayName(filter),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : const Color(0xFFEF5350),
                    ),
                  ),
                  if (count > 0) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isSelected 
                            ? Colors.white.withOpacity(0.3)
                            : const Color(0xFFEF5350).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        count.toString(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : const Color(0xFFEF5350),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _filter = filter;
                  });
                  HapticFeedback.selectionClick();
                }
              },
              backgroundColor: Colors.white,
              selectedColor: const Color(0xFFEF5350),
              side: BorderSide(
                color: isSelected ? const Color(0xFFEF5350) : Colors.grey[300]!,
              ),
              elevation: isSelected ? 4 : 0,
              shadowColor: const Color(0xFFEF5350).withOpacity(0.3),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(32),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              spreadRadius: 0,
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFEF5350).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.work_outline_rounded,
                size: 48,
                color: Color(0xFFEF5350),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _filter == 'all' 
                  ? 'No Jobs Yet'
                  : 'No ${_getFilterDisplayName(_filter)} Jobs',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _filter == 'all'
                  ? 'Your assigned jobs will appear here when customers request your services.'
                  : 'No jobs with ${_getFilterDisplayName(_filter).toLowerCase()} status found.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _refreshJobs,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Refresh'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF5350),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getFilterDisplayName(String filter) {
    switch (filter) {
      case 'all': return 'All';
      case 'assigned': return 'Assigned';
      case 'accepted': return 'Accepted';
      case 'in_progress': return 'In Progress';
      case 'inspection_completed': return 'Inspected';
      case 'invoice_sent': return 'Invoice Sent';
      case 'completed': return 'Completed';
      default: return filter.toUpperCase();
    }
  }
}

class _AngkasJobCard extends StatelessWidget {
  final Map<String, dynamic> job;
  final VoidCallback onTap;

  const _AngkasJobCard({
    required this.job,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final customer = job['customer'] ?? {};
    final customerName = '${customer['first_name'] ?? ''} ${customer['last_name'] ?? ''}'.trim();
    final status = job['status'] ?? 'unknown';
    final serviceType = job['service_type'] ?? 'Unknown Service';
    final location = job['location'] ?? 'Unknown Location';
    final createdAt = DateTime.tryParse(job['created_at'] ?? '');
    final urgency = job['urgency'] ?? 'normal';

    final statusConfig = _getStatusConfig(status);
    final urgencyConfig = _getUrgencyConfig(urgency);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: statusConfig['color'].withOpacity(0.2),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  spreadRadius: 0,
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: statusConfig['color'].withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.build_rounded,
                        color: statusConfig['color'],
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            serviceType,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                          Text(
                            customerName.isNotEmpty ? customerName : 'Unknown Customer',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusConfig['color'],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            statusConfig['label'],
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        if (urgency != 'normal') ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: urgencyConfig['color'].withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  urgencyConfig['icon'],
                                  size: 10,
                                  color: urgencyConfig['color'],
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  urgencyConfig['label'],
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: urgencyConfig['color'],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Location Row
                Row(
                  children: [
                    Icon(
                      Icons.location_on_rounded,
                      color: Colors.grey[600],
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        location,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // Bottom Row
                Row(
                  children: [
                    if (createdAt != null) ...[
                      Icon(
                        Icons.access_time_rounded,
                        color: Colors.grey[500],
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatTimeAgo(createdAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                    const Spacer(),
                    Row(
                      children: [
                        Text(
                          'View Details',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: statusConfig['color'],
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 12,
                          color: statusConfig['color'],
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Map<String, dynamic> _getStatusConfig(String status) {
    switch (status) {
      case 'assigned':
        return {
          'label': 'ASSIGNED',
          'color': const Color(0xFF1976D2),
        };
      case 'accepted':
        return {
          'label': 'ACCEPTED',
          'color': const Color(0xFFEF5350),
        };
      case 'in_progress':
        return {
          'label': 'IN PROGRESS',
          'color': const Color(0xFFE65100),
        };
      case 'inspection_completed':
        return {
          'label': 'INSPECTED',
          'color': const Color(0xFF7B1FA2),
        };
      case 'invoice_sent':
        return {
          'label': 'INVOICE SENT',
          'color': const Color(0xFF1565C0),
        };
      case 'completed':
        return {
          'label': 'COMPLETED',
          'color': const Color(0xFFEF5350),
        };
      default:
        return {
          'label': status.toUpperCase(),
          'color': Colors.grey[600],
        };
    }
  }

  Map<String, dynamic> _getUrgencyConfig(String urgency) {
    switch (urgency) {
      case 'urgent':
        return {
          'label': 'URGENT',
          'color': const Color(0xFFD32F2F),
          'icon': Icons.priority_high_rounded,
        };
      case 'high':
        return {
          'label': 'HIGH',
          'color': const Color(0xFFE65100),
          'icon': Icons.keyboard_arrow_up_rounded,
        };
      default:
        return {
          'label': 'NORMAL',
          'color': Colors.grey[600],
          'icon': Icons.remove_rounded,
        };
    }
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}

