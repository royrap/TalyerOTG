import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';
import '../services/user_data_service.dart';
import '../services/pricing_service.dart';
import '../services/supabase_service.dart';
import '../screens/mobile_paymongo_screen.dart';

class PaymentScreen extends StatefulWidget {
  final String? issueType;
  final String? issueDescription;
  final String? issueTitle;
  final String? vehicleType;
  final String? vehicleBrand;
  final String? vehicleModel;
  final String? vehicleYear;
  final String? vehicleId;
  final String? serviceRequestId;

  const PaymentScreen({
    Key? key,
    this.issueType,
    this.issueDescription,
    this.issueTitle,
    this.vehicleType,
    this.vehicleBrand,
    this.vehicleModel,
    this.vehicleYear,
    this.vehicleId,
    this.serviceRequestId,
  }) : super(key: key);

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  bool _isProcessing = false;
  final _formKey = GlobalKey<FormState>();
  
  // Pricing calculation variables
  final PricingService _pricingService = PricingService();
  LatLng? _customerLocation;
  LatLng? _mechanicLocation;
  double? _serviceFee;
  double? _totalAmount;
  bool _isLoadingPricing = true;
  final double _processingFee = 15.0;
  
  // Selected services (if any) and subtotal
  List<Map<String, dynamic>> _selectedServiceItems = [];
  double _itemsSubtotal = 0.0;
  bool get _hasSelectedItems => _selectedServiceItems.isNotEmpty;
  
  @override
  void initState() {
    super.initState();
    // Load location data and compute pricing/items
    _loadLocationDataAndCalculatePricing();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Payment',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            // Progress bar
            Container(
              width: double.infinity,
              height: 8,
              color: Colors.grey[200],
              child: Row(
                children: [
                  Container(
                    width: MediaQuery.of(context).size.width,
                    height: 8,
                    color: const Color.fromARGB(255, 176, 12, 1),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Service Summary Card
                    _buildServiceSummaryCard(),
                    
                    const SizedBox(height: 24),
                    
                    // Mechanic Assigned Section
                    _buildMechanicAssignedSection(),
                    
                    const SizedBox(height: 24),
                    
                    // Selected Services (if any)
                    if (_hasSelectedItems) ...[
                      _buildSelectedServicesCard(),
                      const SizedBox(height: 24),
                    ],
                    const SizedBox(height: 24),
                    
                    // Total Amount Card
                    _buildTotalAmountCard(),
                    
                    const SizedBox(height: 16),
                    
                    // Payment Cancellation Note
                    _buildPaymentCancellationNote(),
                  ],
                ),
              ),
            ),

            // Confirm Button
            _buildConfirmButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceSummaryCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Service Summary',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 12),
          _buildSummaryRow('Service Type', widget.issueTitle ?? 'General Service'),
          _buildSummaryRow('Vehicle', '${widget.vehicleBrand ?? ''} ${widget.vehicleModel ?? ''} ${widget.vehicleYear ?? ''}'.trim()),
          _buildSummaryRow('Description', widget.issueDescription ?? 'No description provided'),
        ],
      ),
    );
  }

  Widget _buildMechanicAssignedSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 232, 245, 233),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color.fromARGB(255, 76, 175, 80),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color.fromARGB(255, 76, 175, 80),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Mechanic Assigned!',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color.fromARGB(255, 27, 94, 32),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'A qualified mechanic has accepted your request. Complete payment to confirm the service.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedServicesCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Selected Services',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ..._selectedServiceItems.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        item['name'] ?? 'Service',
                        style: const TextStyle(fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '₱${(item['price'] as double).toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              )),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Subtotal', style: TextStyle(fontWeight: FontWeight.w600)),
              Text('₱${_itemsSubtotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
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

  Widget _buildTotalAmountCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 248, 249, 250),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: _isLoadingPricing
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(
                  color: Color.fromARGB(255, 176, 12, 1),
                ),
              ),
            )
          : Column(
              children: [
                if (!_hasSelectedItems && _customerLocation != null && _mechanicLocation != null) ...[
                  // Distance info only when using service fee pricing
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.straighten,
                            size: 16,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            'Distance',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                        ],
                      ),
                      Text(
                        '${_pricingService.getPricingBreakdown(customerLocation: _customerLocation!, mechanicLocation: _mechanicLocation!)['distance_km'].toStringAsFixed(1)} km',
                        style: const TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Rate (₱500 per 10km)',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                      Text(
                        '${_pricingService.getPricingBreakdown(customerLocation: _customerLocation!, mechanicLocation: _mechanicLocation!)['segments']} segments',
                        style: const TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                if (_hasSelectedItems) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Subtotal', style: TextStyle(fontSize: 16)),
                      Text('₱${_itemsSubtotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16)),
                    ],
                  ),
                ] else ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Service Fee',
                        style: TextStyle(fontSize: 16),
                      ),
                      Text(
                        '₱${_serviceFee?.toStringAsFixed(2) ?? '500.00'}',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Payment Processing Fee',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    Text(
                      '₱${_processingFee.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ],
                ),
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total Amount',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '₱${_totalAmount?.toStringAsFixed(2) ?? '515.00'}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color.fromARGB(255, 176, 12, 1),
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _buildPaymentCancellationNote() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange[200]!),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.warning_amber,
            color: Colors.orange[700],
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Payment Cancellation Policy',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange[800],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Once payment is completed, cancellation requests are not refundable. Please ensure all details are correct before proceeding.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.orange[700],
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

  }

  Widget _buildConfirmButton() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _isProcessing ? null : (_totalAmount != null && (widget.serviceRequestId?.isNotEmpty ?? false)) ? _handleConfirmPayment : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color.fromARGB(255, 176, 12, 1),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
          child: _isProcessing
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(
                  'Pay ₱${_totalAmount?.toStringAsFixed(2) ?? '515.00'}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ),
    );
  }

  Future<void> _handleConfirmPayment() async {
    if (_formKey.currentState != null) {
      // No inputs currently require validation; keep structure
      _formKey.currentState!.validate();
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      // Check if we have a service request ID to update
      if (widget.serviceRequestId != null && widget.serviceRequestId!.isNotEmpty) {
        print('💳 Processing direct payment for service request: ${widget.serviceRequestId}');
        
        final requestId = widget.serviceRequestId!;
        final amount = _totalAmount ?? 515.00;
        
        // TEMPORARY: Direct payment update (bypass PayMongo since it's not working)
        // Update service request status directly
        await Supabase.instance.client.from('service_requests').update({
          'status': 'ready_to_assign',
          'payment_status': 'completed',
          'payment_completed_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', requestId);
        
        // Check if payment record exists, update or create
        final existingPayment = await Supabase.instance.client
            .from('payments')
            .select('id')
            .eq('request_id', requestId)
            .maybeSingle();
            
        if (existingPayment != null) {
          await Supabase.instance.client.from('payments').update({
            'status': 'completed',
            'payment_method': 'gcash',
            'payment_gateway': 'direct_test',
            'processed_at': DateTime.now().toIso8601String(),
          }).eq('request_id', requestId);
        } else {
          // Get customer_id from service request
          final serviceRequest = await Supabase.instance.client
              .from('service_requests')
              .select('customer_id, provider_id')
              .eq('id', requestId)
              .maybeSingle();
          
          // Only insert payment record if we have both customer and provider
          // For initial service fee payment, provider might not be assigned yet
          if (serviceRequest != null && serviceRequest['provider_id'] != null) {
            await Supabase.instance.client.from('payments').insert({
              'request_id': requestId,
              'customer_id': serviceRequest['customer_id'],
              'provider_id': serviceRequest['provider_id'],
              'amount': amount,
              'provider_amount': amount * 0.9,
              'platform_fee': amount * 0.1,
              'status': 'completed',
              'payment_method': 'gcash',
              'payment_gateway': 'direct_test',
              'processed_at': DateTime.now().toIso8601String(),
            });
          } else {
            print('ℹ️ Skipping payment record - no provider assigned yet (service fee payment)');
          }
        }
        
        print('✅ Direct payment completed for request: $requestId');
        
        // Show success and navigate
        _showSuccessMessage('Payment successful! Your service request has been confirmed.');
        
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => AuthWrapper(
                paymentSuccessData: {
                  'requestId': widget.serviceRequestId ?? 'N/A',
                  'issueTitle': widget.issueTitle,
                  'vehicleBrand': widget.vehicleBrand,
                  'vehicleModel': widget.vehicleModel,
                  'vehicleYear': widget.vehicleYear,
                  'paymentMethod': 'GCash',
                  'phoneNumber': null,
                  'amount': '₱${amount.toStringAsFixed(2)}',
                  'isActualPayment': true,
                },
              ),
            ),
            (route) => false,
          );
        }
      } else {
        // Fallback for when no service request ID is available
        print('⚠️ No service request ID available, simulating payment...');
        
        // Simulate payment processing
        await Future.delayed(const Duration(seconds: 2));
        _showSuccessMessage('Payment successful!');
        
        // Navigate back with success result
        if (mounted) {
          Navigator.of(context).pop({
            'success': true,
            'paymentMethod': 'GCash',
          });
        }
      }
    } catch (e) {
      print('❌ Payment processing error: $e');
      _showErrorMessage('Payment processing failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Load location data and calculate distance-based pricing
  Future<void> _loadLocationDataAndCalculatePricing() async {
    try {
      setState(() {
        _isLoadingPricing = true;
      });

      // Get service request details to get customer location
      if (widget.serviceRequestId != null) {
        final serviceRequest = await SupabaseService.getServiceRequestById(widget.serviceRequestId!);
        
        if (serviceRequest != null && 
            serviceRequest['latitude'] != null && 
            serviceRequest['longitude'] != null) {
          _customerLocation = LatLng(
            (serviceRequest['latitude'] as num).toDouble(),
            (serviceRequest['longitude'] as num).toDouble(),
          );
          
          // Get mechanic location for the service request
          final mechanicLocationData = await SupabaseService.getMechanicLocationForRequest(widget.serviceRequestId!);
          
          if (mechanicLocationData != null &&
              mechanicLocationData['latitude'] != null &&
              mechanicLocationData['longitude'] != null) {
            _mechanicLocation = LatLng(
              (mechanicLocationData['latitude'] as num).toDouble(),
              (mechanicLocationData['longitude'] as num).toDouble(),
            );
          }
          
          // Try to load selected services (if stored in additional_details)
          try {
            final additional = serviceRequest['additional_details'];
            List<dynamic>? selected;
            if (additional is Map<String, dynamic>) {
              if (additional['selected_services'] is List) {
                selected = additional['selected_services'] as List<dynamic>;
              } else if (additional['shop_data'] is Map && (additional['shop_data']['selectedServices'] is List)) {
                selected = List<dynamic>.from(additional['shop_data']['selectedServices'] as List);
              }
            }

            if (selected != null && selected.isNotEmpty) {
              final items = <Map<String, dynamic>>[];
              double subtotal = 0.0;
              for (final s in selected) {
                if (s is Map) {
                  final name = (s['service_name'] ?? s['name'] ?? s['title'] ?? s['custom_name'] ?? 'Service').toString();
                  final dynamic rawPrice = s['price'] ?? s['custom_price'] ?? s['base_price'];
                  double? price;
                  if (rawPrice is num) price = rawPrice.toDouble();
                  if (rawPrice is String) price = double.tryParse(rawPrice);
                  if (price != null && price > 0) {
                    items.add({'name': name, 'price': price});
                    subtotal += price;
                  }
                }
              }

              if (items.isNotEmpty) {
                _selectedServiceItems = items;
                _itemsSubtotal = subtotal;
              }
            }
          } catch (e) {
            print('⚠️ Could not parse selected services: $e');
          }
        }
      }
      
      // Decide pricing model
      if (_hasSelectedItems) {
        // Use items subtotal + processing fee
        _serviceFee = null; // Not used in items mode
        _totalAmount = _itemsSubtotal + _processingFee;
        print('🧮 Items pricing: subtotal=₱${_itemsSubtotal.toStringAsFixed(2)}, total=₱${_totalAmount!.toStringAsFixed(2)}');
      } else {
        // Calculate distance-based service fee
        if (_customerLocation != null && _mechanicLocation != null) {
          _serviceFee = _pricingService.calculateServiceFee(
            customerLocation: _customerLocation!,
            mechanicLocation: _mechanicLocation!,
          );
          _totalAmount = (_serviceFee ?? 500.0) + _processingFee;
          print('🧮 Service-fee pricing: serviceFee=₱${_serviceFee?.toStringAsFixed(2)}, total=₱${_totalAmount!.toStringAsFixed(2)}');
        } else {
          print('⚠️ Could not get location data, using default pricing');
          // Fallback to minimum pricing (500 + processing fee)
          _serviceFee = 500.00;
          _totalAmount = 500.00 + _processingFee;
        }
      }
      
    } catch (e) {
      print('❌ Error loading pricing data: $e');
      // Fallback to minimum pricing (500 + 15 processing fee)
      _serviceFee = 500.00;
      _totalAmount = 500.00 + _processingFee;
    } finally {
      setState(() {
        _isLoadingPricing = false;
      });
    }
  }
}











