import 'package:flutter/material.dart';
import '../services/marketplace_service.dart';

class ShopDetailsScreen extends StatefulWidget {
  final ShopWithServices shop;

  const ShopDetailsScreen({
    super.key,
    required this.shop,
  });

  @override
  State<ShopDetailsScreen> createState() => _ShopDetailsScreenState();
}

class _ShopDetailsScreenState extends State<ShopDetailsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.shop.shopName),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildShopHeader(),
            const SizedBox(height: 24),
            _buildContactInfo(),
            const SizedBox(height: 24),
            _buildBusinessHours(),
            const SizedBox(height: 24),
            _buildServicesSection(),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withAlpha(51),
              spreadRadius: 1,
              blurRadius: 5,
              offset: const Offset(0, -1),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: () {
            // Navigate to service request screen
            Navigator.pop(context);
            // You would navigate to ServiceRequestScreen here
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: const Text(
            'Request Service',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget _buildShopHeader() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.blue.withAlpha(26),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: widget.shop.shopImageUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            widget.shop.shopImageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(Icons.car_repair, size: 40, color: Colors.blue),
                          ),
                        )
                      : const Icon(Icons.car_repair, size: 40, color: Colors.blue),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.shop.shopName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 20),
                          const SizedBox(width: 4),
                          Text(
                            widget.shop.averageRating.toStringAsFixed(1),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            ' (${widget.shop.totalReviews} reviews)',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            widget.shop.isCurrentlyOpen ? Icons.access_time : Icons.access_time_filled,
                            size: 16,
                            color: widget.shop.isCurrentlyOpen ? Colors.green : Colors.red,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            widget.shop.isCurrentlyOpen ? 'Open Now' : 'Closed',
                            style: TextStyle(
                              color: widget.shop.isCurrentlyOpen ? Colors.green : Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (widget.shop.shopDescription != null) ...[
              const SizedBox(height: 16),
              Text(
                widget.shop.shopDescription!,
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 14,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildContactInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Contact Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (widget.shop.shopAddress != null)
              _buildContactItem(
                Icons.location_on,
                'Address',
                widget.shop.shopAddress!,
              ),
            if (widget.shop.contactPhone != null)
              _buildContactItem(
                Icons.phone,
                'Phone',
                widget.shop.contactPhone!,
              ),
            if (widget.shop.contactEmail != null)
              _buildContactItem(
                Icons.email,
                'Email',
                widget.shop.contactEmail!,
              ),
            _buildContactItem(
              Icons.route,
              'Distance',
              '${widget.shop.distanceKm.toStringAsFixed(1)} km away',
            ),
            _buildContactItem(
              Icons.attach_money,
              'Min Service Fee',
              '₱${widget.shop.minServiceFee.toStringAsFixed(0)}',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.blue),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBusinessHours() {
    if (widget.shop.businessHours == null) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Business Hours',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildBusinessHourItem('Monday', widget.shop.businessHours!['monday']),
            _buildBusinessHourItem('Tuesday', widget.shop.businessHours!['tuesday']),
            _buildBusinessHourItem('Wednesday', widget.shop.businessHours!['wednesday']),
            _buildBusinessHourItem('Thursday', widget.shop.businessHours!['thursday']),
            _buildBusinessHourItem('Friday', widget.shop.businessHours!['friday']),
            _buildBusinessHourItem('Saturday', widget.shop.businessHours!['saturday']),
            _buildBusinessHourItem('Sunday', widget.shop.businessHours!['sunday']),
          ],
        ),
      ),
    );
  }

  Widget _buildBusinessHourItem(String day, dynamic hours) {
    String timeText;
    if (hours['is_open'] == true) {
      timeText = '${hours['open']} - ${hours['close']}';
    } else {
      timeText = 'Closed';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              day,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Text(
            timeText,
            style: TextStyle(
              color: hours['is_open'] == true ? Colors.black : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServicesSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Available Services (${widget.shop.availableServices.length})',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...widget.shop.availableServices.map((service) => _buildServiceItem(service)),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceItem(ShopService service) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  service.serviceName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              Text(
                '₱${service.price.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          if (service.description != null) ...[
            const SizedBox(height: 4),
            Text(
              service.description!,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              if (service.estimatedDuration != null) ...[
                Icon(Icons.schedule, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  '${service.estimatedDuration} min',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 16),
              ],
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _getQualityColor(service.serviceQualityLevel).withAlpha(26),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  service.serviceQualityLevel.toUpperCase(),
                  style: TextStyle(
                    color: _getQualityColor(service.serviceQualityLevel),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (service.isFeatured) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.amber.withAlpha(26),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'FEATURED',
                    style: TextStyle(
                      color: Colors.orange,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Color _getQualityColor(String qualityLevel) {
    switch (qualityLevel.toLowerCase()) {
      case 'basic':
        return Colors.grey;
      case 'standard':
        return Colors.blue;
      case 'premium':
        return Colors.purple;
      case 'specialized':
        return Colors.green;
      default:
        return Colors.blue;
    }
  }
}










