import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'talyer_owner_api_service.dart';

class ServiceRequestsAuditScreen extends StatefulWidget {
  final String shopId;

  const ServiceRequestsAuditScreen({Key? key, required this.shopId}) : super(key: key);

  @override
  State<ServiceRequestsAuditScreen> createState() => _ServiceRequestsAuditScreenState();
}

class _ServiceRequestsAuditScreenState extends State<ServiceRequestsAuditScreen> {
  final TalyerOwnerApiService _apiService = TalyerOwnerApiService();
  
  List<Map<String, dynamic>> _requests = [];
  bool _isLoading = true;
  
  String? _selectedStatus;
  DateTime? _startDate;
  DateTime? _endDate;

  final List<String> _statusOptions = [
    'All',
    'pending',
    'accepted',
    'in_progress',
    'completed',
    'cancelled',
    'rejected',
  ];

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() => _isLoading = true);
    
    try {
      final requests = await _apiService.getServiceRequests(
        shopId: widget.shopId,
        status: _selectedStatus == 'All' ? null : _selectedStatus,
        startDate: _startDate,
        endDate: _endDate,
      );
      
      setState(() {
        _requests = requests;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading requests: $e')),
        );
      }
    }
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Service Requests'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: _selectedStatus,
                decoration: const InputDecoration(labelText: 'Status'),
                items: _statusOptions.map((status) {
                  return DropdownMenuItem(value: status, child: Text(status));
                }).toList(),
                onChanged: (value) {
                  setState(() => _selectedStatus = value == 'All' ? null : value);
                },
              ),
              const SizedBox(height: 16),
              ListTile(
                title: Text(_startDate == null
                    ? 'Start Date: Not set'
                    : 'Start: ${DateFormat('MMM dd, yyyy').format(_startDate!)}'),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _startDate ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) {
                    setState(() => _startDate = date);
                  }
                },
              ),
              ListTile(
                title: Text(_endDate == null
                    ? 'End Date: Not set'
                    : 'End: ${DateFormat('MMM dd, yyyy').format(_endDate!)}'),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _endDate ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) {
                    setState(() => _endDate = date);
                  }
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _selectedStatus = null;
                _startDate = null;
                _endDate = null;
              });
              Navigator.pop(context);
              _loadRequests();
            },
            child: const Text('Clear'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _loadRequests();
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Service Requests Audit'),
        backgroundColor: Colors.red,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRequests,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _requests.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.assignment, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No service requests found',
                        style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadRequests,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _requests.length,
                    itemBuilder: (context, index) {
                      return _buildRequestCard(_requests[index]);
                    },
                  ),
                ),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> request) {
    final customerName = request['customer'] != null
        ? '${request['customer']['first_name']} ${request['customer']['last_name']}'
        : 'N/A';
    final mechanicName = request['mechanic'] != null
        ? '${request['mechanic']['first_name']} ${request['mechanic']['last_name']}'
        : 'Not Assigned';
    
    final status = request['status'] as String;
    final statusColor = _getStatusColor(status);
    
    final createdAt = request['created_at'] != null
        ? DateFormat('MMM dd, yyyy hh:mm a').format(DateTime.parse(request['created_at'] as String))
        : 'N/A';

    final categoryName = request['category']?['name'] ?? 'N/A';

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showRequestDetails(request),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          request['title'] ?? 'Service Request',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          createdAt,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 20),
              Row(
                children: [
                  Icon(Icons.person, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Customer: $customerName',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.engineering, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Mechanic: $mechanicName',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.build, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Category: $categoryName',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
              if (request['final_price'] != null) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Final Price:',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
                      ),
                    ),
                    Text(
                      '₱${(request['final_price'] as num).toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'in_progress':
      case 'accepted':
        return Colors.blue;
      case 'pending':
        return Colors.orange;
      case 'cancelled':
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Future<void> _showRequestDetails(Map<String, dynamic> request) async {
    final customerName = request['customer'] != null
        ? '${request['customer']['first_name']} ${request['customer']['last_name']}'
        : 'N/A';
    final customerEmail = request['customer']?['email'] ?? 'N/A';
    final customerPhone = request['customer']?['phone_number'] ?? 'N/A';
    
    final mechanicName = request['mechanic'] != null
        ? '${request['mechanic']['first_name']} ${request['mechanic']['last_name']}'
        : 'Not Assigned';

    // Load status history
    List<Map<String, dynamic>> statusHistory = [];
    try {
      statusHistory = await _apiService.getRequestStatusHistory(request['id'] as String);
    } catch (e) {
      // Ignore error, show without history
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(request['title'] ?? 'Request Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Status', request['status']),
              _buildDetailRow('Payment Status', request['payment_status'] ?? 'N/A'),
              _buildDetailRow('Service Type', request['service_type'] ?? 'N/A'),
              const Divider(),
              const Text('Customer Information', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _buildDetailRow('Name', customerName),
              _buildDetailRow('Email', customerEmail),
              _buildDetailRow('Phone', customerPhone),
              const Divider(),
              const Text('Mechanic Information', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _buildDetailRow('Name', mechanicName),
              const Divider(),
              const Text('Service Information', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _buildDetailRow('Description', request['description'] ?? 'N/A'),
              _buildDetailRow('Category', request['category']?['name'] ?? 'N/A'),
              _buildDetailRow('Pickup Address', request['pickup_address'] ?? 'N/A'),
              const Divider(),
              const Text('Pricing Information', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (request['estimated_price'] != null)
                _buildDetailRow('Estimated Price', '₱${(request['estimated_price'] as num).toStringAsFixed(2)}'),
              if (request['final_price'] != null)
                _buildDetailRow('Final Price', '₱${(request['final_price'] as num).toStringAsFixed(2)}'),
              if (request['service_fee'] != null)
                _buildDetailRow('Service Fee', '₱${(request['service_fee'] as num).toStringAsFixed(2)}'),
              if (statusHistory.isNotEmpty) ...[
                const Divider(),
                const Text('Status History', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...statusHistory.map((history) {
                  final timestamp = history['created_at'] != null
                      ? DateFormat('MMM dd, hh:mm a').format(DateTime.parse(history['created_at'] as String))
                      : 'N/A';
                  final statusValue = history['status'] as String;
                  final changedBy = history['changed_by_user'] != null
                      ? '${history['changed_by_user']['first_name']} ${history['changed_by_user']['last_name']}'
                      : 'System';
                  
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(top: 6, right: 8),
                          decoration: BoxDecoration(
                            color: _getStatusColor(statusValue),
                            shape: BoxShape.circle,
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                statusValue.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: _getStatusColor(statusValue),
                                ),
                              ),
                              Text(
                                '$timestamp • $changedBy',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                ),
                              ),
                              if (history['notes'] != null)
                                Text(
                                  history['notes'] as String,
                                  style: const TextStyle(fontSize: 11),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
