import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'paymongo_service.dart';

class PayMongoWebhookHandler {
  static final PayMongoWebhookHandler _instance = PayMongoWebhookHandler._internal();
  static PayMongoWebhookHandler get instance => _instance;
  PayMongoWebhookHandler._internal();

  final _supabase = Supabase.instance.client;
  
  // Webhook secret for verification - Replace with your actual webhook secret
  // static const String _webhookSecret = 'YOUR_WEBHOOK_SECRET';

  /// Process incoming PayMongo webhook
  Future<Map<String, dynamic>> processWebhook(
    Map<String, String> headers,
    String body,
  ) async {
    try {
      print('🔔 Processing PayMongo webhook...');

      // Verify webhook signature
      if (!_verifyWebhookSignature(headers, body)) {
        print('❌ Webhook signature verification failed');
        return {
          'success': false,
          'error': 'Invalid webhook signature',
          'status': 401,
        };
      }

      // Parse webhook payload
      final webhookData = jsonDecode(body);
      final eventId = webhookData['data']['id'];
      final eventType = webhookData['data']['attributes']['type'];

      print('🔔 Webhook event: $eventType (ID: $eventId)');

      // Check if event already processed
      final existingEvent = await _supabase
          .from('paymongo_webhook_events')
          .select('id')
          .eq('paymongo_event_id', eventId)
          .maybeSingle();

      if (existingEvent != null) {
        print('ℹ️ Webhook event already processed: $eventId');
        return {
          'success': true,
          'message': 'Event already processed',
          'status': 200,
        };
      }

      // Store webhook event
      await _storeWebhookEvent(webhookData);

      // Process the webhook
      final result = await PayMongoService.instance.handleWebhook(webhookData);

      if (result) {
        // Mark as processed
        await _markEventAsProcessed(eventId);
        
        print('✅ Webhook processed successfully: $eventId');
        return {
          'success': true,
          'message': 'Webhook processed successfully',
          'status': 200,
        };
      } else {
        print('❌ Webhook processing failed: $eventId');
        return {
          'success': false,
          'error': 'Webhook processing failed',
          'status': 500,
        };
      }
    } catch (e) {
      print('❌ Error processing webhook: $e');
      return {
        'success': false,
        'error': 'Internal server error: $e',
        'status': 500,
      };
    }
  }

  /// Verify webhook signature
  bool _verifyWebhookSignature(Map<String, String> headers, String body) {
    try {
      final signature = headers['paymongo-signature'];
      if (signature == null) {
        print('❌ Missing PayMongo signature header');
        return false;
      }

      // Extract timestamp and signature from header
      final parts = signature.split(',');
      String? timestamp;
      String? providedSignature;

      for (final part in parts) {
        final keyValue = part.split('=');
        if (keyValue.length == 2) {
          final key = keyValue[0].trim();
          final value = keyValue[1].trim();
          
          if (key == 't') {
            timestamp = value;
          } else if (key == 'v1') {
            providedSignature = value;
          }
        }
      }

      if (timestamp == null || providedSignature == null) {
        print('❌ Invalid signature format');
        return false;
      }

      // For security, you should implement HMAC SHA256 verification here
      // This is a simplified version - implement proper signature verification
      print('ℹ️ Webhook signature verification (simplified): $providedSignature');
      
      // TODO: Implement proper HMAC SHA256 signature verification
      // final expectedSignature = _computeSignature(timestamp, body);
      // return providedSignature == expectedSignature;
      
      return true; // Simplified for demo - implement proper verification
    } catch (e) {
      print('❌ Error verifying webhook signature: $e');
      return false;
    }
  }

  /// Store webhook event in database
  Future<void> _storeWebhookEvent(Map<String, dynamic> webhookData) async {
    try {
      final eventData = webhookData['data'];
      final eventId = eventData['id'];
      final eventType = eventData['attributes']['type'];
      final paymentData = eventData['attributes']['data'];

      // Extract invoice ID from metadata
      String? invoiceId;
      if (paymentData['attributes']?['metadata']?['invoice_id'] != null) {
        invoiceId = paymentData['attributes']['metadata']['invoice_id'];
      }

      await _supabase.from('paymongo_webhook_events').insert({
        'paymongo_event_id': eventId,
        'event_type': eventType,
        'payment_intent_id': paymentData['id'],
        'invoice_id': invoiceId,
        'event_data': webhookData,
        'processed': false,
        'processing_attempts': 0,
        'created_at': DateTime.now().toIso8601String(),
      });

      print('✅ Webhook event stored: $eventId');
    } catch (e) {
      print('❌ Error storing webhook event: $e');
      throw e;
    }
  }

  /// Mark webhook event as processed
  Future<void> _markEventAsProcessed(String eventId) async {
    try {
      await _supabase
          .from('paymongo_webhook_events')
          .update({
            'processed': true,
            'processed_at': DateTime.now().toIso8601String(),
          })
          .eq('paymongo_event_id', eventId);

      print('✅ Webhook event marked as processed: $eventId');
    } catch (e) {
      print('❌ Error marking event as processed: $e');
    }
  }

  /// Retry failed webhook processing
  Future<void> retryFailedWebhooks() async {
    try {
      print('🔄 Retrying failed webhook events...');

      final failedEvents = await _supabase
          .from('paymongo_webhook_events')
          .select('*')
          .eq('processed', false)
          .lt('processing_attempts', 3)
          .order('created_at');

      for (final event in failedEvents) {
        try {
          final webhookData = event['event_data'];
          final result = await PayMongoService.instance.handleWebhook(webhookData);

          if (result) {
            await _markEventAsProcessed(event['paymongo_event_id']);
            print('✅ Retry successful for event: ${event['paymongo_event_id']}');
          } else {
            // Increment attempt counter
            await _supabase
                .from('paymongo_webhook_events')
                .update({
                  'processing_attempts': event['processing_attempts'] + 1,
                  'last_processing_error': 'Processing failed during retry',
                })
                .eq('id', event['id']);
            print('❌ Retry failed for event: ${event['paymongo_event_id']}');
          }
        } catch (e) {
          await _supabase
              .from('paymongo_webhook_events')
              .update({
                'processing_attempts': event['processing_attempts'] + 1,
                'last_processing_error': e.toString(),
              })
              .eq('id', event['id']);
          print('❌ Retry error for event ${event['paymongo_event_id']}: $e');
        }
      }

      print('🔄 Webhook retry process completed');
    } catch (e) {
      print('❌ Error retrying failed webhooks: $e');
    }
  }

  /// Get webhook processing statistics
  Future<Map<String, dynamic>> getWebhookStats() async {
    try {
      final stats = await _supabase
          .from('paymongo_webhook_events')
          .select('processed, processing_attempts')
          .order('created_at', ascending: false)
          .limit(1000);

      final total = stats.length;
      final processed = stats.where((event) => event['processed'] == true).length;
      final failed = stats.where((event) => 
          event['processed'] == false && event['processing_attempts'] >= 3).length;
      final pending = total - processed - failed;

      return {
        'total_events': total,
        'processed': processed,
        'failed': failed,
        'pending': pending,
        'success_rate': total > 0 ? (processed / total * 100).toStringAsFixed(1) : '0.0',
      };
    } catch (e) {
      print('❌ Error getting webhook stats: $e');
      return {
        'total_events': 0,
        'processed': 0,
        'failed': 0,
        'pending': 0,
        'success_rate': '0.0',
      };
    }
  }
}










