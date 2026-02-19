import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'talyer_owner_api_service.dart';

class ShopReportsScreen extends StatefulWidget {
  final String shopId;

  const ShopReportsScreen({Key? key, required this.shopId}) : super(key: key);

  @override
  State<ShopReportsScreen> createState() => _ShopReportsScreenState();
}

class _ShopReportsScreenState extends State<ShopReportsScreen> {
  final TalyerOwnerApiService _apiService = TalyerOwnerApiService();
  
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  Map<String, dynamic>? _reportData;
  bool _isLoading = true;
  String _selectedPeriod = 'Last 30 Days';

  @override
  void initState() {
    super.initState();
    _loadReportData();
  }

  Future<void> _loadReportData() async {
    setState(() => _isLoading = true);
    
    try {
      final data = await _apiService.getRevenueReport(
        shopId: widget.shopId,
        startDate: _startDate,
        endDate: _endDate,
      );
      
      setState(() {
        _reportData = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading report: $e')),
        );
      }
    }
  }

  void _changePeriod(String period) {
    setState(() {
      _selectedPeriod = period;
      final now = DateTime.now();
      
      switch (period) {
        case 'Today':
          _startDate = DateTime(now.year, now.month, now.day);
          _endDate = now;
          break;
        case 'Last 7 Days':
          _startDate = now.subtract(const Duration(days: 7));
          _endDate = now;
          break;
        case 'Last 30 Days':
          _startDate = now.subtract(const Duration(days: 30));
          _endDate = now;
          break;
        case 'This Month':
          _startDate = DateTime(now.year, now.month, 1);
          _endDate = now;
          break;
        case 'Last Month':
          final lastMonth = DateTime(now.year, now.month - 1, 1);
          _startDate = lastMonth;
          _endDate = DateTime(now.year, now.month, 0);
          break;
        case 'Custom':
          _showDateRangePicker();
          return;
      }
    });
    _loadReportData();
  }

  Future<void> _showDateRangePicker() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
    );
    
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _loadReportData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shop Reports'),
        backgroundColor: Colors.red,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.date_range),
            onSelected: _changePeriod,
            itemBuilder: (context) => [
              'Today',
              'Last 7 Days',
              'Last 30 Days',
              'This Month',
              'Last Month',
              'Custom',
            ].map((period) {
              return PopupMenuItem<String>(
                value: period,
                child: Text(period),
              );
            }).toList(),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadReportData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadReportData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPeriodInfo(),
                    const SizedBox(height: 16),
                    _buildRevenueOverview(),
                    const SizedBox(height: 24),
                    _buildEarningsBreakdown(),
                    const SizedBox(height: 24),
                    _buildTopMechanics(),
                    const SizedBox(height: 24),
                    _buildTopServices(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildPeriodInfo() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedPeriod,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${DateFormat('MMM dd, yyyy').format(_startDate)} - ${DateFormat('MMM dd, yyyy').format(_endDate)}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            Icon(Icons.calendar_today, color: Colors.orange[700]),
          ],
        ),
      ),
    );
  }

  Widget _buildRevenueOverview() {
    if (_reportData == null) return const SizedBox.shrink();

    final totalRevenue = _reportData!['totalRevenue'] as num;
    final platformFees = _reportData!['platformFees'] as num;
    final mechanicEarnings = _reportData!['mechanicEarnings'] as num;
    final totalJobs = _reportData!['totalJobs'] as int;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '📊 Revenue Overview',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: [
            _buildRevenueCard('Total Jobs', '$totalJobs', Icons.work, Colors.blue),
            _buildRevenueCard('Shop Revenue', '₱${totalRevenue.toStringAsFixed(2)}', Icons.store, Colors.green),
            _buildRevenueCard('Platform Fees', '₱${platformFees.toStringAsFixed(2)}', Icons.payment, Colors.orange),
            _buildRevenueCard('Mechanic Earnings', '₱${mechanicEarnings.toStringAsFixed(2)}', Icons.engineering, Colors.purple),
          ],
        ),
      ],
    );
  }

  Widget _buildRevenueCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [color.withOpacity(0.15), Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                    maxLines: 2,
                  ),
                ),
                Icon(icon, color: color, size: 20),
              ],
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEarningsBreakdown() {
    if (_reportData == null) return const SizedBox.shrink();

    final totalRevenue = _reportData!['totalRevenue'] as num;
    final platformFees = _reportData!['platformFees'] as num;
    final mechanicEarnings = _reportData!['mechanicEarnings'] as num;

    final total = totalRevenue + platformFees + mechanicEarnings;
    final shopPercentage = total > 0 ? (totalRevenue / total * 100) : 0;
    final platformPercentage = total > 0 ? (platformFees / total * 100) : 0;
    final mechanicPercentage = total > 0 ? (mechanicEarnings / total * 100) : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '💰 Earnings Breakdown',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildBreakdownRow('Shop Revenue', totalRevenue, shopPercentage, Colors.green),
                const SizedBox(height: 12),
                _buildBreakdownRow('Platform Fees', platformFees, platformPercentage, Colors.orange),
                const SizedBox(height: 12),
                _buildBreakdownRow('Mechanic Earnings', mechanicEarnings, mechanicPercentage, Colors.purple),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '₱${total.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBreakdownRow(String label, num amount, num percentage, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '₱${amount.toStringAsFixed(2)} (${percentage.toStringAsFixed(1)}%)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: percentage / 100,
          backgroundColor: Colors.grey[200],
          valueColor: AlwaysStoppedAnimation<Color>(color),
          minHeight: 8,
        ),
      ],
    );
  }

  Widget _buildTopMechanics() {
    if (_reportData == null) return const SizedBox.shrink();

    // Use mechanicDetails which contains names, not just IDs
    final mechanicDetails = _reportData!['mechanicDetails'] as Map<String, dynamic>?;
    
    if (mechanicDetails == null || mechanicDetails.isEmpty) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: Column(
              children: const [
                Icon(Icons.people_outline, size: 48, color: Colors.grey),
                SizedBox(height: 12),
                Text(
                  'No mechanics found',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Sort mechanics by earnings
    final sortedMechanics = mechanicDetails.entries.toList()
      ..sort((a, b) => ((b.value['earnings'] ?? 0) as num).compareTo((a.value['earnings'] ?? 0) as num));

    final topMechanics = sortedMechanics.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '👷 Top Performing Mechanics',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: topMechanics.length,
            separatorBuilder: (context, index) => const Divider(height: 16),
            itemBuilder: (context, index) {
              final mechanicData = topMechanics[index].value as Map<String, dynamic>;
              final mechanicName = mechanicData['name'] as String;
              final mechanicEmail = mechanicData['email'] as String;
              final earnings = mechanicData['earnings'] as num;
              
              return Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.red.withOpacity(0.2),
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          mechanicName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          mechanicEmail,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '₱${earnings.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTopServices() {
    if (_reportData == null) return const SizedBox.shrink();

    final earningsByService = _reportData!['earningsByService'] as Map<String, dynamic>;
    
    if (earningsByService.isEmpty) {
      return const SizedBox.shrink();
    }

    // Sort services by earnings
    final sortedServices = earningsByService.entries.toList()
      ..sort((a, b) => (b.value as num).compareTo(a.value as num));

    final topServices = sortedServices.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '🔧 Top Services',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: topServices.length,
            separatorBuilder: (context, index) => const Divider(height: 16),
            itemBuilder: (context, index) {
              final serviceName = topServices[index].key;
              final earnings = topServices[index].value as num;
              
              return Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.blue.withOpacity(0.2),
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      serviceName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    '₱${earnings.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
