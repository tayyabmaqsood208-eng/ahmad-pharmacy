class Batch {
  final String id;
  final String medicineId;
  final String batchNumber;
  final DateTime expiryDate;
  final int quantity;
  final double buyPrice;
  final double sellPrice;
  final DateTime receivedDate;

  Batch({
    required this.id,
    required this.medicineId,
    required this.batchNumber,
    required this.expiryDate,
    required this.quantity,
    required this.buyPrice,
    required this.sellPrice,
    required this.receivedDate,
  });

  bool get isExpired => expiryDate.isBefore(DateTime.now());
  bool get isExpiringSoon {
    final now = DateTime.now();
    final difference = expiryDate.difference(now).inDays;
    return difference >= 0 && difference <= 60;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'medicine_id': medicineId,
      'batch_number': batchNumber,
      'expiry_date': expiryDate.toIso8601String(),
      'quantity': quantity,
      'buy_price': buyPrice,
      'sell_price': sellPrice,
      'received_date': receivedDate.toIso8601String(),
    };
  }

  factory Batch.fromMap(Map<String, dynamic> map) {
    return Batch(
      id: map['id'] as String,
      medicineId: map['medicine_id'] as String,
      batchNumber: map['batch_number'] as String,
      expiryDate: DateTime.parse(map['expiry_date'] as String),
      quantity: (map['quantity'] as num).toInt(),
      buyPrice: (map['buy_price'] as num).toDouble(),
      sellPrice: (map['sell_price'] as num).toDouble(),
      receivedDate: DateTime.parse(map['received_date'] as String),
    );
  }

  Batch copyWith({
    String? id,
    String? medicineId,
    String? batchNumber,
    DateTime? expiryDate,
    int? quantity,
    double? buyPrice,
    double? sellPrice,
    DateTime? receivedDate,
  }) {
    return Batch(
      id: id ?? this.id,
      medicineId: medicineId ?? this.medicineId,
      batchNumber: batchNumber ?? this.batchNumber,
      expiryDate: expiryDate ?? this.expiryDate,
      quantity: quantity ?? this.quantity,
      buyPrice: buyPrice ?? this.buyPrice,
      sellPrice: sellPrice ?? this.sellPrice,
      receivedDate: receivedDate ?? this.receivedDate,
    );
  }
}
