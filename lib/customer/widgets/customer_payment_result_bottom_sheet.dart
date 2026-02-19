import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../services/supabase_service.dart';

class CustomerPaymentResultBottomSheet extends StatefulWidget {
  final Map<String, dynamic> paymentData;
  final VoidCallback? onClose;

  const CustomerPaymentResultBottomSheet({
    Key? key,
    required this.paymentData,
    this.onClose,
  }) : super(key: key);

  @override
  State<CustomerPaymentResultBottomSheet> createState() => _CustomerPaymentResultBottomSheetState();
}

class _CustomerPaymentResultBottomSheetState extends State<CustomerPaymentResultBottomSheet>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late Animation<double> _slideAnimation;
  bool _isExpanded = false;
  String? _mechanicName;
  String? _mechanicPhone;
  LatLng? _mechanicLocation;
  String _serviceStatus = 'Payment Completed';
  bool _isLoadingMechanicInfo = true;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeInOut,
    ));
    
    // Start the slide animation
    _slideController.forward();
    
    // Load mechanic information
    _loadMechanicInfo();
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _loadMechanicInfo() async {
    try {
      final requestId = widget.paymentData['requestId'];
      if (requestId == null) return;

      // Get service request to find assigned mechanic
      final serviceRequest = await SupabaseService.getServiceRequestById(requestId);
      if (serviceRequest != null && serviceRequest['assigned_mechanic_id'] != null) {
        final mechanicId = serviceRequest['assigned_mechanic_id'];
        
        // Get mechanic profile
        final mechanicProfile = await SupabaseService.client
            .from('user_profiles')
            .select('first_name, last_name, phone_number, current_latitude, current_longitude')
            .eq('id', mechanicId)
            .maybeSingle();

        if (mechanicProfile != null && mounted) {
          setState(() {
            _mechanicName = '${mechanicProfile['first_name']} ${mechanicProfile['last_name']}';
            _mechanicPhone = mechanicProfile['phone_number'];
            
            if (mechanicProfile['current_latitude'] != null && 
                mechanicProfile['current_longitude'] != null) {
              _mechanicLocation = LatLng(
                (mechanicProfile['current_latitude'] as num).toDouble(),
                (mechanicProfile['current_longitude'] as num).toDouble(),
              );
            }
            
            _serviceStatus = 'Mechanic Assigned - Payment Complete';
            _isLoadingMechanicInfo = false;
          });
        }
      }
    } catch (e) {
      print('❌ Error loading mechanic info: $e');
      if (mounted) {
        setState(() {
          _isLoadingMechanicInfo = false;
        });
      }
    }
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }

  void _navigateToFullTracking() {
    // TODO: Navigate to actual tracking screen when implemented
    // For now, just show a message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Full tracking screen not yet implemented'),
        backgroundColor: Colors.blue,
      ),
    );
    
    /* When tracking screen is implemented, use this:
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CustomerServiceRequestStatusScreenRealTime(
          serviceRequestId: widget.paymentData['requestId'],
        ),
      ),
    );
    */
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation.drive(
        Tween<Offset>(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ),
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 10,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // Header
            GestureDetector(
              onTap: _toggleExpanded,
              child: Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Success icon
                    Container(
                      width: 50,
                      height: 50,
                      decoration: const BoxDecoration(
                        color: Color.fromARGB(255, 76, 175, 80),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    
                    // Payment info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '🎉 Payment Successful!',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color.fromARGB(255, 27, 94, 32),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _serviceStatus,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Amount: ${widget.paymentData['amount'] ?? 'N/A'}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color.fromARGB(255, 176, 12, 1),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Close button
                    IconButton(
                      onPressed: () {
                        if (widget.onClose != null) {
                          widget.onClose!();
                        }
                      },
                      icon: const Icon(Icons.close, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
            
            // Expandable content
            if (_isExpanded) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Service details
                    _buildServiceDetails(),
                    const SizedBox(height: 20),
                    
                    // Mechanic info
                    _buildMechanicInfo(),
                    const SizedBox(height: 20),
                    
                    // Action buttons
                    _buildActionButtons(),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildServiceDetails() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Service Details',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _buildDetailRow('Service:', widget.paymentData['issueTitle'] ?? 'General Service'),
          _buildDetailRow('Vehicle:', '${widget.paymentData['vehicleBrand'] ?? ''} ${widget.paymentData['vehicleModel'] ?? ''} ${widget.paymentData['vehicleYear'] ?? ''}'.trim()),
          _buildDetailRow('Payment Method:', widget.paymentData['paymentMethod'] ?? 'GCash'),
          if (widget.paymentData['phoneNumber'] != null)
            _buildDetailRow('Phone:', widget.paymentData['phoneNumber']),
        ],
      ),
    );
  }

  Widget _buildMechanicInfo() {
    if (_isLoadingMechanicInfo) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.blue[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue[200]!),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text('Loading mechanic information...'),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Assigned Mechanic',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          if (_mechanicName != null) ...[
            _buildDetailRow('Name:', _mechanicName!),
            if (_mechanicPhone != null)
              _buildDetailRow('Phone:', _mechanicPhone!),
            _buildDetailRow('Status:', 'Ready to serve'),
          ] else ...[
            const Text(
              'Searching for available mechanic...',
              style: TextStyle(
                fontSize: 14,
                fontStyle: FontStyle.italic,
                color: Colors.grey,
              ),
            ),
          ],
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
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
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

  Widget _buildActionButtons() {
    return Column(
      children: [
        // Track Service button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _navigateToFullTracking,
            icon: const Icon(Icons.location_on),
            label: const Text('Track Service'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromARGB(255, 176, 12, 1),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        
        // Contact Mechanic button (if available)
        if (_mechanicPhone != null)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                // Add phone call functionality here
                print('📞 Calling mechanic: $_mechanicPhone');
                // You can use url_launcher to make a phone call
                // launch('tel:$_mechanicPhone');
              },
              icon: const Icon(Icons.phone),
              label: const Text('Contact Mechanic'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color.fromARGB(255, 176, 12, 1),
                side: const BorderSide(color: Color.fromARGB(255, 176, 12, 1)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
      ],
    );
  }
}










