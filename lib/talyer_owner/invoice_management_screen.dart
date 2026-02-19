import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'talyer_owner_api_service.dart';

class InvoiceManagementScreen extends StatefulWidget {
  final String shopId;

  const InvoiceManagementScreen({Key? key, required this.shopId}) : super(key: key);

  @override
  State<InvoiceManagementScreen> createState() => _InvoiceManagementScreenState();
}

class _InvoiceManagementScreenState extends State<InvoiceManagementScreen> {
  List<Map<String, dynamic>> _invoices = [];
  bool _isLoading = true;
  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadInvoices();
  }

  Future<void> _loadInvoices() async {
    setState(() => _isLoading = true);
    try {
      final invoices = await TalyerOwnerApiService().getInvoices(shopId: widget.shopId);
      setState(() {
        _invoices = invoices;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading invoices: $e');
      setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get filteredInvoices {
    if (_selectedFilter == 'all') return _invoices;
    return _invoices.where((invoice) => invoice['status'] == _selectedFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Invoice Management'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Filter chips
          Container(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('All', 'all'),
                  _buildFilterChip('Pending', 'pending'),
                  _buildFilterChip('Paid', 'paid'),
                  _buildFilterChip('Generated', 'generated'),
                  _buildFilterChip('Sent', 'sent'),
                  _buildFilterChip('Disputed', 'disputed'),
                ],
              ),
            ),
          ),
          // Invoices list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.red))
                : filteredInvoices.isEmpty
                    ? Center(
                        child: Text(
                          'No invoices found',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadInvoices,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filteredInvoices.length,
                          itemBuilder: (context, index) {
                            return _buildInvoiceCard(filteredInvoices[index]);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() => _selectedFilter = value);
        },
        selectedColor: Colors.red.withOpacity(0.2),
        checkmarkColor: Colors.red,
        labelStyle: TextStyle(
          color: isSelected ? Colors.red : Colors.grey[700],
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildInvoiceCard(Map<String, dynamic> invoice) {
    final customerName = invoice['customer'] != null
        ? '${invoice['customer']['first_name']} ${invoice['customer']['last_name']}'
        : 'N/A';
    final mechanicName = invoice['mechanic'] != null
        ? '${invoice['mechanic']['first_name']} ${invoice['mechanic']['last_name']}'
        : 'N/A';
    
    final status = invoice['status'] as String;
    final statusColor = _getStatusColor(status);
    
    final generatedAt = invoice['generated_at'] != null
        ? DateFormat('MMM dd, yyyy hh:mm a').format(DateTime.parse(invoice['generated_at'] as String))
        : 'N/A';

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showInvoiceDetails(invoice),
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
                          invoice['invoice_number'] ?? 'N/A',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          generatedAt,
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
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              // Customer info
              Row(
                children: [
                  Icon(Icons.person, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          customerName,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        if (invoice['customer'] != null && invoice['customer']['phone_number'] != null)
                          Text(
                            invoice['customer']['phone_number'],
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Mechanic info
              Row(
                children: [
                  Icon(Icons.engineering, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          mechanicName,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        if (invoice['mechanic'] != null && invoice['mechanic']['email'] != null)
                          Text(
                            invoice['mechanic']['email'],
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Vehicle info
              if (invoice['vehicle'] != null)
                Row(
                  children: [
                    Icon(Icons.directions_car, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${invoice['vehicle']['brand_name']} ${invoice['vehicle']['model_name']} - ${invoice['vehicle']['plate_number']}',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              // Service request info
              if (invoice['service_request'] != null)
                const SizedBox(height: 8),
              if (invoice['service_request'] != null)
                Row(
                  children: [
                    Icon(Icons.build, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        invoice['service_request']['title'] ?? 'Service',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              // Pickup address
              if (invoice['service_request'] != null && invoice['service_request']['pickup_address'] != null)
                const SizedBox(height: 4),
              if (invoice['service_request'] != null && invoice['service_request']['pickup_address'] != null)
                Row(
                  children: [
                    Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        invoice['service_request']['pickup_address'],
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              // Cash verification status
              if (invoice['cash_verification'] != null)
                const SizedBox(height: 8),
              if (invoice['cash_verification'] != null)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber[300]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.payment, size: 16, color: Colors.amber[700]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Cash Payment: ${invoice['cash_verification']['verification_status']}',
                          style: TextStyle(fontSize: 12, color: Colors.amber[900]),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total Amount:',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                  Text(
                    '₱${(invoice['total_amount'] as num).toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
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

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
        return Colors.green;
      case 'pending':
      case 'generated':
      case 'sent':
        return Colors.orange;
      case 'disputed':
        return Colors.red;
      case 'refunded':
        return Colors.blue;
      case 'cancelled':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  void _showInvoiceDetails(Map<String, dynamic> invoice) {
    final customerName = invoice['customer'] != null
        ? '${invoice['customer']['first_name']} ${invoice['customer']['last_name']}'
        : 'N/A';
    final customerEmail = invoice['customer']?['email'] ?? 'N/A';
    final customerPhone = invoice['customer']?['phone_number'] ?? 'N/A';
    
    final mechanicName = invoice['mechanic'] != null
        ? '${invoice['mechanic']['first_name']} ${invoice['mechanic']['last_name']}'
        : 'N/A';

    final serviceTitle = invoice['service_request']?['title'] ?? 'N/A';
    final serviceDescription = invoice['service_request']?['description'] ?? 'N/A';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(invoice['invoice_number'] ?? 'Invoice Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Status', invoice['status']),
              _buildDetailRow('Generated At', invoice['generated_at'] != null
                  ? DateFormat('MMM dd, yyyy hh:mm a').format(DateTime.parse(invoice['generated_at'] as String))
                  : 'N/A'),
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
              _buildDetailRow('Service', serviceTitle),
              _buildDetailRow('Description', serviceDescription),
              const Divider(),
              const Text('Payment Information', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _buildDetailRow('Subtotal', '₱${(invoice['subtotal'] as num).toStringAsFixed(2)}'),
              _buildDetailRow('Platform Fee', '₱${(invoice['platform_fee'] as num).toStringAsFixed(2)}'),
              _buildDetailRow('Total Amount', '₱${(invoice['total_amount'] as num).toStringAsFixed(2)}'),
              _buildDetailRow('Shop Net Amount', '₱${(invoice['talyer_net_amount'] as num).toStringAsFixed(2)}'),
              _buildDetailRow('Payment Method', invoice['selected_payment_method'] ?? 'N/A'),
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
