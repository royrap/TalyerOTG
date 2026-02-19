import 'package:flutter/material.dart';
import 'dart:async';
import '../services/real_time_payment_service.dart';

class RealTimePaymentStatusWidget extends StatefulWidget {
  final String invoiceId;
  final Function(Map<String, dynamic>)? onPaymentUpdate;

  const RealTimePaymentStatusWidget({
    super.key,
    required this.invoiceId,
    this.onPaymentUpdate,
  });

  @override
  State<RealTimePaymentStatusWidget> createState() => _RealTimePaymentStatusWidgetState();
}

class _RealTimePaymentStatusWidgetState extends State<RealTimePaymentStatusWidget>
    with TickerProviderStateMixin {
  StreamSubscription? _paymentSubscription;
  Map<String, dynamic>? _currentPayment;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    
    // Initialize pulse animation for processing states
    _pulseController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    _loadInitialPaymentStatus();
    _subscribeToPaymentUpdates();
  }

  @override
  void dispose() {
    _paymentSubscription?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialPaymentStatus() async {
    try {
      final payment = await RealTimePaymentService.instance.getPaymentStatus(widget.invoiceId);
      if (mounted) {
        setState(() {
          _currentPayment = payment;
          _isLoading = false;
        });
        _updateAnimations();
      }
    } catch (e) {
      print('❌ Error loading payment status: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _subscribeToPaymentUpdates() {
    _paymentSubscription = RealTimePaymentService.instance.paymentStatusStream.listen(
      (update) {
        if (update['type'] == 'payment_update') {
          final paymentData = update['data'] as Map<String, dynamic>;
          
          // Check if this update is for our invoice
          if (paymentData['invoice_id'] == widget.invoiceId) {
            if (mounted) {
              setState(() {
                _currentPayment = paymentData;
              });
              _updateAnimations();
              
              // Notify parent widget
              if (widget.onPaymentUpdate != null) {
                widget.onPaymentUpdate!(paymentData);
              }
            }
          }
        }
      },
      onError: (error) {
        print('❌ Payment status stream error: $error');
      },
    );
  }

  void _updateAnimations() {
    if (_currentPayment != null) {
      final status = _currentPayment!['status']?.toString().toLowerCase() ?? '';
      
      if (['processing', 'validating', 'confirming'].contains(status)) {
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController.stop();
        _pulseController.reset();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Text('Loading payment status...'),
            ],
          ),
        ),
      );
    }

    if (_currentPayment == null) {
      // Don't show "No payment information" for cash payments
      // Cash payment proof is shown separately
      return const SizedBox.shrink();
    }
    
    // Only show payment status widget for online/digital payments
    final paymentMethod = _currentPayment!['payment_method']?.toString().toLowerCase() ?? '';
    if (paymentMethod == 'cash') {
      // Cash payment proof is displayed separately, no need for this widget
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _pulseAnimation.value,
                      child: _getStatusIcon(),
                    );
                  },
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getStatusTitle(),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      if (_getStatusMessage().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          _getStatusMessage(),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (_showAmount()) ...[
                  Text(
                    '₱${(_currentPayment!['amount'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color.fromARGB(255, 176, 12, 1),
                    ),
                  ),
                ],
              ],
            ),
            
            if (_showProgressBar()) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: _getProgressValue(),
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(_getProgressColor()),
              ),
              const SizedBox(height: 8),
              Text(
                _getProgressText(),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
            
            if (_showTransactionDetails()) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow('Payment Method', _currentPayment!['payment_method'] ?? 'N/A'),
                    _buildDetailRow('Transaction ID', _currentPayment!['transaction_id'] ?? 'N/A'),
                    if (_currentPayment!['created_at'] != null)
                      _buildDetailRow('Payment Date', _formatDate(_currentPayment!['created_at'])),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _getStatusIcon() {
    final status = _currentPayment!['status']?.toString().toLowerCase() ?? '';
    
    switch (status) {
      case 'processing':
      case 'validating':
      case 'confirming':
        return const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
          ),
        );
      case 'in_escrow':
        return const Icon(
          Icons.account_balance,
          color: Colors.blue,
          size: 24,
        );
      case 'released_to_provider':
        return const Icon(
          Icons.check_circle,
          color: Colors.green,
          size: 24,
        );
      case 'failed':
        return const Icon(
          Icons.error,
          color: Colors.red,
          size: 24,
        );
      default:
        return const Icon(
          Icons.payment,
          color: Colors.grey,
          size: 24,
        );
    }
  }

  String _getStatusTitle() {
    final status = _currentPayment!['status']?.toString().toLowerCase() ?? '';
    
    switch (status) {
      case 'processing':
        return 'Processing Payment';
      case 'validating':
        return 'Validating Details';
      case 'confirming':
        return 'Confirming Transaction';
      case 'in_escrow':
        return 'Payment Secured';
      case 'released_to_provider':
        return 'Payment Completed';
      case 'failed':
        return 'Payment Failed';
      default:
        return 'Payment Status';
    }
  }

  String _getStatusMessage() {
    final statusMessage = _currentPayment!['status_message']?.toString() ?? '';
    if (statusMessage.isNotEmpty) {
      return statusMessage;
    }
    
    final status = _currentPayment!['status']?.toString().toLowerCase() ?? '';
    switch (status) {
      case 'processing':
        return 'Your payment is being processed...';
      case 'validating':
        return 'Validating payment information...';
      case 'confirming':
        return 'Confirming your transaction...';
      case 'in_escrow':
        return 'Payment held securely until service completion';
      case 'released_to_provider':
        return 'Payment released to mechanic after service completion';
      case 'failed':
        return 'Payment could not be processed';
      default:
        return '';
    }
  }

  bool _showAmount() {
    final status = _currentPayment!['status']?.toString().toLowerCase() ?? '';
    return !['processing', 'validating', 'confirming'].contains(status);
  }

  bool _showProgressBar() {
    final status = _currentPayment!['status']?.toString().toLowerCase() ?? '';
    return ['processing', 'validating', 'confirming'].contains(status);
  }

  double _getProgressValue() {
    final status = _currentPayment!['status']?.toString().toLowerCase() ?? '';
    switch (status) {
      case 'processing':
        return 0.33;
      case 'validating':
        return 0.66;
      case 'confirming':
        return 0.9;
      default:
        return 1.0;
    }
  }

  Color _getProgressColor() {
    final status = _currentPayment!['status']?.toString().toLowerCase() ?? '';
    switch (status) {
      case 'processing':
      case 'validating':
      case 'confirming':
        return Colors.orange;
      case 'in_escrow':
        return Colors.blue;
      case 'released_to_provider':
        return Colors.green;
      case 'failed':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getProgressText() {
    final status = _currentPayment!['status']?.toString().toLowerCase() ?? '';
    switch (status) {
      case 'processing':
        return 'Step 1 of 3: Processing payment...';
      case 'validating':
        return 'Step 2 of 3: Validating details...';
      case 'confirming':
        return 'Step 3 of 3: Confirming transaction...';
      default:
        return 'Payment processing complete';
    }
  }

  bool _showTransactionDetails() {
    final status = _currentPayment!['status']?.toString().toLowerCase() ?? '';
    return ['in_escrow', 'released_to_provider'].contains(status);
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateString;
    }
  }
}










