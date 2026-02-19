import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:url_launcher/url_launcher.dart';
import '../services/mechanic_service.dart';
import 'qr_completion_scanner.dart';
import 'enhanced_invoice_generation_screen.dart';

class EnhancedJobDetailsScreen extends StatefulWidget {
  final String jobId;

  const EnhancedJobDetailsScreen({
    Key? key,
    required this.jobId,
  }) : super(key: key);

  @override
  State<EnhancedJobDetailsScreen> createState() => _EnhancedJobDetailsScreenState();
}

class _EnhancedJobDetailsScreenState extends State<EnhancedJobDetailsScreen> {
  Map<String, dynamic>? _jobDetails;
  bool _isLoading = true;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _loadJobDetails();
  }

  Future<void> _loadJobDetails() async {
    try {
      final details = await MechanicService.instance.getJobDetails(widget.jobId);
      if (mounted) {
        setState(() {
          _jobDetails = details;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading job details: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updateJobStatus(String newStatus) async {
    if (_isUpdating) return;

    setState(() => _isUpdating = true);

    try {
      final success = await MechanicService.instance.updateJobStatus(widget.jobId, newStatus);
      
      if (success) {
        await _loadJobDetails(); // Refresh data
        
        String message = '';
        switch (newStatus) {
          case 'in_progress':
            message = 'Job marked as in progress';
            break;
          case 'inspection_completed':
            message = 'Inspection completed';
            break;
          case 'completed':
            message = 'Job completed successfully';
            break;
          default:
            message = 'Status updated';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
          ),
        );
      } else {
        throw Exception('Failed to update status');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating status: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }

  Future<void> _openNavigation() async {
    if (_jobDetails == null) return;

    final lat = _jobDetails!['pickup_latitude'];
    final lng = _jobDetails!['pickup_longitude'];

    if (lat != null && lng != null) {
      try {
        // Use Google Maps URL scheme
        final url = 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng';
        if (await canLaunch(url)) {
          await launch(url);
        } else {
          throw Exception('Could not launch maps');
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open navigation'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _callCustomer() async {
    final customer = _jobDetails?['customer'];
    final phoneNumber = customer?['phone_number'];
    
    if (phoneNumber == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Phone number not available'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    try {
      // Clean the phone number (remove spaces, dashes, etc.)
      final cleanPhone = phoneNumber.toString().replaceAll(RegExp(r'[^\d+]'), '');
      
      print('📞 Attempting to call customer: $cleanPhone');
      print('📞 Original phone: $phoneNumber');
      
      bool launched = false;
      
      // Strategy 1: Try direct tel: URIs with multiple formats
      final telUris = [
        'tel:$cleanPhone',
        'tel:+63${cleanPhone.startsWith('0') ? cleanPhone.substring(1) : cleanPhone}',
        'tel://$cleanPhone',
        'tel:$phoneNumber',
      ];
      
      for (final telUri in telUris) {
        print('📞 Trying call URI: $telUri');
        try {
          final uri = Uri.parse(telUri);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
            launched = true;
            print('✅ Phone call launched successfully with: $uri');
            break;
          }
        } catch (e) {
          print('❌ Failed with call URI: $telUri - Error: $e');
        }
      }
      
      // Strategy 2: Try Android intent approach (for better compatibility)
      if (!launched && Platform.isAndroid) {
        print('🤖 Trying Android intent approach...');
        try {
          final intentUri = Uri.parse('intent://tel:$cleanPhone#Intent;scheme=tel;action=android.intent.action.DIAL;end');
          await launchUrl(intentUri, mode: LaunchMode.externalApplication);
          launched = true;
          print('✅ Android dialer intent launched successfully');
        } catch (e) {
          print('❌ Android intent failed: $e');
          try {
            final dialUri = Uri.parse('tel:$cleanPhone');
            await launchUrl(dialUri, mode: LaunchMode.platformDefault);
            launched = true;
            print('✅ Simple dialer launched successfully');
          } catch (e2) {
            print('❌ Simple dialer also failed: $e2');
          }
        }
      }
      
      // Strategy 3: Final fallback
      if (!launched) {
        print('📱 Trying final fallback strategies...');
        for (final phone in [cleanPhone, '+63${cleanPhone.startsWith('0') ? cleanPhone.substring(1) : cleanPhone}']) {
          try {
            final dialUri = Uri.parse('tel:$phone');
            await launchUrl(dialUri, mode: LaunchMode.platformDefault);
            launched = true;
            print('✅ Fallback dialer opened successfully with: $dialUri');
            break;
          } catch (e) {
            print('❌ Failed with fallback dialer: tel:$phone - Error: $e');
          }
        }
      }
      
      if (!launched) {
        print('❌ All phone launch strategies failed');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not launch phone dialer for $cleanPhone.\n\nPlease dial manually:\n$phoneNumber'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    } catch (e) {
      print('❌ Phone call error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error making phone call: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _generateInvoice() {
    if (_jobDetails == null) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => EnhancedInvoiceGenerationScreen(
          jobId: widget.jobId,
          jobDetails: _jobDetails!,
        ),
      ),
    );
  }

  void _scanQRForCompletion() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => QRCompletionScanner(
          jobId: widget.jobId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Job Details'),
          backgroundColor: const Color.fromARGB(255, 176, 12, 1),
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: CircularProgressIndicator(
            color: Color.fromARGB(255, 176, 12, 1),
          ),
        ),
      );
    }

    if (_jobDetails == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Job Details'),
          backgroundColor: const Color.fromARGB(255, 176, 12, 1),
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Text(
            'Job not found',
            style: TextStyle(fontSize: 18),
          ),
        ),
      );
    }

    final status = _jobDetails!['status'] ?? 'unknown';
    final customer = _jobDetails!['customer'];
    final vehicle = _jobDetails!['vehicle'];
    final customerName = customer != null 
        ? '${customer['first_name']} ${customer['last_name']}'
        : 'Unknown Customer';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Job Details'),
        backgroundColor: const Color.fromARGB(255, 176, 12, 1),
        foregroundColor: Colors.white,
        actions: [
          if (status == 'completed')
            IconButton(
              icon: const Icon(Icons.qr_code_scanner),
              onPressed: _scanQRForCompletion,
              tooltip: 'Scan QR for completion',
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadJobDetails,
        color: const Color.fromARGB(255, 176, 12, 1),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _getStatusColor(status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _getStatusColor(status),
                    width: 2,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      _getStatusIcon(status),
                      color: _getStatusColor(status),
                      size: 32,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _getStatusText(status),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _getStatusColor(status),
                      ),
                    ),
                    if (_jobDetails!['service_type'] != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _jobDetails!['service_type'],
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Customer Information
              _SectionCard(
                title: 'Customer Information',
                icon: Icons.person,
                children: [
                  _InfoRow(
                    label: 'Name',
                    value: customerName,
                    icon: Icons.person_outline,
                  ),
                  if (customer?['phone_number'] != null) ...[
                    const SizedBox(height: 12),
                    _InfoRow(
                      label: 'Phone',
                      value: customer['phone_number'],
                      icon: Icons.phone,
                      actionIcon: Icons.call,
                      onActionTap: _callCustomer,
                    ),
                  ],
                  if (customer?['email'] != null) ...[
                    const SizedBox(height: 12),
                    _InfoRow(
                      label: 'Email',
                      value: customer['email'],
                      icon: Icons.email,
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 16),

              // Vehicle Information
              if (vehicle != null)
                _SectionCard(
                  title: 'Vehicle Information',
                  icon: Icons.directions_car,
                  children: [
                    _InfoRow(
                      label: 'Vehicle',
                      value: '${vehicle['brand_name']} ${vehicle['model_name']} (${vehicle['year']})',
                      icon: Icons.directions_car_outlined,
                    ),
                    if (vehicle['color'] != null) ...[
                      const SizedBox(height: 12),
                      _InfoRow(
                        label: 'Color',
                        value: vehicle['color'],
                        icon: Icons.palette_outlined,
                      ),
                    ],
                    if (vehicle['plate_number'] != null) ...[
                      const SizedBox(height: 12),
                      _InfoRow(
                        label: 'Plate Number',
                        value: vehicle['plate_number'],
                        icon: Icons.confirmation_number_outlined,
                      ),
                    ],
                  ],
                ),

              const SizedBox(height: 16),

              // Location Information
              _SectionCard(
                title: 'Location Details',
                icon: Icons.location_on,
                children: [
                  _InfoRow(
                    label: 'Address',
                    value: _jobDetails!['pickup_address'] ?? 'Unknown location',
                    icon: Icons.location_on_outlined,
                    actionIcon: Icons.navigation,
                    onActionTap: _openNavigation,
                  ),
                  if (_jobDetails!['distance_km'] != null) ...[
                    const SizedBox(height: 12),
                    _InfoRow(
                      label: 'Distance',
                      value: '${_jobDetails!['distance_km'].toStringAsFixed(1)} km',
                      icon: Icons.route,
                    ),
                  ],
                  if (_jobDetails!['estimated_arrival_minutes'] != null) ...[
                    const SizedBox(height: 12),
                    _InfoRow(
                      label: 'Est. Arrival',
                      value: '${_jobDetails!['estimated_arrival_minutes']} minutes',
                      icon: Icons.access_time,
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 16),

              // Job Information
              _SectionCard(
                title: 'Job Details',
                icon: Icons.work,
                children: [
                  if (_jobDetails!['title'] != null)
                    _InfoRow(
                      label: 'Title',
                      value: _jobDetails!['title'],
                      icon: Icons.title,
                    ),
                  if (_jobDetails!['description'] != null) ...[
                    if (_jobDetails!['title'] != null) const SizedBox(height: 12),
                    _InfoRow(
                      label: 'Description',
                      value: _jobDetails!['description'],
                      icon: Icons.description,
                      isMultiline: true,
                    ),
                  ],
                  if (_jobDetails!['estimated_price'] != null) ...[
                    const SizedBox(height: 12),
                    _InfoRow(
                      label: 'Estimated Price',
                      value: '₱${_jobDetails!['estimated_price'].toStringAsFixed(2)}',
                      icon: Icons.attach_money,
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 24),

              // Action Buttons
              _buildActionButtons(status),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons(String status) {
    List<Widget> buttons = [];

    switch (status) {
      case 'accepted':
        buttons.addAll([
          _ActionButton(
            label: 'Start Job',
            icon: Icons.play_arrow,
            color: Colors.red,
            onPressed: _isUpdating ? null : () => _updateJobStatus('in_progress'),
          ),
          const SizedBox(height: 12),
          _ActionButton(
            label: 'Navigate to Customer',
            icon: Icons.navigation,
            color: Colors.blue,
            onPressed: _openNavigation,
          ),
        ]);
        break;

      case 'in_progress':
        buttons.addAll([
          _ActionButton(
            label: 'Complete Inspection',
            icon: Icons.checklist,
            color: Colors.orange,
            onPressed: _isUpdating ? null : () => _updateJobStatus('inspection_completed'),
          ),
          const SizedBox(height: 12),
          _ActionButton(
            label: 'Navigate to Customer',
            icon: Icons.navigation,
            color: Colors.blue,
            onPressed: _openNavigation,
          ),
        ]);
        break;

      case 'inspection_completed':
        buttons.addAll([
          _ActionButton(
            label: 'Create Invoice',
            icon: Icons.receipt,
            color: const Color.fromARGB(255, 176, 12, 1),
            onPressed: _generateInvoice,
          ),
        ]);
        break;

      case 'invoice_sent':
      case 'invoice_accepted':
        buttons.addAll([
          const Text(
            'Waiting for customer to pay invoice...',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.orange,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          _ActionButton(
            label: 'Edit Invoice',
            icon: Icons.edit_note,
            color: const Color.fromARGB(255, 176, 12, 1),
            onPressed: _generateInvoice, // Reuse same function to open invoice screen
          ),
        ]);
        break;

      case 'invoice_paid':
        buttons.addAll([
          const Text(
            'Payment received! You can now start working.',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.red,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          _ActionButton(
            label: 'Mark as Completed',
            icon: Icons.check_circle,
            color: Colors.red,
            onPressed: _isUpdating ? null : () => _updateJobStatus('completed'),
          ),
        ]);
        break;

      case 'completed':
        buttons.addAll([
          const Text(
            'Job completed! Customer should scan QR code to release payment.',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.red,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          _ActionButton(
            label: 'Scan QR for Payment',
            icon: Icons.qr_code_scanner,
            color: const Color.fromARGB(255, 176, 12, 1),
            onPressed: _scanQRForCompletion,
          ),
        ]);
        break;

      default:
        buttons.add(
          Text(
            'Status: ${status.replaceAll('_', ' ').toUpperCase()}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        );
    }

    return Column(children: buttons);
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'accepted':
        return Colors.blue;
      case 'in_progress':
        return Colors.orange;
      case 'inspection_completed':
        return Colors.purple;
      case 'invoice_sent':
      case 'invoice_accepted':
        return Colors.amber;
      case 'invoice_paid':
        return Colors.green;
      case 'completed':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'accepted':
        return Icons.thumb_up;
      case 'in_progress':
        return Icons.build;
      case 'inspection_completed':
        return Icons.checklist;
      case 'invoice_sent':
      case 'invoice_accepted':
        return Icons.receipt;
      case 'invoice_paid':
        return Icons.payment;
      case 'completed':
        return Icons.check_circle;
      default:
        return Icons.info;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'accepted':
        return 'Job Accepted';
      case 'in_progress':
        return 'In Progress';
      case 'inspection_completed':
        return 'Inspection Complete';
      case 'invoice_sent':
        return 'Invoice Sent';
      case 'invoice_accepted':
        return 'Invoice Accepted';
      case 'invoice_paid':
        return 'Payment Received';
      case 'completed':
        return 'Job Completed';
      default:
        return status.replaceAll('_', ' ').toUpperCase();
    }
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
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
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: const Color.fromARGB(255, 176, 12, 1),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color.fromARGB(255, 176, 12, 1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final IconData? actionIcon;
  final VoidCallback? onActionTap;
  final bool isMultiline;

  const _InfoRow({
    required this.label,
    required this.value,
    required this.icon,
    this.actionIcon,
    this.onActionTap,
    this.isMultiline = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 16,
          color: Colors.grey[600],
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
                maxLines: isMultiline ? null : 1,
                overflow: isMultiline ? null : TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        if (actionIcon != null && onActionTap != null) ...[
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onActionTap,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color.fromARGB(255, 176, 12, 1).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                actionIcon,
                size: 16,
                color: const Color.fromARGB(255, 176, 12, 1),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
      ),
    );
  }
}
