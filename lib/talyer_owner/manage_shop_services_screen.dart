import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 🛠️ Manage Shop Services Screen
/// Allows shop owners to view, add, edit, and manage their shop's services
class ManageShopServicesScreen extends StatefulWidget {
  final String shopId;

  const ManageShopServicesScreen({Key? key, required this.shopId}) : super(key: key);

  @override
  State<ManageShopServicesScreen> createState() => _ManageShopServicesScreenState();
}

class _ManageShopServicesScreenState extends State<ManageShopServicesScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  
  List<Map<String, dynamic>> _services = [];
  bool _isLoading = true;
  String? _error;

  // Search/filter text
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadServices();
  }

  Future<void> _loadServices() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await _supabase
          .from('shop_services')
          .select('*')
          .eq('shop_id', widget.shopId)
          .order('created_at', ascending: false);

      setState(() {
        _services = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredServices {
    if (_searchQuery.isEmpty) {
      return _services;
    }
    return _services.where((service) {
      final serviceName = service['service_name']?.toString().toLowerCase() ?? '';
      final description = service['description']?.toString().toLowerCase() ?? '';
      final query = _searchQuery.toLowerCase();
      return serviceName.contains(query) || description.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Services'),
        backgroundColor: Colors.red,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadServices,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorState()
              : Column(
                  children: [
                    _buildCategoryFilter(),
                    Expanded(
                      child: _filteredServices.isEmpty
                          ? _buildEmptyState()
                          : _buildServicesList(),
                    ),
                  ],
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddServiceDialog(),
        backgroundColor: Colors.red,
        icon: const Icon(Icons.add),
        label: const Text('Add Service'),
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: TextField(
        decoration: InputDecoration(
          hintText: 'Search services...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          filled: true,
          fillColor: Colors.grey[50],
        ),
        onChanged: (value) {
          setState(() => _searchQuery = value);
        },
      ),
    );
  }

  Widget _buildServicesList() {
    return RefreshIndicator(
      onRefresh: _loadServices,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _filteredServices.length,
        itemBuilder: (context, index) {
          final service = _filteredServices[index];
          return _buildServiceCard(service);
        },
      ),
    );
  }

  Widget _buildServiceCard(Map<String, dynamic> service) {
    final price = service['base_price'];
    final serviceName = service['service_name'] ?? 'Unnamed Service';
    final description = service['description'];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Colors.grey.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () => _showEditServiceDialog(service),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Service Icon
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.build_circle,
                      color: Colors.red,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  
                  // Service Name
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          serviceName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Price badge
                        if (price != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.green.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              '₱${price.toString()}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.green[700],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  
                  // Action buttons
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, size: 22),
                        onPressed: () => _showEditServiceDialog(service),
                        color: Colors.blue,
                        tooltip: 'Edit',
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, size: 22),
                        onPressed: () => _confirmDeleteService(service),
                        color: Colors.red,
                        tooltip: 'Delete',
                      ),
                    ],
                  ),
                ],
              ),
              
              // Description
              if (description != null && description.toString().isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.grey.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.description,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          description,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.build_circle_outlined,
            size: 100,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty
                ? 'No services match "$_searchQuery"'
                : 'No services added yet',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty
                ? 'Try a different search term'
                : 'Tap the + button below to add your first service',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 80, color: Colors.red[300]),
            const SizedBox(height: 16),
            const Text(
              'Error Loading Services',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Unknown error',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadServices,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddServiceDialog() {
    _showServiceDialog(null);
  }

  void _showEditServiceDialog(Map<String, dynamic> service) {
    _showServiceDialog(service);
  }

  void _showServiceDialog(Map<String, dynamic>? existingService) {
    final isEdit = existingService != null;
    final formKey = GlobalKey<FormState>();
    
    final nameController = TextEditingController(text: existingService?['service_name']);
    final descriptionController = TextEditingController(text: existingService?['description']);
    final priceController = TextEditingController(
      text: existingService?['base_price']?.toString() ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEdit ? 'Edit Service' : 'Add New Service'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info text
                Text(
                  'Add your custom service with just the basics:',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Service Name (Required)
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Service Name *',
                    hintText: 'e.g., Oil Change, Brake Repair',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.build),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Service name is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                // Description (Optional)
                TextFormField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'Brief description of what you offer',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.description),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                
                // Price (Required)
                TextFormField(
                  controller: priceController,
                  decoration: const InputDecoration(
                    labelText: 'Price (₱) *',
                    hintText: 'Enter your service price',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.attach_money),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Price is required';
                    }
                    final price = double.tryParse(value);
                    if (price == null || price < 0) {
                      return 'Enter a valid price';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                
                // Helper text
                Text(
                  '* Required fields',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context);
                
                final serviceData = {
                  'shop_id': widget.shopId,
                  'service_name': nameController.text.trim(),
                  'description': descriptionController.text.trim().isEmpty 
                      ? null 
                      : descriptionController.text.trim(),
                  'base_price': double.parse(priceController.text),
                  'is_active': true,
                  'is_custom': true, // Mark as custom service
                  'updated_at': DateTime.now().toIso8601String(),
                };

                if (isEdit) {
                  await _updateService(existingService['id'], serviceData);
                } else {
                  serviceData['created_at'] = DateTime.now().toIso8601String();
                  await _addService(serviceData);
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(isEdit ? 'Update' : 'Add Service'),
          ),
        ],
      ),
    );
  }

  Future<void> _addService(Map<String, dynamic> serviceData) async {
    try {
      await _supabase.from('shop_services').insert(serviceData);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Service added successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
      
      await _loadServices();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding service: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updateService(String serviceId, Map<String, dynamic> serviceData) async {
    try {
      await _supabase
          .from('shop_services')
          .update(serviceData)
          .eq('id', serviceId);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Service updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
      
      await _loadServices();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating service: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _confirmDeleteService(Map<String, dynamic> service) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Service'),
        content: Text(
          'Are you sure you want to delete "${service['service_name']}"?\n\n'
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteService(service['id']);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteService(String serviceId) async {
    try {
      await _supabase
          .from('shop_services')
          .delete()
          .eq('id', serviceId);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Service deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
      
      await _loadServices();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting service: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

}
