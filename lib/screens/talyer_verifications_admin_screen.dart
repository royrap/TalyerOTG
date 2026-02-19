import 'package:flutter/material.dart';
import '../services/signup_verification_service.dart';

/// Admin screen to view data saved in talyer_owner_verifications table
class TalyerVerificationsAdminScreen extends StatefulWidget {
  const TalyerVerificationsAdminScreen({super.key}));

  @override
  State<TalyerVerificationsAdminScreen> createState() => _TalyerVerificationsAdminScreenState();
}

class _TalyerVerificationsAdminScreenState extends State<TalyerVerificationsAdminScreen> {
  List<Map<String, dynamic>> _verifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadVerifications();
  }

  Future<void> _loadVerifications() async {
    setState(() => _isLoading = true);
    
    try {
      final verifications = await SignupVerificationService.getAllVerifications();
      setState(() {
        _verifications = verifications;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Error loading verifications: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Talyer Owner Verifications'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadVerifications,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildVerificationsList(),
    );
  }

  Widget _buildVerificationsList() {
    if (_verifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.business_center,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No verifications found',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Data will appear here when users upload documents',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadVerifications,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadVerifications,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _verifications.length,
        itemBuilder: (context, index) {
          final verification = _verifications[index];
          return _buildVerificationCard(verification);
        },
      ),
    );
  }

  Widget _buildVerificationCard(Map<String, dynamic> verification) {
    final businessName = verification['business_name'] ?? 'Unknown Business';
    final contactPerson = verification['contact_person'] ?? 'Unknown Person';
    final email = verification['email'] ?? 'No email';
    final phoneNumber = verification['phone_number'] ?? 'No phone';
    final status = verification['status'] ?? 'pending';
    final createdAt = verification['created_at'] != null 
        ? DateTime.parse(verification['created_at'])
        : DateTime.now();
    final userId = verification['user_id'] ?? '';
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        businessName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Contact: $contactPerson',
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withAlpha(26),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _getStatusColor(status)),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      color: _getStatusColor(status),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Contact Information
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Contact Information',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.email, size: 16, color: Colors.blue),
                      const SizedBox(width: 8),
                      Expanded(child: Text(email)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.phone, size: 16, color: Colors.green),
                      const SizedBox(width: 8),
                      Expanded(child: Text(phoneNumber)),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Document URLs
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Documents',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (verification['business_permit_url'] != null) ...[
                    Row(
                      children: [
                        const Icon(Icons.business, size: 16, color: Colors.blue),
                        const SizedBox(width: 8),
                        const Text('Business Permit:', style: TextStyle(fontWeight: FontWeight.w500)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _showImageDialog(verification['business_permit_url'], 'Business Permit'),
                            child: Text(
                              'View Document',
                              style: TextStyle(
                                color: Colors.blue[700],
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                  ],
                  if (verification['valid_id_url'] != null) ...[
                    Row(
                      children: [
                        const Icon(Icons.credit_card, size: 16, color: Colors.green),
                        const SizedBox(width: 8),
                        const Text('Valid ID:', style: TextStyle(fontWeight: FontWeight.w500)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _showImageDialog(verification['valid_id_url'], 'Valid ID'),
                            child: Text(
                              'View Document',
                              style: TextStyle(
                                color: Colors.green[700],
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Metadata
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Created: ${_formatDate(createdAt)}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
                Text(
                  'ID: ${userId.substring(0, 8)}...',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _approveVerification(verification),
                    icon: const Icon(Icons.check),
                    label: const Text('Approve'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[600],
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _rejectVerification(verification),
                    icon: const Icon(Icons.close),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red[600],
                      side: BorderSide(color: Colors.red[600]!),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'under_review':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inMinutes}m ago';
    }
  }

  void _showImageDialog(String imageUrl, String title) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: Text(title),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            Flexible(
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 200,
                  color: Colors.grey[200],
                  child: const Center(
                    child: Text('Failed to load image'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _approveVerification(Map<String, dynamic> verification) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve Verification'),
        content: Text('Approve verification for ${verification['business_name']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Approve'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await SignupVerificationService.updateVerificationStatus(
        verificationId: verification['verification_id'] ?? verification['id'],
        status: 'approved',
        adminNotes: 'Approved by admin',
        reviewedBy: 'admin', // Replace with actual admin ID
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Verification approved'),
            backgroundColor: Colors.green,
          ),
        );
        _loadVerifications();
      }
    }
  }

  Future<void> _rejectVerification(Map<String, dynamic> verification) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Reject Verification'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Reject verification for ${verification['business_name']}?'),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Rejection reason',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Reject'),
            ),
          ],
        );
      },
    );

    if (reason != null && reason.isNotEmpty) {
      final success = await SignupVerificationService.updateVerificationStatus(
        verificationId: verification['verification_id'] ?? verification['id'],
        status: 'rejected',
        adminNotes: 'Rejected: $reason',
        reviewedBy: 'admin', // Replace with actual admin ID
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Verification rejected'),
            backgroundColor: Colors.red,
          ),
        );
        _loadVerifications();
      }
    }
  }
}










