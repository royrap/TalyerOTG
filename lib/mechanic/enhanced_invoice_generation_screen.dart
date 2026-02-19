import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/mechanic_invoice_realtime_service.dart';
import '../services/auth_service.dart';
import '../widgets/mechanic_qr_scanner.dart';

class EnhancedInvoiceGenerationScreen extends StatefulWidget {
  final String jobId;
  final Map<String, dynamic> jobDetails;

  const EnhancedInvoiceGenerationScreen({
    Key? key,
    required this.jobId,
    required this.jobDetails,
  }) : super(key: key);

  @override
  State<EnhancedInvoiceGenerationScreen> createState() => _EnhancedInvoiceGenerationScreenState();
}

class _EnhancedInvoiceGenerationScreenState extends State<EnhancedInvoiceGenerationScreen> {
  final _formKey = GlobalKey<FormState>();
  final List<InvoiceItem> _items = [];
  final _supabase = Supabase.instance.client;
  bool _isGenerating = false;

  // Form controllers
  final _laborDescriptionController = TextEditingController();
  final _laborAmountController = TextEditingController();
  final _partNameController = TextEditingController();
  final _partAmountController = TextEditingController();
  final _partQuantityController = TextEditingController(text: '1');
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _addDefaultItems();
  }

  @override
  void dispose() {
    _laborDescriptionController.dispose();
    _laborAmountController.dispose();
    _partNameController.dispose();
    _partAmountController.dispose();
    _partQuantityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _addDefaultItems() {
    // No default items - mechanic will add items manually
  }

  void _addLaborItem() {
    if (_laborDescriptionController.text.isNotEmpty && 
        _laborAmountController.text.isNotEmpty) {
      final amount = double.tryParse(_laborAmountController.text);
      if (amount != null) {
        setState(() {
          _items.add(InvoiceItem(
            type: InvoiceItemType.labor,
            description: _laborDescriptionController.text,
            amount: amount,
          ));
        });
        _laborDescriptionController.clear();
        _laborAmountController.clear();
      }
    }
  }

  void _addPartItem() {
    if (_partNameController.text.isNotEmpty && 
        _partAmountController.text.isNotEmpty &&
        _partQuantityController.text.isNotEmpty) {
      final amount = double.tryParse(_partAmountController.text);
      final quantity = int.tryParse(_partQuantityController.text);
      if (amount != null && quantity != null && quantity > 0) {
        setState(() {
          _items.add(InvoiceItem(
            type: InvoiceItemType.part,
            description: _partNameController.text,
            amount: amount,
            quantity: quantity,
          ));
        });
        _partNameController.clear();
        _partAmountController.clear();
        _partQuantityController.text = '1'; // Reset to default quantity
      }
    }
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
    });
  }

  double get _subtotal {
    return _items.fold(0.0, (sum, item) => sum + item.totalAmount);
  }

  double get _total {
    return _subtotal; // Total is just the subtotal (no platform fee)
  }

  double get _mechanicNet {
    return _subtotal; // Mechanic gets the full amount
  }

  Future<void> _generateInvoice() async {
    if (!_formKey.currentState!.validate() || _items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one item to the invoice'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_isGenerating) return;

    setState(() => _isGenerating = true);

    try {
      print('🧾 Starting invoice generation for job: ${widget.jobId}');
      print('🔍 Job details: ${widget.jobDetails}');
      
      // Validate required fields
      final customerId = widget.jobDetails['customer_id'];
      final assignedMechanicId = widget.jobDetails['assigned_mechanic_id'];
      var providerId = widget.jobDetails['provider_id'];
      
      if (customerId == null) {
        throw Exception('Customer ID is required but not found');
      }
      if (assignedMechanicId == null) {
        throw Exception('Assigned mechanic ID is required but not found');
      }
      
      // Get the correct service provider ID for the current mechanic
      if (providerId == null) {
        print('🔍 Provider ID is null, fetching from service_providers table...');
        try {
          final user = _supabase.auth.currentUser;
          if (user != null) {
            final spResp = await _supabase
                .from('service_providers')
                .select('id')
                .eq('user_id', user.id)
                .limit(1)
                .maybeSingle();
                
            if (spResp != null) {
              providerId = spResp['id'];
              print('✅ Found service provider ID: $providerId');
            } else {
              print('⚠️ No service provider found, will create one');
            }
          }
        } catch (e) {
          print('❌ Error fetching service provider: $e');
        }
      }
      
      // Convert UI items to database format
      final itemsData = _items.map((item) => {
        'description': item.description,
        'quantity': item.quantity,
        'unit_price': item.amount,
        'amount': item.totalAmount,
        'type': item.type == InvoiceItemType.labor ? 'labor' : 'parts',
      }).toList();

      // Calculate totals
      final subtotal = _subtotal;
      final totalAmount = _total;
      final talyerNetAmount = subtotal;

      // Ensure we have a valid provider ID
      if (providerId == null) {
        throw Exception('Service provider ID is required but could not be determined');
      }
      
      print('🔍 Using provider ID for invoice: $providerId');

      // Send invoice using real-time service
      final success = await MechanicInvoiceRealtimeService.instance.sendInvoiceToCustomer(
        requestId: widget.jobId,
        customerId: customerId.toString(),
        mechanicId: assignedMechanicId.toString(),
        talyerOwnerId: assignedMechanicId.toString(), // Use user ID for talyer_owner_id
        providerId: providerId.toString(), // Use service provider ID for provider_id
        subtotal: subtotal,
        totalAmount: totalAmount,
        talyerNetAmount: talyerNetAmount,
        items: itemsData,
        notes: _notesController.text.trim(),
      );

      if (success && mounted) {
        HapticFeedback.heavyImpact();
        
        print('✅ Invoice sent to customer successfully');
        
        // Show success dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: Colors.red,
                  size: 32,
                ),
                const SizedBox(width: 12),
                const Text('Invoice Sent!'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Invoice for ₱${_total.toStringAsFixed(2)} has been sent to the customer in real-time!',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '� Invoice sent to customer',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text('💰 Total: ₱${totalAmount.toStringAsFixed(2)}'),
                      Text('🎯 Your Net: ₱${_mechanicNet.toStringAsFixed(2)}'),
                      const SizedBox(height: 8),
                      const Text(
                        '✅ Customer will receive real-time notification and can now pay the invoice.',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              // QR Scan Button - appears first to encourage usage
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop(); // Close dialog first
                  _scanQRCode(); // Then open QR scanner
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Scan QR to Complete'),
              ),
              const SizedBox(width: 8),
              // Regular OK button
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close dialog only
                  // Don't close the invoice screen automatically
                  // Let the mechanic decide when to go back
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } else {
        throw Exception('Failed to generate invoice');
      }
    } catch (e) {
      print('❌ Error generating invoice: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating invoice: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  // QR Code scanning for job completion
  Future<void> _scanQRCode() async {
    try {
      final mechanicId = AuthService.instance.currentUser?.id;
      if (mechanicId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Error: Mechanic ID not found'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Navigate to QR scanner with our custom widget
      final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => MechanicQRScanner(
            mechanicId: mechanicId,
            activeJob: {
              'id': widget.jobId,
              'title': widget.jobDetails['service_type'] ?? 'Service',
              'customer_name': '${widget.jobDetails['customer']?['first_name'] ?? ''} ${widget.jobDetails['customer']?['last_name'] ?? ''}'.trim(),
            },
            onJobCompleted: () {
              // This will be called when QR scan is successful
              _markJobAsCompleted();
            },
          ),
        ),
      );
      
      // If QR scanning was successful (result == true)
      if (result == true) {
        // Job completion is already handled in the onJobCompleted callback
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 8),
                  Text('🎉 Job completed successfully!'),
                ],
              ),
              backgroundColor: Colors.red[700],
            ),
          );
          
          // Navigate back to mechanic dashboard
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      }
    } catch (e) {
      print('❌ Error opening QR scanner: $e');
    }
  }

  // Mark job as completed in database
  Future<void> _markJobAsCompleted() async {
    try {
      await _supabase
          .from('service_requests')
          .update({
            'status': 'completed',
            'completed_at': DateTime.now().toIso8601String(),
          })
          .eq('id', widget.jobId);
      print('✅ Job marked as completed: ${widget.jobId}');
    } catch (e) {
      print('❌ Error marking job as completed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final customer = widget.jobDetails['customer'] ?? {};
    final customerName = '${customer['first_name'] ?? ''} ${customer['last_name'] ?? ''}'.trim();
    final vehicle = widget.jobDetails['vehicle'] ?? {};
    
    // Format vehicle info
    String vehicleInfo = 'Unknown Vehicle';
    if (vehicle.isNotEmpty) {
      final brand = vehicle['brand_name'] ?? '';
      final model = vehicle['model_name'] ?? '';
      final plate = vehicle['plate_number'] ?? '';
      vehicleInfo = '$brand $model - $plate';
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Generate Invoice'),
        backgroundColor: const Color.fromARGB(255, 176, 12, 1),
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Customer info
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Invoice for:',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            customerName.isNotEmpty ? customerName : 'Unknown Customer',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (widget.jobDetails['service_type'] != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Service: ${widget.jobDetails['service_type']}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.directions_car, size: 16, color: Colors.grey),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Vehicle: $vehicleInfo',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Add Labor Section
                    _buildSectionTitle('Add Labor Charges'),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _laborDescriptionController,
                            decoration: InputDecoration(
                              labelText: 'Labor Description',
                              hintText: 'e.g., Diagnostic, Repair work',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _laborAmountController,
                            decoration: InputDecoration(
                              labelText: 'Amount (₱)',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: _addLaborItem,
                          icon: const Icon(Icons.add_circle),
                          color: const Color.fromARGB(255, 176, 12, 1),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Add Parts Section
                    _buildSectionTitle('Add Parts/Materials'),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            controller: _partNameController,
                            decoration: InputDecoration(
                              labelText: 'Part/Material Name',
                              hintText: 'e.g., Oil filter, Brake pads',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _partQuantityController,
                            decoration: InputDecoration(
                              labelText: 'Qty',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _partAmountController,
                            decoration: InputDecoration(
                              labelText: 'Price (₱)',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: _addPartItem,
                          icon: const Icon(Icons.add_circle),
                          color: const Color.fromARGB(255, 176, 12, 1),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Invoice Items
                    if (_items.isNotEmpty) ...[
                      _buildSectionTitle('Invoice Items'),
                      const SizedBox(height: 12),
                      ..._items.asMap().entries.map((entry) {
                        final index = entry.key;
                        final item = entry.value;
                        return _buildInvoiceItem(item, index);
                      }).toList(),
                    ],

                    const SizedBox(height: 24),

                    // Notes
                    _buildSectionTitle('Additional Notes (Optional)'),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _notesController,
                      decoration: InputDecoration(
                        hintText: 'Add any additional notes for the customer...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      maxLines: 3,
                    ),

                    const SizedBox(height: 100), // Space for bottom sheet
                  ],
                ),
              ),
            ),

            // Total Summary Bottom Sheet
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    spreadRadius: 1,
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildSummaryRow('Subtotal:', '₱${_subtotal.toStringAsFixed(2)}'),
                  const Divider(),
                  _buildSummaryRow(
                    'Total for Customer:', 
                    '₱${_total.toStringAsFixed(2)}',
                    isTotal: true,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isGenerating || _items.isEmpty ? null : _generateInvoice,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromARGB(255, 176, 12, 1),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isGenerating
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Send Invoice to Customer',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Color.fromARGB(255, 176, 12, 1),
      ),
    );
  }

  Widget _buildInvoiceItem(InvoiceItem item, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: item.type == InvoiceItemType.labor ? Colors.blue : Colors.red,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              item.type == InvoiceItemType.labor ? 'LABOR' : 'PART',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.description,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (item.type == InvoiceItemType.part && item.quantity > 1)
                  Text(
                    'Qty: ${item.quantity} x ₱${item.amount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
              ],
            ),
          ),
          Text(
            '₱${item.totalAmount.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () => _removeItem(index),
            icon: const Icon(Icons.delete),
            color: Colors.red,
            iconSize: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String amount, {bool isTotal = false, bool isNet = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
              color: isNet ? Colors.red : Colors.black87,
            ),
          ),
          Text(
            amount,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: FontWeight.bold,
              color: isTotal 
                  ? const Color.fromARGB(255, 176, 12, 1)
                  : isNet 
                      ? Colors.red 
                      : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

enum InvoiceItemType { labor, part }

class InvoiceItem {
  final InvoiceItemType type;
  final String description;
  final double amount;
  final int quantity;

  InvoiceItem({
    required this.type,
    required this.description,
    required this.amount,
    this.quantity = 1,
  });

  double get totalAmount => amount * quantity;
}