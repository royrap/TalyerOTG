import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'widgets/angkas_slide_in.dart';
import '../services/auth_service.dart';
import '../services/mechanic_service.dart';
import '../services/mechanic_history_service.dart';
import 'faq_ai_screen.dart';

class AngkasMechanicProfileScreen extends StatefulWidget {
  const AngkasMechanicProfileScreen({super.key});

  @override
  State<AngkasMechanicProfileScreen> createState() => _AngkasMechanicProfileScreenState();
}

class _AngkasMechanicProfileScreenState extends State<AngkasMechanicProfileScreen> 
    with TickerProviderStateMixin {
  Map<String, dynamic> _profile = {};
  Map<String, dynamic> _stats = {};
  bool _isLoading = true;
  String _error = '';
  bool _isEditing = false;
  bool _isSaving = false;
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _phoneController;

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController();
    _lastNameController = TextEditingController();
    _phoneController = TextEditingController();
    _loadProfile();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      if (mounted) {
        setState(() {
          _isLoading = true;
          _error = '';
        });
      }

      // Load mechanic profile directly from database to ensure proper connection
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        throw Exception('No authenticated user');
      }

      // Query user_profiles table directly
      final profileData = await Supabase.instance.client
          .from('user_profiles')
          .select('*')
          .eq('id', user.id)
          .single();

      print('✅ Profile loaded from database: ${profileData['first_name']} ${profileData['last_name']}');

      // Load stats
      final stats = await MechanicHistoryService.instance.getDashboardStats();
      
      if (mounted) {
        setState(() {
          _profile = profileData;
          _stats = stats;
          _isLoading = false;
        });

        // Update text controllers with loaded profile data
        _firstNameController.text = _profile['first_name'] ?? '';
        _lastNameController.text = _profile['last_name'] ?? '';
        _phoneController.text = _profile['phone_number'] ?? '';
      }
    } catch (e) {
      print('❌ Error loading profile: $e');
      if (mounted) {
        setState(() {
          _error = 'Error loading profile from database: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFD32F2F), // Angkas red
              Color(0xFFB71C1C),
            ],
          ),
        ),
        child: SafeArea(
          child: AngkasSlideIn(
            child: Column(
            children: [
              // Custom App Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(51),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    const Expanded(
                      child: Text(
                        'Profile',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(51),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.refresh, color: Colors.white),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          _loadProfile();
                        },
                      ),
                    ),
                  ],
                ),
              ),
              
              // Content
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : _error.isNotEmpty
                        ? _buildErrorState()
                        : _buildProfileContent(),
              ),
            ],
          ),
        ),
      ),
    ),
    ); // end Scaffold
  }

  Widget _buildErrorState() {
    return Center(
        child: Container(
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(26),
                spreadRadius: 0,
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withAlpha(26),
                  borderRadius: BorderRadius.circular(50),
                ),
                child: Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Colors.red[600],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Error loading profile',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.red[700],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                height: 50,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFEF5350), Color(0xFFE53935)],
                  ),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: ElevatedButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    _loadProfile();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: const Text(
                    'Retry',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
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

  Widget _buildProfileContent() {
    return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Profile Header Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(26),
                    spreadRadius: 0,
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Profile Picture (no camera button)
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFFEF5350).withAlpha(26),
                          const Color(0xFFE53935).withAlpha(26),
                        ],
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.transparent,
                      backgroundImage: _profile['profile_image_url'] != null && 
                          _profile['profile_image_url'].toString().isNotEmpty
                          ? NetworkImage(_profile['profile_image_url'])
                          : null,
                      child: _profile['profile_image_url'] == null || 
                          _profile['profile_image_url'].toString().isEmpty
                          ? const Icon(
                              Icons.person,
                              size: 50,
                              color: Color(0xFFEF5350),
                            )
                          : null,
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Name and Email
                  if (!_isEditing) ...[
                    Text(
                      '${_profile['first_name'] ?? ''} ${_profile['last_name'] ?? ''}'.trim().isNotEmpty 
                          ? '${_profile['first_name'] ?? ''} ${_profile['last_name'] ?? ''}'.trim()
                          : 'Mechanic Profile',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFE53935),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _profile['email'] ?? 'No email available',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                    if (_profile['phone_number'] != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        _profile['phone_number'],
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                    const SizedBox(height: 12),
                    _buildEditButton(),
                  ] else ...[
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(child: _buildTextField('First Name', _firstNameController, validator: _requiredValidator)),
                              const SizedBox(width: 12),
                              Expanded(child: _buildTextField('Last Name', _lastNameController, validator: _requiredValidator)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildTextField('Phone Number', _phoneController,
                              keyboardType: TextInputType.phone,
                              validator: (v){
                                if(v==null||v.trim().isEmpty) return 'Required';
                                if(!RegExp(r'^\+?[0-9]{7,15}$').hasMatch(v.trim())) return 'Invalid phone';
                                return null;
                              }),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _isSaving ? null : () {
                                    HapticFeedback.lightImpact();
                                    setState(() { _isEditing = false; });
                                  },
                                  child: const Text('Cancel'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _isSaving ? null : _saveProfile,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFEF5350),
                                    foregroundColor: Colors.white,
                                  ),
                                  child: _isSaving ? const SizedBox(height:20,width:20,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white)) : const Text('Save'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                  
                  // Verification Status
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _stats['isVerified'] == true 
                          ? Colors.green.withAlpha(26)
                          : Colors.orange.withAlpha(26),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _stats['isVerified'] == true 
                              ? Icons.verified 
                              : Icons.pending,
                          size: 16,
                          color: _stats['isVerified'] == true 
                              ? Colors.green
                              : Colors.orange,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _stats['isVerified'] == true 
                              ? 'Verified Mechanic'
                              : 'Pending Verification',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _stats['isVerified'] == true 
                                ? Colors.green
                                : Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Stats Cards
            _buildStatsGrid(),
            
            const SizedBox(height: 20),
            
            // Action Cards (without quick actions and complete profile)
            _buildActionCard(
              icon: Icons.smart_toy,
              title: 'FAQ AI Assistant',
              subtitle: 'Get instant help with AI support',
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const FAQAIScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            _buildActionCard(
              icon: Icons.security,
              title: 'Account Security',
              subtitle: 'Manage your account security settings',
              onTap: () {
                HapticFeedback.lightImpact();
                _showSecurityOptions();
              },
            ),
            const SizedBox(height: 12),
            _buildActionCard(
              icon: Icons.logout,
              title: 'Sign Out',
              subtitle: 'Sign out of your account',
              isDestructive: true,
              onTap: () {
                HapticFeedback.lightImpact();
                _showSignOutDialog();
              },
            ),
          ],
        ),
      );
  }

  Widget _buildStatsGrid() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(26),
            spreadRadius: 0,
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF5350).withAlpha(26),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.analytics,
                  color: Color(0xFFEF5350),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Performance Overview',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Stats Grid
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            // Slightly increase width vs height to give more vertical room and avoid overflow
            childAspectRatio: 1.75,
            children: [
              _buildStatCard(
                icon: Icons.star,
                title: 'Rating',
                value: '${(_stats['averageRating'] ?? 0.0).toStringAsFixed(1)}',
                subtitle: '${_stats['totalReviews'] ?? 0} reviews',
                color: Colors.amber,
              ),
              _buildStatCard(
                icon: Icons.check_circle,
                title: 'Completed',
                value: '${_stats['totalCompleted'] ?? 0}',
                subtitle: 'Total jobs',
                color: Colors.green,
              ),
              _buildStatCard(
                icon: Icons.monetization_on,
                title: 'Earnings',
                value: '₱${(_stats['totalEarnings'] ?? 0.0).toStringAsFixed(0)}',
                subtitle: 'Total earned',
                color: Colors.green,
              ),
              _buildStatCard(
                icon: Icons.today,
                title: 'Today',
                value: '${_stats['completedToday'] ?? 0}',
                subtitle: 'Jobs completed',
                color: Colors.blue,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withAlpha(13),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(38)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Compact vertical layout to avoid overflow on very small devices
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      icon,
                      color: color,
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: color,
                          height: 1.1,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: color,
                    height: 1.1,
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9,
                    color: Colors.grey[600],
                    height: 1.1,
                  ),
                ),
              ],
            );
        },
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(13),
              spreadRadius: 0,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(
            color: isDestructive 
                ? Colors.red.withAlpha(51)
                : const Color(0xFFEF5350).withAlpha(26),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDestructive 
                    ? Colors.red.withAlpha(26)
                    : const Color(0xFFEF5350).withAlpha(26),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isDestructive ? Colors.red : const Color(0xFFEF5350),
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDestructive ? Colors.red : const Color(0xFFE53935),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.grey[400],
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  void _showSignOutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await AuthService.instance.signOut();
              if (mounted) {
                Navigator.of(context).pushReplacementNamed('/login');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Sign Out', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showSecurityOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              child: Column(
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
                  const Text(
                    'Account Security',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Manage your account security settings',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            _buildSecurityOption(
              icon: Icons.verified_user_outlined,
              title: 'Account Verification',
              subtitle: 'View verification status and requirements',
              onTap: () {
                Navigator.pop(context);
                _showVerificationStatus();
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSecurityOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEF5350).withAlpha(26),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: const Color(0xFFEF5350),
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.grey[400],
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  void _showVerificationStatus() {
    final isVerified = _stats['isVerified'] == true;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isVerified 
                    ? Colors.green.withAlpha(26)
                    : Colors.orange.withAlpha(26),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isVerified ? Icons.verified : Icons.pending,
                color: isVerified ? Colors.green : Colors.orange,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Verification Status',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isVerified 
                  ? 'Your account is verified! ✅'
                  : 'Your account verification is pending',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[700],
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              isVerified 
                  ? 'You have full access to all mechanic features and can receive job requests.'
                  : 'Please complete your profile and wait for admin approval to start receiving job requests.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        actions: [
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFEF5350), Color(0xFFE53935)],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text(
                'OK',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditButton(){
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () {
          HapticFeedback.lightImpact();
          setState(() { _isEditing = true; });
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFEF5350),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        icon: const Icon(Icons.edit),
        label: const Text('Edit Profile'),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {String? Function(String?)? validator, TextInputType keyboardType = TextInputType.text}){
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  String? _requiredValidator(String? v){
    if(v==null||v.trim().isEmpty) return 'Required';
    return null;
  }

  Future<void> _saveProfile() async {
    if(!_formKey.currentState!.validate()) return;
    setState(() { _isSaving = true; });
    final success = await MechanicService.instance.updateMechanicProfile(
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      phoneNumber: _phoneController.text.trim(),
    );
    if(!mounted) return;
    setState(() { _isSaving = false; });
    if(success){
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated'), backgroundColor: Colors.red));
      setState(() { _isEditing = false; });
      await _loadProfile();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to update'), backgroundColor: Colors.red));
    }
  }
}











