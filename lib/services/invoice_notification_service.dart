import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/invoice.dart';

class InvoiceNotificationService {
  static final InvoiceNotificationService _instance = InvoiceNotificationService._internal();
  static InvoiceNotificationService get instance => _instance;
  InvoiceNotificationService._internal();

  final _supabase = Supabase.instance.client;
  StreamSubscription<List<Map<String, dynamic>>>? _invoiceSubscription;
  final _newInvoiceController = StreamController<Invoice>.broadcast();

  /// Stream of new invoices for the current user
  Stream<Invoice> get newInvoiceStream => _newInvoiceController.stream;

  /// Initialize the notification service
  Future<void> initialize() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        return;
      }

      // Listen for new invoices in real-time
      _invoiceSubscription = _supabase
          .from('invoices')
          .stream(primaryKey: ['id'])
          .eq('customer_id', user.id)
          .listen(
            (List<Map<String, dynamic>> data) {
              for (final invoiceData in data) {
                try {
                  final invoice = Invoice.fromJson(invoiceData);
                  _newInvoiceController.add(invoice);
                } catch (e) {
                  print('❌ Error parsing invoice notification: $e');
                }
              }
            },
            onError: (error) {
              print('❌ Invoice notification subscription error: $error');
            },
          );
    } catch (e) {
      // Silently handle initialization errors
    }
  }

  /// Show an in-app notification for a new invoice
  void showInvoiceNotification(BuildContext context, Invoice invoice) {
    if (!context.mounted) return;

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.receipt, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'New Invoice Received',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text('Amount: ₱${invoice.total.toStringAsFixed(2)}'),
                  ],
                ),
              ),
            ],
          ),
          backgroundColor: Colors.blue[700],
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'View',
            textColor: Colors.white,
            onPressed: () {
              // Navigate to invoice details
              Navigator.pushNamed(context, '/invoice_details', arguments: invoice);
            },
          ),
        ),
      );
    } catch (e) {
      print('❌ Error showing invoice notification: $e');
    }
  }

  /// Dispose resources
  void dispose() {
    _invoiceSubscription?.cancel();
    _newInvoiceController.close();
  }
}










