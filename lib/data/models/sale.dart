class SaleItem {
  final String id;
  final String saleId;
  final String medicineId;
  final String medicineName;
  final String genericName;
  final String? batchId;
  final String? batchNumber;
  final int quantity;
  final double unitPrice;
  final double unitCostPrice;
  final double discount;
  final double subtotal;
  final double total;

  SaleItem({
    required this.id,
    required this.saleId,
    required this.medicineId,
    required this.medicineName,
    required this.genericName,
    this.batchId,
    this.batchNumber,
    required this.quantity,
    required this.unitPrice,
    required this.unitCostPrice,
    required this.discount,
    required this.subtotal,
    required this.total,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sale_id': saleId,
      'medicine_id': medicineId,
      'medicine_name': medicineName,
      'generic_name': genericName,
      'batch_id': batchId,
      'batch_number': batchNumber,
      'quantity': quantity,
      'unit_price': unitPrice,
      'unit_cost_price': unitCostPrice,
      'discount': discount,
      'subtotal': subtotal,
      'total': total,
    };
  }

  factory SaleItem.fromMap(Map<String, dynamic> map) {
    return SaleItem(
      id: map['id'] as String,
      saleId: map['sale_id'] as String,
      medicineId: map['medicine_id'] as String,
      medicineName: map['medicine_name'] as String,
      genericName: map['generic_name'] as String? ?? '',
      batchId: map['batch_id'] as String?,
      batchNumber: map['batch_number'] as String?,
      quantity: (map['quantity'] as num).toInt(),
      unitPrice: (map['unit_price'] as num).toDouble(),
      unitCostPrice: (map['unit_cost_price'] as num?)?.toDouble() ?? 0.0,
      discount: (map['discount'] as num?)?.toDouble() ?? 0.0,
      subtotal: (map['subtotal'] as num).toDouble(),
      total: (map['total'] as num).toDouble(),
    );
  }
}

class Sale {
  final String id;
  final String invoiceNo;
  final String? customerId;
  final String customerName;
  final double subtotal;
  final double discount;
  final double taxAmount;
  final double totalAmount;
  final double paidAmount;
  final double changeAmount;
  final String paymentMethod; // Cash, Card, Mobile, Credit
  final String status;        // Completed, Voided, Refunded
  final DateTime createdAt;
  final List<SaleItem> items;
  final String? notes;

  Sale({
    required this.id,
    required this.invoiceNo,
    this.customerId,
    required this.customerName,
    required this.subtotal,
    required this.discount,
    required this.taxAmount,
    required this.totalAmount,
    required this.paidAmount,
    required this.changeAmount,
    required this.paymentMethod,
    required this.status,
    required this.createdAt,
    this.items = const [],
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'invoice_no': invoiceNo,
      'customer_id': customerId,
      'customer_name': customerName,
      'subtotal': subtotal,
      'discount': discount,
      'tax_amount': taxAmount,
      'total_amount': totalAmount,
      'paid_amount': paidAmount,
      'change_amount': changeAmount,
      'payment_method': paymentMethod,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'notes': notes,
    };
  }

  factory Sale.fromMap(Map<String, dynamic> map, {List<SaleItem> items = const []}) {
    return Sale(
      id: map['id'] as String,
      invoiceNo: map['invoice_no'] as String,
      customerId: map['customer_id'] as String?,
      customerName: map['customer_name'] as String? ?? 'Walk-in Customer',
      subtotal: (map['subtotal'] as num).toDouble(),
      discount: (map['discount'] as num?)?.toDouble() ?? 0.0,
      taxAmount: (map['tax_amount'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (map['total_amount'] as num).toDouble(),
      paidAmount: (map['paid_amount'] as num).toDouble(),
      changeAmount: (map['change_amount'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: map['payment_method'] as String? ?? 'Cash',
      status: map['status'] as String? ?? 'Completed',
      createdAt: DateTime.parse(map['created_at'] as String),
      items: items,
      notes: map['notes'] as String?,
    );
  }
}
