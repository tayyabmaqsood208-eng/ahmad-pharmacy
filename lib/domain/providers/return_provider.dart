import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../data/models/return.dart';
import '../../data/models/sale.dart';
import '../../data/repositories/return_repository.dart';
import 'sales_provider.dart';
import 'medicine_provider.dart';
import 'inventory_provider.dart';
import 'customer_provider.dart';

final returnRepositoryProvider = Provider((ref) => ReturnRepository());

final returnSearchQueryProvider = StateProvider<String>((ref) => '');

final returnsListProvider = FutureProvider<List<PharmacyReturn>>((ref) async {
  final repo = ref.watch(returnRepositoryProvider);
  final query = ref.watch(returnSearchQueryProvider);
  return repo.getReturns(query: query);
});

class ReturnFormState {
  final Sale? selectedSale;
  final List<ReturnItem> items;
  final bool restockToggle;
  final String notes;

  ReturnFormState({
    this.selectedSale,
    this.items = const [],
    this.restockToggle = true,
    this.notes = '',
  });

  double get totalRefund => items.fold(0.0, (sum, i) => sum + i.totalRefund);

  ReturnFormState copyWith({
    Sale? selectedSale,
    bool clearSale = false,
    List<ReturnItem>? items,
    bool? restockToggle,
    String? notes,
  }) {
    return ReturnFormState(
      selectedSale: clearSale ? null : (selectedSale ?? this.selectedSale),
      items: items ?? this.items,
      restockToggle: restockToggle ?? this.restockToggle,
      notes: notes ?? this.notes,
    );
  }
}

class ReturnFormNotifier extends StateNotifier<ReturnFormState> {
  final ReturnRepository _repo;
  final Ref _ref;

  ReturnFormNotifier(this._repo, this._ref) : super(ReturnFormState());

  void setSale(Sale sale) {
    state = state.copyWith(selectedSale: sale, items: []);
  }

  void toggleRestock(bool value) {
    state = state.copyWith(restockToggle: value);
  }

  void setNotes(String text) {
    state = state.copyWith(notes: text);
  }

  void addOrUpdateItem(ReturnItem item) {
    final updated = List<ReturnItem>.from(state.items);
    final idx = updated.indexWhere((i) => i.medicineId == item.medicineId && i.batchId == item.batchId);
    if (idx >= 0) {
      updated[idx] = item;
    } else {
      updated.add(item);
    }
    state = state.copyWith(items: updated);
  }

  void removeItem(int index) {
    final updated = List<ReturnItem>.from(state.items);
    updated.removeAt(index);
    state = state.copyWith(items: updated);
  }

  void clearForm() {
    state = ReturnFormState();
  }

  Future<void> submitReturn() async {
    if (state.selectedSale == null) {
      throw Exception('Please select an invoice to return');
    }
    if (state.items.isEmpty) {
      throw Exception('Please add at least one item to return');
    }

    const uuid = Uuid();
    final returnNo = await _repo.generateReturnNo();
    final returnId = 'ret-${uuid.v4().substring(0, 8)}';

    final updatedItems = state.items.map((i) => ReturnItem(
      id: 'ritem-${uuid.v4().substring(0, 8)}',
      returnId: returnId,
      medicineId: i.medicineId,
      medicineName: i.medicineName,
      batchId: i.batchId,
      batchNumber: i.batchNumber,
      quantity: i.quantity,
      unitPrice: i.unitPrice,
      totalRefund: i.totalRefund,
      reason: i.reason,
    )).toList();

    final returnRecord = PharmacyReturn(
      id: returnId,
      returnNo: returnNo,
      saleId: state.selectedSale!.id,
      invoiceNo: state.selectedSale!.invoiceNo,
      customerName: state.selectedSale!.customerName,
      returnDate: DateTime.now(),
      totalRefund: state.totalRefund,
      restockToggle: state.restockToggle,
      notes: state.notes.isNotEmpty ? state.notes : null,
      items: updatedItems,
    );

    await _repo.createReturn(returnRecord);

    _ref.invalidate(returnsListProvider);
    _ref.invalidate(salesListProvider);
    _ref.invalidate(medicinesListProvider);
    _ref.invalidate(allBatchesProvider);
    _ref.invalidate(customersListProvider);

    clearForm();
  }
}

final returnFormProvider = StateNotifierProvider<ReturnFormNotifier, ReturnFormState>((ref) {
  final repo = ref.watch(returnRepositoryProvider);
  return ReturnFormNotifier(repo, ref);
});
