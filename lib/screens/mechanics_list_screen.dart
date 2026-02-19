import 'package:flutter/material.dart';
import '../services/talyer_owner_service.dart';

class MechanicsListScreen extends StatefulWidget {
  const MechanicsListScreen({Key? key}) : super(key: key);

  @override
  State<MechanicsListScreen> createState() => _MechanicsListScreenState();
}

class _MechanicsListScreenState extends State<MechanicsListScreen> {
  List<Map<String, dynamic>> _mechanics = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadMechanics();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadMechanics() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final mechanics = await TalyerOwnerService.instance.getShopMechanics();
      
      if (mounted) {
        setState(() {
          _mechanics = mechanics;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading mechanics: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<Map<String, dynamic>> get _filteredMechanics {
    if (_searchQuery.isEmpty) {
      return _mechanics;
    }
    
    return _mechanics.where((mechanic) {
      final name = '${mechanic['first_name']} ${mechanic['last_name']}'.toLowerCase();
      final email = mechanic['email']?.toLowerCase() ?? '';
      final phone = mechanic['phone_number']?.toLowerCase() ?? '';
      final query = _searchQuery.toLowerCase();
      
      return name.contains(query) || email.contains(query) || phone.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text(
          'Mechanics',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF1B5E20),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMechanics,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF1B5E20),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
                decoration: const InputDecoration(
                  hintText: 'Search mechanics...',
                  prefixIcon: Icon(Icons.search, color: Colors.grey),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                ),
              ),
            ),
          ),

          // Statistics Card
          if (!_isLoading)
            Container(
              margin: const EdgeInsets.all(16),
              child: _buildStatisticsCard(),
            ),

          // Mechanics List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredMechanics.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _loadMechanics,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _filteredMechanics.length,
                          itemBuilder: (context, index) {
                            final mechanic = _filteredMechanics[index];
                            return _buildMechanicCard(mechanic);
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToAddMechanic,
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Mechanic'),
      ),
    );
  }

  Widget _buildStatisticsCard() {
    final totalMechanics = _mechanics.length;
    final onlineMechanics = _mechanics.where((m) => 
        m['service_provider']?['status'] == 'online').length;
    final availableMechanics = _mechanics.where((m) => 
        m['service_provider']?['is_available'] == true).length;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: _buildStatItem(
                icon: Icons.people,
                label: 'Total',
                value: totalMechanics.toString(),
                color: Colors.blue,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatItem(
                icon: Icons.online_prediction,
                label: 'Online',
                value: onlineMechanics.toString(),
                color: Colors.green,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatItem(
                icon: Icons.check_circle,
                label: 'Available',
                value: availableMechanics.toString(),
                color: Colors.orange,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildMechanicCard(Map<String, dynamic> mechanic) {
    final serviceProvider = mechanic['service_provider'] ?? {};
    final isOnline = serviceProvider['status'] == 'online';
    final isAvailable = serviceProvider['is_available'] == true;
    final rating = serviceProvider['rating']?.toDouble() ?? 0.0;
    final totalReviews = serviceProvider['total_reviews'] ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showMechanicDetails(mechanic),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Profile Picture
              Stack(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.grey[300],
                    backgroundImage: mechanic['profile_image_url'] != null
                        ? NetworkImage(mechanic['profile_image_url'])
                        : null,
                    child: mechanic['profile_image_url'] == null
                        ? Text(
                            _getInitials(mechanic),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          )
                        : null,
                  ),
                  // Online Status Indicator
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: isOnline ? Colors.green : Colors.grey,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(width: 16),

              // Mechanic Information
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name and Status
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${mechanic['first_name']} ${mechanic['last_name']}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isAvailable ? Colors.green.shade100 : Colors.red.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            isAvailable ? 'Available' : 'Busy',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isAvailable ? Colors.green.shade700 : Colors.red.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 4),

                    // Contact Information
                    Text(
                      mechanic['email'] ?? 'No email',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    Text(
                      mechanic['phone_number'] ?? 'No phone',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Rating and Experience
                    Row(
                      children: [
                        if (rating > 0) ...[
                          Icon(Icons.star, color: Colors.amber, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            rating.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            ' ($totalReviews)',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(width: 16),
                        ],
                        Icon(Icons.work, color: Colors.grey[600], size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '${serviceProvider['years_experience'] ?? 0} years',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Actions
              Column(
                children: [
                  IconButton(
                    icon: Icon(
                      isOnline ? Icons.toggle_on : Icons.toggle_off,
                      color: isOnline ? Colors.green : Colors.grey,
                      size: 28,
                    ),
                    onPressed: () => _toggleMechanicStatus(mechanic),
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_vert, color: Colors.grey),
                    onPressed: () => _showMechanicOptions(mechanic),
                  ),
                ],
              ),
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
            Icons.build,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isEmpty 
                ? 'No mechanics in your shop yet'
                : 'No mechanics match your search',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isEmpty
                ? 'Add your first mechanic to get started'
                : 'Try a different search term',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 24),
          if (_searchQuery.isEmpty)
            ElevatedButton.icon(
              onPressed: _navigateToAddMechanic,
              icon: const Icon(Icons.add),
              label: const Text('Add Mechanic'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B5E20),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
        ],
      ),
    );
  }

  String _getInitials(Map<String, dynamic> mechanic) {
    final firstName = mechanic['first_name'] ?? '';
    final lastName = mechanic['last_name'] ?? '';
    
    if (firstName.isEmpty && lastName.isEmpty) {
      return '??';
    }
    
    return '${firstName.isNotEmpty ? firstName[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}'.toUpperCase();
  }

  void _showMechanicDetails(Map<String, dynamic> mechanic) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(24),
                    child: _buildMechanicDetailsContent(mechanic),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMechanicDetailsContent(Map<String, dynamic> mechanic) {
    final serviceProvider = mechanic['service_provider'] ?? {};
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with Profile Picture
        Row(
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: Colors.grey[300],
              backgroundImage: mechanic['profile_image_url'] != null
                  ? NetworkImage(mechanic['profile_image_url'])
                  : null,
              child: mechanic['profile_image_url'] == null
                  ? Text(
                      _getInitials(mechanic),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${mechanic['first_name']} ${mechanic['last_name']}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    mechanic['email'] ?? 'No email',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  Text(
                    mechanic['phone_number'] ?? 'No phone',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // Status Information
        _buildDetailSection('Status Information', [
          _buildDetailRow('Online Status', 
              serviceProvider['status'] == 'online' ? 'Online' : 'Offline'),
          _buildDetailRow('Availability', 
              serviceProvider['is_available'] == true ? 'Available' : 'Busy'),
          _buildDetailRow('Account Status', mechanic['status'] ?? 'Unknown'),
        ]),

        const SizedBox(height: 20),

        // Professional Information
        _buildDetailSection('Professional Information', [
          _buildDetailRow('Experience', '${serviceProvider['years_experience'] ?? 0} years'),
          _buildDetailRow('Rating', '${serviceProvider['rating']?.toStringAsFixed(1) ?? '0.0'} ⭐'),
          _buildDetailRow('Total Reviews', '${serviceProvider['total_reviews'] ?? 0}'),
          _buildDetailRow('Company', serviceProvider['company_name'] ?? 'Unknown'),
        ]),

        const SizedBox(height: 20),

        // Account Information
        _buildDetailSection('Account Information', [
          _buildDetailRow('User Type', mechanic['user_type'] ?? 'Unknown'),
          _buildDetailRow('Member Since', _formatDate(mechanic['created_at'])),
          _buildDetailRow('Last Updated', _formatDate(mechanic['updated_at'])),
        ]),
      ],
    );
  }

  Widget _buildDetailSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1B5E20),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
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

  void _toggleMechanicStatus(Map<String, dynamic> mechanic) async {
    try {
      final currentStatus = mechanic['service_provider']?['status'] ?? 'offline';
      final newStatus = currentStatus == 'online' ? 'offline' : 'online';
      
      await TalyerOwnerService.instance.updateMechanicStatus(
        mechanicUserId: mechanic['id'],
        status: newStatus,
      );

      await _loadMechanics(); // Refresh the list

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Mechanic status updated to $newStatus',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showMechanicOptions(Map<String, dynamic> mechanic) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.info),
              title: const Text('View Details'),
              onTap: () {
                Navigator.pop(context);
                _showMechanicDetails(mechanic);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit Profile'),
              onTap: () {
                Navigator.pop(context);
                // Navigate to edit profile
              },
            ),
            ListTile(
              leading: const Icon(Icons.assignment),
              title: const Text('Assign Job'),
              onTap: () {
                Navigator.pop(context);
                // Navigate to assign job
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Remove Mechanic', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _confirmRemoveMechanic(mechanic);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmRemoveMechanic(Map<String, dynamic> mechanic) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Mechanic'),
        content: Text(
          'Are you sure you want to remove ${mechanic['first_name']} ${mechanic['last_name']} from your shop?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Implement remove mechanic functionality
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  Future<void> _navigateToAddMechanic() async {
    // TODO: Navigate to add mechanic screen from new talyer_owner implementation
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Add mechanic feature - Use new Talyer Owner Dashboard'),
      ),
    );
    
    // Refresh the list
    _loadMechanics();
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'Unknown';
    
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'Invalid date';
    }
  }
}
