import 'package:flutter/material.dart';
import 'request_assistance_screen.dart';

class ServicesScreen extends StatelessWidget {
  const ServicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Services',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: const ServicesBody(),
      bottomNavigationBar: RoadAidBottomNavBar(
        currentIndex: 1,
        onTap: (index) {
          if (index != 1) {
            Navigator.pop(context);
            // Navigate to the selected tab
            // This would typically use a more sophisticated navigation approach
          }
        },
      ),
    );
  }
}

class ServicesBody extends StatelessWidget {
  const ServicesBody({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search bar
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search for services...',
                  hintStyle: TextStyle(color: Colors.grey[500]),
                  prefixIcon: Icon(Icons.search, color: Colors.grey[500]),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onChanged: (value) {
                  // Search functionality
                },
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Emergency Services section
            const Text(
              'Emergency Services',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Mechanical Repair Card
            ServiceCard(
              icon: Icons.build,
              iconColor: Colors.grey[700]!,
              title: 'Mechanical Repair',
              description: 'Engine issues, overheating, strange noises, and other mechanical problems',
              price: '₱500 - ₱5,000+',
              time: '30 - 120 mins',
              onFindMechanics: () {
                // Find mechanics
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Finding mechanics for Mechanical Repair...')),
                );
              },
              onRequestService: () {
                // Request service
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const RequestAssistanceScreen()),
                );
              },
            ),
            
            const SizedBox(height: 16),
            
            // Battery Services Card
            ServiceCard(
              icon: Icons.battery_charging_full,
              iconColor: Colors.red,
              title: 'Battery Services',
              description: 'Jump start, battery replacement, and electrical system diagnosis',
              price: '₱300 - ₱3,000',
              time: '15 - 45 mins',
              onFindMechanics: () {
                // Find mechanics
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Finding mechanics for Battery Services...')),
                );
              },
              onRequestService: () {
                // Request service
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const RequestAssistanceScreen()),
                );
              },
            ),
            
            const SizedBox(height: 16),
            
            // Tire Services Card
            ServiceCard(
              icon: Icons.tire_repair,
              iconColor: Colors.brown,
              title: 'Tire Services',
              description: 'Flat tire repair, tire replacement, and pressure check',
              price: '₱200 - ₱1,000+',
              time: '20 - 40 mins',
              onFindMechanics: () {
                // Find mechanics
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Finding mechanics for Tire Services...')),
                );
              },
              onRequestService: () {
                // Request service
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const RequestAssistanceScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class ServiceCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;
  final String price;
  final String time;
  final VoidCallback onFindMechanics;
  final VoidCallback onRequestService;
  
  const ServiceCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
    required this.price,
    required this.time,
    required this.onFindMechanics,
    required this.onRequestService,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row with icon
          Row(
            children: [
              Icon(icon, color: iconColor, size: 24),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          // Description
          Text(
            description,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Price and time row
          Row(
            children: [
              Text(
                'Price: $price',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                'Time: $time',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: onFindMechanics,
                style: TextButton.styleFrom(
                  foregroundColor: const Color.fromARGB(255, 176, 12, 1),
                  padding: EdgeInsets.zero,
                ),
                child: const Text(
                  'Find Mechanics',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: onRequestService,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 176, 12, 1),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                child: const Text('Request Service'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class RoadAidBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  
  const RoadAidBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      selectedItemColor: const Color.fromARGB(255, 176, 12, 1),
      unselectedItemColor: Colors.grey,
      currentIndex: currentIndex,
      onTap: onTap,
      items: [
        const BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: 'Home',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.miscellaneous_services),
          label: 'Services',
        ),
        BottomNavigationBarItem(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: const Color.fromARGB(255, 176, 12, 1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.location_on, color: Colors.white),
          ),
          label: 'Request',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.message),
          label: 'Messages',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: 'Profile',
        ),
      ],
    );
  }
}





















