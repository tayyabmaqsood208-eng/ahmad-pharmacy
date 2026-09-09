class StockAdjustment {
  final String id;
  final String medicineId;
  final String medicineName;
  final String? batchId;
  final String? batchNumber;
  final int quantityChange; // Positive for addition, negative for reduction
  final String adjustmentType; // 'Add' or 'Subtract'
  final String reason; // e.g., Damaged, Expired, Inventory Audit, Lost, Gift
  final DateTime createdAt;
  final String? notes;

  StockAdjustment({
    required this.id,
    required this.medicineId,
    required this.medicineName,
    this.batchId,
    this.batchNumber,
    required this.quantityChange,
    required this.adjustmentType,
    required this.reason,
    required this.createdAt,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'medicine_id': medicineId,
      'medicine_name': medicineName,
      'batch_id': batchId,
      'batch_number': batchNumber,
      'quantity_change': quantityChange,
      'adjustment_type': adjustmentType,
      'reason': reason,
      'created_at': createdAt.toIso8601String(),
      'notes': notes,
    };
  }

  factory StockAdjustment.fromMap(Map<String, dynamic> map) {
    return StockAdjustment(
      id: map['id'] as String,
      medicineId: map['medicine_id'] as String,
      medicineName: map['medicine_name'] as String,
      batchId: map['batch_id'] as String?,
      batchNumber: map['batch_number'] as String?,
      quantityChange: (map['quantity_change'] as num).toInt(),
      adjustmentType: map['adjustment_type'] as String,
      reason: map['reason'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      notes: map['notes'] as String?,
    );
  }
}
