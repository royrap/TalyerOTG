import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/talyer_verification_service.dart';
import '../services/admin_auth_service.dart';

class TalyerVerificationScreen extends StatefulWidget {
  const TalyerVerificationScreen({super.key}));

  @override
  _TalyerVerificationScreenState createState() => _TalyerVerificationScreenState();
}

class _TalyerVerificationScreenState extends State<TalyerVerificationScreen>
    with SingleTickerProviderStateMixin {
  final _verificationService = TalyerVerificationService.instance;
  final _adminAuth = AdminAuthService.instance;

  List<TalyerVerificationRequest> _verifications = [];
  VerificationStats? _stats;
  bool _isLoading = true;
  String? _error;
  String _selectedFilter = 'pending';

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadVerifications();
  }

  Future<void> _loadVerifications() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      List<TalyerVerificationRequest> verifications;
      
      if (_selectedFilter == 'all') {
        verifications = await _verificationService.getVerificationHistory();
      } else {
        verifications = _selectedFilter == 'pending'
            ? await _verificationService.getPendingVerifications()
            : await _verificationService.getVerificationHistory(status: _selectedFilter);
      }

      final stats = await _verificationService.getVerificationStats();

      setState(() {
        _verifications = verifications;
        _stats = stats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load verifications: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshVerifications() async {
    await _loadVerifications();
    HapticFeedback.lightImpact();
  }

  void _onFilterChanged(String filter) {
    setState(() {
      _selectedFilter = filter;
    });
    _loadVerifications();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'TalYer Verification',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF1976D2),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _refreshVerifications,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          onTap: (index) {
            final filters = ['pending', 'approved', 'rejected', 'additional_info_required'];
            _onFilterChanged(filters[index]);
          },
          tabs: [
            Tab(
              text: 'Pending',
              icon: Badge(
                backgroundColor: Colors.orange,
                label: Text(
                  _stats?.pending.toString() ?? '0',
                  style: const TextStyle(color: Colors.white, fontSize: 10),
                ),
                child: const Icon(Icons.pending_actions),
              ),
            ),
            Tab(
              text: 'Approved',
              icon: Badge(
                backgroundColor: Colors.green,
                label: Text(
                  _stats?.approved.toString() ?? '0',
                  style: const TextStyle(color: Colors.white, fontSize: 10),
                ),
                child: const Icon(Icons.check_circle),
              ),
            ),
            Tab(
              text: 'Rejected',
              icon: Badge(
                backgroundColor: Colors.red,
                label: Text(
                  _stats?.rejected.toString() ?? '0',
                  style: const TextStyle(color: Colors.white, fontSize: 10),
                ),
                child: const Icon(Icons.cancel),
              ),
            ),
            Tab(
              text: 'Info Req.',
              icon: Badge(
                backgroundColor: Colors.amber,
                label: Text(
                  _stats?.infoRequested.toString() ?? '0',
                  style: const TextStyle(color: Colors.white, fontSize: 10),
                ),
                child: const Icon(Icons.info),
              ),
            ),
          ],
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red[300],
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: TextStyle(color: Colors.red[700]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadVerifications,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_verifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.verified_user,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No ${_selectedFilter == 'pending' ? 'pending' : _selectedFilter} verifications',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'TalYer verification requests will appear here',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshVerifications,
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

  Widget _buildVerificationCard(TalyerVerificationRequest verification) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showVerificationDetails(verification),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with status
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: _getStatusColor(verification.status).withAlpha(51),
                    child: verification.profilePictureUrl != null
                        ? ClipOval(
                            child: Image.network(
                              verification.profilePictureUrl!,
                              width: 40,
                              height: 40,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Icon(
                                    Icons.person,
                                    color: _getStatusColor(verification.status),
                                  ),
                            ),
                          )
                        : Icon(
                            Icons.person,
                            color: _getStatusColor(verification.status),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          verification.fullName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          verification.email,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(verification.status).withAlpha(26),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _getStatusColor(verification.status).withAlpha(77),
                      ),
                    ),
                    child: Text(
                      verification.statusDisplayName,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _getStatusColor(verification.status),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Business details
              if (verification.businessName != null) ...[
                Row(
                  children: [
                    Icon(
                      Icons.business,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        verification.businessName!,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],

              // Service types
              if (verification.serviceTypes.isNotEmpty) ...[
                Row(
                  children: [
                    Icon(
                      Icons.build,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: verification.serviceTypes.take(3).map((service) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue.withAlpha(26),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              service,
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.blue,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    if (verification.serviceTypes.length > 3)
                      Text(
                        '+${verification.serviceTypes.length - 3} more',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[500],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
              ],

              // Experience and certifications
              Row(
                children: [
                  Icon(
                    Icons.star,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${verification.yearsOfExperience ?? "Unknown"} experience',
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(width: 16),
                  Icon(
                    Icons.verified,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${verification.certifications.length} certifications',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Applied date
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Applied ${_formatDateTime(verification.createdAt)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  const Spacer(),
                  if (verification.isPending) ...[
                    TextButton.icon(
                      onPressed: () => _showQuickActions(verification),
                      icon: const Icon(Icons.settings, size: 16),
                      label: const Text('Actions'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF1976D2),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'additional_info_required':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  void _showVerificationDetails(TalyerVerificationRequest verification) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.3,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                // Handle
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Content
                Expanded(
                  child: TalyerVerificationDetailView(
                    verification: verification,
                    scrollController: scrollController,
                    onActionCompleted: () {
                      Navigator.pop(context);
                      _refreshVerifications();
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showQuickActions(TalyerVerificationRequest verification) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Quick Actions',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.check_circle, color: Colors.green),
              title: const Text('Approve Application'),
              onTap: () {
                Navigator.pop(context);
                _approveVerification(verification);
              },
            ),
            ListTile(
              leading: const Icon(Icons.info, color: Colors.amber),
              title: const Text('Request Additional Info'),
              onTap: () {
                Navigator.pop(context);
                _requestAdditionalInfo(verification);
              },
            ),
            ListTile(
              leading: const Icon(Icons.cancel, color: Colors.red),
              title: const Text('Reject Application'),
              onTap: () {
                Navigator.pop(context);
                _rejectVerification(verification);
              },
            ),
            ListTile(
              leading: const Icon(Icons.visibility, color: Colors.blue),
              title: const Text('View Details'),
              onTap: () {
                Navigator.pop(context);
                _showVerificationDetails(verification);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _approveVerification(TalyerVerificationRequest verification) async {
    final adminInfo = await _adminAuth.getCurrentAdminInfo();
    if (adminInfo == null) return;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve TalYer Application'),
        content: Text('Are you sure you want to approve ${verification.fullName}\'s TalYer application?'),
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

    if (result == true) {
      final success = await _verificationService.approveVerification(
        verificationId: verification.id,
        adminId: adminInfo.id,
        adminNotes: 'Approved via quick action',
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('TalYer application approved successfully'),
            backgroundColor: Colors.green,
          ),
        );
        _refreshVerifications();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to approve application'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _rejectVerification(TalyerVerificationRequest verification) async {
    final adminInfo = await _adminAuth.getCurrentAdminInfo();
    if (adminInfo == null) return;

    final reasonController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject TalYer Application'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Provide a reason for rejecting ${verification.fullName}\'s application:'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Rejection Reason',
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
            onPressed: () => Navigator.pop(context, reasonController.text),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      final success = await _verificationService.rejectVerification(
        verificationId: verification.id,
        adminId: adminInfo.id,
        rejectionReason: result,
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('TalYer application rejected'),
            backgroundColor: Colors.orange,
          ),
        );
        _refreshVerifications();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to reject application'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    reasonController.dispose();
  }

  Future<void> _requestAdditionalInfo(TalyerVerificationRequest verification) async {
    final adminInfo = await _adminAuth.getCurrentAdminInfo();
    if (adminInfo == null) return;

    final requestController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Request Additional Information'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('What additional information do you need from ${verification.fullName}?'),
            const SizedBox(height: 12),
            TextField(
              controller: requestController,
              decoration: const InputDecoration(
                labelText: 'Information Request',
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
            onPressed: () => Navigator.pop(context, requestController.text),
            child: const Text('Send Request'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      final success = await _verificationService.requestAdditionalInfo(
        verificationId: verification.id,
        adminId: adminInfo.id,
        requestDetails: result,
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Additional information requested'),
            backgroundColor: Colors.blue,
          ),
        );
        _refreshVerifications();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to send request'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    requestController.dispose();
  }
}

// Detailed view for verification (placeholder - would be a separate file)
class TalyerVerificationDetailView extends StatelessWidget {
  final TalyerVerificationRequest verification;
  final ScrollController scrollController;
  final VoidCallback onActionCompleted;

  const TalyerVerificationDetailView({
    super.key,
    required this.verification,
    required this.scrollController,
    required this.onActionCompleted,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: scrollController,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TalYer Verification Details',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Applicant: ${verification.fullName}',
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'Email: ${verification.email}',
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 8),
          Text(
            'Status: ${verification.statusDisplayName}',
            style: const TextStyle(fontSize: 14),
          ),
          // Add more details here...
          const SizedBox(height: 40),
          Text(
            'This is a detailed view placeholder. Implement full verification details, documents, and actions here.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}










