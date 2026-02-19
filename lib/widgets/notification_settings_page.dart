import 'package:flutter/material.dart';
import '../services/smart_notification_service.dart';

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({Key? key}) : super(key: key);

  @override
  State<NotificationSettingsPage> createState() => _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  // Notification preferences
  Map<NotificationCategory, bool> _categoryPreferences = {};
  bool _doNotDisturbEnabled = false;
  TimeOfDay _doNotDisturbStart = const TimeOfDay(hour: 22, minute: 0);
  TimeOfDay _doNotDisturbEnd = const TimeOfDay(hour: 8, minute: 0);
  int _maxNotificationsPerHour = 10;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _loadSettings();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    // Initialize with defaults
    for (final category in NotificationCategory.values) {
      _categoryPreferences[category] = true;
    }
    
    // TODO: Load actual preferences from storage
    
    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Notification Settings',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: Colors.purple))
          : FadeTransition(
              opacity: _fadeAnimation,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Quick Settings
                  _buildQuickSettingsCard(),
                  
                  const SizedBox(height: 20),
                  
                  // Do Not Disturb
                  _buildDoNotDisturbCard(),
                  
                  const SizedBox(height: 20),
                  
                  // Notification Categories
                  _buildCategoriesCard(),
                  
                  const SizedBox(height: 20),
                  
                  // Advanced Settings
                  _buildAdvancedSettingsCard(),
                  
                  const SizedBox(height: 100),
                ],
              ),
            ),
    );
  }

  Widget _buildQuickSettingsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF6A1B9A), Color(0xFF8E24AA)],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.flash_on, color: Colors.white, size: 24),
                SizedBox(width: 12),
                Text(
                  'Quick Settings',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // All Notifications Toggle
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'All Notifications',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Enable all notification types',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _categoryPreferences.values.every((enabled) => enabled),
                    onChanged: (value) => _toggleAllNotifications(value),
                    activeColor: Colors.white,
                    activeTrackColor: Colors.white.withOpacity(0.3),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Important Only Toggle
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Important Only',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Only urgent and service updates',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _isImportantOnlyMode(),
                    onChanged: (value) => _setImportantOnlyMode(value),
                    activeColor: Colors.white,
                    activeTrackColor: Colors.white.withOpacity(0.3),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDoNotDisturbCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bedtime, color: Colors.indigo[600], size: 24),
                const SizedBox(width: 12),
                const Text(
                  'Do Not Disturb',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Do Not Disturb Toggle
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Enable Do Not Disturb',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Silence non-urgent notifications',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _doNotDisturbEnabled,
                  onChanged: (value) {
                    setState(() {
                      _doNotDisturbEnabled = value;
                    });
                    _saveSettings();
                  },
                  activeColor: Colors.indigo,
                ),
              ],
            ),
            
            if (_doNotDisturbEnabled) ...[
              const SizedBox(height: 20),
              
              // Time Range
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Quiet Hours',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    
                    const SizedBox(height: 12),
                    
                    Row(
                      children: [
                        Expanded(
                          child: _buildTimeSelector(
                            label: 'From',
                            time: _doNotDisturbStart,
                            onChanged: (time) {
                              setState(() {
                                _doNotDisturbStart = time;
                              });
                              _saveSettings();
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildTimeSelector(
                            label: 'Until',
                            time: _doNotDisturbEnd,
                            onChanged: (time) {
                              setState(() {
                                _doNotDisturbEnd = time;
                              });
                              _saveSettings();
                            },
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
      ),
    );
  }

  Widget _buildTimeSelector({
    required String label,
    required TimeOfDay time,
    required Function(TimeOfDay) onChanged,
  }) {
    return GestureDetector(
      onTap: () async {
        final selectedTime = await showTimePicker(
          context: context,
          initialTime: time,
        );
        if (selectedTime != null) {
          onChanged(selectedTime);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              time.format(context),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoriesCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.category, color: Colors.orange[600], size: 24),
                const SizedBox(width: 12),
                const Text(
                  'Notification Types',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            ...NotificationCategory.values.map((category) => 
              _buildCategoryItem(category)).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryItem(NotificationCategory category) {
    final isEnabled = _categoryPreferences[category] ?? true;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _getCategoryColor(category).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _getCategoryIcon(category),
              color: _getCategoryColor(category),
              size: 20,
            ),
          ),
          
          const SizedBox(width: 16),
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getCategoryTitle(category),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  _getCategoryDescription(category),
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          
          Switch(
            value: isEnabled,
            onChanged: (value) {
              setState(() {
                _categoryPreferences[category] = value;
              });
              SmartNotificationService.instance.updateCategoryPreference(category, value);
              _saveSettings();
            },
            activeColor: _getCategoryColor(category),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedSettingsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.tune, color: Colors.teal[600], size: 24),
                const SizedBox(width: 12),
                const Text(
                  'Advanced Settings',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // Rate Limiting
            const Text(
              'Notification Frequency',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            
            const SizedBox(height: 8),
            
            Text(
              'Maximum $_maxNotificationsPerHour notifications per hour',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            
            Slider(
              value: _maxNotificationsPerHour.toDouble(),
              min: 1,
              max: 20,
              divisions: 19,
              label: '$_maxNotificationsPerHour per hour',
              onChanged: (value) {
                setState(() {
                  _maxNotificationsPerHour = value.round();
                });
                SmartNotificationService.instance.setRateLimit(
                  _maxNotificationsPerHour,
                  const Duration(minutes: 5),
                );
                _saveSettings();
              },
              activeColor: Colors.teal,
            ),
            
            const SizedBox(height: 20),
            
            // Test Notification Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _sendTestNotification,
                icon: const Icon(Icons.notifications, color: Colors.white),
                label: const Text(
                  'Send Test Notification',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getCategoryColor(NotificationCategory category) {
    switch (category) {
      case NotificationCategory.serviceUpdate:
        return Colors.blue;
      case NotificationCategory.progressPhoto:
        return Colors.purple;
      case NotificationCategory.etaUpdate:
        return Colors.green;
      case NotificationCategory.paymentRequired:
        return Colors.orange;
      case NotificationCategory.mechanicArrival:
        return Colors.teal;
      case NotificationCategory.serviceComplete:
        return Colors.lightGreen;
      case NotificationCategory.emergency:
        return Colors.red;
      case NotificationCategory.promotional:
        return Colors.indigo;
    }
  }

  IconData _getCategoryIcon(NotificationCategory category) {
    switch (category) {
      case NotificationCategory.serviceUpdate:
        return Icons.build;
      case NotificationCategory.progressPhoto:
        return Icons.camera_alt;
      case NotificationCategory.etaUpdate:
        return Icons.schedule;
      case NotificationCategory.paymentRequired:
        return Icons.payment;
      case NotificationCategory.mechanicArrival:
        return Icons.directions_car;
      case NotificationCategory.serviceComplete:
        return Icons.check_circle;
      case NotificationCategory.emergency:
        return Icons.warning;
      case NotificationCategory.promotional:
        return Icons.local_offer;
    }
  }

  String _getCategoryTitle(NotificationCategory category) {
    switch (category) {
      case NotificationCategory.serviceUpdate:
        return 'Service Updates';
      case NotificationCategory.progressPhoto:
        return 'Progress Photos';
      case NotificationCategory.etaUpdate:
        return 'Arrival Updates';
      case NotificationCategory.paymentRequired:
        return 'Payment Reminders';
      case NotificationCategory.mechanicArrival:
        return 'Mechanic Arrival';
      case NotificationCategory.serviceComplete:
        return 'Service Complete';
      case NotificationCategory.emergency:
        return 'Emergency Alerts';
      case NotificationCategory.promotional:
        return 'Promotions & Offers';
    }
  }

  String _getCategoryDescription(NotificationCategory category) {
    switch (category) {
      case NotificationCategory.serviceUpdate:
        return 'Status changes and general updates';
      case NotificationCategory.progressPhoto:
        return 'Photos from your mechanic showing progress';
      case NotificationCategory.etaUpdate:
        return 'Real-time arrival time updates';
      case NotificationCategory.paymentRequired:
        return 'When payment is needed';
      case NotificationCategory.mechanicArrival:
        return 'When your mechanic arrives';
      case NotificationCategory.serviceComplete:
        return 'Service completion notifications';
      case NotificationCategory.emergency:
        return 'Critical safety alerts';
      case NotificationCategory.promotional:
        return 'Special deals and discounts';
    }
  }

  void _toggleAllNotifications(bool enabled) {
    setState(() {
      for (final category in NotificationCategory.values) {
        _categoryPreferences[category] = enabled;
      }
    });
    
    for (final category in NotificationCategory.values) {
      SmartNotificationService.instance.updateCategoryPreference(category, enabled);
    }
    
    _saveSettings();
  }

  bool _isImportantOnlyMode() {
    return _categoryPreferences[NotificationCategory.serviceUpdate] == true &&
           _categoryPreferences[NotificationCategory.mechanicArrival] == true &&
           _categoryPreferences[NotificationCategory.emergency] == true &&
           _categoryPreferences[NotificationCategory.paymentRequired] == true &&
           _categoryPreferences[NotificationCategory.progressPhoto] == false &&
           _categoryPreferences[NotificationCategory.etaUpdate] == false &&
           _categoryPreferences[NotificationCategory.serviceComplete] == false &&
           _categoryPreferences[NotificationCategory.promotional] == false;
  }

  void _setImportantOnlyMode(bool enabled) {
    setState(() {
      if (enabled) {
        _categoryPreferences[NotificationCategory.serviceUpdate] = true;
        _categoryPreferences[NotificationCategory.mechanicArrival] = true;
        _categoryPreferences[NotificationCategory.emergency] = true;
        _categoryPreferences[NotificationCategory.paymentRequired] = true;
        _categoryPreferences[NotificationCategory.progressPhoto] = false;
        _categoryPreferences[NotificationCategory.etaUpdate] = false;
        _categoryPreferences[NotificationCategory.serviceComplete] = false;
        _categoryPreferences[NotificationCategory.promotional] = false;
      } else {
        // Enable all
        for (final category in NotificationCategory.values) {
          _categoryPreferences[category] = true;
        }
      }
    });
    
    for (final category in NotificationCategory.values) {
      SmartNotificationService.instance.updateCategoryPreference(
        category, 
        _categoryPreferences[category]!,
      );
    }
    
    _saveSettings();
  }

  void _sendTestNotification() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🔔 Test notification sent!'),
        backgroundColor: Colors.green,
      ),
    );
    
    // TODO: Trigger a test notification through the service
  }

  void _saveSettings() {
    // TODO: Save settings to SharedPreferences or Supabase
    SmartNotificationService.instance.setDoNotDisturb(
      _doNotDisturbEnabled,
      _doNotDisturbStart,
      _doNotDisturbEnd,
    );
  }
}