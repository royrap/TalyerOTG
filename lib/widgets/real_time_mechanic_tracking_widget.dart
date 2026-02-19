import 'package:flutter/material.dart';
import 'dart:async';
import '../services/real_time_tracking_service.dart';
import '../models/invoice.dart';
import '../customer/modern_invoice_screen.dart';

class RealTimeMechanicTrackingWidget extends StatefulWidget {
  final String serviceRequestId;
  final VoidCallback? onPaymentRequested;

  const RealTimeMechanicTrackingWidget({
    Key? key,
    required this.serviceRequestId,
    this.onPaymentRequested,
  }) : super(key: key);

  @override
  State<RealTimeMechanicTrackingWidget> createState() => _RealTimeMechanicTrackingWidgetState();
}

class _RealTimeMechanicTrackingWidgetState extends State<RealTimeMechanicTrackingWidget>
    with TickerProviderStateMixin {
  
  late StreamSubscription<Map<String, dynamic>> _locationSubscription;
  late StreamSubscription<Map<String, dynamic>> _invoiceSubscription;
  late AnimationController _pulseController;
  
  Map<String, dynamic>? _currentLocationData;
  Map<String, dynamic>? _currentInvoiceData;
  bool _isTrackingActive = false;
  bool _hasNewInvoice = false;
  String _trackingStatus = 'Initializing...';

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: Duration(seconds: 1),
      vsync: this,
    )..repeat(reverse: true);
    
    _startTracking();
  }

  @override
  void dispose() {
    _locationSubscription.cancel();
    _invoiceSubscription.cancel();
    _pulseController.dispose();
    RealTimeTrackingService.instance.stopTrackingMechanicLocation(widget.serviceRequestId);
    RealTimeTrackingService.instance.stopTrackingInvoiceUpdates(widget.serviceRequestId);
    super.dispose();
  }

  void _startTracking() {
    // Start tracking mechanic location
    _locationSubscription = RealTimeTrackingService.instance
        .trackMechanicLocation(widget.serviceRequestId)
        .listen(
      (locationData) {
        if (mounted) {
          setState(() {
            _currentLocationData = locationData;
            _isTrackingActive = locationData['is_tracking_active'] ?? false;
            _updateTrackingStatus(locationData);
          });
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() {
            _trackingStatus = 'Tracking error: $error';
            _isTrackingActive = false;
          });
        }
      },
    );

    // Start tracking invoice updates
    _invoiceSubscription = RealTimeTrackingService.instance
        .trackInvoiceUpdates(widget.serviceRequestId)
        .listen(
      (invoiceData) {
        if (mounted) {
          setState(() {
            _currentInvoiceData = invoiceData;
            _hasNewInvoice = invoiceData['is_new'] ?? false;
            
            // Show invoice notification if new invoice detected
            if (_hasNewInvoice && invoiceData['has_invoice'] == true) {
              _showInvoiceNotification();
            }
          });
        }
      },
      onError: (error) {
        print('Error tracking invoice: $error');
      },
    );
  }

  void _updateTrackingStatus(Map<String, dynamic> locationData) {
    final status = locationData['status'];
    final hasLocation = locationData['location'] != null;

    if (status == 'in_progress' && hasLocation) {
      _trackingStatus = 'Mechanic is on the way';
    } else if (status == 'in_progress' && !hasLocation) {
      _trackingStatus = 'Mechanic assigned, awaiting location';
    } else if (status == 'ready_to_assign') {
      _trackingStatus = 'Finding a mechanic for you';
    } else if (status == 'awaiting_payment') {
      _trackingStatus = 'Payment required to proceed';
    } else {
      _trackingStatus = 'Service request $status';
    }
  }

  void _showInvoiceNotification() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.receipt_long, color: Colors.white),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'New invoice received! Tap to view and pay.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 5),
        action: SnackBarAction(
          label: 'VIEW',
          textColor: Colors.white,
          onPressed: _showInvoiceBottomSheet,
        ),
      ),
    );
  }

  void _showInvoiceBottomSheet() {
    if (_currentInvoiceData == null || _currentInvoiceData!['has_invoice'] != true) {
      return;
    }

    final invoice = _currentInvoiceData!['invoice'];
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: EdgeInsets.symmetric(vertical: 10),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: EdgeInsets.all(20),
                  children: [
                    Row(
                      children: [
                        Icon(Icons.receipt_long, size: 32, color: Colors.blue),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Service Invoice',
                                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Invoice #${invoice['id']}',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 20),
                    _buildInvoiceStatusChip(invoice['status']),
                    SizedBox(height: 20),
                    Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Text(
                              'Invoice Details',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            SizedBox(height: 12),
                            if (invoice['items'] != null && invoice['items'].isNotEmpty)
                              ...invoice['items'].map<Widget>((item) => Padding(
                                padding: EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${item['description']} (${item['quantity']}x)',
                                        style: TextStyle(fontSize: 14),
                                      ),
                                    ),
                                    Text(
                                      '₱${item['total_price']}',
                                      style: TextStyle(fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                              )).toList(),
                            Divider(),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Total Amount',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                Text(
                                  '₱${invoice['total_amount']}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 20),
                    if (invoice['status'] == 'sent' || invoice['payment_status'] != 'paid')
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: () => _proceedToPayment(invoice),
                          icon: Icon(Icons.payment),
                          label: Text('Pay Invoice'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInvoiceStatusChip(String status) {
    Color backgroundColor;
    Color textColor;
    IconData icon;

    switch (status.toLowerCase()) {
      case 'sent':
        backgroundColor = Colors.orange;
        textColor = Colors.white;
        icon = Icons.send;
        break;
      case 'paid':
        backgroundColor = Colors.green;
        textColor = Colors.white;
        icon = Icons.check_circle;
        break;
      case 'overdue':
        backgroundColor = Colors.red;
        textColor = Colors.white;
        icon = Icons.warning;
        break;
      default:
        backgroundColor = Colors.grey;
        textColor = Colors.white;
        icon = Icons.info;
    }

    return Chip(
      avatar: Icon(icon, color: textColor, size: 18),
      label: Text(
        status.toUpperCase(),
        style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
      ),
      backgroundColor: backgroundColor,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.all(16),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) => Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isTrackingActive 
                          ? Colors.green.withOpacity(0.3 + (_pulseController.value * 0.7))
                          : Colors.grey,
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Service Tracking',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (_hasNewInvoice)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'NEW',
                      style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
            SizedBox(height: 12),
            Text(
              _trackingStatus,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            SizedBox(height: 16),
            
            // Mechanic Information
            if (_currentLocationData?['mechanic'] != null)
              _buildMechanicInfo(_currentLocationData!['mechanic']),
            
            // Location Information
            if (_currentLocationData?['location'] != null)
              _buildLocationInfo(_currentLocationData!['location']),
            
            // Invoice Information
            if (_currentInvoiceData?['has_invoice'] == true)
              _buildInvoiceInfo(),
            
            SizedBox(height: 16),
            
            // Action Buttons
            Row(
              children: [
                if (_currentInvoiceData?['has_invoice'] == true &&
                    _currentInvoiceData!['invoice']['payment_status'] != 'paid')
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _showInvoiceBottomSheet,
                      icon: Icon(Icons.receipt_long),
                      label: Text('View Invoice'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                if (_currentLocationData?['location'] != null) ...[
                  if (_currentInvoiceData?['has_invoice'] == true) SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _openMapsLocation,
                      icon: Icon(Icons.map),
                      label: Text('View on Map'),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMechanicInfo(Map<String, dynamic> mechanic) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.blue,
            child: Icon(Icons.build, color: Colors.white),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mechanic['name'] ?? 'Mechanic',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                if (mechanic['company'] != null)
                  Text(
                    mechanic['company'],
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                if (mechanic['phone'] != null)
                  Text(
                    mechanic['phone'],
                    style: TextStyle(color: Colors.blue, fontSize: 12),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationInfo(Map<String, dynamic> location) {
    final lastUpdated = DateTime.tryParse(location['last_updated'] ?? '');
    final timeAgo = lastUpdated != null 
        ? _getTimeAgo(lastUpdated)
        : 'Unknown';

    return Container(
      margin: EdgeInsets.only(top: 12),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.location_on, color: Colors.green),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current Location',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  'Lat: ${location['latitude']?.toStringAsFixed(6)}, Lng: ${location['longitude']?.toStringAsFixed(6)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                Text(
                  'Updated $timeAgo',
                  style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceInfo() {
    final invoice = _currentInvoiceData!['invoice'];
    final isNew = _currentInvoiceData!['is_new'] ?? false;
    
    return Container(
      margin: EdgeInsets.only(top: 12),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isNew ? Colors.orange[50] : Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: isNew ? Border.all(color: Colors.orange, width: 2) : null,
      ),
      child: Row(
        children: [
          Icon(
            Icons.receipt_long, 
            color: isNew ? Colors.orange : Colors.grey[600],
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Invoice Available',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    if (isNew) ...[
                      SizedBox(width: 8),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'NEW',
                          style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  'Amount: ₱${invoice['total_amount']}',
                  style: TextStyle(color: Colors.green, fontWeight: FontWeight.w500),
                ),
                Text(
                  'Status: ${invoice['status']}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  void _openMapsLocation() {
    final location = _currentLocationData?['location'];
    if (location == null) return;

    final lat = location['latitude'];
    final lng = location['longitude'];
    
    // Open default maps app with mechanic location
    // You can customize this to use Google Maps, Apple Maps, etc.
    print('Opening maps with location: $lat, $lng');
    // Implementation depends on your preferred maps integration
  }

  void _proceedToPayment(Map<String, dynamic> invoice) {
    // Navigate to modern payment screen
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ModernInvoiceScreen(
          invoice: Invoice(
            id: invoice['id'] ?? '',
            requestId: invoice['request_id'] ?? '',
            customerId: invoice['customer_id'] ?? '',
            providerId: invoice['provider_id'] ?? '',
            items: (invoice['items'] as List<dynamic>?)?.map((item) => InvoiceItem(
              description: item['description'] ?? '',
              quantity: item['quantity']?.toDouble() ?? 1.0,
              unitPrice: item['unit_price']?.toDouble() ?? 0.0,
              total: item['total_price']?.toDouble() ?? 0.0,
              type: item['type'] ?? 'service',
            )).toList() ?? [],
            subtotal: invoice['subtotal']?.toDouble() ?? invoice['total_amount']?.toDouble() ?? 0.0,
            tax: invoice['tax']?.toDouble() ?? 0.0,
            total: invoice['total']?.toDouble() ?? invoice['total_amount']?.toDouble() ?? 0.0,
            status: invoice['status'] ?? 'sent',
            createdAt: DateTime.tryParse(invoice['created_at'] ?? '') ?? DateTime.now(),
            paidAt: invoice['paid_at'] != null ? DateTime.tryParse(invoice['paid_at']) : null,
          ),
        ),
      ),
    ).then((success) {
      if (success == true) {
        // Payment was successful, close the bottom sheet
        Navigator.of(context).pop();
      }
    });
  }
}
