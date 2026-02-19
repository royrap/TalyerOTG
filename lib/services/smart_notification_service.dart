import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../models/notification.dart';

enum NotificationPriority {
  low,
  normal,
  high,
  urgent,
}

enum NotificationCategory {
  serviceUpdate,
  progressPhoto,
  etaUpdate,
  paymentRequired,
  mechanicArrival,
  serviceComplete,
  emergency,
  promotional,
}

class SmartNotificationService {
  static final SmartNotificationService _instance = SmartNotificationService._internal();
  factory SmartNotificationService() => _instance;
  SmartNotificationService._internal();

  static SmartNotificationService get instance => _instance;

  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  
  // User preferences for smart filtering
  Map<NotificationCategory, bool> _categoryPreferences = {};
  Map<String, DateTime> _lastNotificationTime = {};
  Set<String> _mutedServiceRequests = {};
  
  // Smart notification settings
  Duration _minimumInterval = const Duration(minutes: 5);
  int _maxNotificationsPerHour = 10;
  bool _doNotDisturbEnabled = false;
  TimeOfDay _doNotDisturbStart = const TimeOfDay(hour: 22, minute: 0);
  TimeOfDay _doNotDisturbEnd = const TimeOfDay(hour: 8, minute: 0);

  Future<void> initialize() async {
    // Initialize local notifications
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );
    
    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Request permissions
    await _requestPermissions();
    
    // Load user preferences
    await _loadUserPreferences();
    
    // Set up Firebase messaging handlers
    _setupFirebaseHandlers();
  }

  Future<void> _requestPermissions() async {
    // Firebase messaging permissions
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
    );

    // Local notifications permissions for Android
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  void _setupFirebaseHandlers() {
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _processIncomingMessage(message, isFromBackground: false);
    });

    // Handle background messages
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _processIncomingMessage(message, isFromBackground: true);
    });
  }

  Future<void> _processIncomingMessage(RemoteMessage message, {bool isFromBackground = false}) async {
    // Parse notification data
    final notificationData = _parseNotificationData(message);
    
    // Apply smart filtering
    if (!await _shouldShowNotification(notificationData)) {
      return;
    }
    
    // Show smart notification
    await _showSmartNotification(notificationData, isFromBackground: isFromBackground);
    
    // Update analytics
    _updateNotificationAnalytics(notificationData);
  }

  NotificationData _parseNotificationData(RemoteMessage message) {
    final data = message.data;
    
    return NotificationData(
      id: data['id'] ?? '',
      title: message.notification?.title ?? data['title'] ?? '',
      message: message.notification?.body ?? data['message'] ?? '',
      category: _parseCategory(data['category'] ?? 'serviceUpdate'),
      priority: _parsePriority(data['priority'] ?? 'normal'),
      serviceRequestId: data['service_request_id'],
      mechanicId: data['mechanic_id'],
      customerId: data['customer_id'],
      imageUrl: data['image_url'],
      actionData: Map<String, dynamic>.from(data),
      timestamp: DateTime.now(),
    );
  }

  NotificationCategory _parseCategory(String category) {
    return NotificationCategory.values.firstWhere(
      (e) => e.name == category,
      orElse: () => NotificationCategory.serviceUpdate,
    );
  }

  NotificationPriority _parsePriority(String priority) {
    return NotificationPriority.values.firstWhere(
      (e) => e.name == priority,
      orElse: () => NotificationPriority.normal,
    );
  }

  Future<bool> _shouldShowNotification(NotificationData notification) async {
    // Check if category is disabled
    if (_categoryPreferences[notification.category] == false) {
      return false;
    }

    // Check if service request is muted
    if (notification.serviceRequestId != null && 
        _mutedServiceRequests.contains(notification.serviceRequestId)) {
      return false;
    }

    // Check Do Not Disturb
    if (_isInDoNotDisturbPeriod() && notification.priority != NotificationPriority.urgent) {
      return false;
    }

    // Check rate limiting
    if (!_isWithinRateLimit(notification)) {
      return false;
    }

    // Check minimum interval between similar notifications
    if (!_respectsMinimumInterval(notification)) {
      return false;
    }

    return true;
  }

  bool _isInDoNotDisturbPeriod() {
    if (!_doNotDisturbEnabled) return false;
    
    final now = TimeOfDay.now();
    
    // Handle overnight periods (e.g., 22:00 to 08:00)
    if (_doNotDisturbStart.hour > _doNotDisturbEnd.hour) {
      return now.hour >= _doNotDisturbStart.hour || now.hour < _doNotDisturbEnd.hour;
    }
    
    // Handle same-day periods (e.g., 12:00 to 14:00)
    return now.hour >= _doNotDisturbStart.hour && now.hour < _doNotDisturbEnd.hour;
  }

  bool _isWithinRateLimit(NotificationData notification) {
    final now = DateTime.now();
    final oneHourAgo = now.subtract(const Duration(hours: 1));
    
    // Count notifications in the last hour
    int recentNotifications = _lastNotificationTime.entries
        .where((entry) => entry.value.isAfter(oneHourAgo))
        .length;
    
    // Allow urgent notifications to bypass rate limiting
    if (notification.priority == NotificationPriority.urgent) {
      return true;
    }
    
    return recentNotifications < _maxNotificationsPerHour;
  }

  bool _respectsMinimumInterval(NotificationData notification) {
    final key = '${notification.category.name}_${notification.serviceRequestId ?? 'global'}';
    final lastTime = _lastNotificationTime[key];
    
    if (lastTime == null) return true;
    
    final now = DateTime.now();
    final timeDifference = now.difference(lastTime);
    
    // Urgent notifications can bypass minimum interval
    if (notification.priority == NotificationPriority.urgent) {
      return true;
    }
    
    return timeDifference >= _minimumInterval;
  }

  Future<void> _showSmartNotification(NotificationData notification, {bool isFromBackground = false}) async {
    // Create channel-specific settings
    final channelId = _getChannelId(notification.category);
    final channelName = _getChannelName(notification.category);
    final importance = _getImportance(notification.priority);
    
    // Create Android notification details
    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: _getChannelDescription(notification.category),
      importance: importance,
      priority: _getPriority(notification.priority),
      styleInformation: _getNotificationStyle(notification),
      actions: _getNotificationActions(notification),
      category: AndroidNotificationCategory.service,
      showWhen: true,
      when: notification.timestamp.millisecondsSinceEpoch,
      color: _getCategoryColor(notification.category),
      largeIcon: notification.imageUrl != null 
          ? NetworkImageIcon(notification.imageUrl!) 
          : null,
    );
    
    final notificationDetails = NotificationDetails(android: androidDetails);
    
    // Show the notification
    await _localNotifications.show(
      notification.hashCode,
      notification.title,
      _enhanceNotificationMessage(notification),
      notificationDetails,
      payload: _createPayload(notification),
    );
    
    // Update tracking
    _updateLastNotificationTime(notification);
  }

  String _enhanceNotificationMessage(NotificationData notification) {
    switch (notification.category) {
      case NotificationCategory.etaUpdate:
        return '🕐 ${notification.message}';
      case NotificationCategory.progressPhoto:
        return '📸 ${notification.message}';
      case NotificationCategory.mechanicArrival:
        return '🚗 ${notification.message}';
      case NotificationCategory.serviceComplete:
        return '✅ ${notification.message}';
      case NotificationCategory.paymentRequired:
        return '💳 ${notification.message}';
      case NotificationCategory.emergency:
        return '🚨 ${notification.message}';
      default:
        return notification.message;
    }
  }

  String _getChannelId(NotificationCategory category) {
    return 'RoadAid_${category.name}';
  }

  String _getChannelName(NotificationCategory category) {
    switch (category) {
      case NotificationCategory.serviceUpdate:
        return 'Service Updates';
      case NotificationCategory.progressPhoto:
        return 'Progress Photos';
      case NotificationCategory.etaUpdate:
        return 'Arrival Updates';
      case NotificationCategory.paymentRequired:
        return 'Payment Notifications';
      case NotificationCategory.mechanicArrival:
        return 'Mechanic Arrival';
      case NotificationCategory.serviceComplete:
        return 'Service Completion';
      case NotificationCategory.emergency:
        return 'Emergency Alerts';
      case NotificationCategory.promotional:
        return 'Promotions';
    }
  }

  String _getChannelDescription(NotificationCategory category) {
    switch (category) {
      case NotificationCategory.serviceUpdate:
        return 'Updates about your service request status';
      case NotificationCategory.progressPhoto:
        return 'Photos showing work progress from your mechanic';
      case NotificationCategory.etaUpdate:
        return 'Real-time updates about mechanic arrival time';
      case NotificationCategory.paymentRequired:
        return 'Notifications when payment is required';
      case NotificationCategory.mechanicArrival:
        return 'Notifications when your mechanic arrives';
      case NotificationCategory.serviceComplete:
        return 'Notifications when your service is complete';
      case NotificationCategory.emergency:
        return 'Critical emergency notifications';
      case NotificationCategory.promotional:
        return 'Special offers and promotions';
    }
  }

  Importance _getImportance(NotificationPriority priority) {
    switch (priority) {
      case NotificationPriority.low:
        return Importance.low;
      case NotificationPriority.normal:
        return Importance.defaultImportance;
      case NotificationPriority.high:
        return Importance.high;
      case NotificationPriority.urgent:
        return Importance.max;
    }
  }

  Priority _getPriority(NotificationPriority priority) {
    switch (priority) {
      case NotificationPriority.low:
        return Priority.low;
      case NotificationPriority.normal:
        return Priority.defaultPriority;
      case NotificationPriority.high:
        return Priority.high;
      case NotificationPriority.urgent:
        return Priority.max;
    }
  }

  AndroidNotificationStyle? _getNotificationStyle(NotificationData notification) {
    if (notification.imageUrl != null) {
      return BigPictureStyleInformation(
        NetworkImageIcon(notification.imageUrl!),
        largeIcon: NetworkImageIcon(notification.imageUrl!),
        contentTitle: notification.title,
        htmlFormatContentTitle: true,
        summaryText: notification.message,
        htmlFormatSummaryText: true,
      );
    }
    
    if (notification.message.length > 50) {
      return BigTextStyleInformation(
        notification.message,
        htmlFormatBigText: true,
        contentTitle: notification.title,
        htmlFormatContentTitle: true,
      );
    }
    
    return null;
  }

  List<AndroidNotificationAction>? _getNotificationActions(NotificationData notification) {
    switch (notification.category) {
      case NotificationCategory.mechanicArrival:
        return [
          const AndroidNotificationAction(
            'call_mechanic',
            'Call Mechanic',
            icon: DrawableResourceAndroidIcon('ic_call'),
          ),
          const AndroidNotificationAction(
            'view_location',
            'View Location',
            icon: DrawableResourceAndroidIcon('ic_location'),
          ),
        ];
      
      case NotificationCategory.paymentRequired:
        return [
          const AndroidNotificationAction(
            'pay_now',
            'Pay Now',
            icon: DrawableResourceAndroidIcon('ic_payment'),
          ),
          const AndroidNotificationAction(
            'view_invoice',
            'View Invoice',
            icon: DrawableResourceAndroidIcon('ic_receipt'),
          ),
        ];
      
      case NotificationCategory.progressPhoto:
        return [
          const AndroidNotificationAction(
            'view_photo',
            'View Photo',
            icon: DrawableResourceAndroidIcon('ic_photo'),
          ),
          const AndroidNotificationAction(
            'view_progress',
            'View Progress',
            icon: DrawableResourceAndroidIcon('ic_timeline'),
          ),
        ];
      
      default:
        return [
          const AndroidNotificationAction(
            'open_app',
            'Open App',
            icon: DrawableResourceAndroidIcon('ic_open'),
          ),
        ];
    }
  }

  Color _getCategoryColor(NotificationCategory category) {
    switch (category) {
      case NotificationCategory.serviceUpdate:
        return const Color(0xFF2196F3);
      case NotificationCategory.progressPhoto:
        return const Color(0xFF9C27B0);
      case NotificationCategory.etaUpdate:
        return const Color(0xFF4CAF50);
      case NotificationCategory.paymentRequired:
        return const Color(0xFFFF9800);
      case NotificationCategory.mechanicArrival:
        return const Color(0xFF4CAF50);
      case NotificationCategory.serviceComplete:
        return const Color(0xFF8BC34A);
      case NotificationCategory.emergency:
        return const Color(0xFFF44336);
      case NotificationCategory.promotional:
        return const Color(0xFF673AB7);
    }
  }

  String _createPayload(NotificationData notification) {
    return jsonEncode({
      'category': notification.category.name,
      'service_request_id': notification.serviceRequestId,
      'action_data': notification.actionData,
    });
  }

  void _onNotificationTapped(NotificationResponse response) {
    // Handle notification tap
    if (response.payload != null) {
      final payload = jsonDecode(response.payload!);
      _handleNotificationAction(response.actionId, payload);
    }
  }

  void _handleNotificationAction(String? actionId, Map<String, dynamic> payload) {
    switch (actionId) {
      case 'call_mechanic':
        _callMechanic(payload['service_request_id']);
        break;
      case 'view_location':
        _viewLocation(payload['service_request_id']);
        break;
      case 'pay_now':
        _openPayment(payload['service_request_id']);
        break;
      case 'view_invoice':
        _viewInvoice(payload['service_request_id']);
        break;
      case 'view_photo':
        _viewPhoto(payload['action_data']);
        break;
      case 'view_progress':
        _viewProgress(payload['service_request_id']);
        break;
      default:
        _openApp(payload['service_request_id']);
        break;
    }
  }

  void _updateLastNotificationTime(NotificationData notification) {
    final key = '${notification.category.name}_${notification.serviceRequestId ?? 'global'}';
    _lastNotificationTime[key] = DateTime.now();
  }

  void _updateNotificationAnalytics(NotificationData notification) {
    // Track notification metrics for optimization
    // Implementation depends on analytics service
  }

  Future<void> _loadUserPreferences() async {
    // Load from SharedPreferences or Supabase
    // Initialize with defaults
    for (final category in NotificationCategory.values) {
      _categoryPreferences[category] = true;
    }
  }

  // Public API methods
  Future<void> updateCategoryPreference(NotificationCategory category, bool enabled) async {
    _categoryPreferences[category] = enabled;
    // Save to storage
  }

  Future<void> muteServiceRequest(String serviceRequestId, Duration duration) async {
    _mutedServiceRequests.add(serviceRequestId);
    
    // Auto-unmute after duration
    Timer(duration, () {
      _mutedServiceRequests.remove(serviceRequestId);
    });
  }

  Future<void> setDoNotDisturb(bool enabled, TimeOfDay? start, TimeOfDay? end) async {
    _doNotDisturbEnabled = enabled;
    if (start != null) _doNotDisturbStart = start;
    if (end != null) _doNotDisturbEnd = end;
    // Save to storage
  }

  Future<void> setRateLimit(int maxPerHour, Duration minimumInterval) async {
    _maxNotificationsPerHour = maxPerHour;
    _minimumInterval = minimumInterval;
    // Save to storage
  }

  // Action handlers (to be implemented based on your navigation system)
  void _callMechanic(String serviceRequestId) {
    // Implementation for calling mechanic
  }

  void _viewLocation(String serviceRequestId) {
    // Implementation for viewing location
  }

  void _openPayment(String serviceRequestId) {
    // Implementation for opening payment
  }

  void _viewInvoice(String serviceRequestId) {
    // Implementation for viewing invoice
  }

  void _viewPhoto(Map<String, dynamic> actionData) {
    // Implementation for viewing photo
  }

  void _viewProgress(String serviceRequestId) {
    // Implementation for viewing progress
  }

  void _openApp(String? serviceRequestId) {
    // Implementation for opening app to specific service
  }
}

class NotificationData {
  final String id;
  final String title;
  final String message;
  final NotificationCategory category;
  final NotificationPriority priority;
  final String? serviceRequestId;
  final String? mechanicId;
  final String? customerId;
  final String? imageUrl;
  final Map<String, dynamic> actionData;
  final DateTime timestamp;

  NotificationData({
    required this.id,
    required this.title,
    required this.message,
    required this.category,
    required this.priority,
    this.serviceRequestId,
    this.mechanicId,
    this.customerId,
    this.imageUrl,
    required this.actionData,
    required this.timestamp,
  });
}

// Helper class for network images in notifications
class NetworkImageIcon extends AndroidBitmap {
  final String url;
  
  const NetworkImageIcon(this.url) : super._();
}