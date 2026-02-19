import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/invoice.dart';
import '../services/invoice_service.dart';

class InvoiceGenerationScreen extends StatefulWidget {
  final String jobId;
  final Map<String, dynamic> jobDetails;

  const InvoiceGenerationScreen({
    super.key,
    required this.jobId,
    required this.jobDetails,
  });

  @override
  State<InvoiceGenerationScreen> createState() => _InvoiceGenerationScreenState();
}

class _InvoiceGenerationScreenState extends State<InvoiceGenerationScreen> {
  final List<InvoiceItemForm> _items = [];
  final TextEditingController _notesController = TextEditingController();
  bool _isGenerating = false;
  double _taxRate = 0.08; // 8% tax

  @override
  void initState() {
    super.initState();
    // Add initial item
    _addItem();
  }

  void _addItem() {
    setState(() {
      _items.add(InvoiceItemForm());
    });
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
    });
  }

  bool get _hasLaborItem {
    return _items.any((item) => item.selectedType == 'labor');
  }

  double get _subtotal {
    return _items.fold(0.0, (sum, item) => sum + item.total);
  }

  double get _tax {
    return _subtotal * _taxRate;
  }

  double get _total {
    return _subtotal + _tax;
  }

  Future<void> _generateInvoice() async {
    if (_items.isEmpty || _items.any((item) => !item.isValid)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all invoice items correctly'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isGenerating = true);

    try {
      final invoiceItems = _items.map((item) => InvoiceItem(
        description: item.descriptionController.text.trim(),
        quantity: int.parse(item.quantityController.text),
        unitPrice: double.parse(item.unitPriceController.text),
        total: item.total,
        type: item.selectedType,
      )).toList();

      final invoice = await InvoiceService.instance.generateInvoice(
        requestId: widget.jobId,
        items: invoiceItems,
        notes: _notesController.text.trim(),
        taxRate: _taxRate,
      );

      if (invoice != null) {
        // Send invoice immediately
        final sent = await InvoiceService.instance.sendInvoice(invoice.id);
        
        if (sent) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invoice generated and sent to customer successfully!'),
              backgroundColor: Colors.red,
            ),
          );
          Navigator.of(context).pop(true); // Return true to indicate success
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invoice generated but failed to send to customer'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        throw Exception('Failed to generate invoice');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating invoice: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 176, 12, 1),
        title: const Text(
          'Generate Invoice',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isGenerating
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color.fromARGB(255, 176, 12, 1)),
                  SizedBox(height: 16),
                  Text('Generating invoice...'),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Job Info Card
                  _JobInfoCard(jobDetails: widget.jobDetails),
                  
                  const SizedBox(height: 20),
                  
                  // Invoice Items Section
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Invoice Items',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              // Only show Add Item button if no labor item exists
                              if (!_hasLaborItem)
                                ElevatedButton.icon(
                                  onPressed: _addItem,
                                  icon: const Icon(Icons.add, size: 18),
                                  label: const Text('Add Item'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color.fromARGB(255, 176, 12, 1),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Labor info message
                          if (_hasLaborItem)
                            Container(
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.blue[200]!),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                    child: Text(
                                      'Labor service selected. Only one labor item allowed per invoice.',
                                      style: TextStyle(fontSize: 14),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          
                          // Invoice Items List
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _items.length,
                            itemBuilder: (context, index) {
                              return _InvoiceItemWidget(
                                item: _items[index],
                                index: index,
                                onRemove: (_items.length > 1 && !_hasLaborItem) ? () => _removeItem(index) : null,
                                onChanged: () => setState(() {}),
                                onTypeChanged: (newType) {
                                  setState(() {
                                    // If changing to labor, remove all other items
                                    if (newType == 'labor' && _items.length > 1) {
                                      final currentItem = _items[index];
                                      _items.clear();
                                      _items.add(currentItem);
                                    }
                                  });
                                },
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Notes Section
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Additional Notes',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _notesController,
                            maxLines: 3,
                            decoration: InputDecoration(
                              hintText: 'Add any additional notes or recommendations...',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: Color.fromARGB(255, 176, 12, 1),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Invoice Summary
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Invoice Summary',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _SummaryRow('Subtotal:', '₱${_subtotal.toStringAsFixed(2)}'),
                          _SummaryRow('Tax (${(_taxRate * 100).toStringAsFixed(0)}%):', '₱${_tax.toStringAsFixed(2)}'),
                          const Divider(),
                          _SummaryRow(
                            'Total:',
                            '₱${_total.toStringAsFixed(2)}',
                            isTotal: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 30),
                  
                  // Generate Invoice Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _generateInvoice,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromARGB(255, 176, 12, 1),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Generate & Send Invoice',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _JobInfoCard extends StatelessWidget {
  final Map<String, dynamic> jobDetails;

  const _JobInfoCard({required this.jobDetails});

  @override
  Widget build(BuildContext context) {
    final customer = jobDetails['customer'] ?? {};
    final customerName = '${customer['first_name'] ?? ''} ${customer['last_name'] ?? ''}'.trim();
    final vehicle = jobDetails['vehicle'] ?? {};
    
    // Format vehicle info
    String vehicleInfo = 'Unknown Vehicle';
    if (vehicle.isNotEmpty) {
      final brand = vehicle['brand_name'] ?? '';
      final model = vehicle['model_name'] ?? '';
      final plate = vehicle['plate_number'] ?? '';
      vehicleInfo = '$brand $model - $plate';
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Job Details',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.build, size: 18, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Service: ${jobDetails['service_type'] ?? 'Unknown'}'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.person, size: 18, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Customer: ${customerName.isNotEmpty ? customerName : 'Unknown'}'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.directions_car, size: 18, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Vehicle: $vehicleInfo'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on, size: 18, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Location: ${jobDetails['pickup_address'] ?? 'Unknown'}'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InvoiceItemWidget extends StatelessWidget {
  final InvoiceItemForm item;
  final int index;
  final VoidCallback? onRemove;
  final VoidCallback onChanged;
  final Function(String)? onTypeChanged;

  const _InvoiceItemWidget({
    required this.item,
    required this.index,
    this.onRemove,
    required this.onChanged,
    this.onTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Item ${index + 1}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (onRemove != null)
                  IconButton(
                    onPressed: onRemove,
                    icon: const Icon(Icons.delete, color: Colors.red),
                    iconSize: 20,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            
            // Type Dropdown
            DropdownButtonFormField<String>(
              value: item.selectedType,
              decoration: InputDecoration(
                labelText: 'Type',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              items: const [
                DropdownMenuItem(value: 'labor', child: Text('Labor')),
                DropdownMenuItem(value: 'parts', child: Text('Parts')),
                DropdownMenuItem(value: 'other', child: Text('Other')),
              ],
              onChanged: (value) {
                if (value != null) {
                  // Notify parent about type change
                  onTypeChanged?.call(value);
                  
                  item.selectedType = value;
                  // Auto-set quantity to 1 and description for labor
                  if (value == 'labor') {
                    item.quantityController.text = '1';
                    item.descriptionController.text = 'Labor Service';
                  }
                  onChanged();
                }
              },
            ),
            
            const SizedBox(height: 8),
            
            // For Labor: Only show Price (no description, no quantity display)
            // For Parts/Other: Show Description, Quantity and Unit Price
            if (item.selectedType == 'labor') ...[
              // Labor - only price field, very simple
              TextField(
                controller: item.unitPriceController,
                decoration: InputDecoration(
                  labelText: 'Labor Price (\$)',
                  hintText: 'Enter total labor cost',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.attach_money, color: Colors.red),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
                onChanged: (_) {
                  // Auto-set quantity to 1 for labor
                  item.quantityController.text = '1';
                  // Auto-set description for labor
                  item.descriptionController.text = 'Labor Service';
                  onChanged();
                },
              ),
              const SizedBox(height: 8),
              // Total display for labor
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[300]!),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total Labor Cost:',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    Text(
                      '₱${item.total.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold, 
                        color: Colors.red,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              // Parts/Other - show description field
              TextField(
                controller: item.descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description',
                  hintText: 'Item description',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onChanged: (_) => onChanged(),
              ),
              const SizedBox(height: 8),
              // Parts/Other - show quantity and unit price
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: item.quantityController,
                      decoration: InputDecoration(
                        labelText: 'Qty',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (_) => onChanged(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: item.unitPriceController,
                      decoration: InputDecoration(
                        labelText: 'Unit Price (\$)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                      ],
                      onChanged: (_) => onChanged(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 80,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Text(
                      '₱${item.total.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isTotal;

  const _SummaryRow(this.label, this.value, {this.isTotal = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 18 : 16,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isTotal ? 18 : 16,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isTotal ? const Color.fromARGB(255, 176, 12, 1) : null,
            ),
          ),
        ],
      ),
    );
  }
}

class InvoiceItemForm {
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController quantityController = TextEditingController(text: '1');
  final TextEditingController unitPriceController = TextEditingController();
  String selectedType = 'labor';

  InvoiceItemForm() {
    // Set up defaults for labor
    if (selectedType == 'labor') {
      quantityController.text = '1';
      descriptionController.text = 'Labor Service';
    }
  }

  double get total {
    final qty = int.tryParse(quantityController.text) ?? 0;
    final price = double.tryParse(unitPriceController.text) ?? 0.0;
    return qty * price;
  }

  bool get isValid {
    return descriptionController.text.trim().isNotEmpty &&
           quantityController.text.trim().isNotEmpty &&
           unitPriceController.text.trim().isNotEmpty &&
           int.tryParse(quantityController.text) != null &&
           double.tryParse(unitPriceController.text) != null;
  }

  void dispose() {
    descriptionController.dispose();
    quantityController.dispose();
    unitPriceController.dispose();
  }
}










