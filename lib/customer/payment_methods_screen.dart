import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/user_data_service.dart';

class PaymentMethodsScreen extends StatefulWidget {
  const PaymentMethodsScreen({super.key});

  @override
  State<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<PaymentMethodsScreen> {
  List<Map<String, dynamic>> _paymentMethods = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPaymentMethods();
  }

  Future<void> _loadPaymentMethods() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final authService = AuthService.instance;
      final userId = authService.userId;
      
      print('🔄 Loading payment methods for user: $userId');
      
      if (userId != null) {
        final paymentMethods = await UserDataService.getPaymentMethods();
        print('📋 Found ${paymentMethods.length} payment methods');
        
        setState(() {
          _paymentMethods = paymentMethods;
          _isLoading = false;
        });
        
        print('✅ Payment methods loaded successfully');
      } else {
        print('⚠️ No user ID, using empty payment methods');
        
        setState(() {
          _paymentMethods = [];
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error loading payment methods: $e');
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Unable to load payment methods. Please try again.'),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: _loadPaymentMethods,
            ),
          ),
        );
      }
    }
  }

  String _getDisplayDetails(Map<String, dynamic> method) {
    final type = method['method_type'] ?? '';
    
    switch (type.toLowerCase()) {
      case 'credit_card':
      case 'debit_card':
        final lastFour = method['card_last_four'] ?? '****';
        return '•••• •••• •••• $lastFour';
      case 'gcash':
        final number = method['gcash_number'] ?? '';
        if (number.isNotEmpty && number.length >= 4) {
          return '•••• ${number.substring(number.length - 4)}';
        }
        return 'GCash Wallet';
      case 'paymaya':
        final number = method['paymaya_number'] ?? '';
        if (number.isNotEmpty && number.length >= 4) {
          return '•••• ${number.substring(number.length - 4)}';
        }
        return 'PayMaya Wallet';
      default:
        return method['display_name'] ?? 'Payment Method';
    }
  }

  IconData _getPaymentIcon(String? type) {
    if (type == null) return Icons.payment;
    
    switch (type.toLowerCase()) {
      case 'credit_card':
      case 'debit_card':
        return Icons.credit_card;
      case 'gcash':
        return Icons.account_balance_wallet;
      case 'paymaya':
        return Icons.payment;
      default:
        return Icons.payment;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context, true),
        ),
        title: const Text(
          'Payment Methods',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.black),
            onPressed: _showAddPaymentMethod,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color.fromARGB(255, 176, 12, 1),
              ),
            )
          : _paymentMethods.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadPaymentMethods,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _paymentMethods.length,
                    itemBuilder: (context, index) {
                      final method = _paymentMethods[index];
                      return PaymentMethodCard(
                        type: method['display_name'] ?? 'Payment Method',
                        details: _getDisplayDetails(method),
                        icon: _getPaymentIcon(method['method_type']),
                        isDefault: method['is_default'] ?? false,
                        onTap: () => _showPaymentMethodOptions(method),
                        onSetDefault: () => _setDefaultPaymentMethod(method['id']),
                      );
                    },
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
            Icons.payment,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No payment methods added',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add a payment method to make payments',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showAddPaymentMethod,
            icon: const Icon(Icons.add),
            label: const Text('Add Payment Method'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromARGB(255, 176, 12, 1),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddPaymentMethod() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            
            const Text(
              'Add Payment Method',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Choose a payment method to add',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 16),
            
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.credit_card, color: Colors.blue),
              ),
              title: const Text('Credit/Debit Card'),
              subtitle: const Text('Via PayMongo - Visa, MasterCard, etc.'),
              onTap: () {
                Navigator.pop(context);
                _addPaymentMethod('credit_card');
              },
            ),
            
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.account_balance_wallet, color: Colors.red),
              ),
              title: const Text('GCash'),
              subtitle: const Text('Via PayMongo - Pay with your GCash wallet'),
              onTap: () {
                Navigator.pop(context);
                _addPaymentMethod('gcash');
              },
            ),
            
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.payment, color: Colors.orange),
              ),
              title: const Text('PayMaya'),
              subtitle: const Text('Via PayMongo - Pay with your PayMaya wallet'),
              onTap: () {
                Navigator.pop(context);
                _addPaymentMethod('paymaya');
              },
            ),
            
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showPaymentMethodOptions(Map<String, dynamic> method) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            
            Text(
              method['display_name'] ?? 'Payment Method',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            if (!(method['is_default'] ?? false))
              ListTile(
                leading: const Icon(Icons.star_outline, color: Color.fromARGB(255, 176, 12, 1)),
                title: const Text('Set as Default'),
                onTap: () {
                  Navigator.pop(context);
                  _setDefaultPaymentMethod(method['id']);
                },
              ),
            
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Remove', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _confirmDeletePaymentMethod(method);
              },
            ),
            
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _setDefaultPaymentMethod(String paymentMethodId) async {
    try {
      await UserDataService.setDefaultPaymentMethod(paymentMethodId);
      
      // Update local state
      setState(() {
        for (var method in _paymentMethods) {
          method['is_default'] = method['id'] == paymentMethodId;
        }
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Default payment method updated'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating default payment method: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _addPaymentMethod(String type) async {
    try {
      print('💳 Adding payment method of type: $type');
      
      String displayName;
      String? cardLastFour;
      String? cardBrand;
      String? gcashNumber;
      String? paymayaNumber;
      
      // Simulate adding different payment methods with dummy data
      switch (type.toLowerCase()) {
        case 'credit_card':
          displayName = 'Credit Card';
          cardLastFour = '1234';
          cardBrand = 'Visa';
          break;
        case 'debit_card':
          displayName = 'Debit Card';
          cardLastFour = '5678';
          cardBrand = 'MasterCard';
          break;
        case 'gcash':
          displayName = 'GCash';
          gcashNumber = '09123456789';
          break;
        case 'paymaya':
          displayName = 'PayMaya';
          paymayaNumber = '09987654321';
          break;
        default:
          displayName = 'Payment Method';
      }
      
      // Check if this is the first payment method (make it default)
      final isFirst = _paymentMethods.isEmpty;
      
      final newMethod = await UserDataService.addPaymentMethod(
        methodType: type,
        displayName: displayName,
        isDefault: isFirst,
        cardLastFour: cardLastFour,
        cardBrand: cardBrand,
        gcashNumber: gcashNumber,
        paymayaNumber: paymayaNumber,
      );
      
      // Add to local state
      setState(() {
        if (isFirst) {
          // If this is the first method, unset any existing defaults
          for (var method in _paymentMethods) {
            method['is_default'] = false;
          }
        }
        _paymentMethods.add(newMethod);
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$displayName added successfully'),
            backgroundColor: Colors.red,
          ),
        );
      }
      
    } catch (e) {
      print('❌ Error adding payment method: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding payment method: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _confirmDeletePaymentMethod(Map<String, dynamic> method) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Payment Method'),
        content: Text(
          'Are you sure you want to remove ${method['display_name']}?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deletePaymentMethod(method['id']);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  Future<void> _deletePaymentMethod(String paymentMethodId) async {
    try {
      await UserDataService.deletePaymentMethod(paymentMethodId);
      
      // Remove from local state
      setState(() {
        _paymentMethods.removeWhere((method) => method['id'] == paymentMethodId);
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment method removed'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error removing payment method: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class PaymentMethodCard extends StatelessWidget {
  final String type;
  final String details;
  final IconData icon;
  final bool isDefault;
  final VoidCallback onTap;
  final VoidCallback onSetDefault;

  const PaymentMethodCard({
    super.key,
    required this.type,
    required this.details,
    required this.icon,
    required this.isDefault,
    required this.onTap,
    required this.onSetDefault,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Payment method icon
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 176, 12, 1).withAlpha(26),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: const Color.fromARGB(255, 176, 12, 1),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              
              // Payment method details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            type,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        if (isDefault)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.red[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.red[200]!),
                            ),
                            child: const Text(
                              'Default',
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      details,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              
              // More options
              Icon(
                Icons.more_vert,
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }
}





















