import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

/// 🔒 Safe Realtime Subscription Manager
/// 
/// Handles Supabase realtime subscriptions with automatic retry logic,
/// error handling, and graceful cleanup.
/// 
/// Usage:
/// ```dart
/// final listener = SafeRealtimeSubscription();
/// 
/// await listener.subscribe(
///   channelName: 'my_channel',
///   table: 'service_requests',
///   filter: PostgresChangeFilter(
///     type: PostgresChangeFilterType.eq,
///     column: 'shop_id',
///     value: shopId,
///   ),
///   callback: (payload) {
///     print('Data changed: ${payload.newRecord}');
///   },
/// );
/// 
/// // Later, clean up:
/// await listener.dispose();
/// ```
class SafeRealtimeSubscription {
  RealtimeChannel? _channel;
  final _supabase = Supabase.instance.client;
  
  int _retryCount = 0;
  static const int MAX_RETRIES = 3;
  Timer? _retryTimer;
  
  // Store subscription parameters for retry
  String? _channelName;
  PostgresChangeEvent? _event;
  String? _table;
  PostgresChangeFilter? _filter;
  void Function(PostgresChangePayload)? _callback;
  
  bool _isDisposed = false;

  /// Subscribe to a table with automatic error handling and retry
  Future<void> subscribe({
    required String channelName,
    PostgresChangeEvent event = PostgresChangeEvent.all,
    required String table,
    required PostgresChangeFilter filter,
    required void Function(PostgresChangePayload) callback,
    void Function(RealtimeSubscribeStatus status)? onStatusChange,
  }) async {
    if (_isDisposed) {
      print('⚠️ Cannot subscribe: listener is disposed');
      return;
    }

    // Store parameters for retry
    _channelName = channelName;
    _event = event;
    _table = table;
    _filter = filter;
    _callback = callback;

    try {
      // Unsubscribe from previous channel if exists
      await _channel?.unsubscribe();

      print('🔌 Subscribing to $channelName...');

      _channel = _supabase
          .channel(channelName)
          .onPostgresChanges(
            event: event,
            schema: 'public',
            table: table,
            filter: filter,
            callback: (payload) {
              if (!_isDisposed) {
                try {
                  callback(payload);
                } catch (e) {
                  print('❌ Error in callback for $channelName: $e');
                }
              }
            },
          )
          .subscribe(
            (status, error) {
              if (_isDisposed) return;

              onStatusChange?.call(status);

              if (status == RealtimeSubscribeStatus.subscribed) {
                print('✅ Subscribed to $channelName');
                _retryCount = 0; // Reset retry count on success
                _retryTimer?.cancel();
              } else if (status == RealtimeSubscribeStatus.channelError) {
                print('❌ Channel error on $channelName: $error');
                _handleSubscriptionError();
              } else if (status == RealtimeSubscribeStatus.timedOut) {
                print('⏱️ Subscription timeout on $channelName');
                _handleSubscriptionError();
              } else if (status == RealtimeSubscribeStatus.closed) {
                print('🔌 Channel closed: $channelName');
              }
            },
          );
    } catch (e) {
      print('❌ Subscription setup error for $channelName: $e');
      _handleSubscriptionError();
    }
  }

  void _handleSubscriptionError() {
    if (_isDisposed || _retryCount >= MAX_RETRIES) {
      if (_retryCount >= MAX_RETRIES) {
        print('❌ Max retries reached for $_channelName. Subscription failed permanently.');
      }
      return;
    }

    _retryCount++;
    final delay = Duration(seconds: 5 * _retryCount); // Exponential backoff
    print('🔄 Retrying $_channelName in ${delay.inSeconds}s (attempt $_retryCount/$MAX_RETRIES)');

    _retryTimer?.cancel();
    _retryTimer = Timer(delay, () {
      if (!_isDisposed && _channelName != null) {
        subscribe(
          channelName: _channelName!,
          event: _event ?? PostgresChangeEvent.all,
          table: _table!,
          filter: _filter!,
          callback: _callback!,
        );
      }
    });
  }

  /// Get current subscription status
  bool get isSubscribed => _channel != null && !_isDisposed;

  /// Unsubscribe and clean up resources
  Future<void> dispose() async {
    if (_isDisposed) return;

    _isDisposed = true;
    _retryTimer?.cancel();
    _retryTimer = null;

    try {
      await _channel?.unsubscribe();
      print('🛑 Unsubscribed from $_channelName');
    } catch (e) {
      print('⚠️ Error unsubscribing from $_channelName: $e');
    } finally {
      _channel = null;
      _channelName = null;
      _event = null;
      _table = null;
      _filter = null;
      _callback = null;
    }
  }
}

/// 🎯 Mechanic Request Listener (for Shop-Based Requests)
/// 
/// Specialized listener for mechanics to receive shop-based service requests.
/// Automatically filters requests by shop and mechanic availability.
class MechanicRequestListener {
  final String mechanicId;
  final String shopId;
  final SafeRealtimeSubscription _subscription = SafeRealtimeSubscription();

  MechanicRequestListener({
    required this.mechanicId,
    required this.shopId,
  });

  /// Start listening for new shop-based requests
  Future<void> startListening({
    required void Function(Map<String, dynamic> requestData) onNewRequest,
  }) async {
    await _subscription.subscribe(
      channelName: 'shop_requests_${mechanicId}_$shopId',
      event: PostgresChangeEvent.insert,
      table: 'service_requests',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'shop_id',
        value: shopId,
      ),
      callback: (payload) {
        final newRequest = payload.newRecord;

        // Filter for shop-based requests only
        if (newRequest['request_type'] == 'shop_based' &&
            newRequest['status'] == 'pending') {
          print('🔔 New shop request received: ${newRequest['id']}');
          onNewRequest(newRequest);
        } else {
          print('ℹ️ Skipping non-shop-based or non-pending request');
        }
      },
      onStatusChange: (status) {
        if (status == RealtimeSubscribeStatus.subscribed) {
          print('👂 Mechanic $mechanicId listening for requests on shop $shopId');
        }
      },
    );
  }

  /// Stop listening for requests
  Future<void> stopListening() async {
    await _subscription.dispose();
    print('🛑 Mechanic $mechanicId stopped listening');
  }

  /// Check if currently listening
  bool get isListening => _subscription.isSubscribed;
}

/// 📊 Customer Invoice Listener
/// 
/// Listens for invoice updates for a specific customer.
class CustomerInvoiceListener {
  final String customerId;
  final SafeRealtimeSubscription _subscription = SafeRealtimeSubscription();

  CustomerInvoiceListener({required this.customerId});

  Future<void> startListening({
    required void Function(Map<String, dynamic> invoice) onInvoiceUpdate,
  }) async {
    await _subscription.subscribe(
      channelName: 'customer_invoices_$customerId',
      event: PostgresChangeEvent.all,
      table: 'invoices',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'customer_id',
        value: customerId,
      ),
      callback: (payload) {
        print('💳 Invoice update for customer $customerId');
        onInvoiceUpdate(payload.newRecord);
      },
    );
  }

  Future<void> stopListening() async {
    await _subscription.dispose();
  }

  bool get isListening => _subscription.isSubscribed;
}

/// 📍 Shop Owner Dashboard Listener
/// 
/// Listens for real-time updates to shop data, service requests, and mechanics.
class ShopOwnerDashboardListener {
  final String shopId;
  final List<SafeRealtimeSubscription> _subscriptions = [];

  ShopOwnerDashboardListener({required this.shopId});

  /// Start listening for service request updates
  Future<void> listenToServiceRequests({
    required void Function(Map<String, dynamic> request) onRequestUpdate,
  }) async {
    final subscription = SafeRealtimeSubscription();
    _subscriptions.add(subscription);

    await subscription.subscribe(
      channelName: 'shop_requests_$shopId',
      event: PostgresChangeEvent.all,
      table: 'service_requests',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'shop_id',
        value: shopId,
      ),
      callback: (payload) {
        print('📋 Service request update for shop $shopId');
        onRequestUpdate(payload.newRecord);
      },
    );
  }

  /// Start listening for mechanic availability updates
  Future<void> listenToMechanicAvailability({
    required void Function(Map<String, dynamic> availability) onAvailabilityUpdate,
  }) async {
    final subscription = SafeRealtimeSubscription();
    _subscriptions.add(subscription);

    await subscription.subscribe(
      channelName: 'shop_mechanic_availability_$shopId',
      event: PostgresChangeEvent.update,
      table: 'mechanic_availability_status',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'shop_id',
        value: shopId,
      ),
      callback: (payload) {
        print('👨‍🔧 Mechanic availability update for shop $shopId');
        onAvailabilityUpdate(payload.newRecord);
      },
    );
  }

  /// Stop all listeners
  Future<void> stopAllListeners() async {
    for (var subscription in _subscriptions) {
      await subscription.dispose();
    }
    _subscriptions.clear();
    print('🛑 Stopped all shop owner listeners');
  }

  bool get isListening => _subscriptions.any((s) => s.isSubscribed);
}
