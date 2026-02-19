import 'package:flutter/material.dart';
import '../screens/chat_screen.dart';

class MechanicDispatchedScreen extends StatefulWidget {
  final String? requestId;
  
  const MechanicDispatchedScreen({super.key, this.requestId});

  @override
  State<MechanicDispatchedScreen> createState() => _MechanicDispatchedScreenState();
}

class _MechanicDispatchedScreenState extends State<MechanicDispatchedScreen> {
  Map<String, dynamic>? _serviceRequest;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    if (widget.requestId != null) {
      _loadServiceRequest();
    } else {
      _isLoading = false;
    }
  }

  Future<void> _loadServiceRequest() async {
    try {
      // In a real app, you'd load the specific service request
      // For now, we'll use dummy data with loading delay
      await Future.delayed(const Duration(seconds: 2));
      
      _serviceRequest = {
        'id': widget.requestId,
        'issue_type': 'mechanical',
        'status': 'pending',
        'estimated_arrival': '15-20 minutes',
        'mechanic_name': 'Juan Tamad Auto Repair',
        'mechanic_phone': '+639171234567',
        'mechanic_rating': 4.8,
      };
    } catch (e) {
      print('Error loading service request: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Color.fromARGB(255, 176, 12, 1),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Mechanic Dispatched',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Mechanic info card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withAlpha(26),
                    spreadRadius: 1,
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.grey,
                        child: Icon(Icons.person, color: Colors.white, size: 30),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _serviceRequest?['mechanic_name'] ?? 'Pedro\'s Auto Repair',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.star, color: Color.fromARGB(255, 176, 12, 1), size: 16),
                                const SizedBox(width: 4),
                                Text(
                                  _serviceRequest?['mechanic_rating']?.toString() ?? '4.8',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  ' (124 reviews)',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '1.2 km away',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Arrival time
                  Row(
                    children: [
                      Icon(Icons.access_time, color: Colors.grey[600], size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Estimated arrival in ${_serviceRequest?['estimated_arrival'] ?? '15 minutes'}',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Vehicle info
                  Row(
                    children: [
                      Icon(Icons.directions_car, color: Colors.grey[600], size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'Mechanic is on their way in a white Toyota',
                        style: TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Service categories
                  Row(
                    children: [
                      ServiceChip(label: 'Mechanical'),
                      const SizedBox(width: 8),
                      ServiceChip(label: 'Electrical'),
                      const SizedBox(width: 8),
                      ServiceChip(label: 'Tires'),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Call and Message buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Calling Pedro\'s Auto Repair...')),
                            );
                          },
                          icon: const Icon(Icons.phone, color: Colors.black),
                          label: const Text(
                            'Call',
                            style: TextStyle(color: Colors.black),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: BorderSide(color: Colors.grey[300]!),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const ChatScreen(
                                  contactName: 'Pedro\'s Auto Repair',
                                  contactAvatar: 'P',
                                  lastSeen: 'Online',
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.message, color: Colors.white),
                          label: const Text(
                            'Message',
                            style: TextStyle(color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color.fromARGB(255, 176, 12, 1),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Payment information
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withAlpha(26),
                    spreadRadius: 1,
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Payment Information',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Pre-authorized amount',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      const Text(
                        '₱700.00',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 8),
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Payment method',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      const Text(
                        'GCash',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 8),
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Transaction ID',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      const Text(
                        'TXN-QKY2TJB',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 12),
                  
                  Text(
                    'Final charges will be processed after service completion. You will only be charged for services rendered.',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Location section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withAlpha(26),
                    spreadRadius: 1,
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Your Location',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Opening map...')),
                          );
                        },
                        child: const Text(
                          'View Map',
                          style: TextStyle(
                            color: const Color.fromARGB(255, 176, 12, 1),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Map placeholder
                  Container(
                    height: 150,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.location_on,
                            color: const Color.fromARGB(255, 176, 12, 1),
                            size: 40,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Your Location',
                            style: TextStyle(
                              color: Colors.grey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ServiceChip extends StatelessWidget {
  final String label;

  const ServiceChip({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.grey[700],
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}










