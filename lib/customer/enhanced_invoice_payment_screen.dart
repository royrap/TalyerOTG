import 'package:flutter/material.dart';
import '../models/invoice.dart';
import 'angkas_style_payment_screen.dart';

class EnhancedInvoicePaymentScreen extends StatelessWidget {
  final Invoice invoice;
  final String? preSelectedPaymentMethod;

  const EnhancedInvoicePaymentScreen({
    super.key,
    required this.invoice,
    this.preSelectedPaymentMethod,
  });

  @override
  Widget build(BuildContext context) {
    // Redirect to the new Angkas-style payment screen
    return AngkasStylePaymentScreen(
      invoice: invoice,
      preSelectedPaymentMethod: preSelectedPaymentMethod,
    );
  }
}





















