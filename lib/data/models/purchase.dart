class PurchaseItem {
  final String id;
  final String purchaseId;
  final String medicineId;
  final String medicineName;
  final String batchNumber;
  final DateTime expiryDate;
  final int quantity;
  final double buyPrice;
  final double sellPrice;
  final double subtotal;

  PurchaseItem({
    required this.id,
    required this.purchaseId,
    required this.medicineId,
    required this.medicineName,
    required this.batchNumber,
    required this.expiryDate,
    required this.quantity,
    required this.buyPrice,
    required this.sellPrice,
    required this.subtotal,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'purchase_id': purchaseId,
      'medicine_id': medicineId,
      'medicine_name': medicineName,
      'batch_number': batchNumber,
      'expiry_date': expiryDate.toIso8601String(),
      'quantity': quantity,
      'buy_price': buyPrice,
      'sell_price': sellPrice,
      'subtotal': subtotal,
    };
  }

  factory PurchaseItem.fromMap(Map<String, dynamic> map) {
    return PurchaseItem(
      id: map['id'] as String,
      purchaseId: map['purchase_id'] as String,
      medicineId: map['medicine_id'] as String,
      medicineName: map['medicine_name'] as String,
      batchNumber: map['batch_number'] as String,
      expiryDate: DateTime.parse(map['expiry_date'] as String),
      quantity: (map['quantity'] as num).toInt(),
      buyPrice: (map['buy_price'] as num).toDouble(),
      sellPrice: (map['sell_price'] as num).toDouble(),
      subtotal: (map['subtotal'] as num).toDouble(),
    );
  }
}

class Purchase {
  final String id;
  final String invoiceNo;
  final String vendorName; // Free-text vendor name (no suppliers module)
  final DateTime purchaseDate;
  final double subtotal;
  final double taxAmount;
  final double totalAmount;
  final String status; // Completed, Pending
  final String? notes;
  final List<PurchaseItem> items;

  Purchase({
    required this.id,
    required this.invoiceNo,
    required this.vendorName,
    required this.purchaseDate,
    required this.subtotal,
    required this.taxAmount,
    required this.totalAmount,
    required this.status,
    this.notes,
    this.items = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'invoice_no': invoiceNo,
      'vendor_name': vendorName,
      'purchase_date': purchaseDate.toIso8601String(),
      'subtotal': subtotal,
      'tax_amount': taxAmount,
      'total_amount': totalAmount,
      'status': status,
      'notes': notes,
    };
  }

  factory Purchase.fromMap(Map<String, dynamic> map, {List<PurchaseItem> items = const []}) {
    return Purchase(
      id: map['id'] as String,
      invoiceNo: map['invoice_no'] as String,
      vendorName: map['vendor_name'] as String? ?? 'General Distributor',
      purchaseDate: DateTime.parse(map['purchase_date'] as String),
      subtotal: (map['subtotal'] as num).toDouble(),
      taxAmount: (map['tax_amount'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (map['total_amount'] as num).toDouble(),
      status: map['status'] as String? ?? 'Completed',
      notes: map['notes'] as String?,
      items: items,
    );
  }
}
