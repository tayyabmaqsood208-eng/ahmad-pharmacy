import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../data/models/cart_item.dart';
import '../../data/models/medicine.dart';
import '../../data/models/batch.dart';
import '../../data/models/customer.dart';
import '../../data/models/sale.dart';
import '../../data/repositories/sales_repository.dart';
import 'medicine_provider.dart';
import 'inventory_provider.dart';
import 'customer_provider.dart';
import 'sales_provider.dart';

final salesRepositoryProvider = Provider((ref) => SalesRepository());

class ParkedSale {
  final String id;
  final String label;
  final DateTime createdAt;
  final List<CartItem> items;
  final Customer? customer;

  ParkedSale({
    required this.id,
    required this.label,
    required this.createdAt,
    required this.items,
    this.customer,
  });
}

class PosCartState {
  final List<CartItem> items;
  final Customer? selectedCustomer;
  final double discountAmount;
  final double taxRate;
  final String paymentMethod; // Cash, Card, Mobile, Credit
  final double paidAmount;
  final List<ParkedSale> parkedSales;

  PosCartState({
    this.items = const [],
    this.selectedCustomer,
    this.discountAmount = 0.0,
    this.taxRate = 0.0, // Tax permanently removed (0%)
    this.paymentMethod = 'Cash',
    this.paidAmount = 0.0,
    this.parkedSales = const [],
  });

  double get subtotal => items.fold(0.0, (sum, item) => sum + item.total);
  double get taxAmount => (subtotal * taxRate) / 100;
  double get grandTotal => (subtotal + taxAmount - discountAmount).clamp(0.0, 999999.0);
  double get changeAmount => (paidAmount - grandTotal).clamp(0.0, 999999.0);

  int get totalItemCount => items.fold(0, (sum, item) => sum + item.quantity);

  PosCartState copyWith({
    List<CartItem>? items,
    Customer? selectedCustomer,
    bool clearCustomer = false,
    double? discountAmount,
    double? taxRate,
    String? paymentMethod,
    double? paidAmount,
    List<ParkedSale>? parkedSales,
  }) {
    return PosCartState(
      items: items ?? this.items,
      selectedCustomer: clearCustomer ? null : (selectedCustomer ?? this.selectedCustomer),
      discountAmount: discountAmount ?? this.discountAmount,
      taxRate: taxRate ?? this.taxRate,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paidAmount: paidAmount ?? this.paidAmount,
      parkedSales: parkedSales ?? this.parkedSales,
    );
  }
}

class PosCartNotifier extends StateNotifier<PosCartState> {
  final SalesRepository _salesRepo;
  final Ref _ref;

  PosCartNotifier(this._salesRepo, this._ref) : super(PosCartState());

  void addItem(Medicine medicine, {Batch? selectedBatch, bool isFullBox = true, int quantity = 1}) {
    final packSize = medicine.effectivePackSize;
    final basePrice = selectedBatch?.sellPrice ?? medicine.defaultPrice;
    final unitPrice = isFullBox ? basePrice : (basePrice / packSize);

    final existingIndex = state.items.indexWhere(
      (i) => i.medicine.id == medicine.id &&
             i.selectedBatch?.id == selectedBatch?.id &&
             i.isFullBox == isFullBox,
    );

    if (existingIndex >= 0) {
      final updatedList = List<CartItem>.from(state.items);
      final current = updatedList[existingIndex];
      updatedList[existingIndex] = current.copyWith(quantity: current.quantity + quantity);
      state = state.copyWith(items: updatedList);
    } else {
      final newItem = CartItem(
        medicine: medicine,
        selectedBatch: selectedBatch,
        quantity: quantity,
        unitPrice: unitPrice,
        isFullBox: isFullBox,
      );
      state = state.copyWith(items: [...state.items, newItem]);
    }
  }

  void toggleItemUnit(int index) {
    if (index < 0 || index >= state.items.length) return;
    final item = state.items[index];
    final packSize = item.medicine.effectivePackSize;
    if (!item.medicine.isTabletOrPack && packSize <= 1) return;

    final newIsFullBox = !item.isFullBox;
    final basePrice = item.selectedBatch?.sellPrice ?? item.medicine.defaultPrice;
    final newUnitPrice = newIsFullBox ? basePrice : (basePrice / packSize);

    final updatedList = List<CartItem>.from(state.items);
    updatedList[index] = item.copyWith(
      isFullBox: newIsFullBox,
      unitPrice: newUnitPrice,
    );
    state = state.copyWith(items: updatedList);
  }

  void updateQuantity(int index, int quantity) {
    if (quantity <= 0) {
      removeItem(index);
      return;
    }
    final updatedList = List<CartItem>.from(state.items);
    updatedList[index] = updatedList[index].copyWith(quantity: quantity);
    state = state.copyWith(items: updatedList);
  }

  void updateItemDiscount(int index, double discount) {
    final updatedList = List<CartItem>.from(state.items);
    updatedList[index] = updatedList[index].copyWith(discountAmount: discount);
    state = state.copyWith(items: updatedList);
  }

  void removeItem(int index) {
    final updatedList = List<CartItem>.from(state.items);
    updatedList.removeAt(index);
    state = state.copyWith(items: updatedList);
  }

  void setCustomer(Customer? customer) {
    if (customer == null) {
      state = state.copyWith(clearCustomer: true);
    } else {
      state = state.copyWith(selectedCustomer: customer);
    }
  }

  void setDiscount(double amount) {
    state = state.copyWith(discountAmount: amount);
  }

  void setTaxRate(double rate) {
    state = state.copyWith(taxRate: rate);
  }

  void setPaymentMethod(String method) {
    state = state.copyWith(paymentMethod: method);
  }

  void setPaidAmount(double amount) {
    state = state.copyWith(paidAmount: amount);
  }

  void parkCurrentSale(String note) {
    if (state.items.isEmpty) return;
    const uuid = Uuid();
    final parked = ParkedSale(
      id: 'park-${uuid.v4().substring(0, 8)}',
      label: note.isNotEmpty ? note : 'Draft Sale #${state.parkedSales.length + 1}',
      createdAt: DateTime.now(),
      items: List.from(state.items),
      customer: state.selectedCustomer,
    );

    state = PosCartState(
      parkedSales: [...state.parkedSales, parked],
      taxRate: state.taxRate,
    );
  }

  void resumeParkedSale(ParkedSale parked) {
    final updatedParkedList = state.parkedSales.where((p) => p.id != parked.id).toList();
    state = PosCartState(
      items: List.from(parked.items),
      selectedCustomer: parked.customer,
      parkedSales: updatedParkedList,
      taxRate: state.taxRate,
    );
  }

  void discardParkedSale(String id) {
    final updatedParkedList = state.parkedSales.where((p) => p.id != id).toList();
    state = state.copyWith(parkedSales: updatedParkedList);
  }

  void clearCart() {
    state = PosCartState(parkedSales: state.parkedSales, taxRate: state.taxRate);
  }

  Future<Sale> processCheckout() async {
    if (state.items.isEmpty) {
      throw Exception('Cart is empty. Please add items to sell.');
    }

    if (state.paymentMethod.toLowerCase() == 'credit' && state.selectedCustomer == null) {
      throw Exception('Customer selection is compulsory for Credit billing! Please select or add customer details.');
    }

    const uuid = Uuid();
    final invoiceNo = await _salesRepo.generateInvoiceNo();
    final saleId = 'sale-${uuid.v4().substring(0, 8)}';

    final saleItems = state.items.map((item) {
      final unitLabel = item.unitLabel;
      final packSize = item.medicine.effectivePackSize;
      final costPrice = item.isFullBox
          ? (item.selectedBatch?.buyPrice ?? item.medicine.defaultCostPrice)
          : ((item.selectedBatch?.buyPrice ?? item.medicine.defaultCostPrice) / packSize);

      return SaleItem(
        id: 'sitem-${uuid.v4().substring(0, 8)}',
        saleId: saleId,
        medicineId: item.medicine.id,
        medicineName: item.medicine.isTabletOrPack ? '${item.medicine.name} ($unitLabel)' : item.medicine.name,
        genericName: item.medicine.genericName,
        batchId: item.selectedBatch?.id,
        batchNumber: item.selectedBatch?.batchNumber,
        quantity: item.quantity,
        unitPrice: item.unitPrice,
        unitCostPrice: costPrice,
        discount: item.discountAmount,
        subtotal: item.subtotal,
        total: item.total,
      );
    }).toList();

    final sale = Sale(
      id: saleId,
      invoiceNo: invoiceNo,
      customerId: state.selectedCustomer?.id,
      customerName: state.selectedCustomer?.name ?? 'Walk-in Customer',
      subtotal: state.subtotal,
      discount: state.discountAmount,
      taxAmount: state.taxAmount,
      totalAmount: state.grandTotal,
      paidAmount: state.paidAmount > 0 ? state.paidAmount : state.grandTotal,
      changeAmount: state.changeAmount,
      paymentMethod: state.paymentMethod,
      status: 'Completed',
      createdAt: DateTime.now(),
      items: saleItems,
    );

    await _salesRepo.createSale(sale);

    _ref.invalidate(medicinesListProvider);
    _ref.invalidate(allBatchesProvider);
    _ref.invalidate(customersListProvider);
    _ref.invalidate(salesListProvider);

    clearCart();
    return sale;
  }
}

final posCartProvider = StateNotifierProvider<PosCartNotifier, PosCartState>((ref) {
  final repo = ref.watch(salesRepositoryProvider);
  return PosCartNotifier(repo, ref);
});
