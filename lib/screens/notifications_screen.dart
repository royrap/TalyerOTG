import 'package:flutter/material.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final List<Map<String, dynamic>> _mockNotifications = [
    {
      'id': '1',
      'title': 'Service Request Accepted',
      'body': 'Your tire change request has been accepted by Quick Fix Mechanics',
      'type': 'service',
      'read': false,
      'created_at': '2025-06-08T10:30:00Z',
    },
    {
      'id': '2',
      'title': 'Payment Confirmation',
      'body': 'Payment of ₱50.00 has been processed successfully',
      'type': 'payment',
      'read': true,
      'created_at': '2025-06-07T15:45:00Z',
    },
  ];

  void _markAsRead(String notificationId) {
    setState(() {
      final notification = _mockNotifications.firstWhere(
        (n) => n['id'] == notificationId,
      );
      notification['read'] = true;
    });
  }

  void _markAllAsRead() {
    setState(() {
      for (var notification in _mockNotifications) {
        notification['read'] = true;
      }
    });
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'service':
        return Icons.build;
      case 'payment':
        return Icons.payment;
      default:
        return Icons.notifications;
    }
  }

  Color _getNotificationColor(String type) {
    switch (type) {
      case 'service':
        return const Color.fromARGB(255, 176, 12, 1);
      case 'payment':
        return Colors.green;
      default:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _mockNotifications.where((n) => !n['read']).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: const Color.fromARGB(255, 176, 12, 1),
        foregroundColor: Colors.white,
        actions: [
          if (unreadCount > 0)
            TextButton(
              onPressed: _markAllAsRead,
              child: const Text(
                'Mark All Read',
                style: TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: _mockNotifications.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_none,
                    size: 64,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No notifications yet',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'You\'ll receive notifications about your services here',
                    style: TextStyle(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: _mockNotifications.length,
              itemBuilder: (context, index) {
                final notification = _mockNotifications[index];
                final isUnread = !notification['read'];

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  color: isUnread ? Colors.blue.shade50 : null,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _getNotificationColor(notification['type']),
                      child: Icon(
                        _getNotificationIcon(notification['type']),
                        color: Colors.white,
                      ),
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification['title'],
                            style: TextStyle(
                              fontWeight: isUnread 
                                  ? FontWeight.bold 
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                        if (isUnread)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(notification['body']),
                        const SizedBox(height: 4),
                        Text(
                          notification['created_at'],
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    onTap: () {
                      if (isUnread) {
                        _markAsRead(notification['id']);
                      }
                    },
                  ),
                );
              },
            ),
    );
  }
}










