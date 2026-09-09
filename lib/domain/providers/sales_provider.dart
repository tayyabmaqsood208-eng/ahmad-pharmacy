import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/sale.dart';
import '../../data/repositories/sales_repository.dart';
import 'pos_cart_provider.dart';
import 'medicine_provider.dart';
import 'inventory_provider.dart';
import 'customer_provider.dart';

final salesSearchQueryProvider = StateProvider<String>((ref) => '');
final salesStatusFilterProvider = StateProvider<String>((ref) => 'All');
final salesPaymentMethodFilterProvider = StateProvider<String>((ref) => 'All');

final salesListProvider = FutureProvider<List<Sale>>((ref) async {
  final repo = ref.watch(salesRepositoryProvider);
  final query = ref.watch(salesSearchQueryProvider);
  final status = ref.watch(salesStatusFilterProvider);
  final payment = ref.watch(salesPaymentMethodFilterProvider);

  return repo.getSales(
    query: query,
    status: status,
    paymentMethod: payment,
  );
});

class VoidSaleNotifier extends StateNotifier<AsyncValue<void>> {
  final SalesRepository _repo;
  final Ref _ref;

  VoidSaleNotifier(this._repo, this._ref) : super(const AsyncValue.data(null));

  Future<void> voidSale(String saleId, String reason) async {
    state = const AsyncValue.loading();
    try {
      await _repo.voidSale(saleId, reason);
      _ref.invalidate(salesListProvider);
      _ref.invalidate(medicinesListProvider);
      _ref.invalidate(allBatchesProvider);
      _ref.invalidate(customersListProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final voidSaleProvider = StateNotifierProvider<VoidSaleNotifier, AsyncValue<void>>((ref) {
  final repo = ref.watch(salesRepositoryProvider);
  return VoidSaleNotifier(repo, ref);
});
