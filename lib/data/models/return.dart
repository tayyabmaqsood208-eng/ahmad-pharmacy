class ReturnItem {
  final String id;
  final String returnId;
  final String medicineId;
  final String medicineName;
  final String? batchId;
  final String? batchNumber;
  final int quantity;
  final double unitPrice;
  final double totalRefund;
  final String reason;

  ReturnItem({
    required this.id,
    required this.returnId,
    required this.medicineId,
    required this.medicineName,
    this.batchId,
    this.batchNumber,
    required this.quantity,
    required this.unitPrice,
    required this.totalRefund,
    required this.reason,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'return_id': returnId,
      'medicine_id': medicineId,
      'medicine_name': medicineName,
      'batch_id': batchId,
      'batch_number': batchNumber,
      'quantity': quantity,
      'unit_price': unitPrice,
      'total_refund': totalRefund,
      'reason': reason,
    };
  }

  factory ReturnItem.fromMap(Map<String, dynamic> map) {
    return ReturnItem(
      id: map['id'] as String,
      returnId: map['return_id'] as String,
      medicineId: map['medicine_id'] as String,
      medicineName: map['medicine_name'] as String,
      batchId: map['batch_id'] as String?,
      batchNumber: map['batch_number'] as String?,
      quantity: (map['quantity'] as num).toInt(),
      unitPrice: (map['unit_price'] as num).toDouble(),
      totalRefund: (map['total_refund'] as num).toDouble(),
      reason: map['reason'] as String? ?? 'Customer mind change',
    );
  }

  ReturnItem copyWith({
    String? id,
    String? returnId,
    String? medicineId,
    String? medicineName,
    String? batchId,
    String? batchNumber,
    int? quantity,
    double? unitPrice,
    double? totalRefund,
    String? reason,
  }) {
    return ReturnItem(
      id: id ?? this.id,
      returnId: returnId ?? this.returnId,
      medicineId: medicineId ?? this.medicineId,
      medicineName: medicineName ?? this.medicineName,
      batchId: batchId ?? this.batchId,
      batchNumber: batchNumber ?? this.batchNumber,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      totalRefund: totalRefund ?? this.totalRefund,
      reason: reason ?? this.reason,
    );
  }
}

class PharmacyReturn {
  final String id;
  final String returnNo;
  final String saleId;
  final String invoiceNo;
  final String customerName;
  final DateTime returnDate;
  final double totalRefund;
  final bool restockToggle;
  final String? notes;
  final List<ReturnItem> items;

  PharmacyReturn({
    required this.id,
    required this.returnNo,
    required this.saleId,
    required this.invoiceNo,
    required this.customerName,
    required this.returnDate,
    required this.totalRefund,
    this.restockToggle = true,
    this.notes,
    this.items = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'return_no': returnNo,
      'sale_id': saleId,
      'invoice_no': invoiceNo,
      'customer_name': customerName,
      'return_date': returnDate.toIso8601String(),
      'total_refund': totalRefund,
      'restock_toggle': restockToggle ? 1 : 0,
      'notes': notes,
    };
  }

  factory PharmacyReturn.fromMap(Map<String, dynamic> map, {List<ReturnItem> items = const []}) {
    return PharmacyReturn(
      id: map['id'] as String,
      returnNo: map['return_no'] as String,
      saleId: map['sale_id'] as String,
      invoiceNo: map['invoice_no'] as String,
      customerName: map['customer_name'] as String? ?? 'Walk-in Customer',
      returnDate: DateTime.parse(map['return_date'] as String),
      totalRefund: (map['total_refund'] as num).toDouble(),
      restockToggle: (map['restock_toggle'] as int?) == 1,
      notes: map['notes'] as String?,
      items: items,
    );
  }
}
