import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/service_history_detail.dart';
import '../services/service_history_detail_service.dart';

class ServiceHistoryDetailScreen extends StatefulWidget {
  final String requestId;

  const ServiceHistoryDetailScreen({
    Key? key,
    required this.requestId,
  }) : super(key: key);

  @override
  State<ServiceHistoryDetailScreen> createState() => _ServiceHistoryDetailScreenState();
}

class _ServiceHistoryDetailScreenState extends State<ServiceHistoryDetailScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  ServiceHistoryDetail? _detail;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final detail = await ServiceHistoryDetailService.instance.getServiceRequestDetail(widget.requestId);

      setState(() {
        _detail = detail;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load service details: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Service Details',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Loading service details...',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
              SizedBox(height: 16),
              Text(
                'Error Loading Details',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
              SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadDetails,
                icon: Icon(Icons.refresh),
                label: Text('Retry'),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_detail == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text(
              'No details available',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadDetails,
      child: SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildServiceHeader(),
            SizedBox(height: 16),
            if (_detail!.hasMechanic) ...[
              _buildMechanicCard(),
              SizedBox(height: 16),
            ],
            if (_detail!.hasShop) ...[
              _buildShopCard(),
              SizedBox(height: 16),
            ],
            _buildDatesCard(),
            SizedBox(height: 16),
            if (_detail!.hasVehicle) ...[
              _buildVehicleCard(),
              SizedBox(height: 16),
            ],
            _buildServiceDetailsCard(),
            SizedBox(height: 16),
            if (_detail!.hasInvoice) ...[
              _buildPaymentCard(),
              SizedBox(height: 16),
            ],
            if (_detail!.hasReview) ...[
              _buildReviewCard(),
              SizedBox(height: 16),
            ],
            if (_detail!.rejectionReason != null || _detail!.mechanicReport != null) ...[
              _buildAdditionalInfoCard(),
              SizedBox(height: 16),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildServiceHeader() {
    Color statusColor = _getStatusColor(_detail!.status);

    return Container(
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
          Row(
            children: [
              Expanded(
                child: Text(
                  _detail!.title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _detail!.statusDisplay,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (_detail!.description.isNotEmpty) ...[
            SizedBox(height: 12),
            Text(
              _detail!.description,
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey[700],
              ),
            ),
          ],
          if (_detail!.serviceCategory != null) ...[
            SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  _getCategoryIcon(_detail!.serviceCategoryIcon),
                  size: 18,
                  color: Colors.blue[700],
                ),
                SizedBox(width: 8),
                Text(
                  _detail!.serviceCategory!,
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.blue[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMechanicCard() {
    return Container(
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
          Row(
            children: [
              Icon(Icons.engineering, size: 24, color: Colors.blue[700]),
              SizedBox(width: 12),
              Text(
                'Mechanic Information',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Row(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: Colors.blue[100],
                backgroundImage: _detail!.mechanicProfileImage != null
                    ? NetworkImage(_detail!.mechanicProfileImage!)
                    : null,
                child: _detail!.mechanicProfileImage == null
                    ? Icon(Icons.person, size: 32, color: Colors.blue[700])
                    : null,
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _detail!.mechanicFullName,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    if (_detail!.mechanicPhone != null) ...[
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.phone, size: 14, color: Colors.grey[600]),
                          SizedBox(width: 6),
                          Text(
                            _detail!.mechanicPhone!,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (_detail!.mechanicEmail != null) ...[
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.email_outlined, size: 14, color: Colors.grey[600]),
                          SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              _detail!.mechanicEmail!,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[700],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildShopCard() {
    return Container(
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
          Row(
            children: [
              Icon(Icons.store, size: 24, color: Colors.red[700]),
              SizedBox(width: 12),
              Text(
                'Shop Information',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Text(
            _detail!.shopName!,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          if (_detail!.shopAddress != null) ...[
            SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _detail!.shopAddress!,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (_detail!.shopPhone != null) ...[
            SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.phone, size: 16, color: Colors.grey[600]),
                SizedBox(width: 6),
                Text(
                  _detail!.shopPhone!,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ],
          if (_detail!.shopEmail != null) ...[
            SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.email_outlined, size: 16, color: Colors.grey[600]),
                SizedBox(width: 6),
                Text(
                  _detail!.shopEmail!,
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
    );
  }

  Widget _buildDatesCard() {
    return Container(
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
          Row(
            children: [
              Icon(Icons.schedule, size: 24, color: Colors.orange[700]),
              SizedBox(width: 12),
              Text(
                'Service Timeline',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          _buildDateRow('Request Date', _detail!.createdAt, Icons.calendar_today),
          if (_detail!.serviceStartTime != null) ...[
            SizedBox(height: 12),
            _buildDateRow('Service Started', _detail!.serviceStartTime!, Icons.play_circle_outline),
          ],
          if (_detail!.serviceCompletionTime != null) ...[
            SizedBox(height: 12),
            _buildDateRow('Service Completed', _detail!.serviceCompletionTime!, Icons.check_circle_outline),
          ],
          if (_detail!.completedAt != null) ...[
            SizedBox(height: 12),
            _buildDateRow('Completed At', _detail!.completedAt!, Icons.done_all),
          ],
          if (_detail!.cancelledAt != null) ...[
            SizedBox(height: 12),
            _buildDateRow('Cancelled At', _detail!.cancelledAt!, Icons.cancel_outlined),
          ],
        ],
      ),
    );
  }

  Widget _buildDateRow(String label, DateTime date, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        SizedBox(width: 8),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                DateFormat('MMM dd, yyyy • hh:mm a').format(date),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVehicleCard() {
    return Container(
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
          Row(
            children: [
              Icon(Icons.directions_car, size: 24, color: Colors.green[700]),
              SizedBox(width: 12),
              Text(
                'Vehicle Information',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Text(
            _detail!.vehicleFullName,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          if (_detail!.vehiclePlate != null) ...[
            SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.confirmation_number, size: 16, color: Colors.grey[600]),
                SizedBox(width: 6),
                Text(
                  'Plate: ${_detail!.vehiclePlate}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ],
          if (_detail!.vehicleYear != null) ...[
            SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.event, size: 16, color: Colors.grey[600]),
                SizedBox(width: 6),
                Text(
                  'Year: ${_detail!.vehicleYear}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ],
          if (_detail!.vehicleColor != null) ...[
            SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.palette, size: 16, color: Colors.grey[600]),
                SizedBox(width: 6),
                Text(
                  'Color: ${_detail!.vehicleColor}',
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
    );
  }

  Widget _buildServiceDetailsCard() {
    return Container(
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
          Row(
            children: [
              Icon(Icons.build, size: 24, color: Colors.purple[700]),
              SizedBox(width: 12),
              Text(
                'Service Details',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          if (_detail!.estimatedPrice != null) ...[
            _buildInfoRow('Estimated Price', '₱${_detail!.estimatedPrice!.toStringAsFixed(2)}'),
            SizedBox(height: 8),
          ],
          if (_detail!.finalPrice != null) ...[
            _buildInfoRow('Final Price', '₱${_detail!.finalPrice!.toStringAsFixed(2)}'),
            SizedBox(height: 8),
          ],
          if (_detail!.distanceKm != null) ...[
            _buildInfoRow('Distance', '${_detail!.distanceKm!.toStringAsFixed(2)} km'),
            SizedBox(height: 8),
          ],
          if (_detail!.pickupAddress != null) ...[
            SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _detail!.pickupAddress!,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPaymentCard() {
    return Container(
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
          Row(
            children: [
              Icon(Icons.payment, size: 24, color: Colors.green[700]),
              SizedBox(width: 12),
              Text(
                'Payment Information',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          if (_detail!.invoiceNumber != null) ...[
            _buildInfoRow('Invoice Number', _detail!.invoiceNumber!),
            SizedBox(height: 12),
          ],
          if (_detail!.subtotal != null) ...[
            _buildInfoRow('Subtotal', '₱${_detail!.subtotal!.toStringAsFixed(2)}'),
            SizedBox(height: 8),
          ],
          if (_detail!.platformFee != null && _detail!.platformFee! > 0) ...[
            _buildInfoRow('Platform Fee', '₱${_detail!.platformFee!.toStringAsFixed(2)}'),
            SizedBox(height: 8),
          ],
          Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Amount',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              Text(
                _detail!.formattedTotalAmount,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[700],
                ),
              ),
            ],
          ),
          if (_detail!.paymentMethod != null) ...[
            SizedBox(height: 12),
            _buildInfoRow('Payment Method', _detail!.paymentMethod!.toUpperCase()),
          ],
          if (_detail!.paymentStatus != null) ...[
            SizedBox(height: 8),
            _buildInfoRow('Payment Status', _detail!.paymentStatus!.split('_').map((w) => w[0].toUpperCase() + w.substring(1)).join(' ')),
          ],
          if (_detail!.paidAt != null) ...[
            SizedBox(height: 8),
            _buildInfoRow('Paid At', DateFormat('MMM dd, yyyy • hh:mm a').format(_detail!.paidAt!)),
          ],
          // Cash Payment Proof Image (for mechanic to view)
          if (_detail!.paymentProofUrl != null && _detail!.paymentProofUrl!.isNotEmpty) ...[
            SizedBox(height: 16),
            Divider(),
            SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.camera_alt, size: 20, color: Colors.blue[700]),
                SizedBox(width: 8),
                Text(
                  'Cash Payment Proof',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue[700],
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            GestureDetector(
              onTap: () => _showPaymentProofFullScreen(_detail!.paymentProofUrl!),
              child: Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    _detail!.paymentProofUrl!,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                              : null,
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.broken_image, size: 48, color: Colors.grey),
                            SizedBox(height: 8),
                            Text('Failed to load image', style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Tap image to view full screen',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ],
      ),
    );
  }

  void _showPaymentProofFullScreen(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            // Full screen image
            InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4.0,
              child: Center(
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    );
                  },
                ),
              ),
            ),
            // Close button
            Positioned(
              top: 40,
              right: 16,
              child: IconButton(
                icon: Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            // Download/Open URL hint
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  'Pinch to zoom • Swipe to pan',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewCard() {
    return Container(
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
          Row(
            children: [
              Icon(Icons.star, size: 24, color: Colors.amber[700]),
              SizedBox(width: 12),
              Text(
                'Customer Review',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Row(
            children: [
              ...List.generate(5, (index) {
                return Icon(
                  index < (_detail!.rating ?? 0).floor()
                      ? Icons.star
                      : Icons.star_border,
                  color: Colors.amber,
                  size: 24,
                );
              }),
              SizedBox(width: 12),
              Text(
                '${_detail!.rating!.toStringAsFixed(1)} / 5.0',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          if (_detail!.reviewComment != null && _detail!.reviewComment!.isNotEmpty) ...[
            SizedBox(height: 12),
            Text(
              _detail!.reviewComment!,
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey[700],
              ),
            ),
          ],
          if (_detail!.reviewDate != null) ...[
            SizedBox(height: 12),
            Text(
              DateFormat('MMM dd, yyyy').format(_detail!.reviewDate!),
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAdditionalInfoCard() {
    return Container(
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
          Row(
            children: [
              Icon(Icons.info_outline, size: 24, color: Colors.grey[700]),
              SizedBox(width: 12),
              Text(
                'Additional Information',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          if (_detail!.rejectionReason != null) ...[
            Text(
              'Rejection Reason:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.red[700],
              ),
            ),
            SizedBox(height: 4),
            Text(
              _detail!.rejectionReason!,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
            SizedBox(height: 16),
          ],
          if (_detail!.mechanicReport != null) ...[
            Text(
              'Mechanic Report:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.blue[700],
              ),
            ),
            SizedBox(height: 4),
            Text(
              _detail!.mechanicReport!,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'in_progress':
        return Colors.blue;
      case 'cancelled':
        return Colors.red;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _getCategoryIcon(String? iconName) {
    if (iconName == null) return Icons.build;
    switch (iconName.toLowerCase()) {
      case 'tire':
        return Icons.circle_outlined;
      case 'engine':
        return Icons.settings;
      case 'battery':
        return Icons.battery_charging_full;
      case 'brake':
        return Icons.car_repair;
      default:
        return Icons.build;
    }
  }
}
