import 'package:flutter/material.dart';
import '../services/marketplace_service.dart';
import '../services/auth_service.dart';

class ShopOwnerRequestsScreen extends StatefulWidget {
  const ShopOwnerRequestsScreen({super.key}));

  @override
  State<ShopOwnerRequestsScreen> createState() => _ShopOwnerRequestsScreenState();
}

class _ShopOwnerRequestsScreenState extends State<ShopOwnerRequestsScreen> {
  final MarketplaceService _marketplaceService = MarketplaceService();
  
  List<PendingServiceRequest> _pendingRequests = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadPendingRequests();
  }

  Future<void> _loadPendingRequests() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      final user = await AuthService.getCurrentUser();
      if (user?.id == null) {
        throw Exception('User not authenticated');
      }

      final requests = await _marketplaceService.getShopPendingRequests(user!.id);
      
      setState(() {
        _pendingRequests = requests;
      });

    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load requests: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _respondToRequest(
    String requestId,
    String action, {
    String? notes,
    DateTime? estimatedArrivalTime,
  }) async {
    try {
      final user = await AuthService.getCurrentUser();
      if (user?.id == null) {
        throw Exception('User not authenticated');
      }

      final result = await _marketplaceService.respondToServiceRequest(
        requestId: requestId,
        shopOwnerId: user!.id,
        action: action,
        notes: notes,
        estimatedArrivalTime: estimatedArrivalTime,
      );

      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: Colors.green,
          ),
        );
        
        // Reload requests
        _loadPendingRequests();
      } else {
        _showError(result.error ?? 'Failed to respond to request');
      }

    } catch (e) {
      _showError('Error: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showAcceptDialog(PendingServiceRequest request) {
    final notesController = TextEditingController();
    DateTime estimatedArrival = DateTime.now().add(const Duration(minutes: 30));

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Accept Service Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Customer: ${request.customerName}'),
            Text('Service: ${request.serviceName}'),
            Text('Location: ${request.pickupAddress}'),
            const SizedBox(height: 16),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                hintText: 'Additional information for customer...',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('Estimated Arrival Time'),
              subtitle: Text(
                '${estimatedArrival.hour.toString().padLeft(2, '0')}:${estimatedArrival.minute.toString().padLeft(2, '0')}',
              ),
              trailing: const Icon(Icons.schedule),
              onTap: () async {
                final time = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.fromDateTime(estimatedArrival),
                );
                if (time != null) {
                  setState(() {
                    estimatedArrival = DateTime(
                      estimatedArrival.year,
                      estimatedArrival.month,
                      estimatedArrival.day,
                      time.hour,
                      time.minute,
                    );
                  });
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _respondToRequest(
                request.requestId,
                'accept',
                notes: notesController.text.trim().isEmpty 
                    ? null 
                    : notesController.text.trim(),
                estimatedArrivalTime: estimatedArrival,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Accept'),
          ),
        ],
      ),
    );
  }

  void _showRejectDialog(PendingServiceRequest request) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Service Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Customer: ${request.customerName}'),
            Text('Service: ${request.serviceName}'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason for rejection',
                hintText: 'Please provide a reason...',
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please provide a reason for rejection'),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }
              Navigator.pop(context);
              _respondToRequest(
                request.requestId,
                'reject',
                notes: reasonController.text.trim(),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Service Requests'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPendingRequests,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading service requests...'),
          ],
        ),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadPendingRequests,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_pendingRequests.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No pending service requests',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'New requests will appear here',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _pendingRequests.length,
      itemBuilder: (context, index) {
        final request = _pendingRequests[index];
        return _buildRequestCard(request);
      },
    );
  }

  Widget _buildRequestCard(PendingServiceRequest request) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Request Header
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.serviceName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Customer: ${request.customerName}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (request.isEmergency)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.withAlpha(26),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red),
                    ),
                    child: const Text(
                      'EMERGENCY',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Request Details
            _buildDetailRow(Icons.location_on, 'Location', request.pickupAddress),
            _buildDetailRow(Icons.phone, 'Phone', request.customerPhone ?? 'Not provided'),
            _buildDetailRow(Icons.route, 'Distance', '${request.distanceKm.toStringAsFixed(1)} km'),
            _buildDetailRow(Icons.attach_money, 'Estimated Price', '₱${request.estimatedPrice.toStringAsFixed(2)}'),
            _buildDetailRow(Icons.schedule, 'Requested', _formatDateTime(request.createdAt)),
            
            // Vehicle Info
            if (request.vehicleInfo.brand != null)
              _buildDetailRow(
                Icons.directions_car,
                'Vehicle',
                '${request.vehicleInfo.brand} ${request.vehicleInfo.model} ${request.vehicleInfo.year}' +
                (request.vehicleInfo.plateNumber != null ? ' (${request.vehicleInfo.plateNumber})' : ''),
              ),
            
            // Description
            if (request.description != null && request.description!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Description:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(request.description!),
                  ],
                ),
              ),
            ],
            
            // Action Buttons
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showRejectDialog(request),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showAcceptDialog(request),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Accept'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
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

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hr ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }
}










