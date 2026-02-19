import 'package:flutter/material.dart';
import '../services/enhanced_service_request_service.dart';

class ServiceRequestStatusTracker extends StatefulWidget {
  final String serviceRequestId;
  final bool showFullHistory;

  const ServiceRequestStatusTracker({
    Key? key,
    required this.serviceRequestId,
    this.showFullHistory = true,
  }) : super(key: key);

  @override
  State<ServiceRequestStatusTracker> createState() => _ServiceRequestStatusTrackerState();
}

class _ServiceRequestStatusTrackerState extends State<ServiceRequestStatusTracker> {
  List<Map<String, dynamic>> _statusHistory = [];
  bool _isLoading = true;
  String _currentStatus = '';

  @override
  void initState() {
    super.initState();
    _loadStatusHistory();
  }

  Future<void> _loadStatusHistory() async {
    try {
      final history = await EnhancedServiceRequestService.getStatusHistory(
        widget.serviceRequestId,
      );
      
      setState(() {
        _statusHistory = history;
        _currentStatus = history.isNotEmpty ? history.last['status'] : '';
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading status history: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_statusHistory.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text('No status history available'),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.timeline,
                color: ServiceRequestStatus.getStatusColor(_currentStatus),
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Request Status',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 4),
          
          // Current Status Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: ServiceRequestStatus.getStatusColor(_currentStatus).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: ServiceRequestStatus.getStatusColor(_currentStatus),
              ),
            ),
            child: Text(
              ServiceRequestStatus.getDisplayName(_currentStatus),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: ServiceRequestStatus.getStatusColor(_currentStatus),
              ),
            ),
          ),
          
          if (widget.showFullHistory) ...[
            const SizedBox(height: 20),
            
            // Status History
            Column(
              children: _statusHistory.asMap().entries.map((entry) {
                final index = entry.key;
                final status = entry.value;
                final isLast = index == _statusHistory.length - 1;
                
                return _buildStatusItem(
                  status,
                  isLast,
                  isLast, // isActive - only the last item is active
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusItem(Map<String, dynamic> status, bool isLast, bool isActive) {
    final statusCode = status['status'];
    final statusColor = ServiceRequestStatus.getStatusColor(statusCode);
    final timestamp = DateTime.parse(status['created_at']);
    final notes = status['notes'] ?? '';
    final userName = status['user_profiles'] != null
        ? '${status['user_profiles']['first_name']} ${status['user_profiles']['last_name']}'
        : 'System';

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline
          Column(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: isActive ? statusColor : Colors.grey[300],
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: statusColor,
                    width: 2,
                  ),
                ),
                child: isActive
                    ? Icon(
                        _getStatusIcon(statusCode),
                        size: 10,
                        color: Colors.white,
                      )
                    : null,
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 40,
                  color: Colors.grey[300],
                ),
            ],
          ),
          
          const SizedBox(width: 16),
          
          // Status Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status Title
                  Text(
                    ServiceRequestStatus.getDisplayName(statusCode),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                      color: isActive ? statusColor : Colors.black87,
                    ),
                  ),
                  
                  const SizedBox(height: 4),
                  
                  // Timestamp and User
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 12,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatTimestamp(timestamp),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.person,
                        size: 12,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        userName,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  
                  // Notes
                  if (notes.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Text(
                        notes,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case ServiceRequestStatus.pending:
        return Icons.hourglass_empty;
      case ServiceRequestStatus.accepted:
        return Icons.check;
      case ServiceRequestStatus.paid:
        return Icons.payment;
      case ServiceRequestStatus.mechanicDispatched:
        return Icons.directions_car;
      case ServiceRequestStatus.invoiceSent:
        return Icons.receipt;
      case ServiceRequestStatus.invoicePaid:
        return Icons.paid;
      case ServiceRequestStatus.completed:
        return Icons.check_circle;
      case ServiceRequestStatus.cancelled:
        return Icons.cancel;
      default:
        return Icons.info;
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${timestamp.day}/${timestamp.month} ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
    }
  }
}