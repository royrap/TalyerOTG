import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'widgets/angkas_slide_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AngkasEarningsScreen extends StatefulWidget {
  const AngkasEarningsScreen({Key? key}) : super(key: key);

  @override
  State<AngkasEarningsScreen> createState() => _AngkasEarningsScreenState();
}

class _AngkasEarningsScreenState extends State<AngkasEarningsScreen>
    with TickerProviderStateMixin {
  Map<String, dynamic> _earnings = {};
  List<Map<String, dynamic>> _recentJobs = [];
  bool _isLoading = true;
  String _error = '';
  String _selectedPeriod = 'today';
  
  // Removed manual slide controller; using AngkasSlideIn for entrance
  late AnimationController _countController;
  late Animation<double> _countAnimation;

  final List<String> _periods = ['today', 'week', 'month', 'year'];

  @override
  void initState() {
    super.initState();
    
    _countController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _countAnimation = CurvedAnimation(
      parent: _countController,
      curve: Curves.easeOutCubic,
    );
    
  _loadMechanicEarnings();
  }

  @override
  void dispose() {
    _countController.dispose();
    super.dispose();
  }

  Future<void> _loadMechanicEarnings() async {
    try {
      setState(() {
        _isLoading = true;
        _error = '';
      });

      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      final providerResponse = await Supabase.instance.client
          .from('service_providers')
          .select('id')
          .eq('user_id', currentUser.id)
          .single();

      final providerId = providerResponse['id'];

      await Future.wait([
        _loadEarningsData(providerId),
        _loadRecentJobs(providerId),
      ]);

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _countController.forward();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadEarningsData(String providerId) async {
    // Get completed service requests with payment data
    final completedJobs = await Supabase.instance.client
        .from('service_requests')
        .select('''
          id, final_price, completed_at, status,
          payments!inner(provider_amount, amount, platform_fee, processed_at),
          service_categories(name),
          user_profiles!customer_id(first_name, last_name)
        ''')
        .eq('provider_id', providerId)
        .eq('status', 'completed')
        .not('final_price', 'is', null);

    // Get payment releases data
    final paymentReleases = await Supabase.instance.client
        .from('payment_releases')
        .select('*')
        .eq('provider_id', providerId);

    // Calculate earnings statistics
    double totalEarnings = 0;
    double totalPlatformFees = 0;
    double weeklyEarnings = 0;
    double monthlyEarnings = 0;
    double yearlyEarnings = 0;
    double highestJob = 0;
    int totalJobs = completedJobs.length;
    
    final today = DateTime.now();
    final weekAgo = today.subtract(const Duration(days: 7));
    final monthAgo = DateTime(today.year, today.month - 1, today.day);
    final yearAgo = DateTime(today.year - 1, today.month, today.day);

    for (final job in completedJobs) {
      final amount = (job['payments']?[0]?['provider_amount'] ?? 0.0).toDouble();
      final platformFee = (job['payments']?[0]?['platform_fee'] ?? 0.0).toDouble();
      final completedAt = DateTime.parse(job['completed_at']);

      totalEarnings += amount;
      totalPlatformFees += platformFee;
      
      if (amount > highestJob) highestJob = amount;

      // Time-based calculations
      if (completedAt.isAfter(weekAgo)) {
        weeklyEarnings += amount;
      }
      if (completedAt.isAfter(monthAgo)) {
        monthlyEarnings += amount;
      }
      if (completedAt.isAfter(yearAgo)) {
        yearlyEarnings += amount;
      }
    }

    // Calculate payment release statistics
    double releasedAmount = 0;
    double pendingReleaseAmount = 0;
    int releasedPayments = 0;
    int pendingReleasePayments = 0;

    for (final release in paymentReleases) {
      final amount = (release['provider_amount'] ?? 0.0).toDouble();
      final status = release['release_status'];

      if (status == 'released') {
        releasedAmount += amount;
        releasedPayments++;
      } else if (status == 'pending' || status == 'approved') {
        pendingReleaseAmount += amount;
        pendingReleasePayments++;
      }
    }

    _earnings = {
      'total_earnings': totalEarnings,
      'total_platform_fees': totalPlatformFees,
      'net_earnings': totalEarnings - totalPlatformFees,
      'weekly_earnings': weeklyEarnings,
      'monthly_earnings': monthlyEarnings,
      'yearly_earnings': yearlyEarnings,
      'highest_job': highestJob,
      'total_jobs': totalJobs,
      'released_amount': releasedAmount,
      'pending_release_amount': pendingReleaseAmount,
      'released_payments': releasedPayments,
      'pending_release_payments': pendingReleasePayments,
    };
  }

  Future<void> _loadRecentJobs(String providerId) async {
    final recentJobs = await Supabase.instance.client
        .from('service_requests')
        .select('''
          id, title, final_price, completed_at, status, pickup_address,
          service_categories(name),
          user_profiles!customer_id(first_name, last_name),
          payments(provider_amount, status)
        ''')
        .eq('provider_id', providerId)
        .eq('status', 'completed')
        .order('completed_at', ascending: false)
        .limit(10);

    _recentJobs = List<Map<String, dynamic>>.from(recentJobs);
  }

  double _getSelectedPeriodEarnings() {
    switch (_selectedPeriod) {
      case 'today': return _earnings['daily_earnings'] ?? 0.0;
      case 'week': return _earnings['weekly_earnings'] ?? 0.0;
      case 'month': return _earnings['monthly_earnings'] ?? 0.0;
      case 'year': return _earnings['yearly_earnings'] ?? 0.0;
      default: return 0.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: AngkasSlideIn(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFFEF5350)),
                )
              : _error.isNotEmpty
                  ? _buildErrorState()
                  : RefreshIndicator(
                      onRefresh: _loadMechanicEarnings,
                      color: const Color(0xFFEF5350),
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Column(
                          children: [
                            _buildHeader(),
                            _buildEarningsCard(),
                            _buildPeriodSelector(),
                            _buildStatsGrid(),
                            _buildPaymentStatus(),
                            _buildRecentJobs(),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your Earnings',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              Text(
                'Track your income and payments',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFEF5350).withAlpha(26),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.account_balance_wallet_rounded,
              color: Color(0xFFEF5350),
              size: 24,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEarningsCard() {
    final selectedEarnings = _getSelectedPeriodEarnings();
    
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFEF5350), Color(0xFFE53935)],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFEF5350).withAlpha(102),
              spreadRadius: 0,
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_selectedPeriod.toUpperCase()}\'S EARNINGS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white.withAlpha(204),
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),
            AnimatedBuilder(
              animation: _countAnimation,
              builder: (context, child) {
                final animatedValue = selectedEarnings * _countAnimation.value;
                return Text(
                  '₱${animatedValue.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildEarningsMetric(
                    'Jobs Completed',
                    '${_earnings['total_jobs'] ?? 0}',
                    Icons.check_circle_rounded,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildEarningsMetric(
                    'Best Single Job',
                    '₱${(_earnings['highest_job'] ?? 0.0).toStringAsFixed(0)}',
                    Icons.star_rounded,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEarningsMetric(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(38),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withAlpha(204),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      height: 50,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _periods.length,
        itemBuilder: (context, index) {
          final period = _periods[index];
          final isSelected = _selectedPeriod == period;
          final earnings = _getPeriodEarnings(period);
          
          return Container(
            margin: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedPeriod = period;
                });
                HapticFeedback.selectionClick();
                _countController.reset();
                _countController.forward();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFEF5350) : Colors.white,
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(
                    color: isSelected ? const Color(0xFFEF5350) : Colors.grey[300]!,
                  ),
                  boxShadow: isSelected ? [
                    BoxShadow(
                      color: const Color(0xFFEF5350).withAlpha(77),
                      spreadRadius: 0,
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ] : null,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      period.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : const Color(0xFFEF5350),
                      ),
                    ),
                    Text(
                      '₱${earnings.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 10,
                        color: isSelected ? Colors.white.withAlpha(204) : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatsGrid() {
    return Container(
      margin: const EdgeInsets.all(20),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        childAspectRatio: 1.3,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        children: [
          _AngkasStatCard(
            title: 'Total Earnings',
            value: '₱${(_earnings['total_earnings'] ?? 0.0).toStringAsFixed(2)}',
            icon: Icons.monetization_on_rounded,
            color: const Color(0xFF1976D2),
          ),
          _AngkasStatCard(
            title: 'Net Income',
            value: '₱${(_earnings['net_earnings'] ?? 0.0).toStringAsFixed(2)}',
            icon: Icons.account_balance_rounded,
            color: const Color(0xFFEF5350),
          ),
          _AngkasStatCard(
            title: 'Platform Fees',
            value: '₱${(_earnings['total_platform_fees'] ?? 0.0).toStringAsFixed(2)}',
            icon: Icons.percent_rounded,
            color: const Color(0xFFE65100),
          ),
          _AngkasStatCard(
            title: 'Avg Per Job',
            value: '₱${_calculateAverageEarnings().toStringAsFixed(2)}',
            icon: Icons.trending_up_rounded,
            color: const Color(0xFF7B1FA2),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentStatus() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Payment Status',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildPaymentStatusCard(
                  'Available',
                  '₱${(_earnings['released_amount'] ?? 0.0).toStringAsFixed(2)}',
                  Icons.check_circle_rounded,
                  const Color(0xFFEF5350),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildPaymentStatusCard(
                  'Pending',
                  '₱${(_earnings['pending_release_amount'] ?? 0.0).toStringAsFixed(2)}',
                  Icons.access_time_rounded,
                  const Color(0xFFE65100),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentStatusCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha(51)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            spreadRadius: 0,
            blurRadius: 10,
            offset: const Offset(0, 4),
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
                  color: color.withAlpha(26),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A),
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentJobs() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent Earnings',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 16),
          if (_recentJobs.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(13),
                    spreadRadius: 0,
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.receipt_long_rounded,
                    size: 48,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No earnings yet',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Your completed jobs will appear here',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            )
          else
            ...List.generate(
              (_recentJobs.length > 5 ? 5 : _recentJobs.length),
              (index) => _RecentJobCard(job: _recentJobs[index]),
            ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(32),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(13),
              spreadRadius: 0,
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: Color(0xFFD32F2F),
            ),
            const SizedBox(height: 16),
            const Text(
              'Error Loading Earnings',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadMechanicEarnings,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF5350),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _getPeriodEarnings(String period) {
    switch (period) {
      case 'today': return _earnings['daily_earnings'] ?? 0.0;
      case 'week': return _earnings['weekly_earnings'] ?? 0.0;
      case 'month': return _earnings['monthly_earnings'] ?? 0.0;
      case 'year': return _earnings['yearly_earnings'] ?? 0.0;
      default: return 0.0;
    }
  }

  double _calculateAverageEarnings() {
    final totalJobs = _earnings['total_jobs'] ?? 0;
    final totalEarnings = _earnings['total_earnings'] ?? 0.0;
    return totalJobs > 0 ? totalEarnings / totalJobs : 0.0;
  }
}

class _AngkasStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _AngkasStatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha(51)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            spreadRadius: 0,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withAlpha(26),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentJobCard extends StatelessWidget {
  final Map<String, dynamic> job;

  const _RecentJobCard({required this.job});

  @override
  Widget build(BuildContext context) {
    final customer = job['user_profiles'] ?? {};
    final customerName = '${customer['first_name'] ?? ''} ${customer['last_name'] ?? ''}'.trim();
    final payment = job['payments']?[0] ?? {};
    final amount = (payment['provider_amount'] ?? 0.0).toDouble();
    final completedAt = DateTime.tryParse(job['completed_at'] ?? '');
    final category = job['service_categories']?['name'] ?? 'Service';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            spreadRadius: 0,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFEF5350).withAlpha(26),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.build_rounded,
              color: Color(0xFFEF5350),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                Text(
                  customerName.isNotEmpty ? customerName : 'Customer',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                if (completedAt != null)
                  Text(
                    _formatDate(completedAt),
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[500],
                    ),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₱${amount.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFEF5350),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF5350).withAlpha(26),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'PAID',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFEF5350),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}



