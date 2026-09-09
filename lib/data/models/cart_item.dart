import 'medicine.dart';
import 'batch.dart';

class CartItem {
  final Medicine medicine;
  final Batch? selectedBatch;
  int quantity;
  double unitPrice;
  double discountAmount;
  final bool isFullBox;

  CartItem({
    required this.medicine,
    this.selectedBatch,
    this.quantity = 1,
    required this.unitPrice,
    this.discountAmount = 0.0,
    this.isFullBox = true,
  });

  String get unitLabel {
    if (!isFullBox) {
      return medicine.dosageForm.isNotEmpty ? medicine.dosageForm : 'Tablet';
    }
    return medicine.unit.isNotEmpty ? medicine.unit : 'Box';
  }

  double get subtotal => unitPrice * quantity;
  double get total => (unitPrice * quantity) - discountAmount;

  CartItem copyWith({
    Medicine? medicine,
    Batch? selectedBatch,
    int? quantity,
    double? unitPrice,
    double? discountAmount,
    bool? isFullBox,
  }) {
    return CartItem(
      medicine: medicine ?? this.medicine,
      selectedBatch: selectedBatch ?? this.selectedBatch,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      discountAmount: discountAmount ?? this.discountAmount,
      isFullBox: isFullBox ?? this.isFullBox,
    );
  }
}
