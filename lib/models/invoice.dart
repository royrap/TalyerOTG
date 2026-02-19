class Invoice {
  final String id;
  final String requestId;
  final String providerId;
  final String customerId;
  final List<InvoiceItem> items;
  final double subtotal;
  final double tax;
  final double total;
  final String status; // 'pending', 'sent', 'accepted', 'paid', 'cancelled'
  final DateTime createdAt;
  final DateTime? sentAt;
  final DateTime? acceptedAt;
  final DateTime? paidAt;
  final String? notes;

  Invoice({
    required this.id,
    required this.requestId,
    required this.providerId,
    required this.customerId,
    required this.items,
    required this.subtotal,
    required this.tax,
    required this.total,
    required this.status,
    required this.createdAt,
    this.sentAt,
    this.acceptedAt,
    this.paidAt,
    this.notes,
  });

  // Getters for compatibility
  double get totalAmount => total;
  
  String get description {
    if (items.isEmpty) return 'Service Invoice';
    if (items.length == 1) return items.first.description;
    return '${items.first.description} and ${items.length - 1} more item${items.length > 2 ? 's' : ''}';
  }

  factory Invoice.fromJson(Map<String, dynamic> json) {
    // Handle both new and existing database structure
    final items = json['items'] != null 
        ? (json['items'] as List).map((item) => InvoiceItem.fromJson(item)).toList()
        : <InvoiceItem>[];
    
    // Use total_amount if total doesn't exist (existing structure), handle null values
    final total = json['total'] != null 
        ? (json['total'] as num).toDouble()
        : json['total_amount'] != null 
            ? (json['total_amount'] as num).toDouble()
            : 0.0;
    
    // Handle subtotal with null check
    final subtotal = json['subtotal'] != null 
        ? (json['subtotal'] as num).toDouble() 
        : 0.0;
    
    // Use created_at if available, otherwise issued_at (existing structure)
    final createdAt = json['created_at'] != null 
        ? DateTime.parse(json['created_at'])
        : DateTime.parse(json['issued_at']);
    
    return Invoice(
      id: json['id'],
      requestId: json['request_id'],
      providerId: json['provider_id'],
      customerId: json['customer_id'],
      items: items,
      subtotal: subtotal,
      tax: json['tax'] != null ? (json['tax'] as num).toDouble() : 0.0,
      total: total,
      status: json['status'] ?? 'pending',
      createdAt: createdAt,
      sentAt: json['sent_at'] != null ? DateTime.parse(json['sent_at']) : null,
      acceptedAt: json['accepted_at'] != null ? DateTime.parse(json['accepted_at']) : null,
      paidAt: json['paid_at'] != null ? DateTime.parse(json['paid_at']) : null,
      notes: json['notes'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'request_id': requestId,
      'provider_id': providerId,
      'customer_id': customerId,
      'items': items.map((item) => item.toJson()).toList(),
      'subtotal': subtotal,
      'tax': tax,
      'total': total,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'sent_at': sentAt?.toIso8601String(),
      'accepted_at': acceptedAt?.toIso8601String(),
      'paid_at': paidAt?.toIso8601String(),
      'notes': notes,
    };
  }
}

class InvoiceItem {
  final String description;
  final int quantity;
  final double unitPrice;
  final double total;
  final String type; // 'labor', 'parts', 'other'

  InvoiceItem({
    required this.description,
    required this.quantity,
    required this.unitPrice,
    required this.total,
    required this.type,
  });

  factory InvoiceItem.fromJson(Map<String, dynamic> json) {
    return InvoiceItem(
      description: json['description'] ?? '',
      quantity: json['quantity'] ?? 1,
      unitPrice: json['unit_price'] != null ? (json['unit_price'] as num).toDouble() : 0.0,
      total: json['total'] != null ? (json['total'] as num).toDouble() : 0.0,
      type: json['type'] ?? 'other',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'description': description,
      'quantity': quantity,
      'unit_price': unitPrice,
      'total': total,
      'type': type,
    };
  }
}
