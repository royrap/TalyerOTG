import 'package:flutter/material.dart';
import '../services/mechanic_history_service.dart';
import '../models/job_history.dart';
import '../screens/service_history_detail_screen.dart';
import 'package:intl/intl.dart';

class MechanicJobHistoryScreen extends StatefulWidget {
  const MechanicJobHistoryScreen({Key? key}) : super(key: key);

  @override
  State<MechanicJobHistoryScreen> createState() => _MechanicJobHistoryScreenState();
}

class _MechanicJobHistoryScreenState extends State<MechanicJobHistoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  bool _isLoading = true;
  List<MechanicJobHistory> _allJobs = [];
  List<MechanicJobHistory> _completedJobs = [];
  List<MechanicJobHistory> _cancelledJobs = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadJobHistory();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadJobHistory() async {
    try {
      setState(() => _isLoading = true);
      
      final futures = await Future.wait([
        MechanicHistoryService.instance.getMechanicJobHistory(),
        MechanicHistoryService.instance.getJobHistoryByStatus('completed'),
        MechanicHistoryService.instance.getJobHistoryByStatus('cancelled'),
      ]);
      
      setState(() {
        _allJobs = futures[0] as List<MechanicJobHistory>;
        _completedJobs = futures[1] as List<MechanicJobHistory>;
        _cancelledJobs = futures[2] as List<MechanicJobHistory>;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Error loading job history: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load job history'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<MechanicJobHistory> _getFilteredJobs() {
    List<MechanicJobHistory> jobs = [];
    
    switch (_tabController.index) {
      case 0:
        jobs = _allJobs;
        break;
      case 1:
        jobs = _completedJobs;
        break;
      case 2:
        jobs = _cancelledJobs;
        break;
    }
    
    // Apply search filter
    final query = _searchController.text.toLowerCase();
    if (query.isNotEmpty) {
      jobs = jobs.where((job) {
        return job.jobTitle.toLowerCase().contains(query) ||
               job.customerDisplayName.toLowerCase().contains(query) ||
               job.customerLocation.toLowerCase().contains(query);
      }).toList();
    }
    
    return jobs;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Job History',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(100),
          child: Column(
            children: [
              // Search bar
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search jobs, customers, locations...',
                    prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),
              // Tab bar
              TabBar(
                controller: _tabController,
                onTap: (index) => setState(() {}),
                labelColor: Colors.blue[700],
                unselectedLabelColor: Colors.grey[600],
                indicatorColor: Colors.blue[700],
                indicatorWeight: 2,
                tabs: [
                  Tab(text: 'All Jobs (${_allJobs.length})'),
                  Tab(text: 'Completed (${_completedJobs.length})'),
                  Tab(text: 'Cancelled (${_cancelledJobs.length})'),
                ],
              ),
            ],
          ),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Summary cards
                _buildSummaryCards(),
                
                // Job list
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _loadJobHistory,
                    child: _buildJobList(),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSummaryCards() {
    // Summary cards removed - stats now shown in profile tab
    return SizedBox.shrink();
  }

  Widget _buildJobList() {
    final jobs = _getFilteredJobs();
    
    if (jobs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.work_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            SizedBox(height: 16),
            Text(
              _searchController.text.isNotEmpty 
                  ? 'No jobs match your search'
                  : 'No job history yet',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 8),
            Text(
              _searchController.text.isNotEmpty
                  ? 'Try different search terms'
                  : 'Complete some jobs to see your history here',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: jobs.length,
      itemBuilder: (context, index) {
        final job = jobs[index];
        return _buildEnhancedJobCard(job);
      },
    );
  }

  Widget _buildEnhancedJobCard(MechanicJobHistory job) {
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

    return GestureDetector(
      onTap: () {
        // Navigate to detailed view
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ServiceHistoryDetailScreen(
              requestId: job.serviceRequestId,
            ),
          ),
        );
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 16),
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.08),
              spreadRadius: 1,
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job.jobTitle,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 18,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      displayData['fullDate'],
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  displayData['status'],
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          
          SizedBox(height: 16),
          
          // Customer info card
          Container(
            padding: EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.withOpacity(0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.person, size: 18, color: Colors.blue[700]),
                    SizedBox(width: 8),
                    Text(
                      'Customer Details',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.blue[700],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  displayData['customer'],
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (displayData['customerPhone'].isNotEmpty) ...[
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.phone, size: 14, color: Colors.grey[600]),
                      SizedBox(width: 6),
                      Text(
                        displayData['customerPhone'],
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          
          SizedBox(height: 12),
          
          // Debug logging for vehicle data
          Builder(
            builder: (context) {
              print('🔍 UI Check - Job: ${job.jobTitle}');
              print('   serviceRequest: ${job.serviceRequest}');
              print('   vehicleBrand: ${job.serviceRequest?.vehicleBrand}');
              print('   vehicleModel: ${job.serviceRequest?.vehicleModel}');
              print('   vehiclePlate: ${job.serviceRequest?.vehiclePlate}');
              return SizedBox.shrink();
            },
          ),
          
          // Vehicle info - SAME STYLE AS INVOICE
          if (job.serviceRequest?.vehicleBrand != null && 
              job.serviceRequest?.vehicleModel != null) ...[
            Row(
              children: [
                Icon(Icons.directions_car, size: 16, color: Colors.grey[600]),
                SizedBox(width: 6),
                Text(
                  '${job.serviceRequest!.vehicleBrand} ${job.serviceRequest!.vehicleModel} - ${job.serviceRequest!.vehiclePlate ?? "N/A"}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
          ],
          
          // Location info
          if (displayData['hasLocation']) ...[
            Container(
              padding: EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withOpacity(0.1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 18, color: Colors.red[700]),
                      SizedBox(width: 8),
                      Text(
                        'Service Location',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.red[700],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    displayData['location'],
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 12),
          ],
          
          // Earnings info
          Container(
            padding: EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.withOpacity(0.1)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.monetization_on, size: 18, color: Colors.red[700]),
                        SizedBox(width: 8),
                        Text(
                          'Earnings',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.red[700],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Total: ${displayData['amount']}',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.black87,
                      ),
                    ),
                    if (job.netEarnings != null)
                      Text(
                        'You earned: ${displayData['netEarnings']}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.red[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
                if (job.jobStatus == 'completed' && job.jobDurationMinutes != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.timer, size: 16, color: Colors.grey[600]),
                          SizedBox(width: 4),
                          Text(
                            displayData['duration'],
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                      if (job.rating != null) ...[
                        SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.star, size: 16, color: Colors.amber),
                            SizedBox(width: 4),
                            Text(
                              '${job.rating!.toStringAsFixed(1)}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
              ],
            ),
          ),
          
          // Additional job details
          if (job.jobDescription != null && job.jobDescription!.isNotEmpty) ...[
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.withOpacity(0.1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.description, size: 16, color: Colors.grey[600]),
                      SizedBox(width: 8),
                      Text(
                        'Job Description',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[700],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    job.jobDescription!,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      ),
    );
  }
}