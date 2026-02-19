import 'package:flutter/material.dart';
import '../services/mechanic_invoice_service.dart';
import '../services/customer_invoice_service.dart';
import '../services/mechanic_history_service.dart';
import '../services/earnings_service.dart';
import '../models/job_history.dart';
import '../models/earnings_models.dart' as earnings;

class HistoryBottomSheetWidget extends StatefulWidget {
  final bool isMechanic;
  final String title;
  final int? maxItems;

  const HistoryBottomSheetWidget({
    Key? key,
    required this.isMechanic,
    this.title = 'Recent History',
    this.maxItems = 5,
  }) : super(key: key);

  @override
  State<HistoryBottomSheetWidget> createState() => _HistoryBottomSheetWidgetState();
}

class _HistoryBottomSheetWidgetState extends State<HistoryBottomSheetWidget> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _transactions = [];
  List<MechanicJobHistory> _mechanicJobHistory = [];
  Map<String, dynamic> _summary = {};
  earnings.MechanicEarningsSummary? _earningsSummary;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      setState(() => _isLoading = true);

      if (widget.isMechanic) {
        // Load mechanic job history with enhanced details and new earnings data
        final jobHistory = await MechanicHistoryService.instance.getMechanicJobHistory(limit: widget.maxItems ?? 5);
        final transactions = await MechanicInvoiceService.instance.getRecentTransactions(limit: widget.maxItems ?? 5);
        final summary = await MechanicInvoiceService.instance.getMechanicFinancialSummary();
        final earningsSummary = await EarningsService.instance.getMechanicEarningsSummary();
        
        setState(() {
          _mechanicJobHistory = jobHistory;
          _transactions = transactions;
          _summary = summary;
          _earningsSummary = earningsSummary;
          _isLoading = false;
        });
      } else {
        final transactions = await CustomerInvoiceService.instance.getRecentTransactions(limit: widget.maxItems ?? 5);
        final summary = await CustomerInvoiceService.instance.getCustomerServiceSummary();
        
        setState(() {
          _transactions = transactions;
          _summary = summary;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error loading history data: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                widget.isMechanic ? Icons.build : Icons.history,
                color: widget.isMechanic ? Colors.orange : Colors.blue,
              ),
              SizedBox(width: 8),
              Text(
                widget.title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Spacer(),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.close),
              ),
            ],
          ),
          SizedBox(height: 16),

          if (_isLoading)
            Center(
              child: CircularProgressIndicator(),
            )
          else ...[
            // Summary Cards
            _buildSummarySection(),
            
            SizedBox(height: 16),
            
            // Recent Transactions
            Text(
              widget.isMechanic ? 'Recent Jobs with Customer Details' : 'Recent Activity',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 8),
            
            if (widget.isMechanic && _mechanicJobHistory.isEmpty && _transactions.isEmpty)
              Container(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.work_outline,
                        size: 48,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'No job history yet',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              )
            else if (!widget.isMechanic && _transactions.isEmpty)
              Container(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.inbox_outlined,
                        size: 48,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'No recent activity',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              )
            else
              Column(
                children: [
                  // Show enhanced mechanic job history if available
                  if (widget.isMechanic && _mechanicJobHistory.isNotEmpty)
                    ListView.builder(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      itemCount: _mechanicJobHistory.length,
                      itemBuilder: (context, index) {
                        final job = _mechanicJobHistory[index];
                        return _buildEnhancedJobHistoryItem(job);
                      },
                    ),
                  
                  // Show regular transaction items
                  if (_transactions.isNotEmpty && (!widget.isMechanic || _mechanicJobHistory.isEmpty))
                    ListView.builder(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      itemCount: _transactions.length,
                      itemBuilder: (context, index) {
                        final transaction = _transactions[index];
                        return _buildTransactionItem(transaction);
                      },
                    ),
                ],
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummarySection() {
    if (widget.isMechanic) {
      return _buildMechanicSummary();
    } else {
      return _buildCustomerSummary();
    }
  }

  Widget _buildMechanicSummary() {
    // Use new earnings summary if available, fallback to old system
    if (_earningsSummary != null) {
      return Row(
        children: [
          Expanded(
            child: _buildSummaryCard(
              'You Earned',
              '₱${_earningsSummary!.totalEarnings.toStringAsFixed(2)}',
              Icons.account_balance_wallet,
              Colors.green,
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: _buildSummaryCard(
              'This Month',
              '₱${_earningsSummary!.thisMonthEarnings.toStringAsFixed(2)}',
              Icons.calendar_month,
              Colors.orange,
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: _buildSummaryCard(
              'Jobs Done',
              '${_earningsSummary!.totalJobs}',
              Icons.check_circle,
              Colors.blue,
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: _buildSummaryCard(
              'Rating',
              '${_earningsSummary!.averageRating.toStringAsFixed(1)}⭐',
              Icons.star,
              Colors.amber,
            ),
          ),
        ],
      );
    }
    
    // Fallback to old system
    final totalEarnings = _summary['total_earnings'] ?? 0.0;
    final earningsThisMonth = _summary['earnings_this_month'] ?? 0.0;
    final completedJobs = _summary['completed_jobs'] ?? 0;
    final averageRating = _summary['average_rating'] ?? 0.0;

    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            'You Earned',
            '₱${totalEarnings.toStringAsFixed(2)}',
            Icons.account_balance_wallet,
            Colors.green,
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: _buildSummaryCard(
            'This Month',
            '₱${earningsThisMonth.toStringAsFixed(2)}',
            Icons.calendar_month,
            Colors.orange,
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: _buildSummaryCard(
            'Jobs Done',
            '$completedJobs',
            Icons.check_circle,
            Colors.blue,
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: _buildSummaryCard(
            'Rating',
            '${averageRating.toStringAsFixed(1)}⭐',
            Icons.star,
            Colors.amber,
          ),
        ),
      ],
    );
  }

  Widget _buildCustomerSummary() {
    final totalSpent = _summary['total_spent'] ?? 0.0;
    final completedJobs = _summary['completed_jobs'] ?? 0;
    final averageRating = _summary['average_rating_given'] ?? 0.0;
    final totalJobs = _summary['total_jobs'] ?? 0;

    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            'Total Spent',
            '₱${totalSpent.toStringAsFixed(2)}',
            Icons.payment,
            Colors.green,
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: _buildSummaryCard(
            'Completed',
            '$completedJobs',
            Icons.check_circle,
            Colors.blue,
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: _buildSummaryCard(
            'Total Jobs',
            '$totalJobs',
            Icons.work,
            Colors.orange,
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: _buildSummaryCard(
            'Avg Rating',
            '${averageRating.toStringAsFixed(1)}⭐',
            Icons.star,
            Colors.amber,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedJobHistoryItem(MechanicJobHistory job) {
    final displayData = job.displaySummary;
    
    // Status color
    Color statusColor = Colors.grey;
    switch (job.jobStatus) {
      case 'completed':
        statusColor = Colors.green;
        break;
      case 'in_progress':
        statusColor = Colors.blue;
        break;
      case 'cancelled':
        statusColor = Colors.red;
        break;
      case 'pending':
        statusColor = Colors.orange;
        break;
    }

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with job title and status
          Row(
            children: [
              Expanded(
                child: Text(
                  job.jobTitle,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  displayData['status'],
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          
          SizedBox(height: 8),
          
          // Customer info
          Row(
            children: [
              Icon(Icons.person, size: 16, color: Colors.blue[600]),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  displayData['customer'],
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          
          SizedBox(height: 6),
          
          // Location info
          if (displayData['hasLocation']) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.location_on, size: 16, color: Colors.red[600]),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    displayData['shortLocation'],
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[700],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            SizedBox(height: 6),
          ],
          
          // Date and earnings row (updated for Angkas-style display)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.schedule, size: 16, color: Colors.grey[600]),
                  SizedBox(width: 6),
                  Text(
                    displayData['date'],
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Show mechanic earnings with "You earned" format
                  if (job.totalAmount != null && job.totalAmount! > 0) ...[
                    // Calculate Angkas-style earnings (75% of total)
                    Builder(builder: (context) {
                      final totalAmount = job.totalAmount!;
                      final mechanicEarnings = totalAmount * 0.75; // 75% to mechanic
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'You earned ₱${mechanicEarnings.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Colors.green[700],
                            ),
                          ),
                          Text(
                            'Total: ${displayData['amount']}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      );
                    }),
                  ] else ...[
                    Text(
                      displayData['amount'],
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.green[700],
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          
          // Additional details for completed jobs including earnings breakdown
          if (job.jobStatus == 'completed' && job.totalAmount != null && job.totalAmount! > 0) ...[
            SizedBox(height: 8),
            // Earnings breakdown section
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withOpacity(0.2)),
              ),
              child: Column(
                children: [
                  // Job duration and rating row
                  if (job.jobDurationMinutes != null || job.rating != null) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (job.jobDurationMinutes != null)
                          Row(
                            children: [
                              Icon(Icons.timer, size: 14, color: Colors.green[600]),
                              SizedBox(width: 4),
                              Text(
                                'Duration: ${displayData['duration']}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.green[700],
                                ),
                              ),
                            ],
                          ),
                        if (job.rating != null)
                          Row(
                            children: [
                              Icon(Icons.star, size: 14, color: Colors.amber),
                              SizedBox(width: 2),
                              Text(
                                '${job.rating!.toStringAsFixed(1)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                    SizedBox(height: 8),
                  ],
                  
                  // Angkas-style earnings breakdown
                  Builder(builder: (context) {
                    final totalAmount = job.totalAmount!;
                    final mechanicEarnings = totalAmount * 0.75; // 75% to mechanic
                    final shopEarnings = totalAmount * 0.20;     // 20% to shop
                    final platformFee = totalAmount * 0.05;      // 5% platform fee
                    
                    return Column(
                      children: [
                        // Total amount row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Service Total:',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[700],
                              ),
                            ),
                            Text(
                              '₱${totalAmount.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                        Divider(height: 8, thickness: 0.5),
                        
                        // Mechanic earnings (highlighted)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'You earned (75%):',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.green[700],
                              ),
                            ),
                            Text(
                              '₱${mechanicEarnings.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.green[700],
                              ),
                            ),
                          ],
                        ),
                        
                        // Shop earnings
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Shop share (20%):',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                              ),
                            ),
                            Text(
                              '₱${shopEarnings.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        
                        // Platform fee
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Service fee (5%):',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                              ),
                            ),
                            Text(
                              '₱${platformFee.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ] else if (job.jobStatus == 'completed' && job.jobDurationMinutes != null) ...[
            // Fallback for jobs without amount data
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.timer, size: 14, color: Colors.green[600]),
                      SizedBox(width: 4),
                      Text(
                        'Duration: ${displayData['duration']}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green[700],
                        ),
                      ),
                    ],
                  ),
                  if (job.rating != null)
                    Row(
                      children: [
                        Icon(Icons.star, size: 14, color: Colors.amber),
                        SizedBox(width: 2),
                        Text(
                          '${job.rating!.toStringAsFixed(1)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTransactionItem(Map<String, dynamic> transaction) {
    final type = transaction['type'];
    final title = transaction['title'];
    final amount = transaction['amount'];
    final status = transaction['status'];
    final date = transaction['date'] as DateTime;
    final netEarnings = transaction['net_earnings'];

    // Colors based on type and status
    Color statusColor = Colors.grey;
    IconData icon = Icons.receipt;
    
    if (type == 'invoice') {
      icon = Icons.receipt_long;
      switch (status) {
        case 'paid':
          statusColor = Colors.green;
          break;
        case 'pending':
        case 'sent':
          statusColor = Colors.orange;
          break;
        case 'disputed':
          statusColor = Colors.red;
          break;
        case 'cancelled':
          statusColor = Colors.grey;
          break;
      }
    } else if (type == 'job') {
      icon = Icons.build;
      switch (status) {
        case 'completed':
          statusColor = Colors.green;
          break;
        case 'in_progress':
          statusColor = Colors.blue;
          break;
        case 'cancelled':
          statusColor = Colors.red;
          break;
        case 'pending':
          statusColor = Colors.orange;
          break;
      }
    }

    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: statusColor, size: 20),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  '${date.day}/${date.month}/${date.year}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (amount != null) ...[
                Text(
                  '₱${amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                if (widget.isMechanic && netEarnings != null)
                  Text(
                    'Net: ₱${netEarnings.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: Colors.green[600],
                      fontSize: 10,
                    ),
                  ),
              ],
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Easy-to-use static methods for showing history bottom sheets
class HistoryBottomSheet {
  static void showMechanicHistory(BuildContext context, {String? title, int? maxItems}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (_, controller) => SingleChildScrollView(
          controller: controller,
          child: HistoryBottomSheetWidget(
            isMechanic: true,
            title: title ?? 'Mechanic Earnings & History',
            maxItems: maxItems,
          ),
        ),
      ),
    );
  }

  static void showCustomerHistory(BuildContext context, {String? title, int? maxItems}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (_, controller) => SingleChildScrollView(
          controller: controller,
          child: HistoryBottomSheetWidget(
            isMechanic: false,
            title: title ?? 'Service History',
            maxItems: maxItems,
          ),
        ),
      ),
    );
  }
}