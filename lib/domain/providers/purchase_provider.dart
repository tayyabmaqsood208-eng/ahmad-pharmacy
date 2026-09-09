import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../data/models/purchase.dart';
import '../../data/repositories/purchase_repository.dart';
import 'medicine_provider.dart';
import 'inventory_provider.dart';

final purchaseRepositoryProvider = Provider((ref) => PurchaseRepository());

final purchaseSearchQueryProvider = StateProvider<String>((ref) => '');

final purchasesListProvider = FutureProvider<List<Purchase>>((ref) async {
  final repo = ref.watch(purchaseRepositoryProvider);
  final query = ref.watch(purchaseSearchQueryProvider);
  return repo.getPurchases(query: query);
});

class PurchaseFormState {
  final String vendorName;
  final String notes;
  final List<PurchaseItem> items;

  PurchaseFormState({
    this.vendorName = '',
    this.notes = '',
    this.items = const [],
  });

  double get subtotal => items.fold(0.0, (sum, i) => sum + i.subtotal);
  double get totalAmount => subtotal; // Can add tax if needed

  PurchaseFormState copyWith({
    String? vendorName,
    String? notes,
    List<PurchaseItem>? items,
  }) {
    return PurchaseFormState(
      vendorName: vendorName ?? this.vendorName,
      notes: notes ?? this.notes,
      items: items ?? this.items,
    );
  }
}

class PurchaseFormNotifier extends StateNotifier<PurchaseFormState> {
  final PurchaseRepository _repo;
  final Ref _ref;

  PurchaseFormNotifier(this._repo, this._ref) : super(PurchaseFormState());

  void setVendorName(String name) {
    state = state.copyWith(vendorName: name);
  }

  void setNotes(String notes) {
    state = state.copyWith(notes: notes);
  }

  void addItem(PurchaseItem item) {
    state = state.copyWith(items: [...state.items, item]);
  }

  void removeItem(int index) {
    final updated = List<PurchaseItem>.from(state.items);
    updated.removeAt(index);
    state = state.copyWith(items: updated);
  }

  void clearForm() {
    state = PurchaseFormState();
  }

  Future<void> submitPurchase() async {
    if (state.vendorName.trim().isEmpty) {
      throw Exception('Vendor name is required');
    }
    if (state.items.isEmpty) {
      throw Exception('Please add at least one item to purchase');
    }

    const uuid = Uuid();
    final invoiceNo = await _repo.generatePurchaseInvoiceNo();
    final purchaseId = 'purch-${uuid.v4().substring(0, 8)}';

    final updatedItems = state.items.map((i) => PurchaseItem(
      id: i.id.isEmpty ? 'pitem-${uuid.v4().substring(0, 8)}' : i.id,
      purchaseId: purchaseId,
      medicineId: i.medicineId,
      medicineName: i.medicineName,
      batchNumber: i.batchNumber,
      expiryDate: i.expiryDate,
      quantity: i.quantity,
      buyPrice: i.buyPrice,
      sellPrice: i.sellPrice,
      subtotal: i.subtotal,
    )).toList();

    final purchase = Purchase(
      id: purchaseId,
      invoiceNo: invoiceNo,
      vendorName: state.vendorName.trim(),
      purchaseDate: DateTime.now(),
      subtotal: state.subtotal,
      taxAmount: 0.0,
      totalAmount: state.totalAmount,
      status: 'Completed',
      notes: state.notes.isNotEmpty ? state.notes : null,
      items: updatedItems,
    );

    await _repo.createPurchase(purchase);

    _ref.invalidate(purchasesListProvider);
    _ref.invalidate(medicinesListProvider);
    _ref.invalidate(allBatchesProvider);

    clearForm();
  }
}

final purchaseFormProvider = StateNotifierProvider<PurchaseFormNotifier, PurchaseFormState>((ref) {
  final repo = ref.watch(purchaseRepositoryProvider);
  return PurchaseFormNotifier(repo, ref);
});
